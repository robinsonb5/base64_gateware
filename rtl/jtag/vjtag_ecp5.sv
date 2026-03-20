// Bundle the JTAG signals into a struct for neatness

`default_nettype none
package vjtag_plumbing;

typedef struct {
	bit tck;
	bit tdi;
	bit sel;
	bit shift;
	bit update;
} jtag_to_reg;

endpackage


// Implement a register of selectable width, accessible over JTAG
// but with operations happening in the system clock domain.
// (Hopefully will solve issues with JTAG becoming unreliable in busy designs.)

import vjtag_plumbing::*;

module vjtag_register #(parameter bits=32) (
	input sysclk,
	input jtag_to_reg to_reg,
	output reg tdo,
	input [bits-1:0] d,
	output reg [bits-1:0] q,
	output reg upd
);

reg [2:0] tck_s; // JTAG clock synced to sysclk domain

always @(posedge sysclk) begin
	tck_s <= {tck_s[1:0],to_reg.tck};
end

wire tck_p,tck_n; // Rising and falling edges of JTAG clock, in sysclk domain
assign tck_p=tck_s[2:1]==2'b01 ? 1'b1 : 1'b0;
assign tck_n=tck_s[2:1]==2'b10 ? 1'b1 : 1'b0;


// As we leave the shift state we latch the previous value of tdi.
// Without this, we lose the last bit shifted when doing a multi-part
// shift interspersed with the DR_PAUSE state.
reg shift_d;
reg tdi_latched;
always @(posedge sysclk) begin
	if(tck_p) begin
		shift_d <= to_reg.shift;
		if(shift_d)
			tdi_latched <= to_reg.tdi;
	end
end

wire tdi_mux = shift_d ? to_reg.tdi : tdi_latched;

reg [bits-1:0] shiftreg;
wire [bits-1:0] shiftnext = {tdi_mux,shiftreg[bits-1:1]};
reg selected;

always @(posedge sysclk) begin
	upd <= 1'b0;

	if(tck_p) begin

		if(to_reg.sel && !to_reg.shift) // Work around the lack of a capture signal
			shiftreg <= d;
	
		if(to_reg.shift)
			selected <= to_reg.sel;

		if(to_reg.shift && to_reg.sel) begin
			tdo <= shiftreg[0];
			shiftreg <= shiftnext;
		end

		if(to_reg.update && selected) begin
			q <= shiftnext;
			upd <= 1'b1;
		end
	end
end

endmodule 


// Instantate the JTAG primitive, and wire it up to a pair of jtag_to_reg bundles,
// one for each of the two USER JTAG scan codes offered by the ECP5.

import vjtag_plumbing::*;

module vjtag (
	output jtag_to_reg to_reg1,
	input tdo1,
	output jtag_to_reg to_reg2,
	input tdo2,
	output reset_n
);

wire jtck,jtdi,jshift,jupdate,jrstn,jce1,jce2;

jtaggwrapper jtag_inst (
	.JTCK(jtck),
	.JTDI(jtdi),
	.JSHIFT(jshift),
	.JUPDATE(jupdate),
	.JRSTN(jrstn),
	.JCE1(jce1),
	.JCE2(jce2),
	.JRTI1(),
	.JRTI2(),
	.JTDO1(tdo1),
	.JTDO2(tdo2)
);

assign reset_n = jrstn;

assign to_reg1.tck = jtck;
assign to_reg1.tdi = jtdi;
assign to_reg1.shift=jshift;
assign to_reg1.update=jupdate;
assign to_reg1.sel=jce1;

assign to_reg2.tck = jtck;
assign to_reg2.tdi = jtdi;
assign to_reg2.shift=jshift;
assign to_reg2.update=jupdate;
assign to_reg2.sel=jce2;

endmodule

