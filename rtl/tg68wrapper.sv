import base64_m68k_pkg::*;
import cpu_pkg::*;

`default_nettype none

module tg68wrapper # (
	parameter sysclk_freq
) (
	input m68k_clocks clocks,
	input cpu_response cpu_resp,
	output cpu_request cpu_req,
	input m68k_misc_in socket_miscin, // for IPL, etc.
	input rxd,
	output txd,
	input spi_cipo,
	output spi_copi,
	output reg spi_cs,
	output spi_clk,
	input reset_btn
);

// Reset signal controllable over JTAG - set initial state here.
reg jtag_reset_n = 1'b1;


typedef enum logic[3:0] {
	RESET,
	INIT,
	REQ,
	DECODE,
	WAIT,
	WAIT_INTERNAL,
	PERIPHERAL,
	FASTRAM,
	ROM,
	SPI
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
wire tg68_reset_out;
reg  tg68_reset_in;

// Address decoding

// We need the decode the following regions:
// First n kb for boot ROM
// UART and SPI register block at 0x01000000
// 32-bit Fast RAM, most likely at 0x40000000
// 24-bit Fast RAM at 0x200000
// Kickstart ROM at 0xf80000 - either forward to motherboard or handle ourselves
// Autoconfig range at 0xe80000
// CIA at 0xbfe001 - for control of OVL bit
// (Maybe Akiko at 0xb80000 for C2P converter?)


// These two are critical timewise, so we generate them combinationally:
wire sel_fast24 = tg68_addr[31:24] == 8'h0 && (tg68_addr[23:20] == 4'h2) ? 1'b1 : 1'b0;
wire sel_fast32 = tg68_addr[31:27] == 5'h0 && tg68_addr[26]==1'b1 ? 1'b1 : 1'b0;

// The rest can be handled on a more relaxed schedule, so we use a latched copy
// of the address
reg [31:0] tg68_addr_d;
always @(posedge clocks.sysclk)
	tg68_addr_d <= tg68_addr;

reg softkick_ena;
reg softkick_overlay;

wire sel_autoconfig = tg68_addr_d[31:16] == 16'h00b8 ? 1'b1 : 1'b0;
wire sel_bootrom = tg68_addr_d[31:16] == 16'h0000 && bootrom_ena ? 1'b1 : 1'b0;
wire sel_kickoverlay = tg68_addr_d[31:16] == 16'h0000 && softkick_ena && softkick_overlay ? 1'b1 : 1'b0;
wire sel_kickstart = tg68_addr_d[31:20] == 12'h00f && tg68_addr_d[19]==1'b1 && softkick_ena ? 1'b1 : 1'b0;
wire sel_cia = tg68_addr_d[31:16] == 16'h00bf ? 1'b1 : 1'b0;
wire sel_peripherals = tg68_addr_d[31:24] == 8'h01 ? 1'b1 : 1'b0;

// Boot ROM

reg bootrom_ena;
reg  [15:0] bootrom_d;
wire [15:0] bootrom_q;
reg bootrom_we;
reg  [1:0] bootrom_bs;
wire [15:1] bootrom_a;

Firmware_ROM #(
	.addr_width(15)
	) rom_inst (
	.clk(clocks.sysclk),
	.addr(bootrom_a),
	.q(bootrom_q),
	.d(bootrom_d),
	.we(bootrom_we),
	.bs(bootrom_bs)
);

assign bootrom_a = tg68_addr_d[15:1];


// Peripherals:
// UART

reg  [7:0] uart_d;
reg  uart_stb;
wire [7:0] uart_q;
wire uart_rxint;
wire uart_txready;
reg  uart_rxpending;

uart uart_inst (
	.clk(clocks.sysclk),
	.reset_n(clocks.reset_n_sys),
	.clkdiv(16'((sysclk_freq * 10000) / 1152)),
	.d(uart_d),
	.d_stb(uart_stb),
	.q(uart_q),
	.rxint(uart_rxint),
	.txready(uart_txready),
	.txint(),
	.rxd(rxd),
	.txd(txd)
);

localparam STATE_FETCH = 2'b00;
localparam STATE_INTERNAL = 2'b01;
localparam STATE_READ = 2'b10;
localparam STATE_WRITE = 2'b11;

reg [1:0] tg68_reset_s;
reg [10:0] reset_debounce_ctr=0;
wire reset_debounced = reset_debounce_ctr[10];

//Temporarily disable reset

always @(posedge clocks.sysclk) begin
	if(!reset_debounced)
		reset_debounce_ctr<=reset_debounce_ctr+1;

	tg68_reset_s <= {tg68_reset_s[0],socket_miscin.reset};
//	if(!tg68_reset_s[1])
//		reset_debounce_ctr<=0;
end


// SD card

localparam spi_speed_slow = (sysclk_freq * 10 ) / 4;
localparam spi_speed_fast = sysclk_freq  / 25;
reg spi_speed_sel;
wire [7:0] spi_speed;
wire spi_busy;
reg [7:0] spi_d;
reg spi_d_stb;
wire [7:0] spi_q;

assign spi_speed = spi_speed_sel ? spi_speed_fast : spi_speed_slow;

spi spi_inst (
	.clk(clocks.sysclk),
	.reset_n(clocks.reset_n_sys),
	.d(spi_d),
	.d_stb(spi_d_stb),
	.q(spi_q),
	.busy(spi_busy),
	.speed(spi_speed),
	.copi(spi_copi),
	.cipo(spi_cipo),
	.sck(spi_clk)
);

always @(posedge clocks.sysclk) begin
	clkena <= 1'b0;

    tg68_reset_in <= clocks.reset_n_sys & reset_debounced & jtag_reset_n & reset_btn;

	bootrom_we <= 1'b0;
	uart_stb <= 1'b0;

	spi_d_stb <= 1'b0;

	case(state)
		RESET: begin
			softkick_ena <= 1'b0;
			softkick_overlay <= 1'b0;
			uart_rxpending <= 1'b0;
			cpu_req.req <= 1'b0;
			clkena <= 1'b0;
            tg68_reset_in <= 1'b0;
            bootrom_ena <= 1'b1;
			state <= INIT;
		end

		INIT: begin
			state <= DECODE;
		end

		DECODE: begin
				if(slower[0] && !clkena) begin
					if(sel_fast24 || sel_fast32) begin // We need to handle Fast RAM requests as promptly as possible
						state <= REQ;  // FIXME - replace with fast path to SDRAM
					end else begin
						state <= REQ;	// Handle other requests a cycle later
					end
				end
			end

		ROM: begin
			tg68_din <= bootrom_q;
			clkena <= 1'b1;
			state <= DECODE;
		end

		REQ: begin
			if(sel_peripherals) begin
				case(tg68_addr_d[11:8])
				
					4'd0: begin // UART
						uart_d <= tg68_dout[7:0];
						tg68_din <= {6'b0,uart_rxpending,uart_txready,uart_q};
						if(tg68_state == STATE_WRITE) begin
							if(uart_txready) begin
								uart_stb <= 1'b1;
								clkena <= 1'b1;
								state <= DECODE;
							end
						end else begin
							uart_rxpending<=1'b0;
							clkena <= 1'b1;
							state <= DECODE;
						end

					end

					4'd1: begin // SPI SD card
						if(tg68_addr_d[2] && ~spi_busy) begin // Data register
							spi_d <= tg68_dout[7:0];
							if(tg68_state == STATE_WRITE)
								spi_d_stb <= 1'b1;
							state <= SPI;
						end else if(~spi_busy) begin // CS register
							if(tg68_state == STATE_WRITE) begin
								spi_speed_sel <= tg68_dout[8];
								spi_cs <= ~tg68_dout[0];
							end
							tg68_din <= {spi_busy,15'd0};
							clkena <= 1'b1;
							state <= DECODE;
						end
					end

					default : begin
						clkena <= 1'b1;
						state <= DECODE;
					end
				endcase
			end else if(sel_bootrom) begin
				bootrom_d <= tg68_dout;
				bootrom_bs <= {~tg68_uds,~tg68_lds};
				bootrom_we <= ~tg68_wr;
				state <= ROM;
			end else if(sel_autoconfig) begin

			end else if(sel_kickstart) begin
	
			end else begin
				if(sel_cia && tg68_state == STATE_WRITE) // First write to CIA registers cancels overlay
					softkick_overlay <= 1'b0;

				cpu_req.addr <= tg68_addr;
				cpu_req.d <= tg68_dout;
				cpu_req.dm <= {~tg68_uds,~tg68_lds};				
				case(tg68_state)
					STATE_FETCH: begin // Instruction fetch
							cpu_req.req<=~cpu_resp.ack;
							cpu_req.wr <= 1'b0;
							cpu_req.ifetch <= 1'b1;
						end
					STATE_INTERNAL: begin // Internal cycle
						end
					STATE_READ: begin // Data read
							cpu_req.req<=~cpu_resp.ack;
							cpu_req.wr <= 1'b0;
							cpu_req.ifetch <= 1'b0;
						end
					STATE_WRITE: begin // Data write
							cpu_req.req<=~cpu_resp.ack;
							cpu_req.wr <= 1'b1;
							cpu_req.ifetch <= 1'b0;
						end			
				endcase
				state <= WAIT;
			end
		end

		PERIPHERAL : begin
		
		end

		SPI : begin
			if(!spi_busy) begin
				tg68_din <= {8'd0,spi_q};
				clkena <= 1'b1;
				state <= DECODE;
			end
		end

		WAIT: begin
				if(slower[0] && (cpu_resp.ack==cpu_req.req)) begin
					tg68_din <= cpu_resp.q;
					clkena <=1'b1;
					state <= DECODE;
				end
			end

		default :
			state <= INIT;

	endcase

	if(uart_rxint)
		uart_rxpending<=1'b1;

	if(!clocks.reset_n_sys) begin
		state <= RESET;
		spi_speed_sel <= 1'b0;
		spi_cs <= 1'b1;
	end

end


/* verilator lint_off UNSIGNED */
/* verilator lint_off UNOPTFLAT */
TG68KdotC_Kernel tg68 (
	.clk(clocks.sysclk),
	.nReset(tg68_reset_in),
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
	.nResetOut(tg68_reset_out),
	.FC(tg68_fc),
	.clr_berr(),
	.skipFetch(),
	.regin_out(),
	.CACR_out(),
	.VBR_out()
);

/* verilator lint_on UNSIGNED */
/* verilator lint_on UNOPTFLAT */

// JTAG capture module to monitor the cpu bus lines
localparam capturewidth = 77;
localparam capturedepth = 12;
wire [capturewidth-1:0] jtag_d;
wire [capturewidth-1:0] jtag_q;
wire jtag_update;

assign jtag_d[1:0] = tg68_state;
assign jtag_d[2] = tg68_reset_in;
assign jtag_d[6:3] = state;
assign jtag_d[38:7] = tg68_addr_d;
assign jtag_d[54:39] = tg68_din;
assign jtag_d[55] = clkena;
assign jtag_d[56] = spi_cs;
assign jtag_d[64:57] = spi_q;
assign jtag_d[72:65] = spi_speed;
assign jtag_d[73] = spi_d_stb;
assign jtag_d[74] = spi_cipo;
assign jtag_d[75] = spi_copi;
assign jtag_d[76] = spi_clk;

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

endmodule

