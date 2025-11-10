module tb_mac;
    parameter AXIS_DATA_WIDTH = 32;
    parameter AXIS_DATA_BYTES = AXIS_DATA_WIDTH / 8;
    parameter XGMII_DATA_WIDTH = 32;
    parameter XGMII_DATA_BYTES = XGMII_DATA_WIDTH / 8;

    reg mac_clk;
    reg mac_rst;

    wire [XGMII_DATA_WIDTH-1:0] xgmii_tx_data;
    wire [XGMII_DATA_BYTES-1:0] xgmii_tx_ctl;
    reg                            xgmii_tx_pcs_ready;

    reg  [XGMII_DATA_WIDTH-1:0] xgmii_rx_data;
    reg  [XGMII_DATA_BYTES-1:0] xgmii_rx_ctl;
    wire                           xgmii_rx_pcs_ready;

    reg  [AXIS_DATA_WIDTH-1:0]     tx_axis_tdata;
    reg  [AXIS_DATA_BYTES-1:0]     tx_axis_tkeep;
    reg                            tx_axis_tvalid;
    reg                            tx_axis_tlast;
    wire                           tx_axis_tready;

    wire [AXIS_DATA_WIDTH-1:0]     rx_axis_tdata;
    wire [AXIS_DATA_BYTES-1:0]     rx_axis_tkeep;
    wire                           rx_axis_tvalid;
    wire                           rx_axis_tlast;
    reg                            rx_axis_tready;

    wire tx_frame_valid;
    wire tx_frame_error;
    wire rx_frame_valid;
    wire rx_frame_error;
    wire rx_crc_error;


    localparam XGMII_IDLE      = 8'h07;
    localparam XGMII_START     = 8'hFB;
    localparam XGMII_TERMINATE = 8'hFD;
    localparam PREAMBLE_BYTE   = 8'h55;
    localparam SFD_BYTE        = 8'hD5;

    initial begin
        mac_clk = 0;
        forever #5 mac_clk = ~mac_clk;
    end

    mac #(
        .AXIS_DATA_WIDTH(AXIS_DATA_WIDTH),
        .AXIS_DATA_BYTES(AXIS_DATA_BYTES),
        .XGMII_DATA_WIDTH(XGMII_DATA_WIDTH),
        .XGMII_DATA_BYTES(XGMII_DATA_BYTES),
        .LOCAL_MAC(48'hAA_BB_CC_DD_EE_FF),
        .DEFAULT_DEST_MAC(48'h00_11_22_33_44_55),
        .DEFAULT_ETHER_TYPE(16'h0800)
    ) dut (
        .mac_clk(mac_clk),
        .mac_rst(mac_rst),
        .xgmii_tx_data(xgmii_tx_data),
        .xgmii_tx_ctl(xgmii_tx_ctl),
        .xgmii_tx_pcs_ready(xgmii_tx_pcs_ready),
        .xgmii_rx_data(xgmii_rx_data),
        .xgmii_rx_ctl(xgmii_rx_ctl),
        .xgmii_rx_pcs_ready(xgmii_rx_pcs_ready),
        .tx_axis_tdata(tx_axis_tdata),
        .tx_axis_tkeep(tx_axis_tkeep),
        .tx_axis_tvalid(tx_axis_tvalid),
        .tx_axis_tlast(tx_axis_tlast),
        .tx_axis_tready(tx_axis_tready),
        .rx_axis_tdata(rx_axis_tdata),
        .rx_axis_tkeep(rx_axis_tkeep),
        .rx_axis_tvalid(rx_axis_tvalid),
        .rx_axis_tlast(rx_axis_tlast),
        .rx_axis_tready(rx_axis_tready),
        .tx_frame_valid(tx_frame_valid),
        .tx_frame_error(tx_frame_error),
        .rx_frame_valid(rx_frame_valid),
        .rx_frame_error(rx_frame_error),
        .rx_crc_error(rx_crc_error)
    );

    task init_signals;
        begin
            mac_rst              = 1'b0;
            xgmii_tx_pcs_ready   = 1'b0;

            xgmii_rx_data        = {4{XGMII_IDLE}};
            xgmii_rx_ctl         = 4'b1111;

            tx_axis_tdata        = {AXIS_DATA_WIDTH{1'b0}};
            tx_axis_tkeep        = {AXIS_DATA_BYTES{1'b0}};
            tx_axis_tvalid       = 1'b0;
            tx_axis_tlast        = 1'b0;

            rx_axis_tready       = 1'b1;
        end
    endtask

    task apply_reset;
        begin
            @(posedge mac_clk);
            mac_rst = 1'b0;
            repeat(2) @(posedge mac_clk);
            mac_rst = 1'b1;
            @(posedge mac_clk);
        end
    endtask

    task send_tx_beat;
        input [AXIS_DATA_WIDTH-1:0] data;
        input [AXIS_DATA_BYTES-1:0] keep;
        input last;
        begin
            @(posedge mac_clk);
            tx_axis_tdata  = data;
            tx_axis_tkeep  = keep;
            tx_axis_tvalid = 1'b1;
            tx_axis_tlast  = last;
        end
    endtask

    task clear_tx;
        begin
            @(posedge mac_clk);
            tx_axis_tdata  = {AXIS_DATA_WIDTH{1'b0}};
            tx_axis_tkeep  = {AXIS_DATA_BYTES{1'b0}};
            tx_axis_tvalid = 1'b0;
            tx_axis_tlast  = 1'b0;
        end
    endtask

    task send_rx_xgmii_beat;
        input [XGMII_DATA_WIDTH-1:0] data;
        input [XGMII_DATA_BYTES-1:0] ctl;
        begin
            @(posedge mac_clk);
            xgmii_rx_data = data;
            xgmii_rx_ctl  = ctl;
        end
    endtask

    task send_rx_xgmii_idles;
        begin
            @(posedge mac_clk);
            xgmii_rx_data = {4{XGMII_IDLE}};
            xgmii_rx_ctl  = 4'b1111;
        end
    endtask

    initial begin
        init_signals();
        apply_reset();

        xgmii_tx_pcs_ready = 1'b1;

        repeat (5) @(posedge mac_clk);

        wait (xgmii_tx_pcs_ready == 1'b1);

        send_tx_beat(32'hA1B2C3D4, 4'b1111, 1'b0);
        xgmii_rx_data = {PREAMBLE_BYTE, PREAMBLE_BYTE, PREAMBLE_BYTE, XGMII_START};
        xgmii_rx_ctl  = 4'b0001;

        send_tx_beat(32'h12345678, 4'b1111, 1'b0);
        xgmii_rx_data = {SFD_BYTE, PREAMBLE_BYTE, PREAMBLE_BYTE, PREAMBLE_BYTE};
        xgmii_rx_ctl  = 4'b0000;

        send_tx_beat(32'hDEADBEEF, 4'b1111, 1'b0);
        xgmii_rx_data = 32'h33221100;
        xgmii_rx_ctl  = 4'b0000;

        send_tx_beat(32'h87654321, 4'b1111, 1'b0);
        xgmii_rx_data = 32'hBBAA5544;
        xgmii_rx_ctl  = 4'b0000;

        send_tx_beat(32'hFEDCBA98, 4'b1111, 1'b0);
        xgmii_rx_data = 32'hFFEEDDCC;
        xgmii_rx_ctl  = 4'b0000;

        send_tx_beat(32'h55AA33CC, 4'b1111, 1'b0);
        xgmii_rx_data = 32'h00000008;
        xgmii_rx_ctl  = 4'b0000;

        send_tx_beat(32'h9F8E7D6C, 4'b1111, 1'b0);
        xgmii_rx_data = 32'hA1B2C3D4;
        xgmii_rx_ctl  = 4'b0000;

        send_tx_beat(32'h1A2B3C4D, 4'b1111, 1'b0);
        xgmii_rx_data = 32'h12345678;
        xgmii_rx_ctl  = 4'b0000;

        send_tx_beat(32'hCAFEBABE, 4'b1111, 1'b0);
        xgmii_rx_data = 32'hDEADBEEF;
        xgmii_rx_ctl  = 4'b0000;

        send_tx_beat(32'h6789ABCD, 4'b1111, 1'b0);
        xgmii_rx_data = 32'h87654321;
        xgmii_rx_ctl  = 4'b0000;

        send_tx_beat(32'hF0E1D2C3, 4'b1111, 1'b0);
        xgmii_rx_data = 32'hFEDCBA98;
        xgmii_rx_ctl  = 4'b0000;

        send_tx_beat(32'h3E5F7A9B, 4'b1111, 1'b1);
        xgmii_rx_data = 32'h55AA33CC;
        xgmii_rx_ctl  = 4'b0000;

        clear_tx();
        xgmii_rx_data = 32'h9F8E7D6C;
        xgmii_rx_ctl  = 4'b0000;

        send_rx_xgmii_beat(32'h1A2B3C4D, 4'b0000); // 8
        send_rx_xgmii_beat(32'hCAFEBABE, 4'b0000); // 9
        send_rx_xgmii_beat(32'h6789ABCD, 4'b0000); // 10
        send_rx_xgmii_beat(32'hF0E1D2C3, 4'b0000); // 11
        send_rx_xgmii_beat(32'h3E5F7A9B, 4'b0000); // 12
        send_rx_xgmii_beat(32'h0F0821EE, 4'b0000); // CRC

        send_rx_xgmii_beat({XGMII_TERMINATE, {3{XGMII_IDLE}}}, 4'b1111);
        send_rx_xgmii_idles();

        wait (xgmii_tx_pcs_ready == 1'b1);

        send_tx_beat(32'hA1B2C3D4, 4'b1111, 1'b0);
        xgmii_rx_data = {PREAMBLE_BYTE, PREAMBLE_BYTE, PREAMBLE_BYTE, XGMII_START};
        xgmii_rx_ctl  = 4'b0001;

        send_tx_beat(32'h12345678, 4'b1111, 1'b0);
        xgmii_rx_data = {SFD_BYTE, PREAMBLE_BYTE, PREAMBLE_BYTE, PREAMBLE_BYTE};
        xgmii_rx_ctl  = 4'b0000;

        send_tx_beat(32'hDEADBEEF, 4'b1111, 1'b0);
        xgmii_rx_data = 32'h33221100;
        xgmii_rx_ctl  = 4'b0000;

        send_tx_beat(32'h87654321, 4'b1111, 1'b0);
        xgmii_rx_data = 32'hBBAA5544;
        xgmii_rx_ctl  = 4'b0000;

        send_tx_beat(32'hFEDCBA98, 4'b1111, 1'b0);
        xgmii_rx_data = 32'hFFEEDDCC;
        xgmii_rx_ctl  = 4'b0000;

        send_tx_beat(32'h55AA33CC, 4'b1111, 1'b0);
        xgmii_rx_data = 32'h00000008;
        xgmii_rx_ctl  = 4'b0000;

        send_tx_beat(32'h9F8E7D6C, 4'b1111, 1'b0);
        xgmii_rx_data = 32'hA1B2C3D4;
        xgmii_rx_ctl  = 4'b0000;

        send_tx_beat(32'h1A2B3C4D, 4'b1111, 1'b0);
        xgmii_rx_data = 32'h12345678;
        xgmii_rx_ctl  = 4'b0000;

        send_tx_beat(32'hCAFEBABE, 4'b1111, 1'b0);
        xgmii_rx_data = 32'hDEADBEEF;
        xgmii_rx_ctl  = 4'b0000;

        send_tx_beat(32'h6789ABCD, 4'b1111, 1'b0);
        xgmii_rx_data = 32'h87654321;
        xgmii_rx_ctl  = 4'b0000;

        send_tx_beat(32'hF0E1D2C3, 4'b1111, 1'b0);
        xgmii_rx_data = 32'hFEDCBA98;
        xgmii_rx_ctl  = 4'b0000;

        send_tx_beat(32'h3E5F7A9B, 4'b1111, 1'b1);
        xgmii_rx_data = 32'h55AA33CC;
        xgmii_rx_ctl  = 4'b0000;

        clear_tx();
        xgmii_rx_data = 32'h9F8E7D6C;
        xgmii_rx_ctl  = 4'b0000;

        send_rx_xgmii_beat(32'h1A2B3C4D, 4'b0000); // 8
        send_rx_xgmii_beat(32'hCAFEBABE, 4'b0000); // 9
        send_rx_xgmii_beat(32'h6789ABCD, 4'b0000); // 10
        send_rx_xgmii_beat(32'hF0E1D2C3, 4'b0000); // 11
        send_rx_xgmii_beat(32'h3E5F7A9B, 4'b0000); // 12
        send_rx_xgmii_beat(32'h0F0821EE, 4'b0000); // CRC

        send_rx_xgmii_beat({XGMII_TERMINATE, {3{XGMII_IDLE}}}, 4'b1111);
        send_rx_xgmii_idles();

        repeat (50) @(posedge mac_clk);

        $finish;
    end

endmodule
