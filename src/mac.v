module mac #(
    parameter AXIS_DATA_WIDTH = 64,
    parameter AXIS_DATA_BYTES = AXIS_DATA_WIDTH/8,
    parameter XGMII_DATA_WIDTH = 32,
    parameter XGMII_DATA_BYTES = XGMII_DATA_WIDTH/8,
    
    parameter [47:0] LOCAL_MAC = 48'hAA_BB_CC_DD_EE_FF,
    parameter [47:0] DEFAULT_DEST_MAC = 48'h00_11_22_33_44_55,
    parameter [15:0] DEFAULT_ETHER_TYPE = 16'h0800, 
    
    parameter ENABLE_PROMISCUOUS_MODE = 1'b0,      
    parameter ENABLE_CRC_CHECK = 1'b1,            
    parameter ENABLE_LENGTH_CHECK = 1'b1,          
    parameter ENABLE_PAUSE_FRAMES = 1'b0           
) (
    input mac_clk,             
    input mac_rst,              
    
    input [47:0] config_local_mac,      
    input [47:0] config_dest_mac,      
    input [15:0] config_ether_type,     
    input config_promiscuous,          
    input config_valid,                
    
    output [XGMII_DATA_WIDTH-1:0] xgmii_tx_data,
    output [XGMII_DATA_BYTES-1:0] xgmii_tx_ctl,
    input xgmii_tx_pcs_ready,
    
    input [XGMII_DATA_WIDTH-1:0] xgmii_rx_data,
    input [XGMII_DATA_BYTES-1:0] xgmii_rx_ctl,
    output xgmii_rx_pcs_ready,
    
    input [AXIS_DATA_WIDTH-1:0] tx_axis_tdata,
    input [AXIS_DATA_BYTES-1:0] tx_axis_tkeep,
    input tx_axis_tvalid,
    input tx_axis_tlast,
    output tx_axis_tready,
    
    output [AXIS_DATA_WIDTH-1:0] rx_axis_tdata,
    output [AXIS_DATA_BYTES-1:0] rx_axis_tkeep,
    output rx_axis_tvalid,
    output rx_axis_tlast,
    input rx_axis_tready,
    
    output tx_frame_valid,              
    output tx_frame_error,             
    output rx_frame_valid,              
    output rx_frame_error,          
    output rx_crc_error,          
    
    output [31:0] stat_tx_frames,      
    output [31:0] stat_tx_bytes,       
    output [31:0] stat_tx_errors,      
    output [31:0] stat_rx_frames,     
    output [31:0] stat_rx_bytes,       
    output [31:0] stat_rx_errors,      
    output [31:0] stat_rx_crc_errors,  
    
    input pause_req,                   
    input [15:0] pause_time,           
    output pause_frame_sent,           
    output pause_frame_received,       
    output [15:0] received_pause_time, 
    
    output link_up,                    
    output [3:0] link_speed            
);

    reg [47:0] active_local_mac;
    reg [47:0] active_dest_mac;
    reg [15:0] active_ether_type;
    reg active_promiscuous;
    
    initial begin
        active_local_mac = LOCAL_MAC;
        active_dest_mac = DEFAULT_DEST_MAC;
        active_ether_type = DEFAULT_ETHER_TYPE;
        active_promiscuous = ENABLE_PROMISCUOUS_MODE;
    end
    
    always @(posedge mac_clk) begin
        if (!mac_rst) begin
            active_local_mac <= LOCAL_MAC;
            active_dest_mac <= DEFAULT_DEST_MAC;
            active_ether_type <= DEFAULT_ETHER_TYPE;
            active_promiscuous <= ENABLE_PROMISCUOUS_MODE;
        end else if (config_valid) begin
            active_local_mac <= config_local_mac;
            active_dest_mac <= config_dest_mac;
            active_ether_type <= config_ether_type;
            active_promiscuous <= config_promiscuous;
        end
    end
    
    wire tx_mac_frame_valid, tx_mac_frame_error;
    wire rx_mac_frame_valid, rx_mac_frame_error, rx_mac_crc_error;
    
    reg [31:0] tx_frame_counter;
    reg [31:0] tx_byte_counter;
    reg [31:0] tx_error_counter;
    reg [31:0] rx_frame_counter;
    reg [31:0] rx_byte_counter;
    reg [31:0] rx_error_counter;
    reg [31:0] rx_crc_error_counter;
    
    reg pause_frame_detected;
    reg [15:0] pause_time_reg;
    reg pause_sent_flag;
    
    assign link_up = xgmii_tx_pcs_ready && xgmii_rx_pcs_ready;
    assign link_speed = 4'b1010; // 10G 
    
    assign tx_frame_valid = tx_mac_frame_valid;
    assign tx_frame_error = tx_mac_frame_error;
    assign rx_frame_valid = rx_mac_frame_valid && (!rx_mac_frame_error || active_promiscuous);
    assign rx_frame_error = rx_mac_frame_error;
    assign rx_crc_error = rx_mac_crc_error;
    
    assign stat_tx_frames = tx_frame_counter;
    assign stat_tx_bytes = tx_byte_counter;
    assign stat_tx_errors = tx_error_counter;
    assign stat_rx_frames = rx_frame_counter;
    assign stat_rx_bytes = rx_byte_counter;
    assign stat_rx_errors = rx_error_counter;
    assign stat_rx_crc_errors = rx_crc_error_counter;
    
    assign pause_frame_sent = pause_sent_flag;
    assign pause_frame_received = pause_frame_detected;
    assign received_pause_time = pause_time_reg;
    
    always @(posedge mac_clk) begin
        if (!mac_rst) begin
            tx_frame_counter <= 0;
            tx_byte_counter <= 0;
            tx_error_counter <= 0;
            rx_frame_counter <= 0;
            rx_byte_counter <= 0;
            rx_error_counter <= 0;
            rx_crc_error_counter <= 0;
            pause_frame_detected <= 1'b0;
            pause_time_reg <= 0;
            pause_sent_flag <= 1'b0;
        end else begin
            if (tx_mac_frame_valid) begin
                tx_frame_counter <= tx_frame_counter + 1;
            end
            
            if (tx_mac_frame_error) begin
                tx_error_counter <= tx_error_counter + 1;
            end
            
            if (rx_mac_frame_valid && !rx_mac_frame_error) begin
                rx_frame_counter <= rx_frame_counter + 1;
            end
            
            if (rx_mac_frame_error) begin
                rx_error_counter <= rx_error_counter + 1;
            end
            
            if (rx_mac_crc_error) begin
                rx_crc_error_counter <= rx_crc_error_counter + 1;
            end
            
            pause_frame_detected <= 1'b0;
            pause_sent_flag <= 1'b0;
        end
    end
    
    tx_mac #(
        .AXIS_DATA_WIDTH(AXIS_DATA_WIDTH),
        .AXIS_DATA_BYTES(AXIS_DATA_BYTES),
        .XGMII_DATA_WIDTH(XGMII_DATA_WIDTH),
        .XGMII_DATA_BYTES(XGMII_DATA_BYTES)
    ) tx_mac_inst (
        .tx_clk(mac_clk),
        .tx_rst(mac_rst),
        .in_slave_tx_tdata(tx_axis_tdata),
        .in_slave_tx_tkeep(tx_axis_tkeep),
        .in_slave_tx_tvalid(tx_axis_tvalid),
        .in_slave_tx_tlast(tx_axis_tlast),
        .out_slave_tx_tready(tx_axis_tready),
        .out_xgmii_data(xgmii_tx_data),
        .out_xgmii_ctl(xgmii_tx_ctl),
        .in_xgmii_pcs_ready(xgmii_tx_pcs_ready)
    );
    
    rx_mac #(
        .AXIS_DATA_WIDTH(AXIS_DATA_WIDTH),
        .AXIS_DATA_BYTES(AXIS_DATA_BYTES),
        .XGMII_DATA_WIDTH(XGMII_DATA_WIDTH),
        .XGMII_DATA_BYTES(XGMII_DATA_BYTES)
    ) rx_mac_inst (
        .rx_clk(mac_clk),
        .rx_rst(mac_rst),
        .in_xgmii_data(xgmii_rx_data),
        .in_xgmii_ctl(xgmii_rx_ctl),
        .out_xgmii_pcs_ready(xgmii_rx_pcs_ready),
        .out_master_rx_tdata(rx_axis_tdata),
        .out_master_rx_tkeep(rx_axis_tkeep),
        .out_master_rx_tvalid(rx_axis_tvalid),
        .out_master_rx_tlast(rx_axis_tlast),
        .in_master_rx_tready(rx_axis_tready),
        .frame_valid(rx_mac_frame_valid),
        .frame_error(rx_mac_frame_error),
        .crc_error(rx_mac_crc_error)
    );    
endmodule