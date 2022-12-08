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
/***************************************************************************************************
 * Standard Control Signals
 **************************************************************************************************/

parameter PC_START_ADDRESS=0;

input   wire clk, rst, ena;
output logic instructions_completed; assign instructions_completed = (state == S_HALT);


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
      S_LOAD: begin
        mem_wr_ena = 0;
        mem_addr = load_store_address;
      end
      S_STORE: begin
        mem_wr_ena = 1;
        mem_addr = load_store_address;
        case (funct3_stype)
          FUNCT3_STORE_SW: mem_wr_data = rs2_data;
          default: `PANIC("Unsupported funct3_stype");
        endcase
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
  end else if (ena) case (state)
    S_FETCH: begin
      PC_old <= PC;
      PC <= alu_result;
    end
    S_EXECUTE: begin
      case (op_type)
        OP_JAL, OP_JALR: PC <= alu_result;
        OP_AUIPC: PC <= alu_result;
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
  end else if (ena) case (state)
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
  .clk(clk), .rst(rst),
  .wr_ena(rd_ena), .wr_addr(rd), .wr_data(rd_data),
  .rd_addr0(rs1), .rd_addr1(rs2),
  .rd_data0(rs1_data), .rd_data1(rs2_data)
);

always_comb begin : register_write_control
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
        OP_LUI: begin
          rd_ena = 1;
          rd_data = upimm;
        end
        default: begin
          rd_ena = 0;
          rd_data = 0;
        end
      endcase
    end
    S_LOAD: case (funct3_ltype)
      FUNCT3_LOAD_LW: begin
        rd_ena = 1;
        rd_data = mem_rd_data;
      end
      default: `PANIC("Unknown funct3_ltype");
    endcase
    default: begin
      rd_ena = 0;
      rd_data = 0;
    end
  endcase
end


/***************************************************************************************************
 * Instruction Decoder
 **************************************************************************************************/

op_type_t op_type;
wire [4:0] rd, rs1, rs2;

funct3_ritype_t funct3_ritype;
funct3_btype_t funct3_btype;
funct3_ltype_t funct3_ltype;
funct3_stype_t funct3_stype;
funct3_debug_t funct3_debug;

wire [6:0] funct7;

wire [31:0] imm, upimm;
wire [4:0] uimm;

instruction_decoder INSTRUCTION_DECODER(
  .ena(state == S_DECODE),
  .clk(clk), .rst(rst), .instr(IR),
  .op_type(op_type), .rd(rd), .rs1(rs1), .rs2(rs2),
  .imm(imm), .uimm(uimm), .upimm(upimm),
  .funct3_ritype(funct3_ritype), .funct3_btype(funct3_btype),
  .funct3_stype(funct3_stype), .funct3_ltype(funct3_ltype),
  .funct3_debug(funct3_debug), .funct7(funct7)
);


