module jcapture # (
    parameter capturewidth,
    parameter capturedepth,
    parameter triggerwidth,
    parameter id
) (
    input  clk,
    input  reset_n,
	input  stb,
    input  [capturewidth-1:0] d,
    output [capturewidth-1:0] q,
    output update
);

endmodule

