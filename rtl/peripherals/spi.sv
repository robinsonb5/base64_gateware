`default_nettype none

module spi (
	input clk,
	input reset_n,
	input [7:0] speed,
	output reg sck,
	input cipo,
	output reg copi,
	input d_stb,
	input [7:0] d,
	output [7:0] q,
	output busy
);

// SPI clock generation

reg [7:0] sckcnt;
reg sck_stb;

always @(posedge clk) begin
	sck_stb <= 1'b0;
	if((!d_stb) && |sckcnt)
		sckcnt <= sckcnt - 1;
	else begin
		sck_stb <= ~d_stb; // Don't emit a tick if the data strobe has just come in.
		sckcnt <= speed;
	end
end


// SPI shift register

reg [7:0] sd_shift;
reg [3:0] shiftcnt;

assign busy = shiftcnt[3] | d_stb;
assign q = sd_shift;
	
always @(posedge clk) begin

	if(d_stb) begin
		shiftcnt <= 4'b1111;
		sd_shift <= d;
		sck <= 1'b1;
	end else if (sck_stb && busy) begin
		if(sck) begin
			copi <= sd_shift[7];
			sck <= 1'b0;
		end else begin
			sck <= 1'b1;
			sd_shift <= {sd_shift[6:0],cipo};
			shiftcnt <= shiftcnt - 1;
		end
	end

	if(!reset_n) begin
		shiftcnt <= 4'b0;
		sck <= 1'b1;
		copi <= 1'b1;
		sd_shift <= {8{1'b1}};
	end
end

endmodule

