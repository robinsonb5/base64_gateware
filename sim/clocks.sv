// In an ideal world we'd generate these clocks with 
// initial / forever blocks and use verilator's --timing option,
// however that (a) required up-to-date gcc for coroutines support, and
// (b) doesn't seem to actually work yet - so we just inject clocks in the
// C++ simulation wrapper.

module clocks (
	input CLKI,
	output reg CLKOP,
	output reg CLKOS,
	output reg LOCK
);

assign LOCK=1;

endmodule


module supervisorclk (
	input CLKI,
	output reg CLKOP,
	output reg CLKOS,
	output reg CLKOS2,
	output reg CLKOS3,
	output reg LOCK
);

assign LOCK=1;

endmodule

