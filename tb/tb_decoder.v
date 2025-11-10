module tb_decoder();
    parameter PCS_DATA_WIDTH = 64;
    parameter XGMII_DATA_WIDTH = 32;
    parameter XGMII_DATA_BYTES = XGMII_DATA_WIDTH/8;
    
    reg clk;
    reg rst;
    
    reg [PCS_DATA_WIDTH-1:0] encoded_data_in;
    reg [1:0] encoded_header_in;
    reg encoded_valid_in;
    
    wire [XGMII_DATA_WIDTH-1:0] xgmii_data_out;
    wire [XGMII_DATA_BYTES-1:0] xgmii_ctrl_out;
    wire xgmii_valid_out;
    reg xgmii_ready_in;
    
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    decoder #(
        .XGMII_DATA_WIDTH(XGMII_DATA_WIDTH),
        .XGMII_DATA_BYTES(XGMII_DATA_BYTES),
        .PCS_DATA_WIDTH(PCS_DATA_WIDTH)
    ) dut (
        .clk(clk),
        .rst(rst),
        .in_encoded_data(encoded_data_in),
        .in_encoded_header(encoded_header_in),
        .in_encoded_valid(encoded_valid_in),
        .out_xgmii_data(xgmii_data_out),
        .out_xgmii_ctl(xgmii_ctrl_out),
        .out_xgmii_valid(xgmii_valid_out),
        .in_xgmii_ready(xgmii_ready_in)
    );
    
    task init_signals;
        begin
            rst = 1'b0;
            encoded_data_in = 0;
            encoded_header_in = 0;
            encoded_valid_in = 0;
            xgmii_ready_in = 0;
        end
    endtask
    
    task apply_reset;
        begin
            @(posedge clk);
            rst = 1'b0;
            repeat(2) @(posedge clk);
            rst = 1'b1;
            @(posedge clk);
        end
    endtask
    
    task send_block;
        input [PCS_DATA_WIDTH-1:0] data;
        input [1:0] header;
        begin
            @(posedge clk);
            encoded_data_in = data;
            encoded_header_in = header;
            encoded_valid_in = 1'b1;
            xgmii_ready_in = 1'b1;
            @(posedge clk);
            encoded_valid_in = 1'b0; 
        end        
    endtask
    
    initial begin
        init_signals();
        apply_reset();

        send_block(64'h0123456789ABCDEF, 2'b01);
        send_block(64'h1E55555555555555, 2'b10);
        send_block(64'h78D5555555555555, 2'b10);
        send_block(64'h33AABBCCDD112233, 2'b10);
        send_block(64'h8700000000000000, 2'b10);
        send_block(64'h99AA000000000000, 2'b10);
        send_block(64'hAAABCD0000000000, 2'b10);
        send_block(64'hB4ABCDEF00000000, 2'b10);
        send_block(64'hCCABCDEF12000000, 2'b10);
        send_block(64'hD2ABCDEF12340000, 2'b10);
        send_block(64'hE1ABCDEF12345600, 2'b10);
        send_block(64'hFFABCDEF12345678, 2'b10);
        send_block(64'h5555555555555555, 2'b10);
        send_block(64'h0123456789ABCDEF, 2'b11);
         
        #100;
        $finish;
    end
    
endmodule
