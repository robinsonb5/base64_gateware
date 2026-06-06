module jcapture # (
    parameter capturewidth,
    parameter capturedepth,
    parameter triggerwidth,
    parameter designid
) (
    input  clk,
    input  reset_n,
	input  stb,
    input  [capturewidth-1:0] capture_d,
    output [capturewidth-1:0] user_q,
    output user_update
);

endmodule

