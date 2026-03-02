import vjtag_plumbing::*;

`default_nettype none

module jcapture #(parameter capturewidth=32, parameter capturedepth=9, parameter triggerwidth=32, parameter id = 16'h35ac) (
	input clk,
	input reset_n,
    input stb,
	input [capturewidth-1:0] d,
	output reg [capturewidth-1:0] q,
	output reg update
);

// JTAG Logic capture module with triggers, for Lattice ECP5 / Yosys / Trellis / NextPnR flow.

// Copyright (c) 2025, 2026 by Alastair M. Robinson

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.


// Triggers can be set for absolute values or for rising or falling edges (but not currently both edges)
// To save logic, the triggers can be narrower than the capture bus; signals to be included in trigger
// conditions should be in the lowest-order bits of the port.

// Use JTAG commands to set the following registers:
// Mask: '1' bits select which signals should be included in the trigger condition.
// Invert: The trigger will match '0' bits unless the corresponding bit in this register is set.
// Edge: For bits set in both Edge and Mask, the trigger will match on falling edges, unless the corresponding invert bit is set.

localparam jcapture_irsize = 20;

localparam jcapture_ir_status       = 4'b0000;
localparam jcapture_ir_abort        = 4'b0001;
localparam jcapture_ir_read         = 4'b0010;
localparam jcapture_ir_write        = 4'b0011;
localparam jcapture_ir_setleadin    = 4'b0100;
localparam jcapture_ir_setmask      = 4'b0101;
localparam jcapture_ir_setinvert    = 4'b0110;
localparam jcapture_ir_setedge      = 4'b0111;
localparam jcapture_ir_capture      = 4'b1000;
localparam jcapture_ir_capturewidth = 4'b1001;
localparam jcapture_ir_capturedepth = 4'b1010;
localparam jcapture_ir_triggerwidth = 4'b1011;
localparam jcapture_ir_subsample    = 4'b1100;
localparam jcapture_ir_bypass       = 4'b1111;


// JTAG signals

wire irupdate;
wire [jcapture_irsize-1:0] irfromjtag;
wire [jcapture_irsize-1:0] irtojtag;

wire drupdate;
wire [capturewidth-1:0] drfromjtag;
reg  [capturewidth-1:0] drtojtag;

// FIFO signals
reg [1:0] leadin;
reg [capturewidth-1:0] to_fifo;
reg fifo_wr;
wire fifo_full;
wire fifo_empty;

// Capture triggering logic

// From the current and previous incoming values, a mask, invert and edge signal
// we digest a zero value if the trigger condition is satisfied.
// Mask is a bitmap of bits to be included in the trigger condition
// Invert reverses the sense of the comparison: value triggers match '0' by default
// and '1' if the corresponding bit in invert is set.  Edge triggers match a falling
// edge by default and a rising edge if the invert bit is set.

// if V is a bit from the incoming value, and P is its previous value, then
// V' is (V^I) and P' is (P^I), where I is the corresponding bit from the invert register.
// M comes from the mask register, and E comes from the edge register.
// The active-low trigger value for each bit = ((not P') and M and E) or (V' and M)


wire trigger;

reg [triggerwidth-1:0] prev;
reg [triggerwidth-1:0] trigedge;
reg [triggerwidth-1:0] triginvert;
reg [triggerwidth-1:0] trigmask;
reg [triggerwidth-1:0] triggers;
wire [triggerwidth-1:0] inverted;

// Record the mask, invert and edge signals
// and set the trigger signal when conditions are met.

always @(posedge clk) begin
	if (drupdate) begin
		case (irfromjtag[3:0])
			jcapture_ir_setmask   : trigmask   <= drfromjtag[triggerwidth-1:0];
			jcapture_ir_setinvert : triginvert <= drfromjtag[triggerwidth-1:0];
			jcapture_ir_setedge   : trigedge   <= drfromjtag[triggerwidth-1:0];
			default : ;
		endcase;
	end
	if(!reset_n) begin
		trigmask <= 0;
		triginvert <= 0;
		trigedge <=0;
	end
end

assign inverted = d[triggerwidth-1:0] ^ triginvert;

always @(posedge clk) begin
	prev <= inverted;
	triggers <= ((~prev) & trigmask & trigedge) | (inverted & trigmask);
	if(!reset_n)
		prev <= 0;
end

assign trigger = (|triggers) ? 1'b0 : 1'b1;


// Subsampling logic

// Allow the host to select a number of clocks to skip between samples, and also optionally
// wait for either a trigger or an external strobe signal between successive samples.
// When trigger or strobe are selected, the counter won't reset after underflow until
// the strobe /trigger arrives.

reg [5:0] subsample_ctr;
reg [5:0] subsample_schedule=0;
reg subsample_stb_sel;
reg subsample_trigger_sel;

wire subsample_stb = (trigger | ~subsample_trigger_sel) & (stb | ~subsample_stb_sel) & ~(|subsample_ctr);

always @(posedge clk) begin
	if(|subsample_ctr)
		subsample_ctr <= subsample_ctr - 1;
	if(subsample_stb)
		subsample_ctr <= subsample_schedule;
end

always @(posedge clk) begin
	if (drupdate) begin
		case (irfromjtag[3:0])
			jcapture_ir_subsample : begin
				subsample_schedule <= drfromjtag[5:0];
				subsample_trigger_sel <= drfromjtag[6];
				subsample_stb_sel <= drfromjtag[7];
			end
			default :
				;
		endcase;
	end
	if(!reset_n) begin
		subsample_schedule <= 7'b0;
		subsample_stb_sel <= 1'b0;
	end
end


typedef enum logic [2:0] { STATE_IDLE,STATE_CAPTURE,STATE_FILL,STATE_READ } capstate_t;
capstate_t capstate;
reg busy;
reg capturing;
	
always @(posedge clk) begin
	
	update <= 1'b0;
	if(drupdate) begin

		case (irfromjtag[3:0])
			jcapture_ir_write : begin
				q <= drfromjtag;
				update <= 1'b1;
			end

			jcapture_ir_setleadin :
				leadin <= drfromjtag[1:0];
				
			default
				;
		endcase
	end

	to_fifo <= d;
	fifo_wr <= 1'b0;

	case(capstate)
		STATE_CAPTURE : begin
			if(trigger) begin
				capstate <= STATE_FILL;
				leadin <= 2'b00;
				fifo_wr <= subsample_stb;
			end else begin
				if(leadin)
					fifo_wr <= subsample_stb;
			end
		end
		
		STATE_FILL : begin
			if(fifo_full)
				capstate <= STATE_IDLE;
			else
				fifo_wr <= subsample_stb;
		end
		
		STATE_READ : begin
			if(fifo_empty)
				capstate <= STATE_IDLE;
		end
		
		default :
			capstate <= STATE_IDLE;
	endcase
	
	if(irupdate) begin
		case (irfromjtag[3:0])	
			jcapture_ir_capture : 
				capstate <= STATE_CAPTURE;
			jcapture_ir_abort : begin
				fifo_wr <= 1'b1;  // Capture one sample on abort
				leadin <= 2'b00;
				capstate <= STATE_IDLE;
			end
			default :
				;
		endcase
	end

	if(!reset_n) begin
		leadin <= 2'b00;
		fifo_wr <= 1'b0;
		capstate <= STATE_IDLE;
		q <= 0;
	end
end

assign busy = capstate==STATE_IDLE ? 1'b0 : 1'b1;
assign capturing = capstate==STATE_CAPTURE ? 1'b1 : 1'b0;

assign irtojtag = {id,capturing,fifo_empty,fifo_full,busy};


jtag_to_reg to_reg1;
wire tdo1;
jtag_to_reg to_reg2;
wire tdo2;


vjtag jtag_inst (
	.to_reg1(to_reg1),
	.tdo1(tdo1),
	.to_reg2(to_reg2),
	.tdo2(tdo2)
);

wire frd_en;
wire [capturewidth-1:0] frd;

vjtag_sync_fifo #(.fifowidth(capturewidth),.fifodepth(capturedepth)) fifo (
	.sysclk(clk),
	.reset_n(reset_n),
	
	.rd_en(frd_en),
	.dout(frd),
	.empty(fifo_empty),
	
	.wr_en(fifo_wr),
	.din(d),
	.full(fifo_full),
	
	.leadin(leadin)
);


// Create a pair of registers to be accessed over the JTAG chain
	
vjtag_register #(.bits(jcapture_irsize)) vir (
	// JTAG plumbing and system clock (must be significantly faster than the JTAG clock)
	.sysclk(clk),
	.to_reg(to_reg1),
	.tdo(tdo1),
	// Input, output and update signal.
	.d(irtojtag),
	.q(irfromjtag),
	.upd(irupdate)
);

always @(posedge clk) begin
	case(irfromjtag[3:0])
		jcapture_ir_capturewidth :
			drtojtag <= capturewidth;
		jcapture_ir_capturedepth :
			drtojtag <= capturedepth;
		jcapture_ir_triggerwidth :
			drtojtag <= triggerwidth;
		default:
			drtojtag <= frd;
	endcase
end

vjtag_register #(.bits(capturewidth)) vdr (
	// JTAG plumbing and system clock (must be significantly faster than the JTAG clock)
	.sysclk(clk),
	.to_reg(to_reg2),
	.tdo(tdo2),
	// Input, output and update signal.
	.d(drtojtag),
	.q(drfromjtag),
	.upd(drupdate)
);


// Advance the FIFO on Update rather than Capture because neither the Intel raw JTAG nor the Gowin JTAG primitive
// supply a capture signal.

assign frd_en = drupdate;


endmodule

