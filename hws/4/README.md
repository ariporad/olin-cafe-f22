# Homework 4
The written portion is available [here](https://docs.google.com/document/d/1XybXmTD5-NTJ1gfLq3tYb-wUUDJGZS8xgO912DLf50Q/edit?usp=sharing)

Add a pdf of your written answers to this folder, then use `make clean` then `make submission` to submit!

## Implementation Notes

### Adder

I re-used the adder from Lab 1. It's an N-bit ripple-carry adder, composed of N 1-bit full adders. The 1-bit adder was written by me and by lab partner Cole Marco, and the N-bit adder was I believe provided in the assignment.

### Mux32

I decided to go the Keep-It-Simple-Stupid route and generate the bulk of the code for this module with Python. It uses a case statement to pick the output based on the input select symbol.

#### Testing

Testing a Mux32 is hard, because it's not feasible to verify the entire truth table. Instead, I opted for the approach of setting each input to a known value (specifically, LOW for even-numbered inputs and HIGH for odd-numbered inputs), then selecting each input and verifying we got the right value.

## Running the Tests

The Makefile automagically generates a target for each pair of `foo.sv`/`foo.test.sv` files, of which there are currently three: `adder`, `mux32`, and `practice`. Each target's tests can be run with `make <target>_test`, and the test can be visualized using GTKWave with `make <target>_waves`. Putting that all together, all the tests can be run with:

```
make practice_test
make adder_test
make mux32_test
```

Testing artifacts are ignored by git, and can be cleaned with `make clean`.