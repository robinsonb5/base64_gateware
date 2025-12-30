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


typedef enum logic[2:0] {
    RESET,
    SETDDR,
	SETPOTGO,
    READRMB,
    READLMB,
    WRITECOLOR0,   
    WRITELED
} state_t;

state_t state;

reg [7:0] btns1; // $bfe001 - left button.
reg [15:0] btns2; // $dff016 - right and middle mouse buttons
reg [15:0] rgb=0;

reg[19:0] ledcounter;

always @(posedge clocks.sysclk) begin
    case (state)
        RESET : begin
    		cpu_req.req<=1'b0;
    		rgb<=0;
            state <= SETDDR;
        end
        SETDDR : begin
            if(cpu_resp.ack == cpu_req.req) begin
	            cpu_req.addr <= 32'hbfe201;
	            cpu_req.dm<=2'b11;
                cpu_req.wr<=1'b1;
                cpu_req.d<=16'h3; // OVL and LED output, all other input.
			    cpu_req.req<=~cpu_resp.ack;
                state <= SETPOTGO;
            end            
        end
		SETPOTGO : begin
            if(cpu_resp.ack == cpu_req.req) begin
	            cpu_req.addr <= 32'hdff034;
	            cpu_req.dm<=2'b11;
                cpu_req.wr<=1'b1;
                cpu_req.d<=16'hff00; // Drive outputs high to use as button inputs
			    cpu_req.req<=~cpu_resp.ack;
                state <= READRMB;
            end            
		end
        READRMB : begin
            if(cpu_resp.ack == cpu_req.req) begin
	            cpu_req.addr <= 32'hfc0004; // ROM
	            cpu_req.dm<=2'b11;
                cpu_req.wr<=1'b0;
			    cpu_req.req<=~cpu_resp.ack;
                state <= READLMB;
            end
        end
        READLMB : begin
            if(cpu_resp.ack == cpu_req.req) begin
                btns2<=cpu_resp.q;
	            cpu_req.addr <= 32'hbfe001;
	            cpu_req.dm<=2'b11;
                cpu_req.wr<=1'b0;
			    cpu_req.req<=~cpu_resp.ack;
                state <= WRITECOLOR0;
            end
        end
        WRITECOLOR0 : begin
		    if(cpu_resp.ack==cpu_req.req) begin
                btns1<=cpu_resp.q;
	            cpu_req.addr <= 32'hdff180;
	            cpu_req.dm<=2'b11;
			    cpu_req.d<=rgb ^ btns2 ^ btns1;
			    cpu_req.wr<=1'b1;
			    cpu_req.req<=~cpu_resp.ack;
			    rgb <= rgb + {btns2[8],btns2[10],btns1[6],1'b1};
                state <= WRITELED;
		    end
    	end
        WRITELED : begin
            if(cpu_resp.ack == cpu_req.req) begin
                ledcounter <= ledcounter + 1;
	            cpu_req.addr <= 32'hbfe001;
	            cpu_req.dm<=2'b11;
                cpu_req.wr<=1'b1;
                cpu_req.d<={ledcounter[19],1'b0}; // Keep OVL low, LED toggles.
			    cpu_req.req<=~cpu_resp.ack;
                state <= READRMB;
            end            
        end
        default : begin
            state <= RESET;
        end
    endcase
    if(!clocks.reset_n_sys)
        state <= RESET;
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


// JTAG capture module to monitor the cpu
wire [0:0] jtag_q;
wire jtag_update;
cpu_probe #(.out_width(1)) probe (
    .clocks(clocks),
    .m_addr(socket_addr_ctrl),
    .m_data_in(socket_din),
    .m_data_out(socket_dout),
    .m_misc_in(socket_miscin),
    .m_misc_out(socket_miscout),
    .extra(1'b0),
    .update(jtag_update),
    .q(jtag_q)
);

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
