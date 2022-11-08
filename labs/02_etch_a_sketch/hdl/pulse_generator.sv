/*
  Outputs a pulse generator with a period of "ticks".
  out should go high for one cycle every "ticks" clocks.
*/
`include "adder_n.sv"
`include "comparator_eq.sv"

module pulse_generator(clk, rst, ena, ticks, out);

parameter N = 8;
input wire clk, rst, ena;
input wire [N-1:0] ticks;
output logic out;

logic [N-1:0] counter;

comparator_eq #(.N(N)) comp_eq(
  .a(ticks),
  .b(counter),
  .out(out)
);

wire [N-1:0] next_count;

adder_n #(.N(N)) adder(
  .a(counter),
  .b(1),
  .c_in(1'b0),
  .sum(next_count)
);

always_ff @( posedge clk ) begin
  if (rst) begin
    // The spec is slightly unclear here, I'm reading it as the output should be high for 1/ticks
    // clock cycles (ie. low for ticks-1 cycles then high for 1). It might be low for ticks cycles
    // then high for 1, in which case this should be 0. (Same below)
    counter <= 1;
  end else if (ena) begin
    // See above
    counter <= out ? 1 : next_count;
  end
end

endmodule
