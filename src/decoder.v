module decoder #(
    parameter XGMII_DATA_WIDTH = 32,
    parameter XGMII_DATA_BYTES = XGMII_DATA_WIDTH/8,
    parameter PCS_DATA_WIDTH = 64
) (
    input clk,
    input rst,
    
    input [PCS_DATA_WIDTH-1:0] in_encoded_data,
    input [1:0] in_encoded_header,
    input in_encoded_valid,
    
    output reg [XGMII_DATA_WIDTH-1:0] out_xgmii_data,
    output reg [XGMII_DATA_BYTES-1:0] out_xgmii_ctl,
    output reg out_xgmii_valid,
    input in_xgmii_ready
);

    localparam SYNC_DATA = 2'b01;
    localparam SYNC_CTRL = 2'b10;
    
    localparam BLOCK_TYPE_C0 = 8'h1E;
    localparam BLOCK_TYPE_S0 = 8'h78;
    localparam BLOCK_TYPE_S4 = 8'h33;
    localparam BLOCK_TYPE_T0 = 8'h87;
    localparam BLOCK_TYPE_T1 = 8'h99;
    localparam BLOCK_TYPE_T2 = 8'hAA;
    localparam BLOCK_TYPE_T3 = 8'hB4;
    localparam BLOCK_TYPE_T4 = 8'hCC;
    localparam BLOCK_TYPE_T5 = 8'hD2;
    localparam BLOCK_TYPE_T6 = 8'hE1;
    localparam BLOCK_TYPE_T7 = 8'hFF;
    
    localparam XGMII_IDLE = 8'h07;
    localparam XGMII_START = 8'hFB;
    localparam XGMII_TERMINATE = 8'hFD;
    localparam XGMII_ERROR = 8'hFE;
    
    reg state;
    localparam FIRST = 1'b0;
    localparam SECOND = 1'b1;
    
    reg [63:0] decoded_data;
    reg [7:0] decoded_ctrl;
    reg block_valid;
    reg decode_error;
            
    always @(posedge clk) begin
        if (!rst) begin
            decoded_data <= 64'h0;
            decoded_ctrl <= 8'h0;
            block_valid <= 1'b0;
            decode_error <= 1'b0;
        end else begin
            block_valid <= 1'b0;
            decode_error <= 1'b0;
            
            if (in_encoded_valid) begin 
                block_valid <= 1'b1;
                case (in_encoded_header)
                    SYNC_DATA: begin
                        decoded_data <= in_encoded_data[63:0];
                        decoded_ctrl <= 8'h00; // All data
                    end
                    
                    SYNC_CTRL: begin
                        case (in_encoded_data[63:56])
                            BLOCK_TYPE_C0: begin
                                decoded_data <= {{7{XGMII_IDLE}}, in_encoded_data[55:48]};
                                decoded_ctrl <= 8'hFF; 
                            end
                            
                            BLOCK_TYPE_S0: begin
                                decoded_data <= {in_encoded_data[55:0], XGMII_START};
                                decoded_ctrl <= 8'h01; 
                            end
                            
                            BLOCK_TYPE_S4: begin
                                decoded_data <= {in_encoded_data[31:0], XGMII_START, in_encoded_data[55:32]};
                                decoded_ctrl <= 8'h10; 
                            end
                            
                            BLOCK_TYPE_T0: begin
                                decoded_data <= {{7{XGMII_IDLE}}, XGMII_TERMINATE};
                                decoded_ctrl <= 8'hFF; 
                            end
                            
                            BLOCK_TYPE_T1: begin
                                decoded_data <= {{6{XGMII_IDLE}}, XGMII_TERMINATE, in_encoded_data[55:48]};
                                decoded_ctrl <= 8'hFE; 
                            end
                            
                            BLOCK_TYPE_T2: begin
                                decoded_data <= {{5{XGMII_IDLE}}, XGMII_TERMINATE, in_encoded_data[55:40]};
                                decoded_ctrl <= 8'hFC; 
                            end
                            
                            BLOCK_TYPE_T3: begin
                                decoded_data <= {{4{XGMII_IDLE}}, XGMII_TERMINATE, in_encoded_data[55:32]};
                                decoded_ctrl <= 8'hF8; 
                            end
                            
                            BLOCK_TYPE_T4: begin
                                decoded_data <= {{3{XGMII_IDLE}}, XGMII_TERMINATE, in_encoded_data[55:24]};
                                decoded_ctrl <= 8'hF0; 
                            end
                            
                            BLOCK_TYPE_T5: begin
                                decoded_data <= {{2{XGMII_IDLE}}, XGMII_TERMINATE, in_encoded_data[55:16]};
                                decoded_ctrl <= 8'hE0;
                            end
                            
                            BLOCK_TYPE_T6: begin
                                decoded_data <= {XGMII_IDLE, XGMII_TERMINATE, in_encoded_data[55:8]};
                                decoded_ctrl <= 8'hC0; 
                            end
                            
                            BLOCK_TYPE_T7: begin
                                decoded_data <= {XGMII_TERMINATE, in_encoded_data[55:0]};
                                decoded_ctrl <= 8'h80; 
                            end
                            
                            default: begin
                                decoded_data <= {8{XGMII_ERROR}};
                                decoded_ctrl <= 8'hFF;
                                decode_error <= 1'b1;
                            end
                        endcase
                    end
                    
                    default: begin
                        decoded_data <= {8{XGMII_ERROR}};
                        decoded_ctrl <= 8'hFF;
                        decode_error <= 1'b1;
                    end
                endcase
            end
        end
    end
    
    always @(posedge clk) begin
        if (!rst) begin
            state <= FIRST;
            out_xgmii_data <= {XGMII_DATA_WIDTH{1'b0}};
            out_xgmii_ctl <= {XGMII_DATA_BYTES{1'b0}};
            out_xgmii_valid <= 1'b0;
        end else begin
            case (state)
                FIRST: begin
                    out_xgmii_valid <= 1'b0;
                    if (block_valid && in_xgmii_ready) begin
                        out_xgmii_data <= decoded_data[31:0];
                        out_xgmii_ctl <= decoded_ctrl[3:0];
                        out_xgmii_valid <= 1'b1;
                        state <= SECOND;
                    end
                end
                
                SECOND: begin
                    out_xgmii_data <= decoded_data[63:32];
                    out_xgmii_ctl <= decoded_ctrl[7:4];
                    out_xgmii_valid <= 1'b1;
                    state <= FIRST;
                end
                
                default: state <= FIRST;
            endcase
        end
    end

endmodule