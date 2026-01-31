import board_pkg::*;
import base64_m68k_pkg::*;
import sdram_pkg::*;

`default_nettype none

module base64_icesugarpro_top (
	input clk_i,
	
	// 7MHz and 14MHz clocks
	input clk,
	input clk2x,
		
	// Address bus
	output a_hi_oe, // Covers a[23:18], rw, lds, uds & as
	output a_md_oe, // Covers a[27:8]
	output a_lo_oe, // Covers a[7:1]
	inout [23:1] a,
	output rw,
	output lds,
	output uds,
	output as,

	// Data bus
	output d_lo_oe,
	output d_hi_oe,
	inout [15:0] d,

	// Other inputs
	input bgack,
	input br,
	input dtack,
	input vpa,
	input halt,
	input berr,
	input [2:0] ipl,
	
	// Other outputs
	output bg,
	output vma,
	output e,
	inout  reset,
	output [2:0] fc,

	// Autoconfig signals (shouldn't need these since we can autoconfig
	// in-FPGA resources before running autoconfig cycles on the motherboard.)

	input  cfgin,
	output cfgout,
	
	// LEDs
	
	output led_red,
	output led_green,
	output led_blue,

	// SDRAM signals
	
	output sdram_clk,
	output sdram_cs_n,
	output [SDRAM_ROW_BITS-1:0]  sdram_a,
	inout  [SDRAM_DATA_WIDTH-1:0] sdram_dq,
	output sdram_we_n,
	output sdram_ras_n,
	output sdram_cas_n,
	output sdram_cke,
	output [1:0] sdram_ba,
	output [SDRAM_DATA_WIDTH/8-1:0] sdram_dqm,
	
	// SD Card
`ifdef SDCARD_FULL
	output sd_clk,	// SPI Clk
	output sd_cmd,	// SPI COPI
	inout  sd_d0,	// SPI CIPO
	inout  sd_d1,
	inout  sd_d2,
	inout  sd_d3,	// SPI CS
`else	
	output spisdcard_clk,
	output spisdcard_mosi,
	output spisdcard_cs_n,
	input spisdcard_miso,
`endif

	// UART
	input rxd,
	output txd
);


