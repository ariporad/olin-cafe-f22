`default_nettype none
`timescale 1ns/1ps

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

wire [N-1:0] x_decoded;
decoder_3_to_8 COL_DECODER(ena, x, x_decoded);

always_comb begin : display
  rows[0] = ena & cells[(0 * N) + x];
  rows[1] = ena & cells[(1 * N) + x];
  rows[2] = ena & cells[(2 * N) + x];
  rows[3] = ena & cells[(3 * N) + x];
  rows[4] = ena & cells[(4 * N) + x];
  rows[5] = ena & cells[(5 * N) + x];
  rows[6] = ena & cells[(6 * N) + x];
  rows[7] = ena & cells[(7 * N) + x];
end

endmodule
