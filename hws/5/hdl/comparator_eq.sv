module comparator_eq(a, b, out);
parameter N = 32;
input wire signed [N-1:0] a, b;
output logic out;

// Using only *structural* combinational logic, make a module that computes if a == b. 

// XOR of 2 bits returns 1 if the bits don't match. Therefore, XNOR (ie. NOT XOR) returns 1 if they do.
// If a and b are both 32 bits, then a XNOR b returns 32 bits of pairwise comparisons (ie. the third
// bit of the result is 1 iff the third bit of a and b match). The output of this module should be
// 1 iff every bit in the XNOR result is 1 (ie. all bits matched). This can be achieved by ANDing
// all the bits of the XNOR result together, which Verilog makes easy:

always_comb out = &(a ~^ b);

endmodule


