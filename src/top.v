module top #(
    parameter AXIS_DATA_WIDTH = 32,
    parameter AXIS_DATA_BYTES = AXIS_DATA_WIDTH/8,
    parameter XGMII_DATA_WIDTH = 32,
    parameter XGMII_DATA_BYTES = XGMII_DATA_WIDTH/8,
    parameter PCS_DATA_WIDTH = 64,
    
    parameter [47:0] LOCAL_MAC = 48'hAA_BB_CC_DD_EE_FF,
    parameter [47:0] DEFAULT_DEST_MAC = 48'h00_11_22_33_44_55,
    parameter [15:0] DEFAULT_ETHER_TYPE = 16'h0800, 
    parameter RESET_POLARITY = 1'b0  // 0 = active low, 1 = active high
) (
    input sys_clk,                  // 156.25 MHz for 10G
    input sys_rst_n,              
    
    input [AXIS_DATA_WIDTH-1:0] user_tx_axis_tdata,
    input [AXIS_DATA_BYTES-1:0] user_tx_axis_tkeep,
    input user_tx_axis_tvalid,
    input user_tx_axis_tlast,
    output user_tx_axis_tready,
    
    output [AXIS_DATA_WIDTH-1:0] user_rx_axis_tdata,
    output [AXIS_DATA_BYTES-1:0] user_rx_axis_tkeep,
    output user_rx_axis_tvalid,
    output user_rx_axis_tlast,
    input user_rx_axis_tready,
    
    output [PCS_DATA_WIDTH-1:0] phy_tx_data,
    output phy_tx_valid,
    input phy_tx_ready,
    
    input [PCS_DATA_WIDTH-1:0] phy_rx_data,
    input phy_rx_valid,
    output phy_rx_ready,
    
    input [47:0] config_local_mac,
    input [47:0] config_dest_mac,
    input [15:0] config_ether_type,
    input config_promiscuous,
    input config_valid,
    
    output link_up,
    output [3:0] link_speed,
    output tx_frame_valid,
    output tx_frame_error,
    output rx_frame_valid,
    output rx_frame_error,
    output rx_crc_error
);

    reg internal_rst;
    reg [3:0] reset_counter;
    
    always @(posedge sys_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            reset_counter <= 4'hF;
            internal_rst <= (RESET_POLARITY == 1'b0) ? 1'b0 : 1'b1;
        end else begin
            if (reset_counter != 4'h0) begin
                reset_counter <= reset_counter - 1;
                internal_rst <= (RESET_POLARITY == 1'b0) ? 1'b0 : 1'b1;
            end else begin
                internal_rst <= (RESET_POLARITY == 1'b0) ? 1'b1 : 1'b0;
            end
        end
    end
    
    wire [XGMII_DATA_WIDTH-1:0] xgmii_tx_data;
    wire [XGMII_DATA_BYTES-1:0] xgmii_tx_ctrl;
    wire xgmii_tx_ready;
    
    wire [XGMII_DATA_WIDTH-1:0] xgmii_rx_data;
    wire [XGMII_DATA_BYTES-1:0] xgmii_rx_ctrl;
    wire xgmii_rx_valid;
    wire xgmii_rx_ready;
    
    wire pcs_tx_ready;
    wire pcs_rx_ready;
    
    mac #(
        .AXIS_DATA_WIDTH(AXIS_DATA_WIDTH),
        .AXIS_DATA_BYTES(AXIS_DATA_BYTES),
        .XGMII_DATA_WIDTH(XGMII_DATA_WIDTH),
        .XGMII_DATA_BYTES(XGMII_DATA_BYTES),
        .LOCAL_MAC(LOCAL_MAC),
        .DEFAULT_DEST_MAC(DEFAULT_DEST_MAC),
        .DEFAULT_ETHER_TYPE(DEFAULT_ETHER_TYPE)
    ) mac_inst (
        .mac_clk(sys_clk),
        .mac_rst(internal_rst),
        
        .xgmii_tx_data(xgmii_tx_data),
        .xgmii_tx_ctl(xgmii_tx_ctrl),
        .xgmii_tx_pcs_ready(xgmii_tx_ready),
        
        .xgmii_rx_data(xgmii_rx_data),
        .xgmii_rx_ctl(xgmii_rx_ctrl),
        .xgmii_rx_pcs_ready(xgmii_rx_ready),
        
        .tx_axis_tdata(user_tx_axis_tdata),
        .tx_axis_tkeep(user_tx_axis_tkeep),
        .tx_axis_tvalid(user_tx_axis_tvalid),
        .tx_axis_tlast(user_tx_axis_tlast),
        .tx_axis_tready(user_tx_axis_tready),
        
        .rx_axis_tdata(user_rx_axis_tdata),
        .rx_axis_tkeep(user_rx_axis_tkeep),
        .rx_axis_tvalid(user_rx_axis_tvalid),
        .rx_axis_tlast(user_rx_axis_tlast),
        .rx_axis_tready(user_rx_axis_tready),
        
        .tx_frame_valid(tx_frame_valid),
        .tx_frame_error(tx_frame_error),
        .rx_frame_valid(rx_frame_valid),
        .rx_frame_error(rx_frame_error),
        .rx_crc_error(rx_crc_error)
    );
    
    pcs #(
        .XGMII_DATA_WIDTH(XGMII_DATA_WIDTH),
        .XGMII_DATA_BYTES(XGMII_DATA_BYTES),
        .PCS_DATA_WIDTH(PCS_DATA_WIDTH)
    ) pcs_inst (
        .pcs_clk(sys_clk),
        .pcs_rst(internal_rst),
        
        .in_tx_xgmii_data(xgmii_tx_data),
        .in_tx_xgmii_ctl(xgmii_tx_ctrl),
        
        .tx_pcs_data(phy_tx_data),
        .tx_pcs_valid(phy_tx_valid),
        .tx_pcs_ready(phy_tx_ready),
        
        .rx_pcs_data(phy_rx_data),
        .rx_pcs_valid(phy_rx_valid),
        .rx_pcs_ready(phy_rx_ready),
        
        .rx_xgmii_data(xgmii_rx_data),
        .rx_xgmii_ctrl(xgmii_rx_ctrl),
        .rx_xgmii_valid(xgmii_rx_valid),
        .rx_xgmii_ready(xgmii_rx_ready)
    );    
endmodule