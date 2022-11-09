`timescale 1ns/1ps
`default_nettype none

module alu(a, b, control, result, overflow, zero, equal);
parameter N = 32; // Don't need to support other numbers, just using this as a constant.

input wire [N-1:0] a, b; // Inputs to the ALU.
input alu_control_t control; // Sets the current operation.
output logic [N-1:0] result; // Result of the selected operation.

output logic overflow; // Is high if the result of an ADD or SUB wraps around the 32 bit boundary.
output logic zero;  // Is high if the result is ever all zeros.
output logic equal; // is high if a == b.

// Use *only* structural logic and previously defined modules to implement an 
// ALU that can do all of operations defined in alu_types.sv's alu_op_code_t.

logic ADDSUB_overflow;
wire [N-1:0] ADDSUB_result;
wire [N-1:0] SLL_result;
wire [N-1:0] SRL_result;
wire [N-1:0] SRA_result;
wire [N-1:0] SLT_result;
wire [N-1:0] SLTU_result;

logic shift_overflow;
always_comb shift_overflow = |(b[N-1:$clog2(N)]);

logic is_AND , is_OR  , is_XOR , is_SLL , is_SRL , is_SRA , is_ADD , is_SUB , is_SLT , is_SLTU;
logic is_shift, is_addsub;

always_comb begin : is_whatevering
	is_AND  = &(control ~^ ALU_AND);
	is_OR   = &(control ~^ ALU_OR );
	is_XOR  = &(control ~^ ALU_XOR);
	is_SLL  = &(control ~^ ALU_SLL);
	is_SRL  = &(control ~^ ALU_SRL);
	is_SRA  = &(control ~^ ALU_SRA);
	is_ADD  = &(control ~^ ALU_ADD);
	is_SUB  = &(control ~^ ALU_SUB);
	is_SLT  = &(control ~^ ALU_SLT);
	is_SLTU = &(control ~^ ALU_SLTU);
	is_shift = is_SLL | is_SRL | is_SRA;
	is_addsub = is_ADD | is_SUB;
end

always_comb begin : aux_outputs
	equal = &(a~^b);
	zero = &(~result);
	// NOTE: The solution reports overflows for SLT and SLTU. My less-than comparator does not
	// overflow, and so never reports an overflow.
	overflow = (
		(is_ADD & (a[N-1] ~^ b[N-1]) & (a[N-1] ^ ADDSUB_result[N-1])) |
		(is_SUB & (a[N-1] ^ b[N-1]) & (a[N-1] ^ ADDSUB_result[N-1]))
	);
end

always_comb begin : operations
	case(control)
    	ALU_AND  : result = a & b;
    	ALU_OR   : result = a | b;
    	ALU_XOR  : result = a ^ b;
    	ALU_SLL  : result = shift_overflow ? 0 : SLL_result;
    	ALU_SRL  : result = shift_overflow ? 0 : SRL_result;
    	ALU_SRA  : result = shift_overflow ? 0 : SRA_result;
    	ALU_ADD  : result = ADDSUB_result;
    	ALU_SUB  : result = ADDSUB_result;
    	ALU_SLT  : result = SLT_result;
    	ALU_SLTU : result = SLTU_result;
    	default  : result = 0;
	endcase
end

adder_n #(.N(N)) addsub(
	.a(a),
	.b(is_SUB ? ~b : b),
	.c_in(is_SUB),
	.sum(ADDSUB_result)
);

shift_left_logical #(.N(N)) sll_mod(
	.in(a),
	.shamt(b[4:0]),
	.out(SLL_result)
);

shift_right_logical #(.N(N)) srl_mod(
	.in(a),
	.shamt(b[4:0]),
	.out(SRL_result)
);

shift_right_arithmetic #(.N(N)) sra_mod(
	.in(a),
	.shamt(b[4:0]),
	.out(SRA_result)
);

slt #(.N(N)) slt_mod(
	.a(a),
	.b(b),
	.out(SLT_result)
);

sltu #(.N(N)) sltu_mod(
	.a(a),
	.b(b),
	.out(SLTU_result)
);



endmodule