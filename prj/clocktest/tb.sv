import base64_m68k_pkg::*;
// import sdram_pkg::*;
// import cpu_pkg::*;

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
assign e = clocks.e_internal;
assign clocks.sysclk=sysclk;
assign clocks.svclk=svclk;
/* verilator lint_on MULTIDRIVEN */


reg [25:0] sctr;
always @(posedge clocks.sysclk) begin
	sctr<=sctr+1;
end

wire [31:0] jtag_d;

assign jtag_d[0] = clocks.clk7;
assign jtag_d[2:1] = {clocks.clk7_en_p,clocks.clk7_en_n};
assign jtag_d[3] = clocks.e_internal;
assign jtag_d[31:12] = 20'b0;

assign jtag_d[11:4] = sctr[7:0] | sctr[13:6];

wire full;

reg fifo_rd=1'b0;
reg fifo_wr=1'b1;

vjtag_sync_fifo #(.fifodepth(8)) fifo (
	.sysclk(clocks.sysclk),
	.reset_n(1'b1),
	.rd_en(fifo_rd),
	.dout(),
	.empty(),
	.wr_en(fifo_wr),
	.din(jtag_d),
	.full(full),
	.leadin(2'b00)
);

always @(posedge clocks.sysclk) begin
	if(full) begin
		fifo_rd<=1'b1;
		fifo_wr<=1'b0;
	end
end

endmodule

