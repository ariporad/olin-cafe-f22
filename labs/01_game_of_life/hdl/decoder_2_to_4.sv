`timescale 1ns/1ps
module decoder_2_to_4(ena, in, out);

input wire ena;
input wire [1:0] in;
output logic [3:0] out;

decoder_1_to_2 high_is_0(
	.ena(ena & (~in[1])),
	.in(in[0]),
	.out(out[1:0])
);

decoder_1_to_2 high_is_1(
	.ena(ena & in[1]),
	.in(in[0]),
	.out(out[3:2])
);

endmodule