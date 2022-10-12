`timescale 1ns/1ps
module decoder_3_to_8(ena, in, out);

  input wire ena;
  input wire [2:0] in;
  output logic [7:0] out;

  decoder_2_to_4 high_is_0(
  	.ena(ena & (~in[2])),
  	.in(in[1:0]),
  	.out(out[3:0])
  );

  decoder_2_to_4 high_is_1(
  	.ena(ena & in[2]),
  	.in(in[1:0]),
  	.out(out[7:4])
  );

endmodule