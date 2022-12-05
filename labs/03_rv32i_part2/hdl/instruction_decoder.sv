`timescale 1ns/1ps
`default_nettype none

`ifndef PANIC
  `ifdef SIMULATION
    `define PANIC $error
  `else
    `define PANIC
  `endif // SIMULATION
`endif // `PANIC

module instruction_decoder(
	clk, ena, rst, IR,
	op_type, rd, rs1, rs2, imm, uimm, upimm, funct7,
	funct3_ltype, funct3_ritype, funct3_btype, funct3_stype, funct3_debug
);
input wire clk, ena, rst;
input wire [31:0] IR;

output op_type_t op_type;
op_type_t decoded_op_type; // OP Type, comb, private

output logic halt;

output logic [4:0] rd, rs1, rs2;

output logic [31:0] imm; // sign-extended
output logic [4:0] uimm; always_comb uimm = imm[4:0]; // unsigned
output logic [31:0] upimm; always_comb upimm[11:0] = 12'b0;

output funct3_ltype_t funct3_ltype;
output funct3_ritype_t funct3_ritype;
output funct3_btype_t funct3_btype;
output funct3_stype_t funct3_stype;
output funct3_debug_t funct3_debug;

output logic [6:0] funct7;

always_comb begin : for_some_reason_you_cant_assign_a_value_to_an_enum
  // For some reason iverilog didn't like this:
  // decoded_op_type = IR[6:0]
  // So we have this stupid thing instead
  // TODO: Get help with this
  case (IR[6:0])
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


always_ff @(posedge clk) begin : register_parsing
  if (rst) begin
    op_type <= 0;
    halt <= 0;
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
        rd <= IR[11:7];
        funct3_ritype <= IR[14:12];
        rs1 <= IR[19:15];
        rs2 <= IR[24:20];
        funct7 <= IR[31:25];
      end
      OP_ITYPE, OP_LTYPE, OP_JALR, OP_DEBUG: begin
        rd <= IR[11:7];
        // L-Type and I-Type are the same, just with different enums for funct3
        case (decoded_op_type)
          OP_ITYPE: funct3_ritype <= IR[14:12];
          OP_LTYPE: funct3_ltype <= IR[14:12];
          OP_DEBUG: funct3_debug <= IR[14:12];
          // OP_JALR has no funct3
        endcase
        rs1 <= IR[19:15];
        imm[10:0] <= IR[30:20];
        imm[31:11] <= {21{IR[31]}}; // Sign extension
        if (decoded_op_type == OP_DEBUG) begin
          rs2 <= 5'd10; // Debug instructions have an implicit r2 = a0
        end
      end
      OP_STYPE: begin
        imm[4:0] <= IR[11:7];
        funct3_stype <= IR[14:12];
        rs1 <= IR[19:15];
        rs2 <= IR[24:20];
        imm[10:5] <= IR[30:25];
        imm[31:11] <= {21{IR[31]}}; // Sign extension
      end
      OP_BTYPE: begin
        imm[0] <= 1'b0; // LSB is always 0
        imm[11] <= IR[7];
        imm[4:1] <= IR[11:8];
        funct3_btype <= IR[14:12];
        rs1 <= IR[19:15];
        rs2 <= IR[24:20];
        imm[10:5] <= IR[30:25];
        imm[31:12] <= {20{IR[31]}}; // Sign Extension
      end
      OP_LUI, OP_AUIPC: begin // U-Type
        rd <= IR[11:7];
        upimm[31:12] <= IR[31:12];
      end
      OP_JAL: begin
        rd <= IR[11:7];
        imm[0] <= 1'b0; // LSB is always 0
        imm[19:12] <= IR[19:12];
        imm[11] <= IR[20];
        imm[10:1] <= IR[30:21];
        imm[31:20] <= {12{IR[31]}}; // Sign extension
      end
      OP_DEBUG: begin
      end
      default: `PANIC("Unknown op_type");
    endcase
  end
end

endmodule
