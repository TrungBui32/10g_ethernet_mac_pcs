module pcs #(
    parameter XGMII_DATA_WIDTH = 32,
    parameter XGMII_DATA_BYTES = XGMII_DATA_WIDTH/8,
    parameter PCS_DATA_WIDTH = 64
) (
    input pcs_clk,
    input pcs_rst,
    
    // receive from tx mac
    input [XGMII_DATA_WIDTH-1:0] in_tx_xgmii_data,
    input [XGMII_DATA_BYTES-1:0] in_tx_xgmii_ctl,
    input in_tx_xgmii_valid,
    output out_tx_xgmii_ready,
    
    // ouput of pcs to gearbox
    output [PCS_DATA_WIDTH-1:0] tx_pcs_data,
    output tx_pcs_data_valid,
    input tx_pcs_ready,
    
    // input from gearbox to pcs
    input [PCS_DATA_WIDTH-1:0] rx_pcs_data,
    input [1:0] rx_pcs_header,
    input rx_pcs_valid,
    
    // output of pcs to rx mac
    output [XGMII_DATA_WIDTH-1:0] rx_xgmii_data,
    output [XGMII_DATA_BYTES-1:0] rx_xgmii_ctl,
    output rx_xgmii_valid,
    input rx_xgmii_ready
);
    // encoder signals
    wire encoder_clk;
    wire encoder_rst;
    wire [XGMII_DATA_WIDTH-1:0] encoder_xgmii_data;
    wire [XGMII_DATA_BYTES-1:0] encoder_xgmii_ctl;
    wire encoder_xgmii_valid;
    wire encoder_xgmii_ready;
    wire [PCS_DATA_WIDTH-1:0] encoder_encoded_data;
    wire [1:0] encoder_encoded_header;
    wire encoder_encoded_valid;

    // scrambler signals
    wire scrambler_clk;
    wire scrambler_rst;
    wire [PCS_DATA_WIDTH-1:0] scrambler_in_data;
    wire scrambler_in_data_valid;
    wire [PCS_DATA_WIDTH-1:0] scrambled_data;
    wire scramber_out_data_valid;

    // descrambler signals
    wire descrambler_clk;
    wire descrambler_rst;
    wire [PCS_DATA_WIDTH-1:0] descrambler_in_data;
    wire descrambler_in_data_valid;
    wire [PCS_DATA_WIDTH-1:0] descrambled_data;

    // decoder signals
    wire decoder_clk;
    wire decoder_rst;
    wire [PCS_DATA_WIDTH-1:0] decoder_in_encoded_data;
    wire [1:0] decoder_in_encoded_header;
    wire decoder_in_encoded_valid;
    wire [XGMII_DATA_WIDTH-1:0] decoder_xgmii_data;
    wire [XGMII_DATA_BYTES-1:0] decoder_xgmii_ctl;
    wire decoder_xgmii_valid;
    wire decoder_xgmii_ready;
    
    // encoder assignements
    assign encoder_clk = pcs_clk;
    assign encoder_rst = pcs_rst;
    assign encoder_xgmii_data = in_tx_xgmii_data;
    assign encoder_xgmii_ctl = in_tx_xgmii_ctl;
    assign encoder_xgmii_valid = in_tx_xgmii_valid;
    assign out_tx_xgmii_ready = encoder_xgmii_ready;


    // scrambler assignements
    assign scrambler_clk = pcs_clk;
    assign scrambler_rst = pcs_rst;
    assign scrambler_in_data = encoder_encoded_data;
    assign scrambler_in_data_valid = encoder_encoded_valid;

    // descrambler assignements
    assign descrambler_clk = pcs_clk;
    assign descrambler_rst = pcs_rst;
    assign descrambler_in_data = rx_pcs_data;
    assign descrambler_in_data_valid = rx_pcs_valid;

    // decoder assignements
    assign decoder_clk = pcs_clk;
    assign decoder_rst = pcs_rst;
    assign decoder_in_encoded_data = descrambled_data;
    assign decoder_in_encoded_header = rx_pcs_header; 
    assign decoder_in_encoded_valid = rx_pcs_valid;
    assign decoder_xgmii_ready = rx_xgmii_ready;

    // pcs output assignements
    assign tx_pcs_data = scrambled_data;
    assign rx_xgmii_data = decoder_xgmii_data;
    assign rx_xgmii_ctl = decoder_xgmii_ctl;
    assign rx_xgmii_valid = decoder_xgmii_valid;
    assign tx_pcs_data_valid = scramber_out_data_valid;

    encoder encoder_inst (
        .clk(encoder_clk),
        .rst(encoder_rst),
        .in_xgmii_data(encoder_xgmii_data),
        .in_xgmii_ctl(encoder_xgmii_ctl),
        .in_xgmii_valid(encoder_xgmii_valid),
        .out_xgmii_ready(encoder_xgmii_ready),
        .out_encoded_data(encoder_encoded_data),
        .out_encoded_header(encoder_encoded_header),
        .out_encoded_valid(encoder_encoded_valid)
    );
    
    scrambler scrambler_inst (
        .clk(scrambler_clk),
        .rst(scrambler_rst),
        .in_data(scrambler_in_data),
        .in_data_valid(scrambler_in_data_valid),
        .out_data(scrambled_data),
        .out_data_valid(scramber_out_data_valid)
    );
    
    descrambler descrambler_inst (
        .clk(descrambler_clk),
        .rst(descrambler_rst),
        .in_data(descrambler_in_data),
        .in_data_valid(descrambler_in_data_valid),
        .out_data(descrambled_data)
    );
    
    decoder decoder_inst (
        .clk(decoder_clk),
        .rst(decoder_rst),
        .in_encoded_data(descrambled_data),
        .in_encoded_header(decoder_in_encoded_header),
        .in_encoded_valid(decoder_in_encoded_valid),
        .out_xgmii_data(decoder_xgmii_data),
        .out_xgmii_ctl(decoder_xgmii_ctl),
        .out_xgmii_valid(decoder_xgmii_valid),
        .in_xgmii_ready(decoder_xgmii_ready)
    );

endmodule
