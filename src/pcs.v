module pcs #(
    parameter XGMII_DATA_WIDTH = 32,
    parameter XGMII_DATA_BYTES = XGMII_DATA_WIDTH/8,
    parameter PCS_DATA_WIDTH = 66
) (
    input pcs_clk,
    input pcs_rst,
    
    input [XGMII_DATA_WIDTH-1:0] tx_xgmii_data,
    input [XGMII_DATA_BYTES-1:0] tx_xgmii_ctrl,
    output tx_xgmii_ready,
    
    output [PCS_DATA_WIDTH-1:0] tx_pcs_data,
    output tx_pcs_valid,
    input tx_pcs_ready,
    
    input [PCS_DATA_WIDTH-1:0] rx_pcs_data,
    input rx_pcs_valid,
    output rx_pcs_ready,
    
    output [XGMII_DATA_WIDTH-1:0] rx_xgmii_data,
    output [XGMII_DATA_BYTES-1:0] rx_xgmii_ctrl,
    output rx_xgmii_valid,
    input rx_xgmii_ready
);

    wire [PCS_DATA_WIDTH-1:0] encoded_data;
    wire encoded_valid;
    wire encoded_ready;
    
    wire [PCS_DATA_WIDTH-1:0] scrambled_data;
    wire scrambled_valid;
    wire scrambled_ready;
    
    wire [PCS_DATA_WIDTH-1:0] descrambled_data;
    wire descrambled_valid;
    wire descrambled_ready;
    
    encoder encoder_inst (
        .tx_clk(pcs_clk),
        .tx_rst(pcs_rst),
        .xgmii_data_in(tx_xgmii_data),
        .xgmii_ctrl_in(tx_xgmii_ctrl),
        .xgmii_ready(tx_xgmii_ready),
        .encoded_data_out(encoded_data),
        .encoded_valid_out(encoded_valid),
        .encoded_ready_in(encoded_ready)
    );
    
    scrambler scrambler_inst (
        .tx_clk(pcs_clk),
        .tx_rst(pcs_rst),
        .data_in(encoded_data),
        .data_valid_in(encoded_valid),
        .data_ready_out(encoded_ready),
        .data_out(scrambled_data),
        .data_valid_out(scrambled_valid),
        .data_ready_in(scrambled_ready)
    );
    
    assign tx_pcs_data = scrambled_data;
    assign tx_pcs_valid = scrambled_valid;
    assign scrambled_ready = tx_pcs_ready;
    
    descrambler descrambler_inst (
        .rx_clk(pcs_clk),
        .rx_rst(pcs_rst),
        .data_in(rx_pcs_data),
        .data_valid_in(rx_pcs_valid),
        .data_ready_out(rx_pcs_ready),
        .data_out(descrambled_data),
        .data_valid_out(descrambled_valid),
        .data_ready_in(descrambled_ready)
    );
    
    decoder decoder_inst (
        .rx_clk(pcs_clk),
        .rx_rst(pcs_rst),
        .encoded_data_in(descrambled_data),
        .encoded_valid_in(descrambled_valid),
        .encoded_ready_out(descrambled_ready),
        .xgmii_data_out(rx_xgmii_data),
        .xgmii_ctrl_out(rx_xgmii_ctrl),
        .xgmii_valid_out(rx_xgmii_valid),
        .xgmii_ready_in(rx_xgmii_ready)
    );

endmodule
