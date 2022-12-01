`timescale 1ns/1ps
`default_nettype none

`include "alu_types.sv"
`include "rv32i_defines.sv"

module rv32i_multicycle_core(
  clk, rst, ena,
  mem_addr, mem_rd_data, mem_wr_data, mem_wr_ena,
  PC,
  instructions_completed
);

/**

Thoughts on timing:
- Registers only change on positive clock edge
- Each state should be present for one clock cycle (maybe more in the future)
- When a clock cycle begins, a new state gets stored in the state register
- Therefore, during a given state's clock cycle, all the CL runs to do the work
- At the end of a state's clock cycle, all the results from the CL gets copied into registers

Therefore:
- In an always_ff block, `state` refers to the state that just finished (?)
- So an always_ff block should store things that the CL calculated.
- ENAs need to be combinational
*/

parameter PC_START_ADDRESS=0;

/***************************************************************************************************
 * Standard control signals.
 **************************************************************************************************/
input  wire clk, rst, ena; // <- worry about implementing the ena signal last.
output logic instructions_completed;

/***************************************************************************************************
 * Memory Interface
 **************************************************************************************************/
output logic [31:0] mem_addr, mem_wr_data;
input   wire [31:0] mem_rd_data;
output logic mem_wr_ena;

always_comb begin : mem_logic
  if (rst) begin
    mem_wr_ena = 0;
    mem_addr = 0;
    mem_wr_data = 0;
  end else begin
    case (state)
      S_FETCH: begin
        mem_wr_ena = 0;
        mem_addr = PC;
      end
      default: mem_wr_ena = 0;
    endcase
  end
end

/***************************************************************************************************
 * Program Counter
 **************************************************************************************************/
output logic [31:0] PC;
logic [31:0] PC_old;

always_ff @(posedge clk) begin: PC_logic
  if (rst) begin
    PC <= PC_START_ADDRESS;
    PC_old <= 0;
  end else case (state)
    S_FETCH: begin
      PC_old <= PC;
      PC <= alu_result;
    end
    S_EXECUTE: begin
      case (op_type)
        OP_JAL, OP_JALR: PC <= alu_result;
        // default: PC remains unchanged
      endcase
    end
    S_BRANCH_JUMP: PC <= alu_result;
  endcase
end

/***************************************************************************************************
 * Instruction Register
 **************************************************************************************************/
logic [31:0] IR;

always_ff @(posedge clk) begin
  if (rst) begin
    IR <= 0;
  end else case (state)
    S_FETCH: IR <= mem_rd_data;
    // default: IR remains unchanged
  endcase
end

/***************************************************************************************************
 * Register File
 **************************************************************************************************/
logic rd_ena;
logic [31:0] rd_data;
wire [31:0] rs1_data, rs2_data;
register_file REGISTER_FILE(
  .clk(clk), 
  .wr_ena(rd_ena), .wr_addr(rd), .wr_data(rd_data),
  .rd_addr0(rs1), .rd_addr1(rs2),
  .rd_data0(rs1_data), .rd_data1(rs2_data)
);

always_comb begin : rd_write_control
  if (rst) begin
    rd_ena = 0;
    rd_data = 0;
  end else case (state)
    S_EXECUTE: begin
      case (op_type)
        OP_ITYPE, OP_RTYPE: begin
          rd_ena = 1;
          rd_data = alu_result;
        end
        OP_JAL, OP_JALR: begin
          rd_ena = 1;
          rd_data = PC; // already incremented by 4
        end
      endcase
    end
    default: rd_ena = 0;
  endcase
end

/***************************************************************************************************
 * Decoder
 **************************************************************************************************/

op_type_t op_type;
wire [4:0] rd, rs1, rs2;

funct3_ltype_t funct3_ltype;
funct3_ritype_t funct3_ritype;
funct3_btype_t funct3_btype;

wire [6:0] funct7;

wire [31:0] imm, upimm;
wire [4:0] uimm;

instruction_decoder INSTRUCTION_DECODER(
  .ena(state == S_DECODE),
  .clk(clk), .rst(rst), .IR(IR),
  .op_type(op_type), .rd(rd), .rs1(rs1), .rs2(rs2),
  .imm(imm), .uimm(uimm), .upimm(upimm),
  .funct3_ltype(funct3_ltype), .funct3_ritype(funct3_ritype), .funct3_btype(funct3_btype),
  .funct7(funct7)
);

/***************************************************************************************************
 * ALU and related controls
 * Feel free to replace with your ALU from the homework
 **************************************************************************************************/
logic [31:0] alu_src_a, alu_src_b;
alu_control_t alu_control;
wire [31:0] alu_result;
wire alu_overflow, alu_zero, alu_equal;
alu_behavioural ALU (
  .a(alu_src_a), .b(alu_src_b), .result(alu_result),
  .control(alu_control),
  .overflow(alu_overflow), .zero(alu_zero), .equal(alu_equal)
);

