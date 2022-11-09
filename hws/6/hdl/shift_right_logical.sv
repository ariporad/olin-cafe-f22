`timescale 1ns/1ps
`default_nettype none
module shift_right_logical(in,shamt,out);
parameter N = 32; // only used as a constant! Don't feel like you need to a shifter for arbitrary N.

//port definitions
input  wire [N-1:0] in;    // A 32 bit input
input  wire [$clog2(N)-1:0] shamt; // Amount we shift by.
output logic [N-1:0] out;  // Output.

generate
	genvar i;

	for (i = 0; i < N; i = i + 1) begin
		one_bit_mux #(.N(N)) bit_i(
			.in(in[N-1:i]),
			.select(shamt),
			.out(out[i])
		);
	end
endgenerate


endmodule
