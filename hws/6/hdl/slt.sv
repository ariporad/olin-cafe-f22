module slt(a, b, out);
parameter N = 32;
input wire signed [N-1:0] a, b;
output logic out;

// Using only *structural* combinational logic, make a module that computes if a is less than b!
// Note: this assumes that the two inputs are signed: aka should be interpreted as two's complement.

// Copy any other modules you use into this folder and update the Makefile accordingly.

// OK, we want to know if a < b.
// If a < b, then a - b < 0.
// Detecting if a two's compliment signed number is less than zero is easy--just check the high
// (sign) bit.
// Doing subtraction is also easy: a - b = a + (-b), so we just have to negate b then add it to a
// Negation in two's compliment is equally easy: just flip all the bits and add 1
// Convinently, our adder can "add two numbers plus 1" just by adding the two numbers with c_in = 1
// So: putting it all together: We need to add a + ~b, with c_in = 1, then check if the high/sign
// bit of the result is 1. If, so then (a + (-b)) = (a - b) < 0, meaning a < b.

// NOTE: This isn't entirely my idea, it was discussed in class and in the textbook. The HDL is mine
// though.

// NOTE: This misbehaves when it overflows, which occurs when two very-far-from-zero numbers of
// opposite signs are compared (ex. -2^N < 2^N-1 would be wrong). This doesn't occur for two numbers
// of the same sign (because one is negated, so it gets closer to zero).
// An easy solution to this is that if the numbers are of opposite signs, we compute the result
// manually.

// Truth table for this alternate path:
// | a[N-1] | b[N-1] | out |    comment     |
// |--------|--------|-----|----------------|
// |   0    |   0    | N/A | same sign      |
// |   1    |   1    | N/A | same sign      |
// |   0    |   1    |  0  | a >= 0, b <  0 |
// |   1    |   0    |  1  | a <  0, b >= 0 |
//
// This is (A[N-1] XOR B[N-1]) ? (A[N-1]) : <other process>

wire signed [N-1:0] sum;

adder_n #(.N(N)) adder(
	.a(a),
	.b(~b),
	.c_in(1),
	.sum(sum)
);
always_comb begin
	out = (
		(a[N-1] ^ b[N-1]) // if signs don't match
		? a[N-1] // then return a < 0
		: sum[N - 1] // else return (a - b) < 0
	);
end


endmodule


