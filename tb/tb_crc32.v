module tb_crc32();
    parameter SLICE_LENGTH = 4;
    parameter INITIAL_CRC = 32'hFFFFFFFF;
    parameter INVERT_OUTPUT = 1;
    parameter REGISTER_OUTPUT = 1;
    parameter MAX_SLICE_LENGTH = 16;
    
    parameter CLK_PERIOD = 10;
    
    reg clk;
    reg rst;
    reg [8*SLICE_LENGTH-1:0] in_data;
    reg [SLICE_LENGTH-1:0] in_valid;
    wire [31:0] out_crc;
    
    reg [31:0] test_data [0:15]; 
    reg [3:0] test_valid [0:15]; 
    integer test_data_length;
    
    crc32 #(
        .SLICE_LENGTH(SLICE_LENGTH),
        .INITIAL_CRC(INITIAL_CRC),
        .INVERT_OUTPUT(INVERT_OUTPUT),
        .REGISTER_OUTPUT(REGISTER_OUTPUT),
        .MAX_SLICE_LENGTH(MAX_SLICE_LENGTH)
    ) dut (
        .clk(clk),
        .rst(rst),
        .in_data(in_data),
        .in_valid(in_valid),
        .out_crc(out_crc)
    );
    integer k;
    
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    initial begin
        test_data[0] = 32'h33221100; 
        test_data[1] = 32'hBBAA5544; 
        test_data[2] = 32'hFFEEDDCC; 
        test_data[3] = 32'h00000008;
        test_data[4] = 32'hA1B2C3D4; 
        test_data[5] = 32'h12345678; 
        test_data[6] = 32'hDEADBEEF; 
        test_data[7] = 32'h87654321;
        test_data[8] = 32'hFEDCBA98; 
        test_data[9] = 32'h55AA33CC; 
        test_data[10] = 32'h9F8E7D6C; 
        test_data[11] = 32'h1A2B3C4D;
        test_data[12] = 32'hCAFEBABE; 
        test_data[13] = 32'h6789ABCD; 
        test_data[14] = 32'hF0E1D2C3; 
        test_data[15] = 32'h3E5F7A9B;
        
        test_valid[0] = 4'hF;   
        test_valid[1] = 4'hF;  
        test_valid[2] = 4'hF;   
        test_valid[3] = 4'h3;   
        test_valid[4] = 4'hF;   
        test_valid[5] = 4'hF;   
        test_valid[6] = 4'hF;   
        test_valid[7] = 4'hF;  
        test_valid[8] = 4'hF;   
        test_valid[9] = 4'hF;  
        test_valid[10] = 4'hF; 
        test_valid[11] = 4'hF; 
        test_valid[12] = 4'hF; 
        test_valid[13] = 4'hF; 
        test_valid[14] = 4'hF;
        test_valid[15] = 4'hF;
        
        test_data_length = 68;
    end
    
    integer i, j;
    reg [31:0] expected_crc;
    
    initial begin
        $display("Starting CRC32 Testbench with specific test case");
        in_data = 0;
        in_valid = 0;
        rst = 0;
        
        expected_crc = 32'h713b28b2; 
        
        @(posedge clk);
        @(posedge clk);
        rst = 1;
        @(posedge clk);
        
        
        @(posedge clk);
        in_valid = test_valid[0];
        in_data = test_data[0];
        
        @(posedge clk);
        in_valid = test_valid[1];
        in_data = test_data[1];
        
        @(posedge clk);
        in_valid = test_valid[2];
        in_data = test_data[2];
        
        @(posedge clk);
        in_valid = test_valid[3];
        in_data = test_data[3];
        
        @(posedge clk);
        in_valid = test_valid[4];
        in_data = test_data[4];
        
        @(posedge clk);
        in_valid = test_valid[5];
        in_data = test_data[5];
        
        @(posedge clk);
        in_valid = test_valid[6];
        in_data = test_data[6];
        
        @(posedge clk);
        in_valid = test_valid[7];
        in_data = test_data[7];
        
        @(posedge clk);
        in_valid = test_valid[8];
        in_data = test_data[8];
        
        @(posedge clk);
        in_valid = test_valid[9];
        in_data = test_data[9];
        
        @(posedge clk);
        in_valid = test_valid[10];
        in_data = test_data[10];
        
        @(posedge clk);
        in_valid = test_valid[11];
        in_data = test_data[11];
        
        @(posedge clk);
        in_valid = test_valid[12];
        in_data = test_data[12];
        
        @(posedge clk);
        in_valid = test_valid[13];
        in_data = test_data[13];
        
        @(posedge clk);
        in_valid = test_valid[14];
        in_data = test_data[14];
        
        @(posedge clk);
        in_valid = test_valid[15];
        in_data = test_data[15];
        
        @(posedge clk);
        in_valid = 4'b0000;
        in_data = 32'h00000000;
        
        if (REGISTER_OUTPUT) begin
            @(posedge clk);
        end
        #10;
        $display("Final CRC: 0x%08x", out_crc);
        $display("Expected : 0x%08x", expected_crc);
        if (out_crc == expected_crc) begin
            $display("TEST PASSED!");
        end else begin
            $display("TEST FAILED!");
        end
        
        #10;
        $finish;
    end
        
endmodule