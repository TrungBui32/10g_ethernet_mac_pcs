module tb_decoder();
    parameter PCS_DATA_WIDTH = 66;
    parameter XGMII_DATA_WIDTH = 32;
    parameter XGMII_DATA_BYTES = XGMII_DATA_WIDTH/8;
    reg clk;
    reg rst;
    
    reg [PCS_DATA_WIDTH-1:0] encoded_data_in;
    reg encoded_valid_in;
    
    wire [XGMII_DATA_WIDTH-1:0] xgmii_data_out;
    wire [XGMII_DATA_BYTES-1:0] xgmii_ctrl_out;
    wire xgmii_valid_out;
    reg xgmii_ready_in;
    
    initial begin
        clk = 0;
    end
    
    always #5 clk = ~clk; 
    
    decoder #(
        .XGMII_DATA_WIDTH(XGMII_DATA_WIDTH),
        .XGMII_DATA_BYTES(XGMII_DATA_BYTES),
        .PCS_DATA_WIDTH(PCS_DATA_WIDTH)
    ) dut (
        .clk(clk),
        .rst(rst),
        .encoded_data_in(encoded_data_in),
        .encoded_valid_in(encoded_valid_in),
        .xgmii_data_out(xgmii_data_out),
        .xgmii_ctrl_out(xgmii_ctrl_out),
        .xgmii_valid_out(xgmii_valid_out),
        .xgmii_ready_in(xgmii_ready_in)
    );
    
    initial begin
        @(posedge clk);
        rst = 1'b0;
        @(posedge clk);
        
        // Test 3 cases: SYNC_DATA, BLOCK_TYPE_S0, and BLOCK_TYPE_T4
        rst = 1'b1;
        @(posedge clk);
        encoded_data_in = 66'h278d5555555555555;
        encoded_valid_in = 1;
        xgmii_ready_in = 1;
        
        @(posedge clk);
        @(posedge clk);
        encoded_data_in = 66'h1bbaa554433221100;
        encoded_valid_in = 1;
        xgmii_ready_in = 1;
        
        @(posedge clk);
        @(posedge clk);
        encoded_data_in = 66'h2cc713b28b2070707;
        encoded_valid_in = 1;
        xgmii_ready_in = 1;
        
        @(posedge clk);
        xgmii_ready_in = 1;
        
        @(posedge clk);
        xgmii_ready_in = 0;
        
        repeat(5) @(posedge clk);
        
        $finish;
    end
endmodule