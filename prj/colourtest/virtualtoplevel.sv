import sdram_pkg::*;
import base64_m68k_pkg::*;
import cpu_pkg::*;

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

cpu_request cpu_req;
cpu_response cpu_resp;


reg [15:0] rgb=0;
always @(posedge clocks.sysclk) begin
	cpu_req.addr <= 32'hdff180;
	cpu_req.dm<=2'b11;
	if(!clocks.reset_n_sys) begin
		cpu_req.req<=1'b0;
		rgb<=0;
	end else begin
		if(cpu_resp.ack==cpu_req.req) begin
			cpu_req.d<=rgb;
			cpu_req.wr<=1'b1;
			cpu_req.req<=~cpu_resp.ack;
			rgb <= rgb+1;
		end
	end
end


m68k_bridge bridge (
	.clks(clocks),
	.m_addr(socket_addr_ctrl),
	.m_data_out(socket_dout),
	.m_data_in(socket_din),
	.m_misc_in(socket_miscin),
	.m_misc_out(socket_miscout),
	.cpu_req(cpu_req),
	.cpu_resp(cpu_resp)
);


// JTAG capture module to monitor the clock lines
wire [31:0] jtag_d;
wire [31:0] jtag_q;
wire jtag_update;
jcapture #(.id(16'hc01a)) capture_inst (
	.clk(clocks.svclk),
	.reset_n(1'b1), // clocks.reset_n_sys),
	.d(jtag_d),
	.q(jtag_q),
	.update(jtag_update)
);

assign jtag_d[0] = clocks.clk7;
assign jtag_d[2:1] = {clocks.clk7_en_p,clocks.clk7_en_n};
assign jtag_d[3] = socket_miscout.e;
assign jtag_d[4] = socket_addr_ctrl.as;
assign jtag_d[5] = socket_addr_ctrl.uds;
assign jtag_d[6] = socket_addr_ctrl.lds;
assign jtag_d[7] = socket_addr_ctrl.rw;
assign jtag_d[8] = socket_miscin.dtack;
assign jtag_d[9] = socket_miscin.vpa;
assign jtag_d[10] = socket_miscout.vma;
assign jtag_d[26:11] = socket_dout.q;

assign jtag_d[31:27] = 5'b0;

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
