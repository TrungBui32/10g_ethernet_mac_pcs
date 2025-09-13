module tx_mac #(
    parameter AXIS_DATA_WIDTH = 32,
    parameter AXIS_DATA_BYTES = AXIS_DATA_WIDTH/8,
    parameter XGMII_DATA_WIDTH = 32,
    parameter XGMII_DATA_BYTES = XGMII_DATA_WIDTH/8
) (
    input tx_clk,
    input tx_rst,
    
    // AXIS
    input [AXIS_DATA_WIDTH-1:0] in_slave_tx_tdata,
    input [AXIS_DATA_BYTES-1:0] in_slave_tx_tkeep,
    input in_slave_tx_tvalid,
    input in_slave_tx_tlast,
    output reg out_slave_tx_tready,
    
    // XGMII
    output reg [XGMII_DATA_WIDTH-1:0] out_xgmii_data,
    output reg [XGMII_DATA_BYTES-1:0] out_xgmii_ctl,
    input in_xgmii_pcs_ready
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
    localparam IFG_SIZE = 12;            
    
    localparam [47:0] DEST_MAC = 48'h00_11_22_33_44_55;
    localparam [47:0] SRC_MAC  = 48'hAA_BB_CC_DD_EE_FF;
    localparam [15:0] ETHER_TYPE = 16'h0800; 
    
    localparam FIFO_DATA_WIDTH = AXIS_DATA_WIDTH + AXIS_DATA_BYTES; 
    localparam FIFO_DEPTH = 512; 
    localparam FIFO_ADDR_WIDTH = $clog2(FIFO_DEPTH);
    
    localparam [3:0] IDLE_STATE = 4'd0;
    localparam [3:0] PREAMBLE_STATE = 4'd1;
    localparam [3:0] MAC_HEADER_STATE = 4'd2;
    localparam [3:0] PAYLOAD_STATE = 4'd3;
    localparam [3:0] PAD_STATE = 4'd4;
    localparam [3:0] FCS_STATE = 4'd5;
	localparam [3:0] TERMINATE_STATE = 4'd6;
    localparam [3:0] IFG_STATE = 4'd7;
    localparam [3:0] ERROR_STATE = 4'd8;
    
    reg [3:0] current_state, next_state;
    reg [11:0] byte_counter;
    reg [15:0] frame_byte_count;
    
    reg fifo_wr_en;
    reg fifo_rd_en;
    wire [FIFO_DATA_WIDTH-1:0] fifo_rd_data;
    reg [FIFO_DATA_WIDTH-1:0] fifo_wr_data;
    wire fifo_empty;
    wire fifo_full;
    wire [AXIS_DATA_WIDTH-1:0] fifo_tdata;
    wire [AXIS_DATA_BYTES-1:0] fifo_tkeep;
    
    assign fifo_tdata = fifo_rd_data[AXIS_DATA_WIDTH-1:0];
    assign fifo_tkeep = fifo_rd_data[FIFO_DATA_WIDTH-1:AXIS_DATA_WIDTH];
    
    reg frame_in_progress;
    reg frame_complete;
    reg frame_complete_clear;  
    reg frame_error;
    reg [15:0] payload_length;
    reg [7:0] pad_bytes_required;
    
    reg [AXIS_DATA_WIDTH-1:0] current_data;
    reg [AXIS_DATA_BYTES-1:0] current_keep;
    reg data_valid;
    reg [3:0] data_byte_index;
    reg last_word;
    
    wire [31:0] crc_out;
    reg crc_reset;
    reg [31:0] crc_data_in;
    reg [3:0] crc_valid_in;
    reg crc_enable;
    
    reg [7:0] mac_header [0:MAC_HEADER_SIZE-1];
    initial begin
        mac_header[0]  = DEST_MAC[47:40]; 
        mac_header[1]  = DEST_MAC[39:32]; 
        mac_header[2]  = DEST_MAC[31:24]; 
        mac_header[3]  = DEST_MAC[23:16]; 
        mac_header[4]  = DEST_MAC[15:8];  
        mac_header[5]  = DEST_MAC[7:0];   
        mac_header[6]  = SRC_MAC[47:40];  
        mac_header[7]  = SRC_MAC[39:32];  
        mac_header[8]  = SRC_MAC[31:24];  
        mac_header[9]  = SRC_MAC[23:16];  
        mac_header[10] = SRC_MAC[15:8];  
        mac_header[11] = SRC_MAC[7:0];   
        mac_header[12] = ETHER_TYPE[15:8]; 
        mac_header[13] = ETHER_TYPE[7:0];  
    end
    
    integer i, j;
    
    always @(posedge tx_clk) begin
        if (!tx_rst) begin 
            out_slave_tx_tready <= 1'b0;
            fifo_wr_en <= 1'b0;
            fifo_wr_data <= 0;
            frame_in_progress <= 1'b0;
            frame_complete <= 1'b0;
            frame_error <= 1'b0;
            payload_length <= 0;
        end else begin 
            fifo_wr_en <= 1'b0;
            out_slave_tx_tready <= !fifo_full; 
            if (frame_complete_clear) begin
                frame_complete <= 1'b0;
            end
            if (out_slave_tx_tready && in_slave_tx_tvalid) begin
                fifo_wr_en <= 1'b1;
                fifo_wr_data <= {in_slave_tx_tkeep, in_slave_tx_tdata};
                if (!frame_in_progress) begin
                    frame_in_progress <= 1'b1;
                    payload_length <= 0;
                    frame_error <= 1'b0;
                end
				
                for (i = 0; i < AXIS_DATA_BYTES; i = i + 1) begin
                    if (in_slave_tx_tkeep[i]) begin
                        payload_length <= payload_length + 1;
                    end
                end
				
                if (in_slave_tx_tlast) begin
                    frame_in_progress <= 1'b0;
                    frame_complete <= 1'b1;
                    if (payload_length < MIN_PAYLOAD_SIZE) begin
                        pad_bytes_required <= MIN_PAYLOAD_SIZE - payload_length[7:0];
                    end else if (payload_length > MAX_PAYLOAD_SIZE) begin
                        frame_error <= 1'b1; 
                    end else begin
                        pad_bytes_required <= 0;
                    end
                end
            end
        end
    end
    
    always @(posedge tx_clk) begin
        if (!tx_rst) begin 
            current_state <= IDLE_STATE;
            next_state <= IDLE_STATE;
            byte_counter <= 0;
            frame_byte_count <= 0;
            out_xgmii_data <= {XGMII_DATA_BYTES{XGMII_IDLE}};
            out_xgmii_ctl <= {XGMII_DATA_BYTES{1'b1}};
            fifo_rd_en <= 1'b0;
            crc_reset <= 1'b1;
            crc_enable <= 1'b0;
            current_data <= 0;
            current_keep <= 0;
            data_valid <= 1'b0;
            data_byte_index <= 0;
            last_word <= 1'b0;
            frame_complete_clear <= 1'b0;
        end else begin 
            current_state <= next_state;
            frame_complete_clear <= 1'b0; 
            
            if (in_xgmii_pcs_ready) begin
                case (current_state)
                    IDLE_STATE: begin
                        out_xgmii_data <= {XGMII_DATA_BYTES{XGMII_IDLE}};
                        out_xgmii_ctl <= {XGMII_DATA_BYTES{1'b1}};
                        byte_counter <= 0;
                        frame_byte_count <= 0;
                        crc_reset <= 1'b1;
                        crc_enable <= 1'b0;
                        data_valid <= 1'b0;
                        data_byte_index <= 0;
                        fifo_rd_en <= 1'b0;
                        if (frame_complete && !frame_error && !fifo_empty) begin		// consider add a signal check fifo working (controversal due to continuos insertion)
                            next_state <= PREAMBLE_STATE;
                            frame_complete_clear <= 1'b1; 
                        end
                    end
                    
                    PREAMBLE_STATE: begin
                        crc_reset <= 1'b1; 
                        
                        case (byte_counter)
                            0: begin
                                out_xgmii_data <= {{3{PREAMBLE_BYTE}}, XGMII_START};
                                out_xgmii_ctl <= 4'b0001; 
                                byte_counter <= byte_counter + 4;
                            end
                            4: begin
                                out_xgmii_data <= {4{PREAMBLE_BYTE}};
                                out_xgmii_ctl <= 4'b0000; 
                                byte_counter <= 0;
                                next_state <= MAC_HEADER_STATE;
                                crc_reset <= 1'b0; 
                                crc_enable <= 1'b1;
                            end
                        endcase
                    end
                    
                    MAC_HEADER_STATE: begin
                        crc_enable <= 1'b1;
                        out_xgmii_ctl <= 4'b0000;
                        
                        case (byte_counter)
                            0: begin
                                out_xgmii_data <= {mac_header[2], mac_header[1], mac_header[0], SFD_BYTE};
                                crc_data_in <= {mac_header[2], mac_header[1], mac_header[0], SFD_BYTE};
                                crc_valid_in <= 4'b1111;
                                byte_counter <= byte_counter + 4;
                            end 
                            4: begin
                                out_xgmii_data <= {mac_header[6], mac_header[5], mac_header[4], mac_header[3]};
                                crc_data_in <= {mac_header[6], mac_header[5], mac_header[4], mac_header[3]};
                                crc_valid_in <= 4'b1111;
                                byte_counter <= byte_counter + 4;
                            end
                            8: begin
                                out_xgmii_data <= {mac_header[10], mac_header[9], mac_header[8], mac_header[7]};
                                crc_data_in <= {mac_header[10], mac_header[9], mac_header[8], mac_header[7]};
                                crc_valid_in <= 4'b1111;
                                byte_counter <= byte_counter + 4;
                            end
                            12: begin
                                out_xgmii_data <= {8'h00, mac_header[13], mac_header[12], mac_header[11]};
                                crc_data_in <= {8'h00, mac_header[13], mac_header[12], mac_header[11]};
                                crc_valid_in <= 4'b0111;
                                byte_counter <= 0;
                                next_state <= PAYLOAD_STATE;
                                
                                if (!fifo_empty) begin 			// consider add condition !fifo_in_progress or add finished
                                    fifo_rd_en <= 1'b1;
                                end else if (pad_bytes_required > 0) begin
                                    next_state <= PAD_STATE;
                                end else begin
                                    next_state <= FCS_STATE;
                                end
                            end
                        endcase
                        frame_byte_count <= frame_byte_count + 4;
                    end
                    
                    PAYLOAD_STATE: begin
                        crc_enable <= 1'b1;
                        out_xgmii_ctl <= 4'b0000;
                        
                        if (fifo_rd_en) begin
                            current_data <= fifo_tdata;
                            current_keep <= fifo_tkeep;
                            data_valid <= 1'b1;
                            data_byte_index <= 0;
                            fifo_rd_en <= 1'b0;
                            last_word <= fifo_empty; 
                        end
                        
                        if (data_valid) begin
                            out_xgmii_data <= current_data;
                            crc_data_in <= current_data;
                            crc_valid_in <= current_keep;
                            data_valid <= 1'b1;
                                    
                            if (!last_word && !fifo_empty) begin
                                fifo_rd_en <= 1'b1;
							end else begin
                                if (pad_bytes_required > 0) begin
                                    next_state <= PAD_STATE;
                                end else begin
                                    next_state <= FCS_STATE;
                                    crc_enable <= 1'b0;
                                end
							end
                        end
                        frame_byte_count <= frame_byte_count + 4;
                    end
                    
                    PAD_STATE: begin
                        crc_enable <= 1'b1;
                        out_xgmii_ctl <= 4'b0000;
                        out_xgmii_data <= 32'h00000000;
                        crc_data_in <= 32'h00000000;
                        
                        if (byte_counter + 4 >= pad_bytes_required) begin
                            case (pad_bytes_required - byte_counter)
                                1: crc_valid_in <= 4'b0001;
                                2: crc_valid_in <= 4'b0011;
                                3: crc_valid_in <= 4'b0111;
                                default: crc_valid_in <= 4'b1111;
                            endcase
                            next_state <= FCS_STATE;
                            crc_enable <= 1'b0;
                            byte_counter <= 0;
                        end else begin
                            crc_valid_in <= 4'b1111;
                            byte_counter <= byte_counter + 4;
                        end
                        frame_byte_count <= frame_byte_count + 4;
                    end
                    
                    FCS_STATE: begin
                        out_xgmii_data <= {crc_out[7:0], crc_out[15:8], crc_out[23:16], crc_out[31:24]};		// consider add crc_finish signal
                        out_xgmii_ctl <= 4'b0000;
                        crc_enable <= 1'b0;
                        byte_counter <= 0;
                        next_state <= TERMINATE_STATE;
                        frame_byte_count <= frame_byte_count + 4;
                    end
                    
					TERMINATE_STATE: begin
						out_xgmii_data <= {{3{XGMII_IDLE}}, XGMII_TERMINATE};
						out_xgmii_ctl <= 4'b1111;
						next_state <= IFG_STATE;
						frame_byte_count <= frame_byte_count + 1;
					end
					
                    IFG_STATE: begin
                        out_xgmii_data <= {XGMII_DATA_BYTES{XGMII_IDLE}};
                        out_xgmii_ctl <= {XGMII_DATA_BYTES{1'b1}};
                        
                        if (byte_counter >= IFG_SIZE - 4) begin
                            next_state <= IDLE_STATE;
                            byte_counter <= 0;
                        end else begin
                            byte_counter <= byte_counter + 4;
                        end
                    end
                    
                    ERROR_STATE: begin
                        out_xgmii_data <= {{3{XGMII_IDLE}}, XGMII_ERROR};
                        out_xgmii_ctl <= 4'b1001;
                        next_state <= IDLE_STATE;
                        frame_error <= 1'b0;
                    end
                    
                    default: next_state <= IDLE_STATE;
                endcase
            end 
        end
    end 
    
    sync_fifo #(
        .DATA_WIDTH(FIFO_DATA_WIDTH),
        .ADDR_WIDTH(FIFO_ADDR_WIDTH),
        .FIFO_DEPTH(FIFO_DEPTH)
    ) frame_buffer (
        .clk(tx_clk),
        .rst(tx_rst),
        .wr_en(fifo_wr_en),
        .wr_data(fifo_wr_data),
        .rd_en(fifo_rd_en),
        .rd_data(fifo_rd_data),
        .full(fifo_full),
        .empty(fifo_empty),
    );
    
    slicing_crc #(
        .SLICE_LENGTH(4),
        .INITIAL_CRC(32'hFFFFFFFF),    
        .INVERT_OUTPUT(1),             
        .REGISTER_OUTPUT(0)           
    ) ethernet_crc (
        .i_clk(tx_clk),
        .i_reset(crc_reset),
        .i_data(crc_data_in),
        .i_valid(crc_valid_in),
        .o_crc(crc_out)
    );
    
endmodule