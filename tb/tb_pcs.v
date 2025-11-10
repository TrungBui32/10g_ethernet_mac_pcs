module tb_pcs;
    parameter XGMII_DATA_WIDTH = 32;
    parameter XGMII_DATA_BYTES = XGMII_DATA_WIDTH/8;
    parameter PCS_DATA_WIDTH = 64;

    reg pcs_clk;
    reg pcs_rst;

    reg [XGMII_DATA_WIDTH-1:0] in_tx_xgmii_data;
    reg [XGMII_DATA_BYTES-1:0] in_tx_xgmii_ctl;
    reg in_tx_xgmii_valid;
    wire out_tx_xgmii_ready;

    wire [PCS_DATA_WIDTH-1:0] tx_pcs_data;
    wire tx_pcs_data_valid;
    reg tx_pcs_ready;

    reg [PCS_DATA_WIDTH-1:0] rx_pcs_data;
    reg [1:0] rx_pcs_header;
    reg rx_pcs_valid;

    wire [XGMII_DATA_WIDTH-1:0] rx_xgmii_data;
    wire [XGMII_DATA_BYTES-1:0] rx_xgmii_ctl;
    wire rx_xgmii_valid;
    reg rx_xgmii_ready;

    localparam XGMII_IDLE = 8'h07;
    localparam XGMII_START = 8'hFB;
    localparam XGMII_TERMINATE = 8'hFD;
    localparam PREAMBLE_BYTE = 8'h55;
    localparam SFD_BYTE = 8'hD5;

    initial begin
        pcs_clk = 0;
        forever #5 pcs_clk = ~pcs_clk;
    end

    pcs #(
        .XGMII_DATA_WIDTH(XGMII_DATA_WIDTH),
        .XGMII_DATA_BYTES(XGMII_DATA_BYTES),
        .PCS_DATA_WIDTH(PCS_DATA_WIDTH)
    ) dut (
        .pcs_clk(pcs_clk),
        .pcs_rst(pcs_rst),

        .in_tx_xgmii_data(in_tx_xgmii_data),
        .in_tx_xgmii_ctl(in_tx_xgmii_ctl),
        .in_tx_xgmii_valid(in_tx_xgmii_valid),
        .out_tx_xgmii_ready(out_tx_xgmii_ready),

        .tx_pcs_data(tx_pcs_data),
        .tx_pcs_data_valid(tx_pcs_data_valid),
        .tx_pcs_ready(tx_pcs_ready),

        .rx_pcs_data(rx_pcs_data),
        .rx_pcs_header(rx_pcs_header),
        .rx_pcs_valid(rx_pcs_valid),

        .rx_xgmii_data(rx_xgmii_data),
        .rx_xgmii_ctl(rx_xgmii_ctl),
        .rx_xgmii_valid(rx_xgmii_valid),
        .rx_xgmii_ready(rx_xgmii_ready)
    );

    task init_signals;
        begin
            pcs_rst = 1'b0;

            in_tx_xgmii_data = {XGMII_DATA_WIDTH{1'b0}};
            in_tx_xgmii_ctl = {XGMII_DATA_BYTES{1'b0}};
            in_tx_xgmii_valid = 1'b0;

            tx_pcs_ready = 1'b1; 

            rx_pcs_data = {PCS_DATA_WIDTH{1'b0}};
            rx_pcs_header = 2'b01; 
            rx_pcs_valid = 1'b0;

            rx_xgmii_ready = 1'b1; 
        end
    endtask

    task apply_reset;
        begin
            @(posedge pcs_clk);
            pcs_rst = 1'b0;
            repeat (2) @(posedge pcs_clk);
            pcs_rst = 1'b1;
            @(posedge pcs_clk);
        end
    endtask

    task send_tx_xgmii_beat;
        input [XGMII_DATA_WIDTH-1:0] data;
        input [XGMII_DATA_BYTES-1:0] ctl;
        begin
            wait (out_tx_xgmii_ready == 1'b1);
            @(posedge pcs_clk);
            in_tx_xgmii_data  = data;
            in_tx_xgmii_ctl   = ctl;
            in_tx_xgmii_valid = 1'b1;
        end
    endtask

    task send_rx_pcs_block;
        input [PCS_DATA_WIDTH-1:0] data;
        input [1:0]                header;
        begin
            @(posedge pcs_clk);
            rx_pcs_data   = data;
            rx_pcs_header = header;
            rx_pcs_valid  = 1'b1;
        end
    endtask

    initial begin
        forever begin
            @(posedge pcs_clk);
            if (tx_pcs_data_valid && tx_pcs_ready) begin
                $display("[%0t] TX PCS out: data=%h", $time, tx_pcs_data);
            end
            if (rx_xgmii_valid && rx_xgmii_ready) begin
                $display("[%0t] RX XGMII out: data=%h ctl=%b", $time, rx_xgmii_data, rx_xgmii_ctl);
            end
        end
    end

    initial begin
        init_signals();
        apply_reset();

        repeat (3) @(posedge pcs_clk);

        fork
            begin
                send_tx_xgmii_beat({PREAMBLE_BYTE, PREAMBLE_BYTE, PREAMBLE_BYTE, XGMII_START}, 4'b0001);
                send_tx_xgmii_beat({SFD_BYTE, PREAMBLE_BYTE, PREAMBLE_BYTE, PREAMBLE_BYTE},    4'b0000);
                send_tx_xgmii_beat(32'h33221100, 4'b0000);
                send_tx_xgmii_beat(32'hBBAA5544, 4'b0000);
                send_tx_xgmii_beat(32'hFFEEDDCC, 4'b0000);
                send_tx_xgmii_beat(32'h00000008, 4'b0000);
                send_tx_xgmii_beat(32'hA1B2C3D4, 4'b0000);
                send_tx_xgmii_beat(32'h12345678, 4'b0000);
                send_tx_xgmii_beat(32'hDEADBEEF, 4'b0000);
                send_tx_xgmii_beat(32'h87654321, 4'b0000);
                send_tx_xgmii_beat(32'hFEDCBA98, 4'b0000);
                send_tx_xgmii_beat(32'h55AA33CC, 4'b0000);
                send_tx_xgmii_beat(32'h9F8E7D6C, 4'b0000);
                send_tx_xgmii_beat(32'h1A2B3C4D, 4'b0000);
                send_tx_xgmii_beat(32'hCAFEBABE, 4'b0000);
                send_tx_xgmii_beat(32'h6789ABCD, 4'b0000);
                send_tx_xgmii_beat(32'hF0E1D2C3, 4'b0000);
                send_tx_xgmii_beat(32'h3E5F7A9B, 4'b0000);
                send_tx_xgmii_beat(32'h713B28B2, 4'b0000);

                send_tx_xgmii_beat({XGMII_TERMINATE, {3{XGMII_IDLE}}}, 4'b1111);
                send_tx_xgmii_beat({4{XGMII_IDLE}},                   4'b1111);
                @(posedge pcs_clk);
                in_tx_xgmii_valid = 1'b0;
            end

            begin
                send_rx_pcs_block(64'h7B2AAAD555555555, 2'b10);

                send_rx_pcs_block(64'h46FF004433221100, 2'b01);

                send_rx_pcs_block(64'h5E8644A8B2070707, 2'b01);
                @(posedge pcs_clk);
                rx_pcs_valid  = 1'b0;
            end
        join

        repeat (50) @(posedge pcs_clk);

        $finish;
    end

endmodule
