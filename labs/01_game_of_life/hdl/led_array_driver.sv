`default_nettype none
`timescale 1ns/1ps

// NOTE: This LED Matrix is active-LOW for the row pin, but we're choosing to invert that because it
// looks much cooler (ie. a lit green LED is a dead cell, a dark LED is a living cell).
// What even is life, you know?

module led_array_driver(ena, x, cells, rows, cols);
// Module I/O and parameters
parameter N=5; // Size of Conway Cell Grid.
parameter ROWS=N;
parameter COLS=N;

// I/O declarations
input wire ena;
input wire [$clog2(N):0] x;
input wire [N*N-1:0] cells;
output logic [N-1:0] rows;
output logic [N-1:0] cols;


// You can check parameters with the $error macro within initial blocks.
initial begin
  if ((N <= 0) || (N > 8)) begin
    $error("N must be within 0 and 8.");
  end
  if (ROWS != COLS) begin
    $error("Non square led arrays are not supported. (%dx%d)", ROWS, COLS);
  end
  if (ROWS < N) begin
    $error("ROWS/COLS must be >= than the size of the Conway Grid.");
  end
end

// X is the current column to render (as a number). We want that column to be HIGH (and all others LOW),
// then we'll set the appropriate values for the rows to show the image.
// Using a number to pick only one output to turn on is exactly what a decoder does, so we can just
// use a 3:8 decoder to light up our columns.
// TODO: If we wanted to truly support dynamically-sized LED Matricies of any size, we'd have to
// make this a dynamically-sized decoder.
decoder_3_to_8 COL_DECODER(ena, x, cols);

// Dynamically generate the rows
generate
  genvar i;
  for (i = 0; i < N; i = i + 1) begin
    // Row should be on if the matrix is enabled and the appropriate cell is alive.
    // See above note about how we're actually inverting that behavior for aesthetics.
    always_comb rows[i] = ena & cells[(i * N) + x];
  end
endgenerate

endmodule
