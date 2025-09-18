module tb_tx_mac;

    parameter AXIS_DATA_WIDTH = 32;
    parameter AXIS_DATA_BYTES = AXIS_DATA_WIDTH / 8;
    parameter XGMII_DATA_WIDTH = 32;
    parameter XGMII_DATA_BYTES = XGMII_DATA_WIDTH / 8;

    reg tx_clk;
    reg tx_rst;

    reg [AXIS_DATA_WIDTH-1:0] in_slave_tx_tdata;
    reg [AXIS_DATA_BYTES-1:0] in_slave_tx_tkeep;
    reg in_slave_tx_tvalid;
    reg in_slave_tx_tlast;
    wire out_slave_tx_tready;

    wire [XGMII_DATA_WIDTH-1:0] out_xgmii_data;
    wire [XGMII_DATA_BYTES-1:0] out_xgmii_ctl;
    reg in_xgmii_pcs_ready;
    
    initial begin
        tx_clk = 0;
    end
    always #5 tx_clk = ~tx_clk;

    tx_mac #(
        .AXIS_DATA_WIDTH(AXIS_DATA_WIDTH),
        .AXIS_DATA_BYTES(AXIS_DATA_BYTES),
        .XGMII_DATA_WIDTH(XGMII_DATA_WIDTH),
        .XGMII_DATA_BYTES(XGMII_DATA_BYTES)
    ) dut (
        .tx_clk(tx_clk),
        .tx_rst(tx_rst),

        .in_slave_tx_tdata(in_slave_tx_tdata),
        .in_slave_tx_tkeep(in_slave_tx_tkeep),
        .in_slave_tx_tvalid(in_slave_tx_tvalid),
        .in_slave_tx_tlast(in_slave_tx_tlast),
        .out_slave_tx_tready(out_slave_tx_tready),

        .out_xgmii_data(out_xgmii_data),
        .out_xgmii_ctl(out_xgmii_ctl),
        .in_xgmii_pcs_ready(in_xgmii_pcs_ready)
    );

    initial begin
        @(posedge tx_clk);
        tx_rst = 1'b0;
        in_slave_tx_tdata = 0;
        in_slave_tx_tkeep = 0;
        in_slave_tx_tvalid = 0;
        in_slave_tx_tlast = 0;
        in_xgmii_pcs_ready = 1'b1; 

        @(posedge tx_clk);
        tx_rst = 1'b1; 
        @(posedge tx_clk);


        in_slave_tx_tvalid = 1'b1;
        in_slave_tx_tdata = 32'h11223344;
        in_slave_tx_tkeep = 4'b1111;
        in_slave_tx_tlast = 1'b0; 
        @(posedge tx_clk); 
        in_slave_tx_tdata = 32'h55667788;
        in_slave_tx_tkeep = 4'b1110;
        in_slave_tx_tvalid = 1'b1;
        in_slave_tx_tlast = 1'b1; 
//        @(posedge tx_clk);
//        in_slave_tx_tdata = 32'h11223344;
//        in_slave_tx_tkeep = 4'b1100;
//        in_slave_tx_tvalid = 1'b1;
//        in_slave_tx_tlast = 1'b1;
                
        wait (out_slave_tx_tready == 1'b1); 
        @(posedge tx_clk);

        in_slave_tx_tvalid = 1'b0;
        in_slave_tx_tlast = 1'b0;

        #250; 

        $finish;
    end

endmodule