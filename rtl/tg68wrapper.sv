import base64_m68k_pkg::*;
import cpu_pkg::*;

`default_nettype none;

module tg68wrapper (
	input m68k_clocks clocks,
	input cpu_response cpu_resp,
	output cpu_request cpu_req,
	input m68k_misc_in socket_miscin // for IPL, etc.
);

typedef enum logic[2:0] {
	RESET,
	INIT,
	REQ,
	WAIT,
	WAIT_INTERNAL
} state_t;

state_t state;

reg clkena;
reg [2:0] slower;

always @(posedge clocks.sysclk) begin
	slower<={1'b1,slower[2:1]};
	if(clkena)
		slower<=0;
end

wire [31:0] tg68_addr;
reg  [15:0] tg68_din;
wire [15:0] tg68_dout;
wire tg68_lds,tg68_uds,tg68_wr;
wire [1:0] tg68_state;
wire [2:0] tg68_fc;
wire tg68_reset;
always @(posedge clocks.sysclk) begin
	clkena <= 1'b0;
	case(state)
		RESET: begin
				cpu_req.req <= 1'b0;
				clkena <= 1'b0;
				state <= INIT;
			end
		INIT: begin
			state <= REQ;
			end
		REQ: begin
				if(slower[0]) begin
					cpu_req.addr <= tg68_addr;
					cpu_req.d <= tg68_dout;
					cpu_req.dm <= {~tg68_uds,~tg68_lds};				
					case(tg68_state)
						2'b00: begin // Instruction fetch
								cpu_req.req<=~cpu_resp.ack;
								cpu_req.wr <= 1'b0;
								cpu_req.ifetch <= 1'b1;
							end
						2'b01: begin // Internal cycle
							end
						2'b10: begin // Data read
								cpu_req.req<=~cpu_resp.ack;
								cpu_req.wr <= 1'b0;
								cpu_req.ifetch <= 1'b0;
							end
						2'b11: begin // Data write
								cpu_req.req<=~cpu_resp.ack;
								cpu_req.wr <= 1'b1;
								cpu_req.ifetch <= 1'b0;
							end			
					endcase
					state <= WAIT;
				end
			end
		WAIT: begin
				if(slower[0] && (cpu_resp.ack==cpu_req.req)) begin
					tg68_din <= cpu_resp.q;
					clkena <=1'b1;
					state <= REQ;
				end
			end
		default :
			state <= INIT;
	endcase

	if(!clocks.reset_n_sys)
		state <= RESET;
end

/* verilator lint_off UNSIGNED */
/* verilator lint_off UNOPTFLAT */
TG68KdotC_Kernel tg68 (
	.clk(clocks.sysclk),
	.nReset(clocks.reset_n_sys),
	.clkena_in(clkena),
	.data_in(tg68_din),
	.IPL(socket_miscin.ipl),
	.IPL_autovector(1'b0),
	.berr(1'b0),
	.CPU(2'b11),
	.addr_out(tg68_addr),
	.data_write(tg68_dout),
	.nWr(tg68_wr),
	.nUDS(tg68_uds),
	.nLDS(tg68_lds),
	.busstate(tg68_state),
	.longword(),
	.nResetOut(tg68_reset),
	.FC(tg68_fc),
	.clr_berr(),
	.skipFetch(),
	.regin_out(),
	.CACR_out(),
	.VBR_out()
);

/* verilator lint_on UNSIGNED */
/* verilator lint_on UNOPTFLAT */


endmodule

