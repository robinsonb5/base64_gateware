// Take a high-frequency system clock and the 7MHz clock from the host system
// and generate pos- and neg-edge enables in the system clock domain,
// and also an e clock.

import base64_m68k_pkg::*;

module hostclocks #(parameter phase=2) (
	input clk7,
	input clk2x,
	input fpgaclk,
	output m68k_clocks cpu_clocks
);

// Clocking - derive a fast internal clock from the incoming 14MHz clock.
// (Will be synchronous to the motherboard clock - could use the incoming 25MHz clock
// to create an asynchronous clock if we have any trouble with this.)

wire sysclk;
wire ramclk;
wire pll_locked;
clocks clocks (
	.CLKI(clk2x),
	.CLKOP(sysclk),
	.CLKOS(ramclk),
	.LOCK(pll_locked)
);

assign cpu_clocks.sysclk = sysclk;
assign cpu_clocks.ramclk = ramclk;

// Supervisor clock, derived from the incoming 25MHz clk
wire svclk;
wire svlocked;
supervisorclk svclocks (
	.CLKI(fpgaclk),
	.CLKOP(svclk),
	.CLKOS(),
	.CLKOS2(),
	.LOCK(svlocked)
);
assign cpu_clocks.svclk = svclk;


// Reset signals
// Created by anding the "locked" signals from the two PLLs
// then synchronising the reset into each clock domain.

wire reset_n = svlocked & pll_locked;

reg [1:0] reset_n_sys;
always @(posedge sysclk) begin
	reset_n_sys<={reset_n_sys[0],reset_n};
end
assign cpu_clocks.reset_n_sys = reset_n_sys[1];

reg [1:0] reset_n_sv;
always @(posedge svclk) begin
	reset_n_sv<={reset_n_sv[0],reset_n};
end
assign cpu_clocks.reset_n_sv = reset_n_sv[1];


// Synchronise the incoming clock signal. Shouldn't be necessary if we're using a system
// clock derived from the motherboard clock, but might as well allow for an async clock later on.

reg [2:0] clk7_s;
always @(posedge sysclk)
	clk7_s <= {clk7_s[1:0],clk7};


// Count how many fast clocks elapse between edges of the 7MHz clock
// When clk7 transitions, latch the cycle count, and count downwards.
// Emit an edge pulse when the downward count reaches a value specified by the 
// phase parameter.

reg [3:0] clk7_ctr;
reg [3:0] edge_ctr;
reg clk7_edge;
reg clk7_en_p;
reg clk7_en_n;
always @(posedge sysclk) begin
	clk7_ctr <= clk7_ctr + 1;
	edge_ctr <= edge_ctr - 1;
	if(clk7_s[2] != clk7_s[1]) begin
		clk7_ctr<=0;
		edge_ctr <= clk7_ctr;
		clk7_edge <= clk7_s[2];
	end
	
	clk7_en_p <= 1'b0;
	clk7_en_n <= 1'b0;
	if(edge_ctr == phase)
		{clk7_en_p,clk7_en_n} <= {clk7_edge,~clk7_edge};
end
assign cpu_clocks.clk7_en_p = clk7_en_p;
assign cpu_clocks.clk7_en_n = clk7_en_n;
assign cpu_clocks.clk7 = clk7;

// Generate a E clock
reg [3:0] e_ctr;
reg e;
always @(posedge sysclk) begin
	if(edge_ctr==phase && ~clk7_edge) begin	// Transition on falling edge of clk7
		e_ctr<=e_ctr-1;
		if(e_ctr==4'd0) begin
			e_ctr<=4'd9;
			e<=1'b1;
		end
		if(e_ctr==4'd6) begin
			e<=1'b0;
		end
	end
end
assign cpu_clocks.e_internal=e;

endmodule


