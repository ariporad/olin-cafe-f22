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

always_ff @(posedge clk) begin
  if (rst) begin
    mem_wr_ena <= 0;
    mem_addr <= 0;
    mem_wr_data <= 0;
  end else begin
    case (state)
      default: begin
        mem_wr_ena <= 0;
      end
    endcase
  end
end

/***************************************************************************************************
 * Program Counter
 **************************************************************************************************/
output wire [31:0] PC;
wire [31:0] PC_old;
logic PC_ena; //always_comb PC_ena = (state == S_FETCH);

// Program Counter Registers
register #(.N(32), .RESET(PC_START_ADDRESS)) PC_REGISTER (
  .clk(clk), .rst(rst), .ena(PC_ena), .d(alu_result), .q(PC)
);
register #(.N(32)) PC_OLD_REGISTER(
  .clk(clk), .rst(rst), .ena(PC_ena), .d(PC), .q(PC_old)
);

always_comb begin
  PC_ena = (state == S_FETCH);
end

/***************************************************************************************************
 * Register File
 **************************************************************************************************/
logic rd_ena;
logic [4:0] rd, rs1, rs2;
logic [31:0] rd_data;
wire [31:0] rs1_data, rs2_data;
register_file REGISTER_FILE(
  .clk(clk), 
  .wr_ena(rd_ena), .wr_addr(rd), .wr_data(rd_data),
  .rd_addr0(rs1), .rd_addr1(rs2),
  .rd_data0(rs1_data), .rd_data1(rs2_data)
);

always_ff @(posedge clk) begin
  if (rst) begin
    rd <= 0;
    rs1 <= 0;
    rs2 <= 0;
    rd_data <= 0;
    rd_ena <= 0;
  end else if (state == S_EXECUTE) begin
    case (op_type)
      OP_RTYPE, OP_ITYPE, OP_AUIPC, OP_LUI: rd_ena <= 1;
      default: rd_ena <= 0;
    endcase
  end
end

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

always_ff @(posedge clk) if (rst) begin
  alu_src_a <= 0;
  alu_src_b <= 0;
  alu_control <= ALU_ADD;
end

/***************************************************************************************************
 * Instruction Register
 **************************************************************************************************/
logic IR_ena; always_comb IR_ena = (state == S_FETCH);
wire [31:0] IR;

register #(.N(32)) IR_REGISTER(
  .clk(clk), .rst(rst), .ena(IR_ena), .d(mem_rd_data), .q(IR)
);


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
  S_EXECUTE = 2,
  S_ERROR = 4'b1111
} state, next_state;

always_ff @(posedge clk) begin
  if (rst) begin
    state <= S_FETCH;
  end else begin
    if (panic) begin
      state <= S_ERROR;
    end else begin
      state <= next_state;
    end
  end
end

always_comb begin : find_next_state
  case (state) 
    S_FETCH:   next_state = S_DECODE;
    S_DECODE:  next_state = S_EXECUTE;
    S_EXECUTE: next_state = S_FETCH;

    default: next_state = S_ERROR;
  endcase
end

/***************************************************************************************************
 * S_FETCH
 **************************************************************************************************/

// Memory: mem_addr, mem_wr_data, mem_rd_data, mem_wr_ena;
// Registers: rd (write addr), rs1 (read addr 1), rs2 (read addr 2), rd_data, rs1_data, rs2_data
// IR: IR_ena, IR
// ALU: alu_src_a, alu_src_b, alu_control, alu_result, alu_overflow, alu_zero, alu_equal

always_comb begin : fetch
  if (state == S_FETCH) begin
    // Load instruction from memory
    mem_addr = PC;

    // Increment PC
    alu_src_a = PC;
    alu_src_b = 32'd4;
    alu_control = ALU_ADD;
  end
end


/***************************************************************************************************
 * S_DECODE
 **************************************************************************************************/

op_type_t op_type; // OP Type, populated during S_DECODE
op_type_t decoded_op_type; // OP Type, comb, private

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
  endcase
end

funct3_load_t funct3_load;
funct3_ritype_t funct3_ritype;
funct3_btype_t funct3_btype;

logic [6:0] funct7;

logic [31:0] imm; // sign-extended
logic [4:0] uimm; always_comb uimm = imm[4:0]; // unsigned
logic [31:0] upimm; always_comb upimm[11:0] = 12'b0;

always_ff @(posedge clk) begin : register_parsing
  if (state == S_DECODE) begin
    op_type <= decoded_op_type;
    case (decoded_op_type)
      OP_RTYPE: begin
        rd <= IR[11:7];
        funct3_ritype <= IR[14:12];
        rs1 <= IR[19:15];
        rs2 <= IR[24:20];
        funct7 <= IR[31:25];
      end
      OP_ITYPE: begin
        rd <= IR[11:7];
        funct3_ritype <= IR[14:12];
        rs1 <= IR[19:15];
        imm[10:0] <= IR[30:20];
        imm[31:11] <= IR[31]; // sign extension
      end
      OP_STYPE: begin
        imm[4:0] <= IR[11:7];
        // funct3_stype <= IR[14:12]; // seemingly unused?
        rs1 <= IR[19:15];
        rs2 <= IR[24:20];
        imm[10:5] <= IR[30:25];
        imm[31:11] <= IR[31]; // sign extension
      end
      OP_BTYPE: begin
        imm[0] <= 1'b0; // LSB is always 0
        imm[11] <= IR[7];
        imm[4:1] <= IR[11:8];
        funct3_btype <= IR[14:12];
        rs1 <= IR[19:15];
        rs2 <= IR[24:20];
        imm[10:5] <= IR[30:25];
        imm[31:12] <= IR[31]; // Sign Extension
      end
      OP_LUI, OP_AUIPC: begin // U-Type
        rd <= IR[11:7];
        upimm[31:12] <= IR[31:12];
      end
      OP_JAL, OP_JALR: begin
        rd <= IR[11:7];
        imm[0] <= 1'b0; // LSB is always 0
        imm[19:12] <= IR[19:12];
        imm[11] <= IR[20];
        imm[10:1] <= IR[30:21];
        imm[31:20] <= IR[31]; // Sign extension
      end
    endcase
  end
end

/***************************************************************************************************
 * S_EXECUTE
 **************************************************************************************************/

// I-Type //////////////////////////////////////////////////////////////////////////////////////////

// is_itype, only valid if you already know it's an R or I type.
logic _is_rtype; always_comb _is_rtype = op_type[6];

always_comb if (state == S_EXECUTE) begin
  case (op_type)
    OP_ITYPE, OP_RTYPE: begin
      case (funct3_ritype)
        FUNCT3_ADD: begin
          alu_src_a = rs1_data;
          alu_src_b = (_is_rtype) ? rs2_data : imm;
          if (_is_rtype & funct7[5]) begin
            alu_control = ALU_SUB;
          end else begin
            alu_control = ALU_ADD;
          end
          rd_data = alu_result;
        end
        default: panic = 1;
      endcase
    end
    default: panic = 1;
  endcase
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