`timescale 1ns/1ps
`default_nettype none

module shift_right_arithmetic(in,shamt,out);
parameter N = 32; // only used as a constant! Don't feel like you need to a shifter for arbitrary N.

//port definitions
input  wire [N-1:0] in;    // A 32 bit input
input  wire [$clog2(N)-1:0] shamt; // Shift ammount
output logic [N-1:0] out; // The same as SRL, but maintain the sign bit (MSB) after the shift! 
// It's similar to SRL, but instead of filling in the extra bits with zero, we
// fill them in with the sign bit.
// Remember the *repetition operator*: {n{bits}} will repeat bits n times.

generate
	genvar i;

	for (i = 0; i < N - 1; i = i + 1) begin
		one_bit_mux #(.N(N)) bit_i(
			.in({ { N { out[N-1] } }, in[N-1:i]}),
			.select(shamt),
			.out(out[i])
		);
	end
endgenerate

always_comb begin : keep_sign
	out[N-1] = in[N-1];
end

endmodule
