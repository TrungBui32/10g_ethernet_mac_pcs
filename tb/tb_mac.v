module tb_mac;
    parameter AXIS_DATA_WIDTH = 32;
    parameter AXIS_DATA_BYTES = AXIS_DATA_WIDTH / 8;
    parameter XGMII_DATA_WIDTH = 32;
    parameter XGMII_DATA_BYTES = XGMII_DATA_WIDTH / 8;
    
    reg mac_clk;
    reg mac_rst;
    
    wire [XGMII_DATA_WIDTH-1:0] xgmii_tx_data;
    wire [XGMII_DATA_BYTES-1:0] xgmii_tx_ctl;
    reg xgmii_tx_pcs_ready;
    
    reg [XGMII_DATA_WIDTH-1:0] xgmii_rx_data;
    reg [XGMII_DATA_BYTES-1:0] xgmii_rx_ctl;
    wire xgmii_rx_pcs_ready;
    
    reg [AXIS_DATA_WIDTH-1:0] tx_axis_tdata;
    reg [AXIS_DATA_BYTES-1:0] tx_axis_tkeep;
    reg tx_axis_tvalid;
    reg tx_axis_tlast;
    wire tx_axis_tready;
    
    wire [AXIS_DATA_WIDTH-1:0] rx_axis_tdata;
    wire [AXIS_DATA_BYTES-1:0] rx_axis_tkeep;
    wire rx_axis_tvalid;
    wire rx_axis_tlast;
    reg rx_axis_tready;
    
    wire tx_frame_valid;
    wire tx_frame_error;
    wire rx_frame_valid;
    wire rx_frame_error;
    wire rx_crc_error;
    wire [31:0] stat_tx_frames;
    wire [31:0] stat_tx_bytes;
    wire [31:0] stat_tx_errors;
    wire [31:0] stat_rx_frames;
    wire [31:0] stat_rx_bytes;
    wire [31:0] stat_rx_errors;
    wire [31:0] stat_rx_crc_errors;

    localparam XGMII_IDLE = 8'h07;        
    localparam XGMII_START = 8'hFB;     
    localparam XGMII_TERMINATE = 8'hFD;   
    localparam PREAMBLE_BYTE = 8'h55;    
    localparam SFD_BYTE = 8'hD5;
    
    initial begin
        mac_clk = 0;
    end
    always #5 mac_clk = ~mac_clk; 
    
    mac #(
        .AXIS_DATA_WIDTH(AXIS_DATA_WIDTH),
        .AXIS_DATA_BYTES(AXIS_DATA_BYTES),
        .XGMII_DATA_WIDTH(XGMII_DATA_WIDTH),
        .XGMII_DATA_BYTES(XGMII_DATA_BYTES),
        .LOCAL_MAC(48'hAA_BB_CC_DD_EE_FF),
        .DEFAULT_DEST_MAC(48'h00_11_22_33_44_55),
        .DEFAULT_ETHER_TYPE(16'h0800)
    ) dut (
        .mac_clk(mac_clk),
        .mac_rst(mac_rst),
        .xgmii_tx_data(xgmii_tx_data),
        .xgmii_tx_ctl(xgmii_tx_ctl),
        .xgmii_tx_pcs_ready(xgmii_tx_pcs_ready),
        .xgmii_rx_data(xgmii_rx_data),
        .xgmii_rx_ctl(xgmii_rx_ctl),
        .xgmii_rx_pcs_ready(xgmii_rx_pcs_ready),
        .tx_axis_tdata(tx_axis_tdata),
        .tx_axis_tkeep(tx_axis_tkeep),
        .tx_axis_tvalid(tx_axis_tvalid),
        .tx_axis_tlast(tx_axis_tlast),
        .tx_axis_tready(tx_axis_tready),
        .rx_axis_tdata(rx_axis_tdata),
        .rx_axis_tkeep(rx_axis_tkeep),
        .rx_axis_tvalid(rx_axis_tvalid),
        .rx_axis_tlast(rx_axis_tlast),
        .rx_axis_tready(rx_axis_tready),
        .tx_frame_valid(tx_frame_valid),
        .tx_frame_error(tx_frame_error),
        .rx_frame_valid(rx_frame_valid),
        .rx_frame_error(rx_frame_error),
        .rx_crc_error(rx_crc_error),
        .stat_tx_frames(stat_tx_frames),
        .stat_tx_bytes(stat_tx_bytes),
        .stat_tx_errors(stat_tx_errors),
        .stat_rx_frames(stat_rx_frames),
        .stat_rx_bytes(stat_rx_bytes),
        .stat_rx_errors(stat_rx_errors),
        .stat_rx_crc_errors(stat_rx_crc_errors)
    );
    
    initial begin
        @(posedge mac_clk);
        mac_rst = 1'b0;
        xgmii_tx_pcs_ready = 1'b0;
        xgmii_rx_data = {4{XGMII_IDLE}};
        xgmii_rx_ctl = 4'b1111;
        tx_axis_tdata = 32'h0;
        tx_axis_tkeep = 4'b0000;
        tx_axis_tvalid = 1'b0;
        tx_axis_tlast = 1'b0;
        rx_axis_tready = 1'b1;
        
        @(posedge mac_clk);
        mac_rst = 1'b1;
        xgmii_tx_pcs_ready = 1'b1;
        
        repeat(5) begin
            @(posedge mac_clk);
        end
        
        $display("=== Test 1: TX Frame ===");
        @(posedge mac_clk);
        tx_axis_tdata = 32'hDEADBEEF;
        tx_axis_tkeep = 4'b1111;
        tx_axis_tvalid = 1'b1;
        tx_axis_tlast = 1'b0;
        
        @(posedge mac_clk);
        while (!tx_axis_tready) @(posedge mac_clk);
        tx_axis_tdata = 32'hCAFEBABE;
        tx_axis_tkeep = 4'b1111;
        tx_axis_tvalid = 1'b1;
        tx_axis_tlast = 1'b0;
        
        @(posedge mac_clk);
        while (!tx_axis_tready) @(posedge mac_clk);
        tx_axis_tdata = 32'h12345678;
        tx_axis_tkeep = 4'b1111;
        tx_axis_tvalid = 1'b1;
        tx_axis_tlast = 1'b1;
        
        @(posedge mac_clk);
        while (!tx_axis_tready) @(posedge mac_clk);
        tx_axis_tvalid = 1'b0;
        tx_axis_tlast = 1'b0;
        tx_axis_tdata = 32'h0;
        tx_axis_tkeep = 4'b0000;
        
        repeat(50) @(posedge mac_clk);
        
        $display("=== Test 2: RX Frame ===");
        @(posedge mac_clk);
        xgmii_rx_data = {PREAMBLE_BYTE, PREAMBLE_BYTE, PREAMBLE_BYTE, XGMII_START};
        xgmii_rx_ctl = 4'b0001;
        
        @(posedge mac_clk);
        xgmii_rx_data = {SFD_BYTE, PREAMBLE_BYTE, PREAMBLE_BYTE, PREAMBLE_BYTE};
        xgmii_rx_ctl = 4'b0000;
        
        @(posedge mac_clk);
        xgmii_rx_data = 32'h33221100; 
        xgmii_rx_ctl = 4'b0000;
        
        @(posedge mac_clk);
        xgmii_rx_data = 32'hBBAA5544; 
        xgmii_rx_ctl = 4'b0000;
        
        @(posedge mac_clk);
        xgmii_rx_data = 32'hFFEEDDCC; 
        xgmii_rx_ctl = 4'b0000;
        
        @(posedge mac_clk);
        xgmii_rx_data = 32'h00000008;
        xgmii_rx_ctl = 4'b0000;
        
        @(posedge mac_clk);
        xgmii_rx_data = 32'hA1B2C3D4; 
        xgmii_rx_ctl = 4'b0000;
        
        @(posedge mac_clk);
        xgmii_rx_data = 32'h12345678; 
        xgmii_rx_ctl = 4'b0000;
        
        @(posedge mac_clk);
        xgmii_rx_data = 32'hDEADBEEF; 
        xgmii_rx_ctl = 4'b0000;
        
        @(posedge mac_clk);
        xgmii_rx_data = 32'h87654321; 
        xgmii_rx_ctl = 4'b0000;
        
        @(posedge mac_clk);
        xgmii_rx_data = 32'hFEDCBA98; 
        xgmii_rx_ctl = 4'b0000;
        
        @(posedge mac_clk);
        xgmii_rx_data = 32'h55AA33CC; 
        xgmii_rx_ctl = 4'b0000;
        
        @(posedge mac_clk);
        xgmii_rx_data = 32'h9F8E7D6C; 
        xgmii_rx_ctl = 4'b0000;
        
        @(posedge mac_clk);
        xgmii_rx_data = 32'h1A2B3C4D; 
        xgmii_rx_ctl = 4'b0000;
        
        @(posedge mac_clk);
        xgmii_rx_data = 32'hCAFEBABE; 
        xgmii_rx_ctl = 4'b0000;
        
        @(posedge mac_clk);
        xgmii_rx_data = 32'h6789ABCD; 
        xgmii_rx_ctl = 4'b0000;
        
        @(posedge mac_clk);
        xgmii_rx_data = 32'hF0E1D2C3; 
        xgmii_rx_ctl = 4'b0000;
        
        @(posedge mac_clk);
        xgmii_rx_data = 32'h3E5F7A9B; 
        xgmii_rx_ctl = 4'b0000;
        
        @(posedge mac_clk);
        xgmii_rx_data = 32'h713b28b2; 
        xgmii_rx_ctl = 4'b0000;
        
        @(posedge mac_clk);
        xgmii_rx_data = {XGMII_TERMINATE, {3{XGMII_IDLE}}};
        xgmii_rx_ctl = 4'b1111;
        
        @(posedge mac_clk);
        xgmii_rx_data = {4{XGMII_IDLE}};
        xgmii_rx_ctl = 4'b1111;
        
        repeat(20) @(posedge mac_clk);
        
        $display("=== Statistics ===");
        $display("TX Frames: %d", stat_tx_frames);
        $display("TX Bytes: %d", stat_tx_bytes);
        $display("RX Frames: %d", stat_rx_frames);
        $display("RX Bytes: %d", stat_rx_bytes);
        
        $finish;
    end
    
    always @(posedge mac_clk) begin
        if (xgmii_tx_ctl[0] && xgmii_tx_data[7:0] == XGMII_START) begin
            $display("TX Frame Start detected");
        end
        if (xgmii_tx_data[31:24] == XGMII_TERMINATE && xgmii_tx_ctl[3]) begin
            $display("TX Frame End detected");
        end
    end
    
    always @(posedge mac_clk) begin
        if (rx_axis_tvalid && rx_axis_tready) begin
            $display("RX Data: 0x%08h, Keep: 0b%04b, Last: %b", 
                     rx_axis_tdata, rx_axis_tkeep, rx_axis_tlast);
        end
        if (rx_frame_valid) begin
            $display("RX Frame Valid detected");
        end
        if (rx_frame_error) begin
            $display("RX Frame Error detected");
        end
        if (rx_crc_error) begin
            $display("RX CRC Error detected");
        end
    end
    
endmodule

