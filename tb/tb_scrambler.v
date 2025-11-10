module tb_scrambler(); 
    parameter DATA_WIDTH = 64; 
    reg clk; 
    reg rst; 
    reg [DATA_WIDTH-1:0] data_in; 
    reg data_in_valid; 
    wire [DATA_WIDTH-1:0] data_out;
    wire data_out_valid;

    initial begin
        clk = 0;
    end
    
    always #5 clk = ~clk; 
    
    scrambler #(
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk(clk),
        .rst(rst), 
        .in_data(data_in),
        .in_data_valid(data_in_valid),
        .out_data(data_out),
        .out_data_valid(data_out_valid)
    );
    
    task init_signals;
        begin
            rst           = 1'b0;
            data_in       = {DATA_WIDTH{1'b0}};
            data_in_valid = 1'b0;
        end
    endtask

    task apply_reset;
        begin
            @(posedge clk);
            rst = 1'b0;
            repeat(2) @(posedge clk);
            rst = 1'b1;
            @(posedge clk);
        end
    endtask

    task send_word;
        input [DATA_WIDTH-1:0] word;
        begin
            @(posedge clk);
            data_in       = word;
            data_in_valid = 1'b1;
            @(posedge clk);
            data_in_valid = 1'b0;
        end
    endtask

    initial begin
        init_signals();
        apply_reset();

        send_word(64'h78d5555555555555); //7b2aaad555555555
        send_word(64'hbbaa554433221100); //46ff004433221100
        send_word(64'h00000008ffeeddcc); //92f77f88ffeeddcc
        send_word(64'h12345678a1b2c3d4); //d6a54ff8a1b2c3d4
        send_word(64'h87654321deadbeef); //0dfb56a1deadbeef
        send_word(64'h55aa33ccfedcba98); //bc8abbccfedcba98
        send_word(64'h1a2b3c4d9f8e7d6c); //17898fcd9f8e7d6c
        send_word(64'h6789abcdcafebabe); //1348e24dcafebabe
        send_word(64'h3e5f7a9bf0e1d2c3); //bafdda1bf0e1d2c3
        send_word(64'hcc713b28b2070707); //b367a528b2070707

        repeat(4) @(posedge clk);
        
        $finish;
    end
endmodule