import base64_m68k_pkg::*;

module cpu_probe #(
    parameter id = 16'h680a,    // TCL scripts will use this ID to ensure they're talking to the correct design
    parameter capture_depth = 9,
    parameter out_width = 8,
    parameter extra_width = 1   // Bit width of any extra signals we might want to bring in
) (
	input m68k_clocks       clocks,

	// m68k socket
	input m68k_address_ctrl m_addr,
	input m68k_data_in      m_data_in,
	input m68k_data_out     m_data_out,
	input m68k_misc_in      m_misc_in,
	input m68k_misc_out     m_misc_out,

    input [extra_width-1:0] extra,

    output update,
    output [out_width-1:0]  q
);

// JTAG capture module to monitor the cpu bus lines
localparam cpusignal_width = 71;
localparam capture_width = cpusignal_width + extra_width;
wire [capture_width-1:0] jtag_d;
wire [capture_width-1:0] jtag_q;
wire jtag_update;
jcapture #(
    .capture_width(capture_width),
    .capture_depth(capture_depth),
    .id(id)
) capture_inst (
	.clk(clocks.sysclk),
	.reset_n(clocks.reset_n_sys), // clocks.reset_n_sys),
	.d(jtag_d),
	.q(jtag_q),
	.update(jtag_update)
);

assign jtag_d[0] = clocks.clk7;
assign jtag_d[2:1] = {clocks.clk7_en_p,clocks.clk7_en_n};
assign jtag_d[3] = m_misc_out.e;
assign jtag_d[4] = m_addr.as;
assign jtag_d[5] = m_addr.uds;
assign jtag_d[6] = m_addr.lds;
assign jtag_d[7] = m_addr.rw;
assign jtag_d[8] = m_misc_in.dtack;
assign jtag_d[9] = m_misc_in.vpa;
assign jtag_d[10] = m_misc_out.vma;
assign jtag_d[26:11] = m_data_out.q;
assign jtag_d[42:27] = m_data_in.d;
assign jtag_d[43] = m_data_out.dq_en;
assign jtag_d[44] = m_data_out.drive;
assign jtag_d[68:45] = {m_addr.a,1'b0};
assign jtag_d[69] = {m_addr.a_en};
assign jtag_d[70] = {m_addr.drive};

assign jtag_d[70+extra_width:71] = extra;

assign update = jtag_update;
assign q = jtag_q[out_width-1:0];
	
endmodule
