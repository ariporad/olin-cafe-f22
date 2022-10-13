`timescale 1ns/1ps
`default_nettype none

module test_adder_n;

parameter N = 4;

logic [N-1:0] a, b;
logic c_in;

wire [N:0] result;

adder_n #(.N(N)) UUT(
	.a(a),
	.b(b),
	.c_in(c_in),
	.sum(result[N-1:0]),
	.c_out(result[N])
);

int failures = 0;

initial begin
	$dumpfile($sformatf("%s.fst", `__FILE__));
	$dumpvars(0, UUT);

	for (int cur_a = 0; cur_a < (2**N); cur_a = cur_a + 1) begin
		a = cur_a;
		for (int cur_b = 0; cur_b < (2**N); cur_b = cur_b + 1) begin
			b = cur_b;
			c_in = 0;
			#10;
			c_in = 1;
			#10;
		end
	end

	if (failures > 0) $display("FAIL: Had %d failures!", failures);
	else $display("PASS!");
	$finish;
end

always @(result) begin
	#1;

	if (result == (a + b + c_in)) begin
		$display("@%t: PASS: a:%d + b:%d + c_in:%d = %d!", $time, a, b, c_in, result);
	end else begin
		$display("@%t: FAILURE: a:%d + b:%d + c_in:%d was %d!", $time, a, b, c_in, result);
		failures = failures + 1;
	end
end

endmodule
