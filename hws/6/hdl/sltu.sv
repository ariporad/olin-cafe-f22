module sltu(a, b, out);
parameter N = 32;
input wire signed [N-1:0] a, b;
output logic out;

// Using only *structural* combinational logic, make a module that computes if a is less than b!
// Note: this assumes that the two inputs are signed: aka should be interpreted as two's complement.

// Copy any other modules you use into this folder and update the Makefile accordingly.

// OK, we need to do less than with unsigned numbers. On the one hand, this is a bit simpler, since
// there can't be any overflow.
//
// On the other hand, if either of the inputs has a high most significant bit, then passing it to an
// adder will cause nonsense.
//
// We can split a SLTU b into two cases: either a[N-1] == b[N-1] == 1 (ie. a and b are both ≥ 2^{N-1}),
// in which case the answer comes down to a[N-2:0] and b[N-2:0] (which can just be treated as signed
// numbers, and they're valid and won't overflow). Otherwise, the smaller number is the one with a
// low MSB.

wire slt_result;

slt #(.N(N)) less_than(
	.a(a[N-2:0]),
	.b(b[N-2:0]),
	.out(slt_result)
);

always_comb begin
	out = (
		(a[N-1] ^ b[N-1]) // if signs don't match
		? b[N-1] // then return if b is the bigger one
		: slt_result // else return (a - b) < 0
	);
end


endmodule