/***************************************************************************************************
 * ALU
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

// R-Types and I-Types use the same logic for the ALU control, so we calculate that here
alu_control_t ri_type_alu_control;
always_comb begin : ri_type_alu_control_logic
  if (rst) begin
    ri_type_alu_control = ALU_ADD;
  end else case (funct3_ritype)
    FUNCT3_ADD: begin
      // For some reason, verilog complains about not having an explicit cast if you use a ternary
      // here (but also won't accept an explicit cast)
      if (op_type == OP_RTYPE & funct7[5]) ri_type_alu_control = ALU_SUB;
      else ri_type_alu_control = ALU_ADD;
    end
    FUNCT3_SLL:  ri_type_alu_control = ALU_SLL;
    FUNCT3_SLT:  ri_type_alu_control = ALU_SLT;
    FUNCT3_SLTU: ri_type_alu_control = ALU_SLTU;
    FUNCT3_XOR:  ri_type_alu_control = ALU_XOR;
    FUNCT3_OR:   ri_type_alu_control = ALU_OR;
    FUNCT3_AND:  ri_type_alu_control = ALU_AND;
    FUNCT3_SHIFT_RIGHT: begin
      // See above, using a ternary isn't valid here for some reason
      if (funct7[5]) ri_type_alu_control = ALU_SRA;
      else ri_type_alu_control = ALU_SRL;
    end
    // For some reason this always triggers at t = 0, so we can't panic
    // default: `PANIC("Unknown funct3_ritype");
  endcase
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
          FUNCT3_BLT: begin
            alu_src_a = rs1_data;
            alu_src_b = rs2_data;
            alu_control = ALU_SLT;
          end
          FUNCT3_BLTU: begin
            alu_src_a = rs1_data;
            alu_src_b = rs2_data;
            alu_control = ALU_SLTU;
          end
          FUNCT3_BGE: begin
            alu_src_a = rs2_data;
            alu_src_b = rs1_data;
            alu_control = ALU_SLT;
          end
          FUNCT3_BGEU: begin
            alu_src_a = rs2_data;
            alu_src_b = rs1_data;
            alu_control = ALU_SLTU;
          end
          default: `PANIC("Unknown funct3_btype");
        endcase
        OP_LTYPE, OP_STYPE: begin
          alu_src_a = rs1_data;
          alu_src_b = imm;
          alu_control = ALU_ADD;
        end
        OP_AUIPC: begin
          alu_src_b = PC_old;
          alu_src_a = upimm;
          alu_control = ALU_ADD;
        end
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

enum logic [3:0] {
  // Fetch next instruction (at PC) from memory, put it in IR, and increment PC.
  // After this cycle, the address of the instruction in IR will be PC_old
  // Followed by: S_DECODE
  S_FETCH  = 0, 

  // Decode the fetched instruction (in IR).
  // Followed by: S_EXECUTE (nominal), S_HALT (if instruction was a halt)
  S_DECODE = 1,

  // First (and possibly only) execution step
  // For branches, this is when we figure out if we will branch
  // For loads/stores, this is when we calculate the target address
  // NOTE: all instruction types must start on S_EXECUTE, since at the time we're picking the next
  // state S_DECODE hasn't finished yet. This should probably be fixed, but isn't a big issue
  // Followed by: S_FETCH (default), S_BRANCH_JUMP (if successful branch), S_LOAD/S_STORE (for loads/stores)
  S_EXECUTE = 2, 

  // When branching, calculate branch target address and update PC
  // Followed by: S_FETCH
  S_BRANCH_JUMP = 3,

  // When loading, actually perform the memory access
  // Followed by: S_FETCH
  S_LOAD = 4,

  // When storing, actually perform the memory access
  // Followed by: S_FETCH
  // TODO: This could possibly be combined with S_LOAD, but it doesn't make much of a difference
  S_STORE = 5,

  // We transition to S_HALT when we recieve a halt instruction, which is usually when we reach the
  // end of the program. Disables all further computation. System must be reset to continue.
  // Followed by: S_HALT (we never leave)
  S_HALT = 14,

  // Indicates that the system has encountered a fatal error. We never leave this state.
  // Overlaps significantly with the `PANIC macro, and the two should probably be combined.
  S_ERROR = 15
} state;

always_ff @(posedge clk) begin
  if (rst) begin
    state <= S_FETCH;
  end else if (~ena) begin
    // Do nothing if disabled
  end else case (state)
    S_FETCH:   state <= S_DECODE;
    S_DECODE:  state <= S_EXECUTE;
    S_EXECUTE: begin
      case (op_type)
        OP_ITYPE, OP_RTYPE, OP_JAL, OP_JALR, OP_LUI, OP_AUIPC: state <= S_FETCH;
        OP_BTYPE: state <= (should_branch) ? S_BRANCH_JUMP : S_FETCH;
        OP_LTYPE: state <= S_LOAD;
        OP_STYPE: state <= S_STORE;
        OP_DEBUG: case (funct3_debug)
          FUNCT3_DEBUG_HALT: state <= S_HALT;
          default: `PANIC("Unknown funct3_debug!");
        endcase
        default: state <= S_ERROR;
      endcase
    end
    S_BRANCH_JUMP: state <= S_FETCH;
    S_LOAD: state <= S_FETCH;
    S_STORE: state <= S_FETCH;
    S_ERROR: state <= S_ERROR; // we never leave S_ERROR
    // This is a little different because we do synchronous things in simulation
    S_HALT: begin
      state <= S_HALT;   // never un-halt
      $display("Halting! Program Returned: %d", rs2_data);
      $finish;
    end
    default: state <= S_ERROR;
  endcase
end


/***************************************************************************************************
 * Branching & Comparisons
 **************************************************************************************************/

// Calculate if we should branch based on ALU output, depending on branch type
logic should_branch;
always_comb begin : branch_logic
  if (rst) begin
    should_branch = 0;
  end else if ((state == S_EXECUTE) & (op_type == OP_BTYPE)) begin
    case (funct3_btype)
      FUNCT3_BNE: should_branch = ~alu_equal;
      FUNCT3_BEQ: should_branch = alu_equal;
      FUNCT3_BLT: should_branch = alu_result[0];
      FUNCT3_BGE: should_branch = alu_result[0] | alu_equal;
      FUNCT3_BLTU: should_branch = alu_result[0];
      FUNCT3_BGEU: should_branch = alu_result[0] | alu_equal;
      default: `PANIC("Unknown branch type!");
    endcase
  end else begin
    should_branch = 0;
  end
end


/***************************************************************************************************
 * Store & Load
 **************************************************************************************************/

// Load/Store target address, non-architectural register used to store ALU result between S_EXECUTE
// and S_LOAD/S_STORE.
logic [31:0] load_store_address;
always_ff @(posedge clk) begin : load_store_address_logic
  if (rst) begin
    load_store_address <= 0;
  end else if (~ena) begin
    // Do nothing if ena is LOW
  end else if ((state == S_EXECUTE) & ((op_type == OP_LTYPE) | (op_type == OP_STYPE))) begin
    load_store_address <= alu_result;
  end else begin
    load_store_address <= 0;
  end
end

endmodule
