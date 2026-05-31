// FIFO queue for debug channel.
// Synchronous, fall-through semantics.

// Also has a lead-in mode, activated by setting "leadin" to "01", "10" or "11".
// While lead in"mode is active, the read pointer will be forced to track the 
// write pointer with an offset of 1/4, 1/2 or 3/4 of the FIFO depth,
// effectively disabling the full / empty logic.

module vjtag_sync_fifo #(parameter fifowidth = 32, parameter fifodepth = 6) (
	input wire sysclk,
	input wire reset_n,
	
	// Read side
	input wire rd_en,
	output reg [fifowidth-1:0] dout,
	output wire empty,
	
	// Write side
	input wire wr_en,
	input wire [fifowidth-1:0] din,
	output wire full,
	
	input wire [1:0] leadin
);

reg [fifowidth-1:0] storage [2**fifodepth];
reg [fifodepth-1:0] readptr;
reg [fifodepth-1:0] writeptr=0;
reg [fifodepth-1:0] writeptr_next=1;

assign empty = (readptr==writeptr) ? 1'b1 : 1'b0;
assign full = (leadin==2'b00 && readptr==writeptr_next) ? 1'b1 : 1'b0;


// Compare and count logic

reg wr_en_d;
reg wr_fifo;
reg wr_adv;
reg [fifowidth-1:0] prev;
reg [fifowidth-1:0] changed;

always @(posedge sysclk) begin
	if(wr_en) begin
		changed <= prev ^ din;
		prev <= din;
		wr_en_d <= wr_en;
	end
	if(!reset_n)
		prev <= 0;
end

reg [7:0] runlength;
reg [fifowidth-1:0] tofifo;
always @(*) begin
	wr_adv <= 1'b0;
	wr_fifo <= 1'b0;
	if(wr_en_d) begin
		tofifo <= prev;
		if(changed == 0) begin
			runlength<=runlength+1;
			tofifo[fifowidth-1] <= 1'b1;	// Run length
			tofifo[7:0] <= runlength;
			wr_fifo <= 1'b1;
			wr_adv <= 1'b1;
		end else begin
			runlength<=0;
			tofifo[fifowidth-1] <= 1'b0;	// Literal data
			wr_fifo <= 1'b1;
		end
	end
end

// Write logic

always @(posedge sysclk) begin
	if(wr_en && !full) begin
		storage[writeptr]<=din;
		writeptr<=writeptr_next;
		if(wr_adv)
			writeptr_next <= writeptr_next+1;
	end
	if(!reset_n) begin
		writeptr <= 0;
		writeptr_next <= 1;
	end
end


// Read logic

always @(posedge sysclk) begin

	dout <= storage[readptr];
	if(rd_en && !empty) begin
		readptr<=readptr+1;
	end
	
	// In leadin mode, make the read pointer track the write pointer with an offset determined by leadin.
	if(wr_en && !full) begin
		if(|leadin)
			readptr <= {writeptr[fifodepth-1 : fifodepth-2] + leadin,writeptr[fifodepth-3:0]};
	end
	
	if(!reset_n) begin
		readptr<=0;
	end
	
end

// Verification

`ifdef SOC_VERIFY
always @(posedge sysclk) begin
	a_fullempty : assert(full==1'b0 || empty==1'b0);
end
`endif

endmodule

