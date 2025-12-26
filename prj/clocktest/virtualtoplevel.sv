import sdram_pkg::*;
import base64_m68k_pkg::*;

module virtualtoplevel (
	input m68k_clocks        clocks,
	
	// m68k socket
	output m68k_address_ctrl socket_addr_ctrl,
	input  m68k_data_in      socket_din,
	output m68k_data_out     socket_dout,
	input  m68k_misc_in      socket_miscin,
	output m68k_misc_out     socket_miscout,

	// SDRAM
	input  sdram_in          sdr_in,
	output sdram_out         sdr_out,

	// SD card
	output spi_cs,
	output spi_copi,
	input  spi_cipo,
	output spi_clk,
	
	// LEDs
	output led_red,
	output led_green,
	output led_blue
);

assign sdr_out.cs=1'b1;
assign sdr_out.cke=1'b0;

assign socket_dout.dq_en=1'b0;
assign socket_dout.drive=1'b0;

assign socket_addr_ctrl.a_en=1'b0;
assign socket_addr_ctrl.as = 1'b1;
assign socket_addr_ctrl.rw = 1'b1;
assign socket_addr_ctrl.uds = 1'b1;
assign socket_addr_ctrl.lds = 1'b1;


// JTAG capture module to monitor the clock lines
wire [31:0] jtag_d;
wire [31:0] jtag_q;
wire jtag_update;
jcapture #(.id(16'hc10c)) capture_inst (
	.clk(clocks.svclk),
	.reset_n(1'b1), // clocks.reset_n_sys),
	.d(jtag_d),
	.q(jtag_q),
	.update(jtag_update)
);

assign jtag_d[0] = clocks.clk7;
assign jtag_d[2:1] = {clocks.clk7_en_p,clocks.clk7_en_n};
assign jtag_d[3] = clocks.e;
assign jtag_d[31:4] = 28'b0;

reg ledr;
always @(posedge clocks.svclk) begin
	if(jtag_update)
		ledr <= jtag_q[0];
end
assign led_red = ledr;

reg [25:1] sctr;
always @(posedge clocks.sysclk) begin
	sctr<=sctr+1;
end
assign led_green = sctr[25];
	
endmodule
