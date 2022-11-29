`timescale 1ns/1ps
`default_nettype none

`include "alu_types.sv"
`include "rv32i_defines.sv"

module rv32i_multicycle_core(
  clk, rst, ena,
  mem_addr, mem_rd_data, mem_wr_data, mem_wr_ena,
  PC
);

parameter PC_START_ADDRESS=0;

/***************************************************************************************************
 * Standard control signals.
 **************************************************************************************************/
input  wire clk, rst, ena; // <- worry about implementing the ena signal last.

/***************************************************************************************************
 * Memory Interface
 **************************************************************************************************/
output logic [31:0] mem_addr, mem_wr_data;
input   wire [31:0] mem_rd_data;
output logic mem_wr_ena;

/***************************************************************************************************
 * Program Counter
 **************************************************************************************************/
output wire [31:0] PC;
wire [31:0] PC_old;
logic PC_ena;
logic [31:0] PC_next; 

// Program Counter Registers
register #(.N(32), .RESET(PC_START_ADDRESS)) PC_REGISTER (
  .clk(clk), .rst(rst), .ena(PC_ena), .d(PC_next), .q(PC)
);
register #(.N(32)) PC_OLD_REGISTER(
  .clk(clk), .rst(rst), .ena(PC_ena), .d(PC), .q(PC_old)
);

/***************************************************************************************************
 * Register File
 **************************************************************************************************/
logic reg_write;
logic [4:0] rd, rs1, rs2;
logic [31:0] rfile_wr_data;
wire [31:0] reg_data1, reg_data2;
register_file REGISTER_FILE(
  .clk(clk), 
  .wr_ena(reg_write), .wr_addr(rd), .wr_data(rfile_wr_data),
  .rd_addr0(rs1), .rd_addr1(rs2),
  .rd_data0(reg_data1), .rd_data1(reg_data2)
);

/***************************************************************************************************
 * ALU and related controls
 * Feel free to replace with your ALU from the homework
 **************************************************************************************************/
logic [31:0] src_a, src_b;
alu_control_t alu_control;
wire [31:0] alu_result;
wire overflow, zero, equal;
alu_behavioural ALU (
  .a(src_a), .b(src_b), .result(alu_result),
  .control(alu_control),
  .overflow(overflow), .zero(zero), .equal(equal)
);

/***************************************************************************************************
 * Instruction Register
 **************************************************************************************************/
logic ir_ena;
logic [31:0] next_ir;
wire [31:0] ir;

register #(.N(32)) IR_REGISTER(
  .clk(clk), .rst(rst), .ena(ir_ena), .d(next_ir), .q(ir)
);

/***************************************************************************************************
 * CPU State
 **************************************************************************************************/
enum logic [2:0] {
  S_FETCH  = 0,
  S_DECODE = 1,
  S_TODO = 3'b111
} state;

always_ff @(posedge clk) begin : state_transition
  case (state)
    S_FETCH: state <= S_DECODE;
    S_DECODE: state <= S_TODO;
    S_TODO: state <= S_TODO;
  endcase
end

/***************************************************************************************************
 * S_FETCH
 **************************************************************************************************/

// Memory: mem_addr, mem_wr_data, mem_rd_data, mem_wr_ena;
// Registers: rd (write addr), rs1 (read addr 1), rs2 (read addr 2), rfile_wr_data, reg_data1, reg_data2
// IR: ir_ena, next_ir, ir
// ALU: src_a, src_b, alu_control, alu_result, overflow, zero, equal

always_ff @(posedge clk) begin : fetch
  if (state == S_FETCH) begin
    // Load instruction from memory
    mem_wr_ena <= 0;
    mem_addr <= PC;
    next_ir <= mem_rd_data;
    ir_ena <= 1;

    // Increment PC
    src_a <= PC;
    src_b <= 32'b1;
    alu_control <= ALU_ADD;
    PC_next <= alu_result;

    // Transition
    state <= S_DECODE;
  end
end


/***************************************************************************************************
 * S_DECODE
 **************************************************************************************************/

op_type_t op_type; always_comb op_type = ir[6:0];

funct3_load_t funct3_load;
funct3_ritype_t funct3_ritype;
funct3_btype_t funct3_btype;

logic [6:0] funct7_rtype;

// TODO: Combine some of these for efficiency
logic [11:0] imm_itype;
logic [11:0] imm_stype;
logic [12:0] imm_btype; always_comb imm_btype[0] = 1'b0;
logic [31:0] imm_utype; always_comb imm_utype[11:0] = 12'b0;
logic [31:0] imm_jtype; always_comb imm_btype[0] = 1'b0;

always_ff @(posedge clk) begin : register_parsing
  if (state == S_DECODE) begin
    case (op_type)
      OP_RTYPE: begin
        rd <= ir[11:7];
        funct3_ritype <= ir[14:12];
        rs1 <= ir[19:15];
        rs2 <= ir[24:20];
        funct7 <= ir[31:25];
      end
      OP_ITYPE: begin
        rd <= ir[11:7];
        funct3_ritype <= ir[14:12];
        rs1 <= ir[19:15];
        imm_itype <= ir[31:20];
      end
      OP_STYPE: begin
        imm_stype[4:0] <= ir[11:7];
        // funct3_stype <= ir[14:12]; // seemingly unused?
        rs1 <= ir[19:15];
        rs2 <= ir[24:20];
        imm_stype[11:5] <= ir[31:25];
      end
      OP_BTYPE: begin
        imm_btype[11] <= ir[7];
        imm_btype[4:1] <= ir[11:8];
        funct3_btype <= ir[14:12];
        rs1 <= ir[19:15];
        rs2 <= ir[24:20];
        imm_btype[10:5] <= ir[30:25];
        imm_btype[31:12] <= ir[31]; // Sign Extension
      end
      OP_UTYPE: begin
        rd <= ir[11:7];
        imm_utype[31:12] <= ir[31:12];
      end
      OP_JTYPE: begin
        rd <= ir[11:7];
        imm_jtype[31:20] <= ir[31]; // Sign extension
        imm_jtype[10:1] <= ir[30:21];
        imm_jtype[11] <= ir[20];
        imm_jtype[19:12] <= ir[19:12];
      end
    endcase
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