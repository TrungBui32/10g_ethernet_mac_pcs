module tb_descrambler();
    parameter PCS_DATA_WIDTH = 64;

    reg clk;
    reg rst;

    reg  [PCS_DATA_WIDTH-1:0] data_in;
    reg                   data_in_valid;
    wire [PCS_DATA_WIDTH-1:0] data_out;

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    descrambler #(
        .PCS_DATA_WIDTH(PCS_DATA_WIDTH)
    ) dut (
        .clk(clk),
        .rst(rst),
        .in_data(data_in),
        .in_data_valid(data_in_valid),
        .out_data(data_out)
    );

    task init_signals;
        begin
            rst           = 1'b0;
            data_in       = {PCS_DATA_WIDTH{1'b0}};
            data_in_valid = 1'b0;
        end
    endtask

    task apply_reset;
        begin
            @(posedge clk);
            rst = 1'b0;
            repeat (2) @(posedge clk);
            rst = 1'b1;
            @(posedge clk);
        end
    endtask

    task send_word;
        input [PCS_DATA_WIDTH-1:0] word;
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

        send_word(64'h7B2A_AAD5_5555_5555);
        send_word(64'h46FF_0044_3322_1100);
        send_word(64'h5E86_44A8_B207_0707);

        repeat (4) @(posedge clk);

        $finish;
    end

endmodule