// SD Card
wire spi_clk;
wire spi_copi;
wire spi_cipo;
wire spi_cs;
`ifdef SDCARD_FULL
assign sd_clk = spi_clk;
assign sd_cmd = spi_copi;
assign sd_d3 = spi_cs;
assign spi_cipo = sd_d0;
assign sd_d0 = 1'bz;
assign sd_d1 = 1'bz;
assign sd_d2 = 1'bz;
`else
assign spisdcard_clk = spi_clk;
assign spisdcard_mosi = spi_copi;
assign spisdcard_cs_n = spi_cs;
assign spi_cipo = spisdcard_miso;
`endif

// SDRAM
wire sdram_drive_dq;
wire [15:0] sdram_data;
assign sdram_dq = sdram_drive_dq ? sdram_data : 16'bzzzzzzzz_zzzzzzzz;


// Clocking
m68k_clocks clocks;
hostclocks hostclocks (
	.clk7(clk),
	.clk2x(clk2x),
	.fpgaclk(clk_i),
	.cpu_clocks(clocks)
);
assign sdram_clk=clocks.ramclk;


// ToDo - run a frequency counter on the incoming 25MHz clock to check that the generated
// sysclock is within acceptable bounds.


// Address / control bus

m68k_address_ctrl address;
assign a = address.drive ? address.a : 23'bzzzzzzz_zzzzzzzz_zzzzzzzz;
assign as = address.as;
assign rw = address.rw;
assign uds = address.uds;
assign lds = address.lds;
assign a_hi_oe = ~address.a_en;	// Active low
assign a_md_oe = ~address.a_en;
assign a_lo_oe = ~address.a_en;


// Data bus

m68k_data_out data_out;
m68k_data_in data_in;
assign d = data_out.drive ? data_out.q : 16'bzzzzzzzz_zzzzzzzz ;
assign data_in.d = d;
assign d_hi_oe = ~data_out.dq_en;	// Active low
assign d_lo_oe = ~data_out.dq_en;


// Misc inputs 

m68k_misc_in misc_in;
assign misc_in.clk = clk;
assign misc_in.dtack = dtack;
assign misc_in.ipl = ipl;
assign misc_in.halt = halt;
assign misc_in.vpa = vpa;
assign misc_in.br = br;
assign misc_in.bgack = bgack;
assign misc_in.berr = berr;
assign misc_in.reset = reset;


// Misc outputs

m68k_misc_out misc_out;
assign fc = misc_out.fc;
assign vma = misc_out.vma;
assign bg = misc_out.bg;
assign e = misc_out.e;


// Reset is bidirectional - tristate if not driven low
assign reset = misc_out.reset ? 1'bz : 1'b0;


// SDRAM
sdram_in sdr_in;
assign sdr_in.d = sdram_dq;

sdram_out sdr_out;
assign sdram_dq = sdr_out.drive ? sdr_out.q : 16'bzzzz_zzzz_zzzz_zzzz;
assign sdram_cas_n = sdr_out.cas;
assign sdram_ras_n = sdr_out.ras;
assign sdram_we_n = sdr_out.we;
assign sdram_cs_n = sdr_out.cs;
assign sdram_dqm = sdr_out.dqm;
assign sdram_a = sdr_out.a;
assign sdram_ba = sdr_out.ba;
assign sdram_cke = sdr_out.cke;


// Instantiate the project

reg jtag_reset_n=1'b1;

virtualtoplevel project (
	.clocks(clocks),
	// M68K bus
	.socket_addr_ctrl(address), 
	.socket_din(data_in),
	.socket_dout(data_out),
	.socket_miscin(misc_in),
	.socket_miscout(misc_out),
	// SDRAM
	.sdr_in(sdr_in),
	.sdr_out(sdr_out),
	// SD card
	.spi_cs(spi_cs),
	.spi_copi(spi_copi),
	.spi_cipo(spi_cipo),
	.spi_clk(spi_clk),
	// LEDs
	.led_red(led_red),
	.led_green(led_green),
	.led_blue(led_blue),
	// UART
	.rxd(rxd),
	.txd(txd),
	.reset_btn(jtag_reset_n)
);

`ifdef COMMENTOUT
// JTAG capture module to monitor the cpu bus lines
localparam capturewidth = 4;
localparam capturedepth = 12;
wire [capturewidth-1:0] jtag_d;
wire [capturewidth-1:0] jtag_q;
wire jtag_update;
assign jtag_d[0] = spi_cs;
assign jtag_d[1] = spi_cipo;
assign jtag_d[2] = spi_copi;
assign jtag_d[3] = spi_clk;

wire jtag_stb;
reg [6:0] jtag_stb_limit=0;
reg [6:0] jtag_stb_ctr;
assign jtag_stb = ~(|jtag_stb_ctr);

always @(posedge clocks.sysclk) begin
	jtag_stb_ctr <= jtag_stb_ctr-1;
	if(jtag_stb)
		jtag_stb_ctr <= jtag_stb_limit;
end

jcapture #(
    .capturewidth(capturewidth),
    .capturedepth(capturedepth),
    .triggerwidth(capturewidth),
    .id(16'h68ff)
) capture_inst (
	.clk(clocks.sysclk),
    .stb(jtag_stb),
	.reset_n(clocks.reset_n_sys), // clocks.reset_n_sys),
	.d(jtag_d),
	.q(jtag_q),
	.update(jtag_update)
);


always @(posedge clocks.sysclk) begin
	if(jtag_update) begin
		jtag_reset_n <= ~jtag_q[0];
		jtag_stb_limit <= jtag_q[7:1];
	end
end
`endif

endmodule
