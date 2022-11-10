`timescale 1ns/1ps
`default_nettype none

module one_bit_mux(
	in,
	select,
	out
);

parameter N = 32; // NB: N probably must be a factor of 2 for this to work right

parameter INVERT = 0;

localparam W = $clog2(N);

input wire [N-1:0] in;
input wire [W-1:0] select;
output logic out;

always_comb out = in[select];

endmodule