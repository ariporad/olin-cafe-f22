`timescale 1ns/1ps
`default_nettype none

`include "rv32i_defines.sv"

/**
 * Instruction Decoder: Decodes Instructions
 */

module instruction_decoder(
  // Control Signals
	clk, // clock signal
  rst, // reset, must be asserted at least once to initialize
  ena, // outputs only change if asserted (use to hold outputs when not in decode stage)
  
  // Input
  instr, // current instruction

  // Outputs
  // All map directly to the RISC-V ISA spec
  // These only change on the rising clock edge if ena is high
  // Each output's behaivor is undefined if the current instruction doesn't include that parameter
	op_type, rd, rs1, rs2, imm, uimm, upimm, funct7,
	funct3_ltype, funct3_ritype, funct3_btype, funct3_stype, funct3_debug
);
input wire clk, ena, rst;
input wire [31:0] instr;

output op_type_t op_type;

output logic [4:0] rd, rs1, rs2;

output logic [31:0] imm; // sign-extended
output logic [4:0] uimm; always_comb uimm = imm[4:0]; // unsigned lowest 5 bits of imm
output logic [31:0] upimm; always_comb upimm[11:0] = 12'b0; // upimm always has 12 zeros at the end

output funct3_ltype_t funct3_ltype;
output funct3_ritype_t funct3_ritype;
output funct3_btype_t funct3_btype;
output funct3_stype_t funct3_stype;
output funct3_debug_t funct3_debug;

output logic [6:0] funct7;

// For some reason iverilog didn't like this:
// decoded_op_type = instr[6:0]
// So we have this stupid thing instead
// TODO: Get help with this
op_type_t decoded_op_type;
always_comb begin : decode_op_type
  if (rst) begin
    decoded_op_type = OP_DEBUG;
  end else case (instr[6:0])
    7'b0110011: decoded_op_type = OP_RTYPE;
    7'b0010011: decoded_op_type = OP_ITYPE;
    7'b0000011: decoded_op_type = OP_LTYPE;
    7'b0100011: decoded_op_type = OP_STYPE;
    7'b1100011: decoded_op_type = OP_BTYPE;
    7'b0110111: decoded_op_type = OP_LUI  ;
    7'b0010111: decoded_op_type = OP_AUIPC;
    7'b1101111: decoded_op_type = OP_JAL  ;
    7'b1100111: decoded_op_type = OP_JALR ;
    7'b0000000: decoded_op_type = OP_DEBUG ;
  endcase
end


always_ff @(posedge clk) begin : parser
  if (rst) begin
    op_type <= 0;
    funct3_ltype <= 0;
    funct3_ritype <= 0;
    funct3_btype <= 0;
    funct3_debug <= 0;
    funct7 <= 0;
    imm <= 0;
    rd <= 0;
    rs1 <= 0;
    rs2 <= 0;
    upimm[31:12] <= 0;
  end else if (ena) begin
    op_type <= decoded_op_type;
    case (decoded_op_type)
      OP_RTYPE: begin
        rd <= instr[11:7];
        funct3_ritype <= instr[14:12];
        rs1 <= instr[19:15];
        rs2 <= instr[24:20];
        funct7 <= instr[31:25];
      end
      // These OP Types are all the same format, but have different funct3 enums
      OP_ITYPE, OP_LTYPE, OP_JALR, OP_DEBUG: begin
        rd <= instr[11:7];
        case (decoded_op_type)
          OP_ITYPE: funct3_ritype <= instr[14:12];
          OP_LTYPE: funct3_ltype <= instr[14:12];
          OP_DEBUG: funct3_debug <= instr[14:12];
          // OP_JALR has no funct3
        endcase
        rs1 <= instr[19:15];
        imm[10:0] <= instr[30:20];
        imm[31:11] <= {21{instr[31]}}; // Sign extension
        if (decoded_op_type == OP_DEBUG) begin
          rs2 <= 5'd10; // Debug instructions have an implicit r2 = a0
        end
      end
      OP_STYPE: begin
        imm[4:0] <= instr[11:7];
        funct3_stype <= instr[14:12];
        rs1 <= instr[19:15];
        rs2 <= instr[24:20];
        imm[10:5] <= instr[30:25];
        imm[31:11] <= {21{instr[31]}}; // Sign extension
      end
      OP_BTYPE: begin
        imm[0] <= 1'b0; // LSB is always 0
        imm[11] <= instr[7];
        imm[4:1] <= instr[11:8];
        funct3_btype <= instr[14:12];
        rs1 <= instr[19:15];
        rs2 <= instr[24:20];
        imm[10:5] <= instr[30:25];
        imm[31:12] <= {20{instr[31]}}; // Sign Extension
      end
      OP_LUI, OP_AUIPC: begin // U-Type
        rd <= instr[11:7];
        upimm[31:12] <= instr[31:12];
      end
      OP_JAL: begin
        rd <= instr[11:7];
        imm[0] <= 1'b0; // LSB is always 0
        imm[19:12] <= instr[19:12];
        imm[11] <= instr[20];
        imm[10:1] <= instr[30:21];
        imm[31:20] <= {12{instr[31]}}; // Sign extension
      end
      default: `PANIC("Unknown op_type");
    endcase
  end
end

endmodule
