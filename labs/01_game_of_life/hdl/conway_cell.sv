`default_nettype none
`timescale 1ns/1ps

module conway_cell(clk, rst, ena, state_0, state_d, state_q, neighbors);
input wire clk;
input wire rst;
input wire ena;

input wire state_0;
output logic state_d; // NOTE - this is only an output of the module for debugging purposes. 
output logic state_q;

input wire [7:0] neighbors;

logic [3:0] num_neigbors;

counter_8 neighbor_counter(
	.items(neighbors),
	.out(num_neigbors)
);

always_comb begin
	state_d = (
		// num_neigbors XNOR 3 or (state_q and (num_neigbors XNOR 2))
		(num_neigbors == 4'd3) |
		(state_q & (num_neigbors == 4'd2))
	);
end

always_ff @( posedge clk ) begin
	state_q = ena ? (rst ? state_0 : state_d) : 1'b0;
end

endmodule