// Generates "triangle" waves (counts from 0 to 2^N-1, then back down again)
// The triangle should increment/decrement only if the ena signal is high, and hold its value otherwise.
`include "adder_n.sv"
module triangle_generator(clk, rst, ena, out);

parameter N = 8;
input wire clk, rst, ena;
output logic [N-1:0] out;

typedef enum logic {COUNTING_UP, COUNTING_DOWN} state_t;
state_t state;
state_t next_state;

always_comb begin : next_state_computation
	if (state == COUNTING_UP & (&out)) begin
		next_state = COUNTING_DOWN;
	end
	else if (state == COUNTING_DOWN & (&(~out))) begin
		next_state = COUNTING_UP;
	end
end

logic is_counting_up_next;
always_comb is_counting_up_next = next_state == COUNTING_UP;

wire [N-1:0] next_out;

adder_n #(.N(N)) adder(
	.a(out),
	// OK, so technically we're doing something bad here by adding a signed and unsigned number, but
	// in this particular circumstance it's OK. Here's why:
	// Let's consider our two numbers (state and -1) to be N+1-bit numbers. State (which is unsigned)
	// would have a 0 at the begininng, and -1 (which is all 1's in two's compliment), would have
	// another 1 at the beginning. (Since -1 is all 1's, it doesn't matter that Verilog doesn't know
	// about our imaginary extra bit--they're all the same.) We do our addition like normal, then
	// the carry out of these N bits would be the carry in to the N+1th (sign) bit. Since we don't
	// care about that bit, we can just discard the carry and not bother to compute it.[1]
	//
	// [1] Since we're adding a positive and negative number and checking elsewhere that we're not
	//     underflowing/the result is not negative, we know the carry out bit will always be a 1 to
	//     cancel out the -1's high bit in the sign place to produce a positive result. This doesn't
	//     matter at all, but it's true.
	.b((is_counting_up_next) ? 1 : -1),
	.c_in(1'b0),
	.sum(next_out)
);

always_ff @( posedge clk ) begin
	if (rst) begin
		next_state = COUNTING_UP;
		state <= COUNTING_UP;
		out <= 0;
	end else if (ena) begin
		state <= next_state;
		out <= next_out;
	end
end


endmodule