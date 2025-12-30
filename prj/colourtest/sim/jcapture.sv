module jcapture # (
    parameter capture_width,
    parameter capture_depth,
    parameter id
) (
    input  clk,
    input  reset_n,
    input  [capture_width-1:0] d,
    output [capture_width-1:0] q,
    output update
);

endmodule

