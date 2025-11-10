module tb_decoder();
    parameter PCS_DATA_WIDTH = 64;
    parameter XGMII_DATA_WIDTH = 32;
    parameter XGMII_DATA_BYTES = XGMII_DATA_WIDTH/8;
    reg clk;
    reg rst;
    
    reg [PCS_DATA_WIDTH-1:0] encoded_data_in;
    reg [1:0] encoded_header_in;
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
        .in_encoded_data(encoded_data_in),
        .in_encoded_header(encoded_header_in),
        .in_encoded_valid(encoded_valid_in),
        .out_xgmii_data(xgmii_data_out),
        .out_xgmii_ctl(xgmii_ctrl_out),
        .out_xgmii_valid(xgmii_valid_out),
        .in_xgmii_ready(xgmii_ready_in)
    );
    
    initial begin
        @(posedge clk);
        rst = 1'b0;
        @(posedge clk);
        
        // Test 3 cases: SYNC_DATA, BLOCK_TYPE_S0, and BLOCK_TYPE_T4
        rst = 1'b1;
        @(posedge clk);
        encoded_data_in = 64'h78D5555555555555;
        encoded_header_in = 2'b10; // SYNC_DATA
        encoded_valid_in = 1;
        xgmii_ready_in = 1;
        
        @(posedge clk);
        @(posedge clk);
        encoded_data_in = 64'hBBAA554433221100;
        encoded_header_in = 2'b01; // BLOCK_TYPE_S0
        encoded_valid_in = 1;
        xgmii_ready_in = 1;
        
        @(posedge clk);
        @(posedge clk);
        encoded_data_in = 64'hCC713B28B2070707;
        encoded_header_in = 2'b01; // BLOCK_TYPE_T4
        encoded_valid_in = 1;
        xgmii_ready_in = 1;
        
        @(posedge clk);
        xgmii_ready_in = 1;
        
        @(posedge clk);
        encoded_data_in = 0;
        encoded_header_in = 0; 
        encoded_valid_in = 0;
        xgmii_ready_in = 0;
        
        repeat(5) @(posedge clk);
        
        $finish;
    end
endmodule