module tb_rx_mac;
    parameter AXIS_DATA_WIDTH = 32;
    parameter AXIS_DATA_BYTES = AXIS_DATA_WIDTH / 8;
    parameter XGMII_DATA_WIDTH = 32;
    parameter XGMII_DATA_BYTES = XGMII_DATA_WIDTH / 8;
    
    reg rx_clk;
    reg rx_rst;
    reg [XGMII_DATA_WIDTH-1:0] in_xgmii_data;
    reg [XGMII_DATA_BYTES-1:0] in_xgmii_ctl;
    wire out_xgmii_pcs_ready;
    wire [AXIS_DATA_WIDTH-1:0] out_master_rx_tdata;
    wire [AXIS_DATA_BYTES-1:0] out_master_rx_tkeep;
    wire out_master_rx_tvalid;
    wire out_master_rx_tlast;
    reg in_master_rx_tready;
    wire frame_valid;
    wire frame_error;
    wire crc_error;
    
    localparam XGMII_IDLE = 8'h07;        
    localparam XGMII_START = 8'hFB;     
    localparam XGMII_TERMINATE = 8'hFD;   
    localparam PREAMBLE_BYTE = 8'h55;    
    localparam SFD_BYTE = 8'hD5;
    
    initial begin
        rx_clk = 0;
    end
    always #5 rx_clk = ~rx_clk;
    
    rx_mac #(
        .AXIS_DATA_WIDTH(AXIS_DATA_WIDTH),
        .AXIS_DATA_BYTES(AXIS_DATA_BYTES),
        .XGMII_DATA_WIDTH(XGMII_DATA_WIDTH),
        .XGMII_DATA_BYTES(XGMII_DATA_BYTES)
    ) dut (
        .rx_clk(rx_clk),
        .rx_rst(rx_rst),
        .in_xgmii_data(in_xgmii_data),
        .in_xgmii_ctl(in_xgmii_ctl),
        .out_xgmii_pcs_ready(out_xgmii_pcs_ready),
        .out_master_rx_tdata(out_master_rx_tdata),
        .out_master_rx_tkeep(out_master_rx_tkeep),
        .out_master_rx_tvalid(out_master_rx_tvalid),
        .out_master_rx_tlast(out_master_rx_tlast),
        .in_master_rx_tready(in_master_rx_tready),
        .frame_valid(frame_valid),
        .frame_error(frame_error),
        .crc_error(crc_error)
    );
    
    initial begin
        @(posedge rx_clk);
        rx_rst = 1'b0;
        in_xgmii_data = {4{XGMII_IDLE}};
        in_xgmii_ctl = 4'b1111;
        in_master_rx_tready = 1'b1;
        
        @(posedge rx_clk);
        rx_rst = 1'b1; 
        
        repeat(5) begin
            @(posedge rx_clk);
            in_xgmii_data = {4{XGMII_IDLE}};
            in_xgmii_ctl = 4'b1111;
        end
        
        @(posedge rx_clk);
        in_xgmii_data = {PREAMBLE_BYTE, PREAMBLE_BYTE, PREAMBLE_BYTE, XGMII_START};
        in_xgmii_ctl = 4'b0001;
        
        @(posedge rx_clk);
        in_xgmii_data = {SFD_BYTE, PREAMBLE_BYTE, PREAMBLE_BYTE, PREAMBLE_BYTE};
        in_xgmii_ctl = 4'b0000;
        
        @(posedge rx_clk);
        in_xgmii_data = 32'h33221100; 
        in_xgmii_ctl = 4'b0000;
        
        @(posedge rx_clk);
        in_xgmii_data = 32'hBBAA5544;
        in_xgmii_ctl = 4'b0000;
        
        @(posedge rx_clk);
        in_xgmii_data = 32'hFFEEDDCC;
        in_xgmii_ctl = 4'b0000;
        
        @(posedge rx_clk);
        in_xgmii_data = 32'h00000008; 
        in_xgmii_ctl = 4'b0000;
        //1
        @(posedge rx_clk);
        in_xgmii_data = 32'hA1B2C3D4; 
        in_xgmii_ctl = 4'b0000;
        //2
        @(posedge rx_clk);
        in_xgmii_data = 32'h12345678; 
        in_xgmii_ctl = 4'b0000;
        //3
        @(posedge rx_clk);
        in_xgmii_data = 32'hDEADBEEF; 
        in_xgmii_ctl = 4'b0000;
        //4
        @(posedge rx_clk);
        in_xgmii_data = 32'h87654321; 
        in_xgmii_ctl = 4'b0000;
        //5
        @(posedge rx_clk);
        in_xgmii_data = 32'hFEDCBA98; 
        in_xgmii_ctl = 4'b0000;
        //6
        @(posedge rx_clk);
        in_xgmii_data = 32'h55AA33CC; 
        in_xgmii_ctl = 4'b0000;
        //7
        @(posedge rx_clk);
        in_xgmii_data = 32'h9F8E7D6C; 
        in_xgmii_ctl = 4'b0000;
        //8
        @(posedge rx_clk);
        in_xgmii_data = 32'h1A2B3C4D; 
        in_xgmii_ctl = 4'b0000;
        //9
        @(posedge rx_clk);
        in_xgmii_data = 32'hCAFEBABE; 
        in_xgmii_ctl = 4'b0000;
        //10
        @(posedge rx_clk);
        in_xgmii_data = 32'h6789ABCD; 
        in_xgmii_ctl = 4'b0000;
        //11
        @(posedge rx_clk);
        in_xgmii_data = 32'hF0E1D2C3; 
        in_xgmii_ctl = 4'b0000;
        //12
        @(posedge rx_clk);
        in_xgmii_data = 32'h3E5F7A9B; 
        in_xgmii_ctl = 4'b0000;
        //CRC
        @(posedge rx_clk);
        in_xgmii_data = 32'h0f0821ee; 
        in_xgmii_ctl = 4'b0000;
        
        @(posedge rx_clk);
        in_xgmii_data = {XGMII_TERMINATE, {3{XGMII_IDLE}}};
        in_xgmii_ctl = 4'b1111;
        
        @(posedge rx_clk);
        in_xgmii_data = {4{XGMII_IDLE}};
        in_xgmii_ctl = 4'b1111;



        @(posedge rx_clk);
        in_xgmii_data = {PREAMBLE_BYTE, PREAMBLE_BYTE, PREAMBLE_BYTE, XGMII_START};
        in_xgmii_ctl = 4'b0001;
        
        @(posedge rx_clk);
        in_xgmii_data = {SFD_BYTE, PREAMBLE_BYTE, PREAMBLE_BYTE, PREAMBLE_BYTE};
        in_xgmii_ctl = 4'b0000;
        
        @(posedge rx_clk);
        in_xgmii_data = 32'h33221100; 
        in_xgmii_ctl = 4'b0000;
        
        @(posedge rx_clk);
        in_xgmii_data = 32'hBBAA5544;
        in_xgmii_ctl = 4'b0000;
        
        @(posedge rx_clk);
        in_xgmii_data = 32'hFFEEDDCC;
        in_xgmii_ctl = 4'b0000;
        
        @(posedge rx_clk);
        in_xgmii_data = 32'h00000008; 
        in_xgmii_ctl = 4'b0000;
        //1
        @(posedge rx_clk);
        in_xgmii_data = 32'hA1B2C3D4; 
        in_xgmii_ctl = 4'b0000;
        //2
        @(posedge rx_clk);
        in_xgmii_data = 32'h12345678; 
        in_xgmii_ctl = 4'b0000;
        //3
        @(posedge rx_clk);
        in_xgmii_data = 32'hDEADBEEF; 
        in_xgmii_ctl = 4'b0000;
        //4
        @(posedge rx_clk);
        in_xgmii_data = 32'h87654321; 
        in_xgmii_ctl = 4'b0000;
        //5
        @(posedge rx_clk);
        in_xgmii_data = 32'hFEDCBA98; 
        in_xgmii_ctl = 4'b0000;
        //6
        @(posedge rx_clk);
        in_xgmii_data = 32'h55AA33CC; 
        in_xgmii_ctl = 4'b0000;
        //7
        @(posedge rx_clk);
        in_xgmii_data = 32'h9F8E7D6C; 
        in_xgmii_ctl = 4'b0000;
        //8
        @(posedge rx_clk);
        in_xgmii_data = 32'h1A2B3C4D; 
        in_xgmii_ctl = 4'b0000;
        //9
        @(posedge rx_clk);
        in_xgmii_data = 32'hCAFEBABE; 
        in_xgmii_ctl = 4'b0000;
        //10
        @(posedge rx_clk);
        in_xgmii_data = 32'h6789ABCD; 
        in_xgmii_ctl = 4'b0000;
        //11
        @(posedge rx_clk);
        in_xgmii_data = 32'hF0E1D2C3; 
        in_xgmii_ctl = 4'b0000;
        //12
        @(posedge rx_clk);
        in_xgmii_data = 32'h3E5F7A9B; 
        in_xgmii_ctl = 4'b0000;
        //CRC
        @(posedge rx_clk);
        in_xgmii_data = 32'h0f0821ee; 
        in_xgmii_ctl = 4'b0000;
        
        @(posedge rx_clk);
        in_xgmii_data = {XGMII_TERMINATE, {3{XGMII_IDLE}}};
        in_xgmii_ctl = 4'b1111;
        
        @(posedge rx_clk);
        in_xgmii_data = {4{XGMII_IDLE}};
        in_xgmii_ctl = 4'b1111;
        
        repeat(20) @(posedge rx_clk);
        
        #200; 
        $finish;
    end
    
    always @(posedge rx_clk) begin
        if (out_master_rx_tvalid && in_master_rx_tready) begin
            $display("RX Data: 0x%08h, Keep: 0b%04b, Last: %b", 
                     out_master_rx_tdata, out_master_rx_tkeep, out_master_rx_tlast);
        end
        if (frame_valid) begin
            $display("Frame Valid detected");
        end
        if (frame_error) begin
            $display("Frame Error detected");
        end
        if (crc_error) begin
            $display("CRC Error detected");
        end
    end
    
endmodule