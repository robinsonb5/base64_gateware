import base64_m68k_pkg::*;
import sdram_pkg::*;
import cpu_pkg::*;

//// module ////
module tb(
  input  wire           clk7,
  input  wire           clk2x,
  input  wire           sysclk,
  input  wire           svclk,
  output wire           e,
  output wire           as,
  output wire           uds,
  output wire           lds,
  output wire           rw,
  output wire [23:0]    a,
  output wire [15:0]    d,
  input  wire           rxd,
  output wire           txd
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

m68k_address_ctrl addr;
m68k_data_in din;
m68k_data_out dout;
m68k_misc_in min;
m68k_misc_out mout;
sdram_in sdrin;
sdram_out sdrout;

wire spi_cs,spi_copi,spi_cipo,spi_clk;
wire led_red,led_green,led_blue;

virtualtoplevel vt (
	.clocks(clocks),
	.socket_addr_ctrl(addr),
	.socket_din(din),
	.socket_dout(dout),
	.socket_miscin(min),
	.socket_miscout(mout),
	.sdr_in(sdrin),
	.sdr_out(sdrout),
	.spi_cs(spi_cs),
	.spi_copi(spi_copi),
	.spi_cipo(spi_cipo),
	.spi_clk(spi_clk),
	.led_red(led_red),
	.led_green(led_green),
	.led_blue(led_blue),
	.txd(txd),
	.rxd(rxd)
);

assign min.dtack = 1'b0; // DTACK grounded!
assign min.vpa = 1'b1;
assign e = mout.e;
assign clocks.sysclk=sysclk;
assign clocks.svclk=svclk;

assign a = {addr.a,1'b0};
assign as = addr.as;
assign uds = addr.uds;
assign lds = addr.lds;
assign rw = addr.rw;
assign d =dout.q;

/* verilator lint_on MULTIDRIVEN */

endmodule

