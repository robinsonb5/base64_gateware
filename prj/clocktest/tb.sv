
//// module ////
module tb(
  input  wire           clk7,
  input  wire           clk2x,
  input  wire           sysclk,
  input  wire           svclk,
  output wire           e
);
/* verilator lint_off MULTIDRIVEN */

// Clocking
m68k_clocks clocks;
hostclocks hostclocks (
	.clk7(clk7),
	.clk2x(clk2x),
	.fpgaclk(clk2x),
	.cpu_clocks(clocks)
);
assign e = clocks.e;
assign clocks.sysclk=sysclk;
assign clocks.svclk=svclk;
/* verilator lint_on MULTIDRIVEN */

endmodule

