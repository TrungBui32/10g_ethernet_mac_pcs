module rx_mac #(
    parameter AXIS_DATA_WIDTH = 64,
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
    
    localparam FIFO_DATA_WIDTH = AXIS_DATA_WIDTH + AXIS_DATA_BYTES + 1;
    localparam FIFO_DEPTH = 512; 
    localparam FIFO_ADDR_WIDTH = $clog2(FIFO_DEPTH);
    
    localparam [3:0] IDLE_STATE = 4'd0;
    localparam [3:0] PREAMBLE_STATE = 4'd1;
    localparam [3:0] MAC_HEADER_STATE = 4'd2;
    localparam [3:0] PAYLOAD_STATE = 4'd3;
    localparam [3:0] FCS_STATE = 4'd4;
    localparam [3:0] FRAME_COMPLETE_STATE = 4'd5;
    localparam [3:0] ERROR_STATE = 4'd6;
    localparam [3:0] DISCARD_STATE = 4'd7;
    
    reg [3:0] current_state, next_state;
    reg [11:0] byte_counter;
    reg [15:0] frame_byte_count;
    reg [3:0] preamble_count;
    
    reg fifo_wr_en;
    reg fifo_rd_en;
    wire [FIFO_DATA_WIDTH-1:0] fifo_rd_data;
    reg [FIFO_DATA_WIDTH-1:0] fifo_wr_data;
    wire fifo_empty;
    wire fifo_full;
    wire fifo_almost_full;
    
    reg frame_in_progress;
    reg frame_receiving;
    reg [15:0] payload_length;
    reg sfd_found;
    reg terminate_found;
    reg error_found;
    
    reg [AXIS_DATA_WIDTH-1:0] output_data;
    reg [AXIS_DATA_BYTES-1:0] output_keep;
    reg output_last;
    reg [31:0] data_buffer;
    reg [7:0] buffer_bytes;
    reg buffer_valid;
    
    wire [31:0] crc_out;
    reg crc_reset;
    reg [31:0] crc_data_in;
    reg [3:0] crc_valid_in;
    reg crc_enable;
    reg [31:0] received_crc;
    reg [3:0] crc_byte_count;
    
    reg [7:0] mac_header [0:MAC_HEADER_SIZE-1];
    reg [3:0] mac_header_index;
    reg mac_header_complete;
    
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
            next_state <= IDLE_STATE;
            byte_counter <= 0;
            frame_byte_count <= 0;
            preamble_count <= 0;
            frame_in_progress <= 1'b0;
            frame_receiving <= 1'b0;
            sfd_found <= 1'b0;
            terminate_found <= 1'b0;
            error_found <= 1'b0;
            payload_length <= 0;
            crc_reset <= 1'b1;
            crc_enable <= 1'b0;
            crc_byte_count <= 0;
            received_crc <= 0;
            mac_header_index <= 0;
            mac_header_complete <= 1'b0;
            frame_too_short <= 1'b0;
            frame_too_long <= 1'b0;
            alignment_error <= 1'b0;
            data_buffer <= 0;
            buffer_bytes <= 0;
            buffer_valid <= 1'b0;
            fifo_wr_en <= 1'b0;
            fifo_wr_data <= 0;
            frame_valid <= 1'b0;
            frame_error <= 1'b0;
            crc_error <= 1'b0;
            start_found <= 1'b0;
            terminate_detected <= 1'b0;
            error_detected <= 1'b0;
        end else begin
            current_state <= next_state;
            
            case (current_state)
                IDLE_STATE: begin
                    frame_in_progress <= 1'b0;
                    frame_receiving <= 1'b0;
                    sfd_found <= 1'b0;
                    terminate_found <= 1'b0;
                    error_found <= 1'b0;
                    byte_counter <= 0;
                    frame_byte_count <= 0;
                    preamble_count <= 0;
                    payload_length <= 0;
                    crc_reset <= 1'b1;
                    crc_enable <= 1'b0;
                    crc_byte_count <= 0;
                    received_crc <= 0;
                    mac_header_index <= 0;
                    mac_header_complete <= 1'b0;
                    frame_too_short <= 1'b0;
                    frame_too_long <= 1'b0;
                    alignment_error <= 1'b0;
                    data_buffer <= 0;
                    buffer_bytes <= 0;
                    buffer_valid <= 1'b0;
                    fifo_wr_en <= 1'b0;
                    frame_valid <= 1'b0;
                    frame_error <= 1'b0;
                    crc_error <= 1'b0;
                    start_found <= 1'b0;
                    
                    for (i = 0; i < XGMII_DATA_BYTES; i = i + 1) begin
                        if (!start_found && in_xgmii_ctl[i] && in_xgmii_data[i*8 +: 8] == XGMII_START) begin
                            next_state <= PREAMBLE_STATE;
                            frame_in_progress <= 1'b1;
                            byte_counter <= i + 1; 
                            start_found <= 1'b1;
                        end
                    end
                end
                
                PREAMBLE_STATE: begin
                    crc_reset <= 1'b1; 
                    for (i = 0; i < XGMII_DATA_BYTES; i = i + 1) begin
                        if (byte_counter + i < XGMII_DATA_BYTES && !sfd_found && !error_found) begin
                            if (!in_xgmii_ctl[byte_counter + i]) begin
                                if (in_xgmii_data[(byte_counter + i)*8 +: 8] == PREAMBLE_BYTE) begin
                                    preamble_count <= preamble_count + 1;
                                end else if (in_xgmii_data[(byte_counter + i)*8 +: 8] == SFD_BYTE) begin
                                    sfd_found <= 1'b1;
                                    next_state <= MAC_HEADER_STATE;
                                    byte_counter <= (byte_counter + i + 1) % XGMII_DATA_BYTES;
                                    crc_reset <= 1'b0; 
                                    crc_enable <= 1'b1;
                                end else begin
                                    next_state <= ERROR_STATE;
                                    error_found <= 1'b1;
                                end
                            end else begin
                                if (in_xgmii_data[(byte_counter + i)*8 +: 8] == XGMII_ERROR) begin
                                    next_state <= ERROR_STATE;
                                    error_found <= 1'b1;
                                end
                            end
                        end
                    end
                    if (preamble_count >= 7 && !sfd_found) begin
                        next_state <= ERROR_STATE;
                        alignment_error <= 1'b1;
                    end
                    
                    if (next_state == MAC_HEADER_STATE || next_state == ERROR_STATE) begin
                        byte_counter <= 0;
                    end else begin
                        byte_counter <= (byte_counter + XGMII_DATA_BYTES) % 8;
                    end
                end
                
                MAC_HEADER_STATE: begin
                    crc_enable <= 1'b1;
                    error_detected <= 1'b0;
                    for (i = 0; i < XGMII_DATA_BYTES; i = i + 1) begin
                        if (!error_detected) begin
                            if (!in_xgmii_ctl[i]) begin
                                if (mac_header_index < MAC_HEADER_SIZE) begin
                                    mac_header[mac_header_index] <= in_xgmii_data[i*8 +: 8];
                                    mac_header_index <= mac_header_index + 1;
                                    crc_data_in[i*8 +: 8] <= in_xgmii_data[i*8 +: 8];
                                    crc_valid_in[i] <= 1'b1;
                                end
                            end else begin
                                if (in_xgmii_data[i*8 +: 8] == XGMII_ERROR) begin
                                    next_state <= ERROR_STATE;
                                    error_found <= 1'b1;
                                    error_detected <= 1'b1;
                                end else if (in_xgmii_data[i*8 +: 8] == XGMII_TERMINATE) begin
                                    next_state <= ERROR_STATE;
                                    frame_too_short <= 1'b1;
                                    error_detected <= 1'b1;
                                end
                            end
                        end
                    end
                    
                    frame_byte_count <= frame_byte_count + XGMII_DATA_BYTES;
                    
                    if (mac_header_index >= MAC_HEADER_SIZE) begin
                        mac_header_complete <= 1'b1;
                        next_state <= PAYLOAD_STATE;
                        frame_receiving <= 1'b1;
                        fifo_wr_en <= 1'b1;
                        if (AXIS_DATA_WIDTH == 32) begin
                            fifo_wr_data <= {1'b0, 4'b1111, mac_header[3], mac_header[2], mac_header[1], mac_header[0]};
                        end else begin 
                            fifo_wr_data <= {1'b0, 8'b11111111, 
                                           mac_header[7], mac_header[6], mac_header[5], mac_header[4],
                                           mac_header[3], mac_header[2], mac_header[1], mac_header[0]};
                        end
                    end
                end
                
                PAYLOAD_STATE: begin
                    crc_enable <= 1'b1;
                    fifo_wr_en <= 1'b0;
                    terminate_detected <= 1'b0;
                    error_detected <= 1'b0;
                    terminate_found <= 1'b0;
                    for (i = 0; i < XGMII_DATA_BYTES; i = i + 1) begin
                        if (!terminate_detected && !error_detected && in_xgmii_ctl[i]) begin
                            if (in_xgmii_data[i*8 +: 8] == XGMII_TERMINATE) begin
                                terminate_found <= 1'b1;
                                byte_counter <= i; 
                                next_state <= FCS_STATE;
                                terminate_detected <= 1'b1;
                            end else if (in_xgmii_data[i*8 +: 8] == XGMII_ERROR) begin
                                next_state <= ERROR_STATE;
                                error_found <= 1'b1;
                                error_detected <= 1'b1;
                            end
                        end
                    end
                    
                    if (!terminate_found && !error_found) begin
                        crc_data_in <= in_xgmii_data;
                        crc_valid_in <= ~in_xgmii_ctl; 
                        if (!fifo_full) begin
                            fifo_wr_en <= 1'b1;
                            if (AXIS_DATA_WIDTH == 32) begin
                                fifo_wr_data <= {1'b0, ~in_xgmii_ctl, in_xgmii_data};
                            end else begin
                                if (buffer_valid) begin
                                    fifo_wr_data <= {1'b0, 8'b11111111, in_xgmii_data, data_buffer};
                                    buffer_valid <= 1'b0;
                                end else begin
                                    data_buffer <= in_xgmii_data;
                                    buffer_valid <= 1'b1;
                                    fifo_wr_en <= 1'b0;
                                end
                            end
                        end
                    end
                    
                    frame_byte_count <= frame_byte_count + XGMII_DATA_BYTES;
                    payload_length <= payload_length + XGMII_DATA_BYTES;
                    if (frame_byte_count > MAX_FRAME_SIZE) begin
                        next_state <= ERROR_STATE;
                        frame_too_long <= 1'b1;
                    end
                end
                
                FCS_STATE: begin
                    crc_enable <= 1'b0;
                    if (byte_counter >= 4) begin
                        for (i = 0; i < 4; i = i + 1) begin
                            received_crc[i*8 +: 8] <= in_xgmii_data[(byte_counter - 4 + i)*8 +: 8];
                        end
                    end else begin
                        received_crc <= in_xgmii_data;
                    end
                    
                    next_state <= FRAME_COMPLETE_STATE;
                end
                
                FRAME_COMPLETE_STATE: begin
                    frame_in_progress <= 1'b0;
                    frame_receiving <= 1'b0;
                    if ({received_crc[7:0], received_crc[15:8], received_crc[23:16], received_crc[31:24]} != crc_out) begin
                        crc_error <= 1'b1;
                        frame_error <= 1'b1;
                        next_state <= DISCARD_STATE;
                    end else if (frame_too_short || frame_too_long || alignment_error) begin
                        frame_error <= 1'b1;
                        next_state <= DISCARD_STATE;
                    end else if (payload_length < MIN_PAYLOAD_SIZE) begin
                        frame_too_short <= 1'b1;
                        frame_error <= 1'b1;
                        next_state <= DISCARD_STATE;
                    end else begin
                        frame_valid <= 1'b1;
                        
                        // Mark last word in FIFO
                        if (buffer_valid && AXIS_DATA_WIDTH == 64) begin
                            fifo_wr_en <= 1'b1;
                            fifo_wr_data <= {1'b1, 8'b11110000, 32'h0, data_buffer}; 
                            buffer_valid <= 1'b0;
                        end
                        
                        next_state <= IDLE_STATE;
                    end
                end
                
                ERROR_STATE: begin
                    frame_error <= 1'b1;
                    next_state <= DISCARD_STATE;
                end
                
                DISCARD_STATE: begin
                    buffer_valid <= 1'b0;
                    fifo_wr_en <= 1'b0;
                    next_state <= IDLE_STATE;
                end
                
                default: next_state <= IDLE_STATE;
            endcase
        end
    end
    
    always @(posedge rx_clk) begin
        if (!rx_rst) begin
            out_master_rx_tdata <= 0;
            out_master_rx_tkeep <= 0;
            out_master_rx_tvalid <= 1'b0;
            out_master_rx_tlast <= 1'b0;
            fifo_rd_en <= 1'b0;
        end else begin
            fifo_rd_en <= 1'b0;
            
            if (!fifo_empty && in_master_rx_tready && frame_valid) begin
                fifo_rd_en <= 1'b1;
                out_master_rx_tdata <= fifo_rd_data[AXIS_DATA_WIDTH-1:0];
                out_master_rx_tkeep <= fifo_rd_data[FIFO_DATA_WIDTH-2:AXIS_DATA_WIDTH];
                out_master_rx_tlast <= fifo_rd_data[FIFO_DATA_WIDTH-1];
                out_master_rx_tvalid <= 1'b1;
            end else if (!in_master_rx_tready || fifo_empty) begin
                out_master_rx_tvalid <= 1'b0;
                out_master_rx_tlast <= 1'b0;
            end
        end
    end
    
    sync_fifo #(
        .DATA_WIDTH(FIFO_DATA_WIDTH),
        .ADDR_WIDTH(FIFO_ADDR_WIDTH),
        .FIFO_DEPTH(FIFO_DEPTH)
    ) frame_buffer (
        .clk(rx_clk),
        .rst(rx_rst),
        .wr_en(fifo_wr_en),
        .wr_data(fifo_wr_data),
        .rd_en(fifo_rd_en),
        .rd_data(fifo_rd_data),
        .full(fifo_full),
        .empty(fifo_empty),
        .almost_full(fifo_almost_full)
    );
    
    slicing_crc #(
        .SLICE_LENGTH(4),
        .INITIAL_CRC(32'hFFFFFFFF),    
        .INVERT_OUTPUT(1),             
        .REGISTER_OUTPUT(0)   
    ) ethernet_crc (
        .i_clk(rx_clk),
        .i_reset(crc_reset),
        .i_data(crc_data_in),
        .i_valid(crc_valid_in),
        .o_crc(crc_out)
    );
    
endmodule