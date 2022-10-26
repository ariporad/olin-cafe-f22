`timescale 1ns/1ps
`default_nettype none
module test_comparators;

parameter N = 32;

int errors = 0;

// These are just helpful for debugging in GTKWave
logic equals_is_wrong, less_than_is_wrong;

logic signed [N-1:0] a, b; // Adding the 'signed' keyword here makes the behavioural logic compute a signed slt.
wire equals, less_than;

comparator_eq #(.N(N)) UUT_EQ(.a(a), .b(b), .out(equals));
comparator_lt #(.N(N)) UUT_LT(.a(a), .b(b), .out(less_than));


/*
It's impossible to exhaustively test all inputs as N gets larger, there are just
too many possibilities. Instead we can use a combination of testing interesting 
specified edge cases (e.g. adding by zero, seeing what happens on an overflow)
and some random testing! SystemVerilog has a lot of capabilities for this 
that we'll explore in further testbenches.
  1) the tester: sets inputs
  2) checker(s): verifies that the functionality of our HDL is correct
                 using higher level programming constructs that don't translate*
                 to real hardware.
*Okay, many of them do, but we're trying to learn here, right?
*/


// Some behavioural comb. logic that computes correct values.
logic correct_equals, correct_less_than;

always_comb begin : behavioural_solution_logic
  correct_less_than = a < b;
  correct_equals = a == b;
end

// You can make "tasks" in testbenches. Think of them like methods of a class, 
// they have access to the member variables.
task print_io;
  $display("%8h %8h | == %b (%b)          | <  %b (%b)", a, b, equals, correct_equals, less_than, correct_less_than);
endtask


// 2) the test cases
initial begin
  // Initialize these (they're only set after a delay)
  equals_is_wrong = 0;
  less_than_is_wrong = 0;

  $dumpfile("comparators.fst");
  $dumpvars;
  
  $display("Specific interesting tests.");
  $display("a        b        | == uut (correct) | < uut (correct)");

  a = 0; b = 0; #2 print_io();
  a = -1; b = 1; #2 print_io();
  a = 38273; b = 38273; #2 print_io();
  a = -(2**32); b = (2**32) - 1; #2 print_io();
  a = -1; b = (2**32) - 1; #2 print_io();
  a = -3; b = 7; #2 print_io();

  // Add more interesting tests here!

  // Just some misc. numbers
  a = 7; b = -3; #2 print_io();
  a = 2; b = 5; #2 print_io();
  a = -2; b = -5; #2 print_io();
  a = 5; b = 2; #2 print_io();
  a = -5; b = -2; #2 print_io();

  // Now test overflows
  a = 32'h90000000; b = 32'h70000000 ; #2 print_io();
  a = 32'h70000000; b = 32'h90000000 ; #2 print_io();
  a = 32'h79999999; b = 32'h79999999 ; #2 print_io();
  a = 32'h80000000; b = 32'h80000000 ; #2 print_io();
  
  $display("Random testing.");
  for (int i = 0; i < 10; i = i + 1) begin : random_testing
    a = $random();
    b = $random();
    #2 print_io();
  end
  #10;
  if (errors !== 0) begin
    $display("---------------------------------------------------------------");
    $display("-- FAILURE                                                   --");
    $display("---------------------------------------------------------------");
    $display(" %d failures found, try again!", errors);
  end else begin
    $display("---------------------------------------------------------------");
    $display("-- SUCCESS                                                   --");
    $display("---------------------------------------------------------------");
  end
  $finish;
end

// Note: the triple === (corresponding !==) check 4-state (e.g. 0,1,x,z) values.
//       It's best practice to use these for checkers!
always @(a or b) begin
  #1;
  if (equals === correct_equals) begin
    equals_is_wrong = 0;
  end else begin
    equals_is_wrong = 1'dx; // we use x so it shows up red in GTKWave
    $display("@%t:: ERROR :: compare_eq should be %b, is %b", $time, correct_equals, equals);
    errors = errors + 1;
  end
  if (less_than === correct_less_than) begin
    less_than_is_wrong = 0;
  end else begin
    less_than_is_wrong = 1'dx; // we use x so it shows up red in GTKWave
    $display("@%t:: ERROR :: compare_lt should be %b, is %b", $time, correct_less_than, less_than);
    errors = errors + 1;
  end
end

endmodule
