module crc32 #(
    parameter SLICE_LENGTH = 8,
    parameter INITIAL_CRC = 32'hFFFFFFFF,
    parameter INVERT_OUTPUT = 1,
    parameter REGISTER_OUTPUT = 1,
    parameter MAX_SLICE_LENGTH = 16
    )(
    input clk,
    input rst,
    input [8*SLICE_LENGTH-1:0] in_data,
    input [SLICE_LENGTH-1:0] in_valid,
    output [31:0] out_crc
    );
    
    localparam NUM_INPUT_BYTES_WIDTH = $clog2(SLICE_LENGTH) + 1;
    
    reg [31:0] crc_tables [0:MAX_SLICE_LENGTH-1][0:255];
    initial begin
        $readmemh("crc_tables.mem", crc_tables);
    end
    
    reg [NUM_INPUT_BYTES_WIDTH-1:0] num_input_bytes;
    wire any_valid;
    
    integer i;
    always @(*) begin 
        num_input_bytes = 0; 
        for (i = 0; i < SLICE_LENGTH; i = i + 1) begin
            if (in_valid[i]) begin
                num_input_bytes = i + 1;
            end
        end
    end
    
    assign any_valid = |in_valid;

    // CRC storage
    reg [31:0] prev_crc, crc_calc;
    wire [31:0] crc_out;
    
    always @(posedge clk) begin
        if (rst) begin
            prev_crc <= INITIAL_CRC;
        end else if (any_valid) begin
            prev_crc <= crc_calc;
        end
    end
    
    wire [31:0] table_outs[0:SLICE_LENGTH-1];
    generate
        for(genvar gi = 0; gi < SLICE_LENGTH; gi = gi + 1) begin
            wire [7:0] table_lookup;
            wire [31:0] table_out;
            if(gi < 4) begin
                assign table_lookup = in_data[8*gi+:8] ^ prev_crc[8*gi+:8];
            end else begin
                assign table_lookup = in_data[8*gi+:8];
            end 
            assign table_out = crc_tables[num_input_bytes - gi - 1][table_lookup];
            assign table_outs[gi] = table_out;
        end
    endgenerate 
    
    always @(*) begin
        crc_calc = 0;
        for(i = 0; i < SLICE_LENGTH; i = i + 1) begin
            if(in_valid[i]) begin
                crc_calc = crc_calc ^ table_outs[i];
            end
        end 
        crc_calc = crc_calc ^ (prev_crc >> (8*num_input_bytes));
    end
    
    assign crc_out = REGISTER_OUTPUT ? prev_crc : crc_calc;
    assign out_crc = INVERT_OUTPUT ? ~crc_out : crc_out;
endmodule
