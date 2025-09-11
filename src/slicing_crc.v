module slicing_crc #(
    parameter SLICE_LENGTH = 8,
    parameter INITIAL_CRC = 32'hFFFFFFFF,
    parameter INVERT_OUTPUT = 1,
    parameter REGISTER_OUTPUT = 1,
    parameter MAX_SLICE_LENGTH = 16
) (
    input wire i_clk,
    input wire i_reset,
    input wire [8*SLICE_LENGTH-1:0] i_data,
    input wire [SLICE_LENGTH-1:0] i_valid,
    output wire [31:0] o_crc
);

    reg [31:0] crc_tables [0:MAX_SLICE_LENGTH-1][0:255];
    
    localparam [31:0] CRC_POLY = 32'h04C11DB7;
    
    integer table_i, table_j, bit_i;
    reg [31:0] temp_crc;
    initial begin
        for (table_i = 0; table_i < MAX_SLICE_LENGTH; table_i = table_i + 1) begin
            for (table_j = 0; table_j < 256; table_j = table_j + 1) begin
                temp_crc = table_j;
                temp_crc = temp_crc << (table_i * 8);
                for (bit_i = 0; bit_i < 8; bit_i = bit_i + 1) begin
                    if (temp_crc[31]) begin
                        temp_crc = (temp_crc << 1) ^ CRC_POLY;
                    end else begin
                        temp_crc = temp_crc << 1;
                    end
                end
                
                crc_tables[table_i][table_j] = temp_crc;
            end
        end
    end

    localparam NUM_INPUT_BYTES_WIDTH = $clog2(SLICE_LENGTH) + 1;
    reg [NUM_INPUT_BYTES_WIDTH-1:0] num_input_bytes;
    wire any_valid;
    
    integer count_i;
    always @(*) begin
        num_input_bytes = 0;
        for (count_i = 0; count_i < SLICE_LENGTH; count_i = count_i + 1) begin
            if (i_valid[count_i]) begin
                num_input_bytes = count_i + 1;
            end
        end
    end
    
    assign any_valid = |i_valid;

    reg [31:0] prev_crc;
    reg [31:0] crc_calc;
    wire [31:0] crc_out;

    always @(posedge i_clk) begin
        if (i_reset) begin
            prev_crc <= INITIAL_CRC;
        end else if (any_valid) begin
            prev_crc <= crc_calc;
        end
    end

    wire [31:0] table_outs [0:SLICE_LENGTH-1];
    wire [7:0] table_lookups [0:SLICE_LENGTH-1];
    
    genvar gi;
    generate 
        for (gi = 0; gi < SLICE_LENGTH; gi = gi + 1) begin: gen_table_lookup
            if (gi < 4) begin: gen_prev_crc_lookup
                assign table_lookups[gi] = i_data[8*gi +: 8] ^ prev_crc[8*gi +: 8];
            end else begin: gen_data_only_lookup
                assign table_lookups[gi] = i_data[8*gi +: 8];
            end
            assign table_outs[gi] = crc_tables[num_input_bytes - gi - 1][table_lookups[gi]];
        end 
    endgenerate

    integer calc_i;
    always @(*) begin
        crc_calc = 32'h0;
        for (calc_i = 0; calc_i < SLICE_LENGTH; calc_i = calc_i + 1) begin
            if (i_valid[calc_i]) begin
                crc_calc = crc_calc ^ table_outs[calc_i];
            end
        end
        if (num_input_bytes < 4) begin
            crc_calc = crc_calc ^ (prev_crc >> (8 * num_input_bytes));
        end
    end
    assign crc_out = (REGISTER_OUTPUT == 1) ? prev_crc : crc_calc;
    assign o_crc = (INVERT_OUTPUT == 1) ? ~crc_out : crc_out;

endmodule