module scrambler #( 
    parameter PCS_DATA_WIDTH = 64 
)( 
    input clk, 
    input rst, 
    input [PCS_DATA_WIDTH-1:0] in_data, 
    input in_data_valid, 
    output [PCS_DATA_WIDTH-1:0] out_data,
    output reg out_data_valid
); 
    reg [127:0] data; 
    wire [127:0] next_data;
    
    always @(posedge clk) begin
        if(!rst) begin
            data <= {128{1'b1}};
        end else if(in_data_valid) begin
            data <= next_data;
            out_data_valid <= 1'b1;
        end else begin
            out_data_valid <= 1'b0;
        end
    end 
        
    assign next_data = {out_data, data[63:0]};
    
    genvar i;
    generate 
        for(i = 0; i < PCS_DATA_WIDTH; i = i + 1) begin
            assign out_data[i] = in_data[i] ^ data[PCS_DATA_WIDTH + i - 39] ^ data[PCS_DATA_WIDTH + i - 58];
        end
    endgenerate
endmodule