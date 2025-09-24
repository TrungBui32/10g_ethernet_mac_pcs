module mac #(
    parameter AXIS_DATA_WIDTH = 32,
    parameter AXIS_DATA_BYTES = AXIS_DATA_WIDTH/8,
    parameter XGMII_DATA_WIDTH = 32,
    parameter XGMII_DATA_BYTES = XGMII_DATA_WIDTH/8,
    
    parameter [47:0] LOCAL_MAC = 48'hAA_BB_CC_DD_EE_FF,
    parameter [47:0] DEFAULT_DEST_MAC = 48'h00_11_22_33_44_55,
    parameter [15:0] DEFAULT_ETHER_TYPE = 16'h0800         
) (
    input mac_clk,             
    input mac_rst,                
                   
    // TX
    input [AXIS_DATA_WIDTH-1:0] tx_axis_tdata,
    input [AXIS_DATA_BYTES-1:0] tx_axis_tkeep,
    input tx_axis_tvalid,
    input tx_axis_tlast,
    output tx_axis_tready,
    
    output [XGMII_DATA_WIDTH-1:0] xgmii_tx_data,
    output [XGMII_DATA_BYTES-1:0] xgmii_tx_ctl,
    input xgmii_tx_pcs_ready,
    
    output tx_frame_valid,              
    output tx_frame_error,     
    
    // RX
    input [XGMII_DATA_WIDTH-1:0] xgmii_rx_data,
    input [XGMII_DATA_BYTES-1:0] xgmii_rx_ctl,
    output xgmii_rx_pcs_ready,
    
    output [AXIS_DATA_WIDTH-1:0] rx_axis_tdata,
    output [AXIS_DATA_BYTES-1:0] rx_axis_tkeep,
    output rx_axis_tvalid,
    output rx_axis_tlast,
    input rx_axis_tready,
            
    output rx_frame_valid,              
    output rx_frame_error,          
    output rx_crc_error,          
    
    
    output [31:0] stat_tx_frames,      
    output [31:0] stat_tx_bytes,       
    output [31:0] stat_tx_errors,      
    output [31:0] stat_rx_frames,     
    output [31:0] stat_rx_bytes,       
    output [31:0] stat_rx_errors,      
    output [31:0] stat_rx_crc_errors     
);
    
    reg [31:0] tx_frame_counter;
    reg [31:0] tx_byte_counter;
    reg [31:0] tx_error_counter;
    reg [31:0] rx_frame_counter;
    reg [31:0] rx_byte_counter;
    reg [31:0] rx_error_counter;
    reg [31:0] rx_crc_error_counter;
    
    wire tx_mac_frame_error;
    wire tx_mac_frame_valid;
    
    wire rx_mac_frame_error;
    wire rx_mac_frame_valid;
    wire rx_mac_crc_error;
    
    
    assign tx_frame_valid = tx_mac_frame_valid;
    assign tx_frame_error = tx_mac_frame_error;
    
    assign rx_frame_valid = rx_mac_frame_valid;
    assign rx_frame_error = rx_mac_frame_error;
    assign rx_crc_error = rx_mac_crc_error;
    
    assign stat_tx_frames = tx_frame_counter;
    assign stat_tx_bytes = tx_byte_counter;
    assign stat_tx_errors = tx_error_counter;
    assign stat_rx_frames = rx_frame_counter;
    assign stat_rx_bytes = rx_byte_counter;
    assign stat_rx_errors = rx_error_counter;
    assign stat_rx_crc_errors = rx_crc_error_counter;
    
    reg [3:0] tx_byte_count_current;
    reg [3:0] rx_byte_count_current;
    
    always @(*) begin
        case(tx_axis_tkeep)
            4'b1111: tx_byte_count_current = 4;
            4'b0111: tx_byte_count_current = 3;
            4'b0011: tx_byte_count_current = 2;
            4'b0001: tx_byte_count_current = 1;
            default: tx_byte_count_current = 0;
        endcase
    end
    
    always @(*) begin
        case(rx_axis_tkeep)
            4'b1111: rx_byte_count_current = 4;
            4'b0111: rx_byte_count_current = 3;
            4'b0011: rx_byte_count_current = 2;
            4'b0001: rx_byte_count_current = 1;
            default: rx_byte_count_current = 0;
        endcase
    end
    
    always @(posedge mac_clk) begin
        if (!mac_rst) begin
            tx_frame_counter <= 0;
            tx_byte_counter <= 0;
            tx_error_counter <= 0;
            rx_frame_counter <= 0;
            rx_byte_counter <= 0;
            rx_error_counter <= 0;
            rx_crc_error_counter <= 0;
        end else begin
            if (tx_axis_tvalid && tx_axis_tready) begin
                tx_byte_counter <= tx_byte_counter + tx_byte_count_current;
                if (tx_axis_tlast) begin
                    tx_frame_counter <= tx_frame_counter + 1;
                end
            end
            
            if (rx_axis_tvalid && rx_axis_tready) begin
                rx_byte_counter <= rx_byte_counter + rx_byte_count_current;
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
        .in_xgmii_pcs_ready(xgmii_tx_pcs_ready),
        .frame_valid(tx_frame_valid),
        .frame_error(tx_frame_error)
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