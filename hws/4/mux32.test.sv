`timescale 1ns/1ps
`default_nettype none

module test_mux32;

// >>> print(", ".join([f"in{i:02}" for i in range(32)]))
logic [31:0] inputs;

logic [4:0] select;

wire out;

mux32 UUT(
  .select(select),
  .out(out),

  // >>> print('\n'.join(f"\t.in{x:02}(inputs[{x:2}])," for x in range(0, 32)))
	.in00(inputs[ 0]),
	.in01(inputs[ 1]),
	.in02(inputs[ 2]),
	.in03(inputs[ 3]),
	.in04(inputs[ 4]),
	.in05(inputs[ 5]),
	.in06(inputs[ 6]),
	.in07(inputs[ 7]),
	.in08(inputs[ 8]),
	.in09(inputs[ 9]),
	.in10(inputs[10]),
	.in11(inputs[11]),
	.in12(inputs[12]),
	.in13(inputs[13]),
	.in14(inputs[14]),
	.in15(inputs[15]),
	.in16(inputs[16]),
	.in17(inputs[17]),
	.in18(inputs[18]),
	.in19(inputs[19]),
	.in20(inputs[20]),
	.in21(inputs[21]),
	.in22(inputs[22]),
	.in23(inputs[23]),
	.in24(inputs[24]),
	.in25(inputs[25]),
	.in26(inputs[26]),
	.in27(inputs[27]),
	.in28(inputs[28]),
	.in29(inputs[29]),
	.in30(inputs[30]),
	.in31(inputs[31])
);

initial begin
  $dumpfile("mux32.fst");
  $dumpvars(0, UUT);

  /*
  Test (since we're not going to check every option):
  - Set even-numbered inputs to 0, odds to 1
  - Iterate through every input, make sure it has the right output
  */

  // Set every input to a known value (even-numbered inputs = 0, odds = 1)
  for (int i = 0; i < 32; i = i + 1) begin
    inputs[i] = i[0];
  end

  // Now check that every input works
  for (int i = 0; i < 32; i = i + 1) begin
    select = i[4:0];
    #1;

    if (out != i[0]) begin
      $display("@%8t : FAIL: Selecting input %d did not work!", $time, i);
      $finish;
    end

  end

  $display("PASS");
end

endmodule
