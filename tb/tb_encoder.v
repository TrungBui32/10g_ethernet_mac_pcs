module tb_encoder();

    parameter XGMII_DATA_WIDTH = 32;
    parameter XGMII_DATA_BYTES = XGMII_DATA_WIDTH/8;
    parameter PCS_DATA_WIDTH = 64;

    localparam PREAMBLE_BYTE = 8'h55;
    localparam SFD_BYTE = 8'hD5;
    localparam XGMII_IDLE = 8'h07;
    localparam XGMII_START = 8'hFB;
    localparam XGMII_TERMINATE = 8'hFD;

    reg clk;
    reg rst;

    reg [XGMII_DATA_WIDTH-1:0] xgmii_data_in;
    reg [XGMII_DATA_BYTES-1:0] xgmii_ctrl_in;
    reg xgmii_valid_in;
    wire xgmii_ready;

    wire [PCS_DATA_WIDTH-1:0] encoded_data_out;
    wire [1:0] encoded_header_out;
    wire encoded_valid_out;

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    encoder #(
        .XGMII_DATA_WIDTH(XGMII_DATA_WIDTH),
        .XGMII_DATA_BYTES(XGMII_DATA_BYTES),
        .PCS_DATA_WIDTH(PCS_DATA_WIDTH)
    ) dut (
        .clk(clk),
        .rst(rst),
        .in_xgmii_data(xgmii_data_in),
        .in_xgmii_ctl(xgmii_ctrl_in),
        .in_xgmii_valid(xgmii_valid_in),
        .out_xgmii_ready(xgmii_ready),
        .out_encoded_data(encoded_data_out),
        .out_encoded_header(encoded_header_out),
        .out_encoded_valid(encoded_valid_out)
    );

    task init_signals;
        begin
            rst = 1'b0;
            xgmii_data_in = {XGMII_DATA_WIDTH{1'b0}};
            xgmii_ctrl_in = {XGMII_DATA_BYTES{1'b0}};
            xgmii_valid_in = 1'b1;
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

    task send_beat;
        input [XGMII_DATA_WIDTH-1:0] data;
        input [XGMII_DATA_BYTES-1:0] ctrl;
        begin
            @(posedge clk);
            xgmii_data_in = data;
            xgmii_ctrl_in = ctrl;
            xgmii_valid_in = 1'b1;
        end
    endtask

    initial begin
        init_signals();
        apply_reset();

        send_beat({PREAMBLE_BYTE, PREAMBLE_BYTE, PREAMBLE_BYTE, XGMII_START}, 4'b0001);
        send_beat({SFD_BYTE, PREAMBLE_BYTE, PREAMBLE_BYTE, PREAMBLE_BYTE},    4'b0000);

        send_beat(32'h33221100, 4'b0000);
        send_beat(32'hBBAA5544, 4'b0000);
        send_beat(32'hFFEEDDCC, 4'b0000);
        send_beat(32'h00000008, 4'b0000); 

        send_beat(32'hA1B2C3D4, 4'b0000); // 1
        send_beat(32'h12345678, 4'b0000); // 2
        send_beat(32'hDEADBEEF, 4'b0000); // 3
        send_beat(32'h87654321, 4'b0000); // 4
        send_beat(32'hFEDCBA98, 4'b0000); // 5
        send_beat(32'h55AA33CC, 4'b0000); // 6
        send_beat(32'h9F8E7D6C, 4'b0000); // 7
        send_beat(32'h1A2B3C4D, 4'b0000); // 8
        send_beat(32'hCAFEBABE, 4'b0000); // 9
        send_beat(32'h6789ABCD, 4'b0000); // 10
        send_beat(32'hF0E1D2C3, 4'b0000); // 11
        send_beat(32'h3E5F7A9B, 4'b0000); // 12

        send_beat(32'h713B28B2, 4'b0000);

        send_beat({XGMII_TERMINATE, {3{XGMII_IDLE}}}, 4'b1111);

        send_beat({4{XGMII_IDLE}}, 4'b1111);
        @(posedge clk);

        repeat (20) @(posedge clk);

        $finish;
    end
endmodule
