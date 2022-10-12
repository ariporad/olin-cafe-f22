`default_nettype none
`timescale 1ns/1ps

module counter_8(items, out);
input wire [7:0] items;
output logic [3:0] out;

// 1-bit adders

wire [1:0] result_1_1;
adder_1 adder_1_1 (
	.a(items[0]),
	.b(items[1]),
	.c_in(1'b0),
	.sum(result_1_1[0]),
	.c_out(result_1_1[1])
);

wire [1:0] result_1_2;
adder_1 adder_1_2 (
	.a(items[2]),
	.b(items[3]),
	.c_in(1'b0),
	.sum(result_1_2[0]),
	.c_out(result_1_2[1])
);

wire [1:0] result_1_3;
adder_1 adder_1_3 (
	.a(items[4]),
	.b(items[5]),
	.c_in(1'b0),
	.sum(result_1_3[0]),
	.c_out(result_1_3[1])
);

wire [1:0] result_1_4;
adder_1 adder_1_4 (
	.a(items[6]),
	.b(items[7]),
	.c_in(1'b0),
	.sum(result_1_4[0]),
	.c_out(result_1_4[1])
);

// 2-bit adders

wire [2:0] result_2_1;
adder_n #(.N(2)) adder_2_1 (
	.a(result_1_1),
	.b(result_1_2),
	.c_in(1'b0),
	.sum(result_2_1[1:0]),
	.c_out(result_2_1[2])
);

wire [2:0] result_2_2;
adder_n #(.N(2)) adder_2_2 (
	.a(result_1_3),
	.b(result_1_4),
	.c_in(1'b0),
	.sum(result_2_2[1:0]),
	.c_out(result_2_2[2])
);

// 3-bit adder

adder_n #(.N(3)) adder_3_1 (
	.a(result_2_1),
	.b(result_2_2),
	.c_in(1'b0),
	.sum(out[2:0]),
	.c_out(out[3])
);

endmodule