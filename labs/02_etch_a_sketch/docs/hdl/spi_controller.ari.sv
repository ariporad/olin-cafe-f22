`include "spi_types.sv"
`include "adder_n.sv"

`timescale 1ns / 100ps
`default_nettype none

module spi_controller(
  clk, rst, sclk, csb, mosi, miso,
  spi_mode, i_ready, i_valid, i_data, o_ready, o_valid, o_data,
  bit_counter
);

input wire clk, rst; // default signals.

// SPI Signals
output logic sclk; // Serial clock to secondary device.
output logic csb; // chip select bar, needs to go low at the start of any SPI transaction, then go high when done.
output logic mosi; // Main Out Secondary In (sends serial data to secondary device)
input wire miso; // Main In Secondary Out (receives serial data from secondary device)

// Control Signals
input spi_transaction_t spi_mode;
output logic i_ready;
input wire i_valid;
input wire [15:0] i_data;

input wire o_ready; // Unused for now.
output logic o_valid;
output logic [23:0] o_data;
output logic unsigned [4:0] bit_counter; // The number of the current bit being transmit.

// TX : transmitting
// RX: receiving
enum logic [2:0] {S_IDLE, S_TXING, S_TX_DONE, S_RXING, S_RX_DONE, S_ERROR } state;

// Internal registers/buffers.
logic [15:0] tx_data;
logic [23:0] rx_data;

always_comb begin : csb_logic
  case(state)
    S_IDLE, S_ERROR : csb = 1;
    S_TXING, S_TX_DONE, S_RXING, S_RX_DONE: csb = 0;
    default: csb = 1;
  endcase
end

always_comb begin : mosi_logic
  mosi = tx_data[bit_counter[4:0]] & (state == S_TXING);
end

wire [4:0] next_bit_counter;

adder_n #(.N(5)) bit_counter_adder(
  .a(bit_counter),
  .b(~5'b1),
  .c_in(1),
  .sum(next_bit_counter)
);

/*
This is going to be one of our more complicated FSMs. 
We need to sample inputs on the positive edge of sclk, but 
we also want to set outputs on the negative edge of the clk (it's
  the safest time to change an output given unknown peripheral
  setup/hold times).

To do this we are going to toggle sclk every cycle. We can then test
whether we are about to be on a negative edge or a positive edge by 
checking the current value of sclk. If it's 1, we're about to go negative,
so that's a negative edge.

*/
always_ff @(posedge clk) begin : spi_controller_fsm
  if(rst) begin
    state <= S_IDLE;
    sclk <= 0;
    bit_counter <= 0;
    o_valid <= 0;
    i_ready <= 1;
    tx_data <= 0;
    rx_data <= 0;
    o_data <= 0;
  end else begin
    case (state)
      S_IDLE: begin
        // These aren't SPI, so are safe to update irregardless of sclk
        o_valid <= 0;
        i_ready <= 1;
        if (i_valid) begin
          tx_data <= i_data;
          state <= S_TXING;
          case (spi_mode)
            WRITE_8, WRITE_8_READ_8, WRITE_8_READ_16, WRITE_8_READ_24: bit_counter <= 5'd7;
            WRITE_16: bit_counter <= 5'd15;
            default: bit_counter <= 5'd0;
          endcase
        end
        // if (~sclk) begin
        //   if (i_valid) begin
        //     tx_data <= i_data;
        //     state <= S_TXING;
        //     case (spi_mode)
        //       WRITE_8, WRITE_8_READ_8, WRITE_8_READ_16, WRITE_8_READ_24: bit_counter <= 5'd7;
        //       WRITE_16: bit_counter <= 5'd15;
        //       default: bit_counter <= 5'd0;
        //     endcase
        //   end
        // end
      end
      S_TXING: begin
        i_ready <= 0; // Not SPI, sclk doesn't matter
        if (sclk) begin
          if (|bit_counter) begin // If the bit counter isn't 0
            bit_counter <= next_bit_counter;
          end else begin // If we just finished sending (ie. sent the 0th bit)
            bit_counter <= 0;
            state <= S_TX_DONE;
          end
        end
      end
      S_TX_DONE: begin
        if (sclk) begin
          case (spi_mode)
            WRITE_8_READ_8, WRITE_8_READ_16, WRITE_8_READ_24: state <= S_RXING;
            default: state <= S_IDLE;
          endcase
        end
      end
      S_RXING: begin
      end
      S_RX_DONE: begin
      end
      S_ERROR: begin
      end
    endcase
    sclk <= ~sclk;
  end
end

endmodule
