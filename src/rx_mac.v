module rx_mac #(
    parameter AXIS_DATA_WIDTH = 32,
    parameter AXIS_DATA_BYTES = AXIS_DATA_WIDTH/8,
    parameter XGMII_DATA_WIDTH = 32,
    parameter XGMII_DATA_BYTES = XGMII_DATA_WIDTH/8
) (
    input rx_clk,
    input rx_rst,
    
    input [XGMII_DATA_WIDTH-1:0] in_xgmii_data,
    input [XGMII_DATA_BYTES-1:0] in_xgmii_ctl,
    output reg out_xgmii_pcs_ready,
    
    output reg [AXIS_DATA_WIDTH-1:0] out_master_rx_tdata,
    output reg [AXIS_DATA_BYTES-1:0] out_master_rx_tkeep,
    output reg out_master_rx_tvalid,
    output reg out_master_rx_tlast,
    input in_master_rx_tready,
    
    output reg frame_valid,
    output reg frame_error,
    output reg crc_error
);

    localparam XGMII_IDLE = 8'h07;        
    localparam XGMII_START = 8'hFB;     
    localparam XGMII_TERMINATE = 8'hFD;   
    localparam XGMII_ERROR = 8'hFE;      
    localparam XGMII_SEQUENCE = 8'h9C;    
    localparam XGMII_SIGNAL = 8'h5C;     
    
    localparam PREAMBLE_BYTE = 8'h55;    
    localparam SFD_BYTE = 8'hD5;         
    
    localparam MIN_FRAME_SIZE = 64;       
    localparam MAX_FRAME_SIZE = 1518;     
    localparam MIN_PAYLOAD_SIZE = 46;     
    localparam MAX_PAYLOAD_SIZE = 1500;  
    localparam PREAMBLE_SFD_SIZE = 8;     
    localparam MAC_HEADER_SIZE = 14;      
    localparam FCS_SIZE = 4;              
    
    localparam [3:0] IDLE_STATE = 4'd0;
    localparam [3:0] PREAMBLE_STATE = 4'd1;
    localparam [3:0] MAC_HEADER_STATE = 4'd2;
    localparam [3:0] PAYLOAD_STATE = 4'd3;
    localparam [3:0] FCS_STATE = 4'd4;
    localparam [3:0] FRAME_COMPLETE_STATE = 4'd5;
    localparam [3:0] ERROR_STATE = 4'd6;
    localparam [3:0] DISCARD_STATE = 4'd7;
    localparam [3:0] TERMINATE_STATE = 4'd8;
    
    reg [3:0] current_state;
    reg [11:0] byte_counter;
    reg [15:0] frame_byte_count;
    reg [3:0] preamble_count;
    
    reg frame_in_progress;
    reg frame_receiving;
    reg [15:0] payload_length;
    
    wire [31:0] crc_out;
    reg crc_reset;
    reg [31:0] crc_data_in;
    reg [3:0] crc_valid_in;
    reg [31:0] received_crc;
    
    reg [7:0] mac_header [0:MAC_HEADER_SIZE-1];
    reg [3:0] mac_header_index;
    reg mac_header_complete;
	
	reg [AXIS_DATA_WIDTH-1:0] received_data1;
	reg [AXIS_DATA_BYTES-1:0] received_ctl1;
	reg received_valid1;
	reg [AXIS_DATA_WIDTH-1:0] received_data2;
	reg [AXIS_DATA_BYTES-1:0] received_ctl2;
	reg received_valid2;
    
    reg frame_too_short;
    reg frame_too_long;
    reg alignment_error;
    
    reg start_found;
    reg terminate_detected;
    reg error_detected;
    
    integer i;
    
    always @(posedge rx_clk) begin
        if (!rx_rst) begin
            out_xgmii_pcs_ready <= 1'b0;
        end else begin
            out_xgmii_pcs_ready <= 1'b1; 
        end
    end
    
    always @(posedge rx_clk) begin
        if (!rx_rst) begin
            current_state <= IDLE_STATE;
            byte_counter <= 0;
            frame_byte_count <= 0;
            preamble_count <= 0;
            frame_in_progress <= 1'b0;
            frame_receiving <= 1'b0;
            payload_length <= 0;
            crc_reset <= 1'b1;
            mac_header_complete <= 1'b0;
            frame_too_short <= 1'b0;
            frame_too_long <= 1'b0;
            alignment_error <= 1'b0;
            frame_valid <= 1'b0;
            frame_error <= 1'b0;
            crc_error <= 1'b0;
            start_found <= 1'b0;
            terminate_detected <= 1'b0;
            error_detected <= 1'b0;
        end else begin
            case (current_state)
                IDLE_STATE: begin
                    frame_in_progress <= 1'b0;
                    frame_receiving <= 1'b0;
                    byte_counter <= 0;
                    frame_byte_count <= 0;
                    preamble_count <= 0;
                    payload_length <= 0;
                    crc_reset <= 1'b1;
                    received_crc <= 0;
                    mac_header_index <= 0;
                    mac_header_complete <= 1'b0;
                    frame_too_short <= 1'b0;
                    frame_too_long <= 1'b0;
                    alignment_error <= 1'b0;
                    frame_valid <= 1'b0;
                    frame_error <= 1'b0;
                    crc_error <= 1'b0;
                    start_found <= 1'b0;	// maybe delete 
					
					if(in_xgmii_ctl[0] && in_xgmii_data[7:0] == XGMII_START) begin
						if(	(!in_xgmii_ctl[1] && in_xgmii_data[15:8] == PREAMBLE_BYTE) &&
							(!in_xgmii_ctl[2] && in_xgmii_data[23:16] == PREAMBLE_BYTE) &&
							(!in_xgmii_ctl[3] && in_xgmii_data[31:24] == PREAMBLE_BYTE)) begin 
							current_state <= PREAMBLE_STATE;
							frame_byte_count <= frame_byte_count + 4;
						end else begin
							frame_error <= 1'b1;
						end
					end else begin
						current_state <= IDLE_STATE;
						received_data2 <= in_xgmii_data;
						received_ctl2 <= in_xgmii_ctl;
						received_valid2 <= 1'b0;
						received_data1 <= received_data2;
						received_ctl1 <= received_ctl2;
						received_valid1 <= received_valid2;
					end
                end
                
                PREAMBLE_STATE: begin
                    crc_reset <= 1'b1; 
					
					if(	(!in_xgmii_ctl[0] && in_xgmii_data[7:0] == PREAMBLE_BYTE) &&
						(!in_xgmii_ctl[1] && in_xgmii_data[15:8] == PREAMBLE_BYTE) &&
						(!in_xgmii_ctl[2] && in_xgmii_data[23:16] == PREAMBLE_BYTE) &&
						(!in_xgmii_ctl[3] && in_xgmii_data[31:24] == SFD_BYTE)) begin 
						current_state <= MAC_HEADER_STATE;
						frame_byte_count = frame_byte_count + 4;
					end else begin
						frame_error <= 1'b1;
					end
                end
                
                MAC_HEADER_STATE: begin
                    error_detected <= 1'b0;
					
					case(byte_counter)
						0: begin
							crc_data_in <= in_xgmii_data;
							crc_valid_in <= 4'b1111;
							byte_counter <= byte_counter + 4;
							frame_byte_count <= frame_byte_count + 4;
						end 
						4: begin
							crc_data_in <= in_xgmii_data;
							crc_valid_in <= 4'b1111;
							byte_counter <= byte_counter + 4;
							frame_byte_count <= frame_byte_count + 4;
						end
						8: begin
							crc_data_in <= in_xgmii_data;
							crc_valid_in <= 4'b1111;
							byte_counter <= byte_counter + 4;
							frame_byte_count <= frame_byte_count + 4;
						end
						12: begin
							crc_data_in <= in_xgmii_data;
							crc_valid_in <= 4'b0011;
							byte_counter <= byte_counter + 2;
							frame_byte_count <= frame_byte_count + 2;
							current_state <= PAYLOAD_STATE;
						end						
					endcase 
                end
                
                PAYLOAD_STATE: begin
                    terminate_detected <= 1'b0;
                    error_detected <= 1'b0;
					
					if(received_valid1) begin
						if (received_data2[31:24] == XGMII_TERMINATE) begin
							received_crc <= received_data1;
							current_state <= FCS_STATE;
						end else begin
							 received_data1 <= received_data2;
							 received_ctl1 <= received_ctl2;
							 received_data2 <= in_xgmii_data;
							 received_ctl2 <= in_xgmii_ctl;
						end
					end else begin 
						received_data2 <= in_xgmii_data;
						received_ctl2 <= in_xgmii_ctl;
						received_valid2 <= 1'b1;
						received_data1 <= received_data2;
						received_ctl1 <= received_ctl2;
						received_valid1 <= received_valid2;
					end
                end 
                
                FCS_STATE: begin
                    frame_in_progress <= 1'b0;
                    frame_receiving <= 1'b0;
                    if ({received_crc[7:0], received_crc[15:8], received_crc[23:16], received_crc[31:24]} != crc_out) begin
                        crc_error <= 1'b1;
                        frame_error <= 1'b1;
                        current_state <= IDLE_STATE;
                    end else if (frame_too_short || frame_too_long || alignment_error) begin
                        frame_error <= 1'b1;
                        current_state <= DISCARD_STATE;
                    end else if (payload_length < MIN_PAYLOAD_SIZE) begin
                        frame_too_short <= 1'b1;
                        frame_error <= 1'b1;
                        current_state <= DISCARD_STATE;
                    end else begin
                        frame_valid <= 1'b1;         
                        terminate_detected <= 1'b0;               
                        current_state <= TERMINATE_STATE;
                    end
                end
                
                ERROR_STATE: begin
                    frame_error <= 1'b1;
                    current_state <= DISCARD_STATE;
                end
                
                DISCARD_STATE: begin
                    current_state <= IDLE_STATE;
                end
                
                TERMINATE_STATE: begin
                    terminate_detected <= 1'b0;
                    current_state <= IDLE_STATE;
                end
                
                default: current_state <= IDLE_STATE;
            endcase
        end
    end
    
    always @(posedge rx_clk) begin
        if (!rx_rst) begin
            out_master_rx_tdata <= 0;
            out_master_rx_tkeep <= 0;
            out_master_rx_tvalid <= 1'b0;
            out_master_rx_tlast <= 1'b0;
        end else begin
            if (received_valid1) begin
                out_master_rx_tdata <= received_data1;
                out_master_rx_tkeep <= received_ctl1;
                out_master_rx_tvalid <= 1'b1;
            end else begin
                out_master_rx_tvalid <= 1'b0;
            end
            out_master_rx_tlast <= terminate_detected;
        end
    end
    
    crc32 #(
        .SLICE_LENGTH(4),
        .INITIAL_CRC(32'hFFFFFFFF),    
        .INVERT_OUTPUT(1),             
        .REGISTER_OUTPUT(0)   
    ) crc (
        .clk(rx_clk),
        .rst(crc_reset),
        .in_data(crc_data_in),
        .in_valid(crc_valid_in),
        .out_crc(crc_out)
    );
    
endmodule
