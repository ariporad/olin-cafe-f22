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

// We need to know how many neighbors we have as a number to know if we should live or die
counter_8 neighbor_counter(
	.items(neighbors),
	.out(num_neigbors)
);

always_comb begin
	// The rules say that any cell should be alive at the next timestep if it has 3 neighbors, and
	// a living cell should remain alive if it has 2 neighbors.

	// We use XNOR for equality comparison: XOR returns 1 when its inputs don't match,
	// so XNOR returns 1 when its inputs do.
	// We then AND each bit of the result. If all the bits are 1, that means all bits matched.
	// Putting it all together: &(a ~^ b) is 1 iff a and b are the same.
	state_d = (
		&(num_neigbors ~^ 4'd3) | // If we have 3 neigbors OR
		(state_q & (&(num_neigbors ~^ 4'd2))) // if we're alive and have 2 neighbors
	);
end

always_ff @( posedge clk ) begin
	// On the rising clock edge, reset if RST is high, otherwise update the state if enabled.
	// Note that if ENA is 0, we keep our current state; and that RST overrides ENA.
	if (rst) begin
		state_q = state_0;
	end else if (ena) begin
		state_q = state_d;
	end
end

endmodule