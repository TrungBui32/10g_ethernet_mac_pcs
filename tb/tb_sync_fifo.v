module tb_sync_fifo;

    parameter DATA_WIDTH = 36;
    parameter ADDR_WIDTH = 2;
    parameter FIFO_DEPTH = 1 << ADDR_WIDTH;

    reg clk;
    reg rst;

    reg wr_en;
    reg [DATA_WIDTH-1:0] wr_data;
    reg rd_en;

    wire [DATA_WIDTH-1:0] rd_data;
    wire empty;
    wire full;

    sync_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .FIFO_DEPTH(FIFO_DEPTH)
    ) dut (
        .clk(clk),
        .rst(rst),
        .wr_en(wr_en),
        .wr_data(wr_data),
        .rd_en(rd_en),
        .rd_data(rd_data),
        .empty(empty),
        .full(full)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
		@(posedge clk);
        rst = 0; 
        wr_en = 0;
		rd_en = 0;
		
		@(posedge clk);
		rst = 1;
		wr_en = 0;
		wr_data = 32'h0001;
		
        @(posedge clk);
        wr_en = 1;
        wr_data = 32'h0001;
        
        
		@(posedge clk);
		wr_en = 0;
        wr_data = 32'd0002;
        
		@(posedge clk);
        wr_en = 1;
        wr_data = 32'd0002;
                
        
		@(posedge clk);
		wr_en = 0;
        wr_data = 32'd0003;
        
		@(posedge clk);
        wr_en = 1;
        wr_data = 32'd0003;
        

        @(posedge clk);
		wr_en = 0;
        wr_data = 32'd0004;
        
		@(posedge clk);
        wr_en = 1;
        wr_data = 32'd0004;
        
        
		@(posedge clk);
		wr_en = 0;
        rd_en = 1;
        
        
        @(posedge clk);
        rd_en = 0;
        wr_en = 0;
        wr_data = 32'd0005;
        
        @(posedge clk);
        wr_en = 1;
        wr_data = 32'd0005; 
        
        
		@(posedge clk);
        wr_en = 0;
        rd_en = 1;
        
        
        @(posedge clk);
        rd_en = 0;
        wr_en = 0;
        wr_data = 32'd0006;
        
        @(posedge clk);
        wr_en = 1;
        wr_data = 32'd0006;       
        
        
        @(posedge clk);
        $finish;
	end
endmodule