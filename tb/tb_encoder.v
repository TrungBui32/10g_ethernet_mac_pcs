module tb_encoder();

    parameter XGMII_DATA_WIDTH = 32;
    parameter XGMII_DATA_BYTES = XGMII_DATA_WIDTH/8;
    parameter PCS_DATA_WIDTH = 66;
    
    localparam PREAMBLE_BYTE = 8'h55;
    localparam SFD_BYTE = 8'hD5;        
    localparam XGMII_IDLE = 8'h07;        
    localparam XGMII_START = 8'hFB;       
    localparam XGMII_TERMINATE = 8'hFD; 
    
    reg clk;
    reg rst;
    
    reg [XGMII_DATA_WIDTH-1:0] xgmii_data_in;
    reg [XGMII_DATA_BYTES-1:0] xgmii_ctrl_in;
    wire xgmii_ready;
    
    wire [PCS_DATA_WIDTH-1:0] encoded_data_out;
    wire encoded_valid_out;
    reg encoded_ready_in;
    
    initial begin
        clk = 0;
    end
    
    always #5 clk = ~clk; 
    
    encoder #(
        .XGMII_DATA_WIDTH(XGMII_DATA_WIDTH),
        .XGMII_DATA_BYTES(XGMII_DATA_BYTES),
        .PCS_DATA_WIDTH(PCS_DATA_WIDTH)
    ) dut (
        .clk(clk),
        .rst(rst),
        .xgmii_data_in(xgmii_data_in),
        .xgmii_ctrl_in(xgmii_ctrl_in),
        .xgmii_ready(xgmii_ready),
        .encoded_data_out(encoded_data_out),
        .encoded_valid_out(encoded_valid_out),
        .encoded_ready_in(encoded_ready_in)
    );
    
    initial begin
        @(posedge clk);
        rst = 1'b0;
        @(posedge clk);
        
        // Test 3 cases: SYNC_DATA, BLOCK_TYPE_S0, and BLOCK_TYPE_T4
        rst = 1'b1;
        encoded_ready_in <= 1'b1;
        @(posedge clk);
        encoded_ready_in <= 1'b1;
        xgmii_data_in = {PREAMBLE_BYTE, PREAMBLE_BYTE, PREAMBLE_BYTE, XGMII_START};
        xgmii_ctrl_in = 4'b0001;
        
        @(posedge clk);
        encoded_ready_in <= 1'b1;
        xgmii_data_in = {SFD_BYTE, PREAMBLE_BYTE, PREAMBLE_BYTE, PREAMBLE_BYTE};
        xgmii_ctrl_in = 4'b0000;
        
        @(posedge clk);
        encoded_ready_in <= 1'b1;
        xgmii_data_in = 32'h33221100; 
        xgmii_ctrl_in = 4'b0000;
        
        @(posedge clk);
        encoded_ready_in <= 1'b1;
        xgmii_data_in = 32'hBBAA5544;
        xgmii_ctrl_in = 4'b0000;
        
        @(posedge clk);
        encoded_ready_in <= 1'b1;
        xgmii_data_in = 32'hFFEEDDCC;
        xgmii_ctrl_in = 4'b0000;
        
        @(posedge clk);
        encoded_ready_in <= 1'b1;
        xgmii_data_in = 32'h00000008; 
        xgmii_ctrl_in = 4'b0000;
        //1
        @(posedge clk);
        encoded_ready_in <= 1'b1;
        xgmii_data_in = 32'hA1B2C3D4; 
        xgmii_ctrl_in = 4'b0000;
        //2
        @(posedge clk);
        encoded_ready_in <= 1'b1;
        xgmii_data_in = 32'h12345678; 
        xgmii_ctrl_in = 4'b0000;
        //3
        @(posedge clk);
        encoded_ready_in <= 1'b1;
        xgmii_data_in = 32'hDEADBEEF; 
        xgmii_ctrl_in = 4'b0000;
        //4
        @(posedge clk);
        encoded_ready_in <= 1'b1;
        xgmii_data_in = 32'h87654321; 
        xgmii_ctrl_in = 4'b0000;
        //5
        @(posedge clk);
        encoded_ready_in <= 1'b1;
        xgmii_data_in = 32'hFEDCBA98; 
        xgmii_ctrl_in = 4'b0000;
        //6
        @(posedge clk);
        encoded_ready_in <= 1'b1;
        xgmii_data_in = 32'h55AA33CC; 
        xgmii_ctrl_in = 4'b0000;
        //7
        @(posedge clk);
        encoded_ready_in <= 1'b1;
        xgmii_data_in = 32'h9F8E7D6C; 
        xgmii_ctrl_in = 4'b0000;
        //8
        @(posedge clk);
        encoded_ready_in <= 1'b1;
        xgmii_data_in = 32'h1A2B3C4D; 
        xgmii_ctrl_in = 4'b0000;
        //9
        @(posedge clk);
        encoded_ready_in <= 1'b1;
        xgmii_data_in = 32'hCAFEBABE; 
        xgmii_ctrl_in = 4'b0000;
        //10
        @(posedge clk);
        encoded_ready_in <= 1'b1;
        xgmii_data_in = 32'h6789ABCD; 
        xgmii_ctrl_in = 4'b0000;
        //11
        @(posedge clk);
        encoded_ready_in <= 1'b1;
        xgmii_data_in = 32'hF0E1D2C3; 
        xgmii_ctrl_in = 4'b0000;
        //12
        @(posedge clk);
        encoded_ready_in <= 1'b1;
        xgmii_data_in = 32'h3E5F7A9B; 
        xgmii_ctrl_in = 4'b0000;
        //CRC
        @(posedge clk);
        encoded_ready_in <= 1'b1;
        xgmii_data_in = 32'h713b28b2; 
        xgmii_ctrl_in = 4'b0000;
        
        @(posedge clk);
        encoded_ready_in <= 1'b1;
        xgmii_data_in = {XGMII_TERMINATE, {3{XGMII_IDLE}}};
        xgmii_ctrl_in = 4'b1111;
        
        @(posedge clk);
        encoded_ready_in <= 1'b0;
        xgmii_data_in = {4{XGMII_IDLE}};
        xgmii_ctrl_in = 4'b1111;
        
        repeat(20) @(posedge clk);
        
        $finish;
    end
endmodule