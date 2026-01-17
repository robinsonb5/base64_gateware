module Firmware_ROM #(
	parameter addr_width = 15,
	parameter data_width = 16
) (
	input clk,
	input [addr_width+(data_width/8)-2:data_width/8-1] addr,
	input [data_width-1:0] d,
	output [data_width-1:0] q,
	input we,
	input [1:0] bs
);

reg [data_width-1:0] mem [0:(1<<addr_width)-1];

initial begin
  $readmemh ("firmware/Firmware.hex", mem);
end

reg[data_width-1:0] q_local;
always @(posedge clk) begin
	if(we) begin
		if(bs[1])
			mem[addr][15:8] <= d[15:8];
		if(bs[0])
			mem[addr][7:0] <= d[7:0];
	end
	q_local <= mem[addr];
end

assign q = q_local;

endmodule

