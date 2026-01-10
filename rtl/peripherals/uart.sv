module uart #(parameter clkdivbits=16) (
	input clk,
	input reset_n,
	input [clkdivbits-1:0] clkdiv, // should be sysclk_freqency / baud_rate
	input [7:0] d,
	input d_stb,
	output reg [7:0] q,
	output reg rxint,
	output reg txready,
	output reg txint,
	input rxd,
	output reg txd
);

// Simplistic 8N1 UART with controllable baud rate


// Synchronise incoming rxd
reg [1:0] rxd_sync;
always @(posedge clk)
	rxd_sync <= {rxd,rxd_sync[1]};

// State machine
typedef enum logic [1:0] {IDLE, STARTBIT, BITSHIFT, STOPBIT} state_t;
state_t rxstate;
state_t txstate;


// Rx Clock generation. When in IDLE state, on the first bit edge we set the counter
// to half a bit width, after which it resets on underflow to a full bit width,
// so that each underrun should land in the middle of a bit.

reg [clkdivbits-1:0] rxcounter;
reg rxclock;

always @(posedge clk) begin
	rxclock <= 1'b0;
	if(rxstate==IDLE) begin
		if(!rxd_sync[0])
			rxcounter <= {1'b0,clkdiv[clkdivbits-1:1]};
	end else begin
		rxcounter<=rxcounter-1;
		if(!(|rxcounter)) begin
			rxclock <= 1'b1;
			rxcounter <= clkdiv;
		end
	end
end


reg [8:0] rxshift;

// Rx data

always @(posedge clk) begin

	rxint <= 1'b0;
	
	case (rxstate)

		IDLE : begin
			if(!rxd_sync[0])
				rxstate <= STARTBIT;
		end

		STARTBIT : begin
			if(rxclock) begin
				if(!rxd_sync[0]) begin
					rxshift <= 9'b100000000;
					rxstate <= BITSHIFT;
				end else
					rxstate <= IDLE; // Framing error, return to idle state.
			end
		end

		BITSHIFT : begin
			if(rxclock)
				rxshift <= {rxd_sync[0],rxshift[8:1]};
			if(rxshift[0])
				rxstate <= STOPBIT;
		end

		STOPBIT : begin
			if(rxclock) begin
				if(rxd_sync[0]) begin
					q <= rxshift[8:1];
					rxint <= 1'b1;
				end
				rxstate <= IDLE;
			end
		end

		default : 
			rxstate <= IDLE;
		
	endcase

	if(!reset_n) begin
		rxstate <= IDLE;
		rxint <= 1'b0;
		rxshift <= 9'b0;
	end
end


// Tx Clock generation

reg txclock;
reg [clkdivbits-1:0] txcounter;

always @(posedge clk) begin
	txclock <= 1'b0;
	txcounter <= txcounter-1;
	if(!(|txcounter)) begin
		txclock <= 1'b1;
		txcounter <= clkdiv;
	end
end

// Tx Data

reg [9:0] txshift;

always @(posedge clk) begin

	txint <= 1'b0;
	
	case(txstate)
		IDLE : begin
			txd <= 1'b1;
			txready <= 1'b1;
			if(d_stb) begin
				txshift <= {1'b1,d,1'b0}; // Stop bit, data, start bit, shifted out LSB first
				txready <= 1'b0;
				txstate <= BITSHIFT;
			end
		end
		
		BITSHIFT : begin
			if(txclock) begin
				txd <= txshift[0];
				txshift <= {1'b0,txshift[9:1]};
				
				if(txshift == 10'b0000000001) begin
					txint <= 1'b1;
					txstate <= IDLE;
				end
			end
		end
		
		default :
			txstate <= IDLE;
	endcase
	
	if(!reset_n) begin
		txstate <= IDLE;
	end

end

endmodule

