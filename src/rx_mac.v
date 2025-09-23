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
    output out_master_rx_tlast,
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
    localparam [3:0] ERROR_STATE = 4'd4;
    localparam [3:0] DISCARD_STATE = 4'd5;
    localparam [3:0] TERMINATE_STATE = 4'd6;
    
    reg [3:0] current_state;
    reg [11:0] byte_counter;
    reg [15:0] frame_byte_count;
    
    wire [31:0] crc_out;
    reg crc_reset;
    reg [31:0] crc_data_in;
    reg [3:0] crc_valid_in;
    
	reg [AXIS_DATA_WIDTH-1:0] received_data;
	reg [AXIS_DATA_BYTES-1:0] received_ctl;
	reg received_valid;
    
    reg frame_too_short;
    reg frame_too_long;
    
    integer i;
    
    assign out_master_rx_tlast = (in_xgmii_data[31:24] == XGMII_TERMINATE);
    
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
            crc_reset <= 1'b0;
            frame_too_short <= 1'b0;
            frame_too_long <= 1'b0;
            frame_valid <= 1'b0;
            frame_error <= 1'b0;
            crc_error <= 1'b0;
        end else begin
            frame_too_short <= 1'b0;
            frame_too_long <= 1'b0;
            frame_valid <= 1'b0;
            frame_error <= 1'b0;
            crc_error <= 1'b0;
            case (current_state)
                IDLE_STATE: begin
                    byte_counter <= 0;
                    frame_byte_count <= 0;
                    crc_reset <= 1'b1;
					
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
						received_data <= 32'h00000000;
						received_ctl <= 4'h0000;
						received_valid <= 1'b0;
					end
                end
                
                PREAMBLE_STATE: begin
					
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
					if(received_valid) begin
						if (in_xgmii_data[31:24] == XGMII_TERMINATE) begin
							received_valid <= 1'b0;
							received_data <= 32'h00000000;
							received_ctl <= 4'h0000;
							crc_data_in <= 32'h00000000;
							crc_valid_in <= 4'b0000;
							
							if (received_data != crc_out) begin
                                crc_error <= 1'b1;
                                frame_error <= 1'b1;
                                current_state <= ERROR_STATE;
                            end else if (frame_byte_count > MAX_FRAME_SIZE) begin
                                frame_error <= 1'b1;
                                frame_too_long <= 1'b1;
                                current_state <= ERROR_STATE;
                            end else if (frame_byte_count < MIN_FRAME_SIZE) begin
                                frame_error <= 1'b1;
                                frame_too_short <= 1'b1;
                                current_state <= ERROR_STATE;
                            end else begin
                                frame_valid <= 1'b1;         
                                current_state <= TERMINATE_STATE;
                            end 
							
						end else begin
							 received_data <= in_xgmii_data;
							 received_ctl <= in_xgmii_ctl;
							 crc_data_in <= received_data;
							 crc_valid_in <= 4'b1111;
							 frame_byte_count <= frame_byte_count + 4;
						end
					end else begin 
						received_data <= in_xgmii_data;
						received_ctl <= in_xgmii_ctl;
						received_valid <= 1'b1;
						crc_valid_in <= 4'b0000;
					end
                end 
                
                ERROR_STATE: begin
                    frame_error <= 1'b1;
                    current_state <= IDLE_STATE;
                end
                
                TERMINATE_STATE: begin
                    current_state <= IDLE_STATE;
                    frame_byte_count <= 0;
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
        end else begin
            if (received_valid && !(in_xgmii_data[31:24] == XGMII_TERMINATE)) begin
                out_master_rx_tdata <= received_data;
                out_master_rx_tkeep <= received_ctl;
                out_master_rx_tvalid <= 1'b1;
            end else begin
                out_master_rx_tdata <= {4{XGMII_IDLE}};
                out_master_rx_tkeep <= 4'b1111;
                out_master_rx_tvalid <= 1'b0;
            end
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