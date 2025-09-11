module sync_fifo #(
	parameter DATA_WIDTH = 52,
	parameter ADDR_WIDTH = 4,
	parameter FIFO_DEPTH = 1 << ADDR_WIDTH
	) (
	input clk,
	input rst,
	input wr_en,
	input [DATA_WIDTH-1:0] wr_data,
	input rd_en,
	output reg [DATA_WIDTH-1:0] rd_data,
	output empty,
	output full,
	output reg almost_full,
	output reg almost_empty
	);
	
	reg [ADDR_WIDTH:0] count;
	reg [DATA_WIDTH-1:0] mem [0:FIFO_DEPTH-1];
	reg [ADDR_WIDTH-1:0] wr_ptr_reg;
	reg [ADDR_WIDTH-1:0] rd_ptr_reg;
	
	assign empty = count == 0;
	assign full = count == FIFO_DEPTH;
	
	always @(posedge clk or negedge rst) begin
		if(!rst) begin
			wr_ptr_reg <= 0;
			rd_ptr_reg <= 0;
			count <= 0;
			rd_data <= 0;
			almost_full <= 1'b0;
		end else begin
		    if(count >= FIFO_DEPTH/2) begin
		      almost_full <= 1'b1;
		    end else if (count < FIFO_DEPTH/2) begin
		      almost_empty <= 1'b1;
		    end
			if(wr_en && !full) begin
				mem[wr_ptr_reg] <= wr_data;
				wr_ptr_reg <= (wr_ptr_reg + 1) & (FIFO_DEPTH-1);
			end
			
			if(rd_en && !empty) begin 
				rd_data <= mem[rd_ptr_reg];
				rd_ptr_reg <= (rd_ptr_reg + 1) & (FIFO_DEPTH - 1);
			end
			
			case ({wr_en && !full, rd_en && !empty})
				2'b10: count <= count + 1;
				2'b01: count <= count - 1; 
				default: count <= count;   
			endcase
		end
	end 
endmodule