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

        send_word(64'h78D5_5555_5555_5555);
        send_word(64'hBBAA_5544_3322_1100);
        send_word(64'hCC71_3B28_B207_0707);

        repeat(4) @(posedge clk);
        
        $finish;
    end
endmodule