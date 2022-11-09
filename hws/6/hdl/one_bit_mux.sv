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

// logic out_high, out_low;

// generate
// 	if (INVERT == 1) begin
// 		always_comb out = select[W-1] ? out_low : out_high;
// 	end else begin
// 		always_comb out = select[W-1] ? out_high : out_low;
// 	end
// endgenerate

// generate
// 	if ($clog2(N) == 1) begin
// 		always_comb begin
// 			out_low = in[0];
// 			out_high = in[1];
// 		end
// 	end else begin
// 		one_bit_mux #(.N(N/2)) low_mux(.in(in[(N/2)-1:0]), .out(out_low), .select(select[W-2:0]));
// 		one_bit_mux #(.N(N/2)) high_mux(.in(in[N-1:(N/2)]), .out(out_high), .select(select[W-2:0]));
// 	end
// endgenerate

endmodule