`timescale 1ns/1ps
module decoder_3_to_8(ena, in, out);

  input wire ena;
  input wire [2:0] in;
  output logic [7:0] out;

  logic in_bar[2:0];

  always_comb begin
    in_bar = ~in;

    out[0] = ena & (~in[2] & ~in[1] & ~in[0])
    out[1] = ena & (~in[2] & ~in[1] &  in[0])
    out[2] = ena & (~in[2] &  in[1] & ~in[0])
    out[3] = ena & (~in[2] &  in[1] &  in[0])
    out[4] = ena & ( in[2] & ~in[1] & ~in[0])
    out[5] = ena & ( in[2] & ~in[1] &  in[0])
    out[6] = ena & ( in[2] &  in[1] & ~in[0])
    out[7] = ena & ( in[2] &  in[1] &  in[0])
  end

endmodule