alu_control_t ri_type_alu_control;

always_comb begin : ri_alu_control_logic
  FUNCT3_ADD: begin
    if (op_type == OP_RTYPE & funct7[5]) begin
      alu_control = ALU_SUB;
    end else begin
      alu_control = ALU_ADD;
    end
  end
  FUNCT3_SLL:  ri_type_alu_control = ALU_SLL;
  FUNCT3_SLT:  ri_type_alu_control = ALU_SLT;
  FUNCT3_SLTU: ri_type_alu_control = ALU_SLTU;
  FUNCT3_XOR:  ri_type_alu_control = ALU_XOR;
  FUNCT3_OR:   ri_type_alu_control = ALU_OR;
  FUNCT3_AND:  ri_type_alu_control = ALU_AND;
  FUNCT3_SHIFT_RIGHT: ri_type_alu_control = (funct7[5]) ? ALU_SRA : ALU_SRL;
  default: panic = 1;
end

always_comb begin : alu_logic
  if (rst) begin
    alu_src_a = 0;
    alu_src_b = 0;
    alu_control = ALU_ADD;
  end else case (state)
    S_FETCH: begin
      alu_src_a = PC;
      alu_src_b = 32'd4;
      alu_control = ALU_ADD;
    end
    S_EXECUTE: begin
      case (op_type)
        OP_ITYPE: begin
          alu_control = ri_type_alu_control;
          alu_src_a = rs1_data;
          case (funct3_ritype)
            FUNCT3_SLL, FUNCT3_SHIFT_RIGHT: alu_src_b = uimm;
            default: alu_src_b = imm;
          endcase
        end
        OP_RTYPE: begin
          alu_control = ri_type_alu_control;
          alu_src_a = rs1_data;
          alu_src_b = rs2_data;
        end
        OP_JAL, OP_JALR: begin
          alu_src_a = imm;
          alu_src_b = (op_type == OP_JALR) ? rs1_data : PC_old;
          alu_control = ALU_ADD;
        end
        OP_BTYPE: case (funct3_btype)
          FUNCT3_BNE, FUNCT3_BEQ: begin
            alu_src_a = rs1_data;
            alu_src_b = rs2_data;
            alu_control = ALU_ADD; // doesn't matter
          end
        endcase
      endcase
    end
    S_BRANCH_JUMP: begin
      alu_src_a = imm;
      alu_src_b = PC_old;
      alu_control = ALU_ADD;
    end
    default: begin
      alu_src_a = 0;
      alu_src_b = 0;
      alu_control = ALU_ADD;
    end
  endcase
end

/***************************************************************************************************
 * CPU State
 **************************************************************************************************/
logic panic;

always_ff @(posedge clk) if (rst) begin
  panic <= 0;
end

enum logic [3:0] {
  S_FETCH  = 0,
  S_DECODE = 1,
  // NOTE: all instruction types must start on S_EXECUTE, since at the time we're picking the next
  // state S_DECODE hasn't finished yet. This should probably be fixed, but isn't a big blocker.
  S_EXECUTE = 2,
  S_BRANCH_JUMP = 3,
  S_LOAD = 4,
  S_ERROR = 15
} state;

always_ff @(posedge clk) begin
  if (rst) begin
    state <= S_FETCH;
  end else if (panic) begin
    state <= S_ERROR;
  end else case (state)
    S_FETCH:   state <= S_DECODE;
    S_DECODE:  state <= S_EXECUTE;
    S_EXECUTE: begin
      case (op_type)
        OP_ITYPE, OP_RTYPE, OP_JAL, OP_JALR: state <= S_FETCH;
        OP_BTYPE: state <= (should_branch) ? S_BRANCH_JUMP : S_FETCH;
        default: state <= S_ERROR;
      endcase
    end
    S_BRANCH_JUMP: state <= S_FETCH;
    default: state <= S_ERROR;
  endcase
end

/***************************************************************************************************
 * Branching & Comparisons
 **************************************************************************************************/

logic should_branch;

always_comb begin : branch_logic
  if (rst) begin
    should_branch = 0;
  end else if ((state == S_EXECUTE) & (op_type == OP_BTYPE)) begin
    case (funct3_btype)
      FUNCT3_BNE: should_branch = ~alu_equal;
      FUNCT3_BEQ: should_branch = alu_equal;
    endcase
  end else begin
    should_branch = 0;
  end
end

endmodule

//  an example of how to make named inputs for a mux:
/*
    enum logic {MEM_SRC_PC, MEM_SRC_RESULT} mem_src;
    always_comb begin : memory_read_address_mux
      case(mem_src)
        MEM_SRC_RESULT : mem_rd_addr = alu_result;
        MEM_SRC_PC : mem_rd_addr = PC;
        default: mem_rd_addr = 0;
    end
*/