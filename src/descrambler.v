module descrambler #(
    parameter DATA_WIDTH = 66
) (
    input rx_clk,
    input rx_rst,
    
    input [DATA_WIDTH-1:0] data_in,
    input data_valid_in,
    output reg data_ready_out,
    
    output reg [DATA_WIDTH-1:0] data_out,
    output reg data_valid_out,
    input data_ready_in
);
    reg [57:0] lfsr;
    
	integer i;
    reg [57:0] temp_lfsr;
	
    always @(*) begin
        data_ready_out = data_ready_in;
    end
    
    always @(posedge rx_clk) begin
        if (!rx_rst) begin
            lfsr <= 58'h3FF_FFFF_FFFF_FFFF;
            data_out <= {DATA_WIDTH{1'b0}};
            data_valid_out <= 1'b0;
        end else if (data_valid_in && data_ready_in) begin
            data_valid_out <= 1'b1;
            data_out[65:64] <= data_in[65:64];
            if (data_in[65:64] != 2'b00) begin 
                temp_lfsr = lfsr;
                for (i = 0; i < DATA_WIDTH - 2; i = i + 1) begin
                    data_out[i] <= data_in[i] ^ temp_lfsr[57];
                    temp_lfsr <= {temp_lfsr[56:0], temp_lfsr[38] ^ temp_lfsr[57]};
                end
                
                lfsr <= temp_lfsr;
            end else begin
                data_out[63:0] <= data_in[63:0];
            end
        end else begin
            data_valid_out <= 1'b0;
        end
    end

endmodule