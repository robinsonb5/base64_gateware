import sdram_pkg::*;
import base64_m68k_pkg::*;

module virtualtoplevel (
	input sysclk,	// System clock, derived from doubled CPU clock
	input svclk,	// Supervisor clock
	input reset_n,
	
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

assign socket_dout.en=1'b0;
assign socket_dout.drive=1'b0;

reg [23:1] actr;
always @(posedge svclk) begin
	actr<=actr+1;
	socket_addr_ctrl.a<=actr;
end

assign socket_addr_ctrl.en=1'b1;
assign socket_addr_ctrl.as = actr[16];
assign socket_addr_ctrl.rw = actr[17];
assign socket_addr_ctrl.uds = actr[18];
assign socket_addr_ctrl.lds = actr[19];


assign led_red = actr[23];

reg [23:1] sctr;
always @(posedge sysclk) begin
	sctr<=sctr+1;
end
assign led_green = sctr[23];
	
endmodule
