module tb_descrambler(); 
    parameter DATA_WIDTH = 64; 
    reg clk; 
    reg rst; 
    reg [DATA_WIDTH-1:0] data_in; 
    reg data_in_valid; 
    wire [DATA_WIDTH-1:0] data_out;

    initial begin
        clk = 0;
    end
    
    always #5 clk = ~clk; 
    
    descrambler #(
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk(clk),
        .rst(rst), 
        .data_in(data_in),
        .data_in_valid(data_in_valid),
        .data_out(data_out)
    );
    
    initial begin
        rst = 1'b0;
        data_in = 0;
        data_in_valid = 0;
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        rst = 1'b1;
        @(posedge clk);
        data_in = 64'h7b2aaad555555555;
        data_in_valid = 1'b1;
        
        @(posedge clk);
        data_in = 64'h46ff004433221100;
        data_in_valid = 1'b1;
        
        @(posedge clk);
        data_in = 64'h5e8644a8b2070707;        
        data_in_valid = 1'b1;
        
        @(posedge clk);
        data_in_valid = 1'b0;
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        
        $finish;
    end
endmodule
