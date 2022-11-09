`timescale 1ns/1ps
`default_nettype none
module shift_left_logical(in, shamt, out);

parameter N = 32; // only used as a constant! Don't feel like you need to a shifter for arbitrary N.

input wire [N-1:0] in;            // the input number that will be shifted left. Fill in the remainder with zeros.
input wire [$clog2(N)-1:0] shamt; // the amount to shift by (think of it as a decimal number from 0 to 31). 
output logic [N-1:0] out;       

logic [N-1:0] in_reversed;

// For some reason, in[0:N-1] doesn't work in Verilog
generate
	genvar j;
	for (j = 0; j < N; j = j + 1) begin
		always_comb in_reversed[N-1-j] = in[j];
	end
endgenerate

generate
	genvar i;

	for (i = 0; i < N; i = i + 1) begin
		one_bit_mux #(.N(N)) bit_i(
			.in(in_reversed[N-1:N-1-i]),
			.select(shamt),
			.out(out[i])
		);
	end
endgenerate

endmodule
