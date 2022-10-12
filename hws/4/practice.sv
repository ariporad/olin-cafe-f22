`timescale 1ns/1ps
`default_nettype none

module practice(rst, clk, ena, seed, out);

	input wire rst, clk, ena, seed;
	output logic out;

	logic a, b, c, d;

	/*

	always_comb d = b ? a : 1'b0;
	always_ff @(posedge c) begin
		out[3] <= d;
	end

	*/

	/*
	// V1

	always_comb b = ena ? a : seed;

	// F1: b -> c
	always_ff @(posedge clk) c = rst ? 1'b0 : b;

	always_comb a = c ^ d;

	// F2: c -> d
	always_ff @(posedge clk) d = rst ? 1'b0 : c;

	// F3: d -> out
	always_ff @(posedge clk) out = rst ? 1'b0 : d;

	*/

	// V2
	always_comb begin
		a = c ^ d;
		b = ena ? a : seed;
	end

	always_ff @(posedge clk) begin
		out = rst ? 1'b0 : d;
		d = rst ? 1'b0 : c;
		c = rst ? 1'b0 : b;
	end

endmodule
