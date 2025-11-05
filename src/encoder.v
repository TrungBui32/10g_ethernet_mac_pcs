module encoder #(
    parameter XGMII_DATA_WIDTH = 32,
    parameter XGMII_DATA_BYTES = XGMII_DATA_WIDTH/8,
    parameter PCS_DATA_WIDTH = 64
) (
    input clk,
    input rst,
    
    input [XGMII_DATA_WIDTH-1:0] in_xgmii_data,
    input [XGMII_DATA_BYTES-1:0] in_xgmii_ctl,
    input in_xgmii_valid,
    output out_xgmii_ready,
    
    output reg [PCS_DATA_WIDTH-1:0] out_encoded_data,
    output reg [1:0] out_encoded_header,
    output reg out_encoded_valid
);

    localparam SYNC_DATA = 2'b01;      // Data 
    localparam SYNC_CTRL = 2'b10;      // Control 
    
    // Control block type field values (IEEE 802.3 Table 49-7)  
	localparam BLOCK_TYPE_C0 = 8'h1E;  // C0 C1 C2 C3 / C4 C5 C6 C7 => 11111111			
	localparam BLOCK_TYPE_S4 = 8'h33;  // C0 C1 C2 C3 / S4 D5 D6 D7 => 00011111  
	localparam BLOCK_TYPE_S0 = 8'h78;  // S0 D1 D2 D3 / D4 D5 D6 D7 => 00000001
	localparam BLOCK_TYPE_T0 = 8'h87;  // T0 C1 C2 C3 / C4 C5 C6 C7 => 11111111			// duplicate, solve by checking T0
	localparam BLOCK_TYPE_T1 = 8'h99;  // D0 T1 C2 C3 / C4 C5 C6 C7 => 11111110
	localparam BLOCK_TYPE_T2 = 8'hAA;  // D0 D1 T2 C3 / C4 C5 C6 C7 => 11111100
	localparam BLOCK_TYPE_T3 = 8'hB4;  // D0 D1 D2 T3 / C4 C5 C6 C7 => 11111000
	localparam BLOCK_TYPE_T4 = 8'hCC;  // D0 D1 D2 D3 / T4 C5 C6 C7 => 11110000
	localparam BLOCK_TYPE_T5 = 8'hD2;  // D0 D1 D2 D3 / D4 T5 C6 C7 => 11100000
	localparam BLOCK_TYPE_T6 = 8'hE1;  // D0 D1 D2 D3 / D4 D5 T6 C7 => 11000000
	localparam BLOCK_TYPE_T7 = 8'hFF;  // D0 D1 D2 D3 / D4 D5 D6 T7 => 10000000
	
	
	
    localparam XGMII_IDLE = 8'h07;
    localparam XGMII_START = 8'hFB;
    localparam XGMII_TERMINATE = 8'hFD;
    localparam XGMII_ERROR = 8'hFE;
    
    reg state;
    localparam FIRST = 1'd0;
    localparam SECOND = 1'd1;
    
    reg [63:0] xgmii_data_block;
    reg [7:0] xgmii_ctrl_block;
    reg block_ready;
    
    assign out_xgmii_ready = state == FIRST;
    
    // XGMII 
    always @(posedge clk) begin
        if (!rst) begin
            state <= FIRST;
            xgmii_data_block <= 64'h0;
            xgmii_ctrl_block <= 8'h0;
            block_ready <= 1'b0;
        end else begin
            case (state)
                FIRST: begin
                    block_ready <= 1'b0;
                    if (in_xgmii_valid) begin
                        xgmii_data_block[31:0] <= in_xgmii_data;
                        xgmii_ctrl_block[3:0] <= in_xgmii_ctl;
                        state <= SECOND;
                    end
                end
                
                SECOND: begin
                    if (in_xgmii_valid) begin
                        xgmii_data_block[63:32] <= in_xgmii_data;
                        xgmii_ctrl_block[7:4] <= in_xgmii_ctl;
                        block_ready <= 1'b1;
                        state <= FIRST;
                    end
                end
            endcase
        end
    end
    
    // 64B/66B 
    always @(posedge clk) begin
        if (!rst) begin
            out_encoded_data <= 66'h0;
            out_encoded_valid <= 1'b0;
        end else if (block_ready) begin
            out_encoded_valid <= 1'b1;
            if (xgmii_ctrl_block == 8'h00) begin
                out_encoded_header <= SYNC_DATA;
                out_encoded_data <= {xgmii_data_block};
            end else begin
                out_encoded_header <= SYNC_CTRL;
                casez (xgmii_ctrl_block)
                    8'b11111111: begin 			// C0 and T0
						if(xgmii_data_block[7:0] == 8'hFD) begin 		// T0, 8'hFD == XGMII_TERMINATE
							out_encoded_data[63:56] <= BLOCK_TYPE_T0;
							out_encoded_data[55:0] <= {7{XGMII_IDLE}};
						end else begin 									// C0
							out_encoded_data[63:56] <= BLOCK_TYPE_C0;
							out_encoded_data[55:0] <= {7{XGMII_IDLE}};
						end
                    end
                    
                    8'b00011111: begin 
                        out_encoded_data[63:56] <= BLOCK_TYPE_S4;
                        out_encoded_data[55:32] <= xgmii_data_block[31:8];
                        out_encoded_data[31:0] <= xgmii_data_block[63:32];
                    end
                    
                    8'b00000001: begin 
                        out_encoded_data[63:56] <= BLOCK_TYPE_S0;
                        out_encoded_data[55:0] <= xgmii_data_block[63:8];
                    end
                    
                    8'b11111110: begin 
                        out_encoded_data[63:56] <= BLOCK_TYPE_T1;
                        out_encoded_data[55:48] <= xgmii_data_block[7:0];
                        out_encoded_data[47:0] <= {6{XGMII_IDLE}};
                    end
                    
                    8'b11111100: begin 
                        out_encoded_data[63:56] <= BLOCK_TYPE_T2;
                        out_encoded_data[55:40] <= xgmii_data_block[15:0];
                        out_encoded_data[39:0] <= {5{XGMII_IDLE}};
                    end
                    
                    8'b11111000: begin 
                        out_encoded_data[63:56] <= BLOCK_TYPE_T3;
                        out_encoded_data[55:32] <= xgmii_data_block[23:0];
                        out_encoded_data[31:0] <= {4{XGMII_IDLE}};
                    end
                    
                    8'b11110000: begin 
                        out_encoded_data[63:56] <= BLOCK_TYPE_T4;
                        out_encoded_data[55:24] <= xgmii_data_block[31:0];
                        out_encoded_data[23:0] <= {3{XGMII_IDLE}};
                    end
                    
                    8'b11100000: begin 
                        out_encoded_data[63:56] <= BLOCK_TYPE_T5;
                        out_encoded_data[55:16] <= xgmii_data_block[39:0];
                        out_encoded_data[15:0] <= {2{XGMII_IDLE}};
                    end
                    
                    8'b11000000: begin
                        out_encoded_data[63:56] <= BLOCK_TYPE_T6;
                        out_encoded_data[55:8] <= xgmii_data_block[47:0];
                        out_encoded_data[7:0] <= XGMII_IDLE;
                    end
                    
                    8'b10000000: begin 
                        out_encoded_data[63:56] <= BLOCK_TYPE_T7;
                        out_encoded_data[55:0] <= xgmii_data_block[55:0];
                    end
                    
                    default: begin  
                        out_encoded_data[63:56] <= BLOCK_TYPE_C0;
                        out_encoded_data[55:0] <= {7{XGMII_ERROR}};
                    end
                endcase
            end
        end else begin
            out_encoded_valid <= 1'b0;
        end
    end

endmodule