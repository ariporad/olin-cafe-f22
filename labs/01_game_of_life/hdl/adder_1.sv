`timescale 1ns/1ps
`default_nettype none
/*
  a 1 bit addder that we can daisy chain for 
  ripple carry adders
*/

module adder_1(a, b, c_in, sum, c_out);

input wire a, b, c_in;
output logic sum, c_out;

always_comb begin
  sum = a ^ b ^ c_in; // Output is high if we have an odd number of inputs (1 or 3)
  c_out = (a & c_in) | (b & c_in) | (a & b); // Carry is high if we have at least two inputs (2 or 3)
end

endmodule
