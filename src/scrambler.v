module scrambler #( 
    parameter DATA_WIDTH = 64 
)( 
    input clk, 
    input rst, 
    input [DATA_WIDTH-1:0] data_in, 
    input data_in_valid, 
    output [DATA_WIDTH-1:0] data_out 
); 
    reg [127:0] data; 
    wire [127:0] next_data;
    
    always @(posedge clk) begin
        if(!rst) begin
            data <= {128{1'b1}};
        end else if(data_in_valid) begin
            data <= next_data;
        end
    end 
        
    assign next_data = {data_out, data[63:0]};
    
    genvar i;
    generate 
        for(i = 0; i < DATA_WIDTH; i = i + 1) begin
            assign data_out[i] = data_in[i] ^ data[DATA_WIDTH + i - 39] ^ data[DATA_WIDTH + i - 58];
        end
    endgenerate
endmodule