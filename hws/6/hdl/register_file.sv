`default_nettype none
`timescale 1ns/1ps

module register_file(
  clk, //Note - intentionally does not have a reset! 
  wr_ena, wr_addr, wr_data,
  rd_addr0, rd_data0,
  rd_addr1, rd_data1
);
// Not parametrizing, these widths are defined by the RISC-V Spec!
input wire clk;

// Write channel
input wire wr_ena;
input wire [4:0] wr_addr;
input wire [31:0] wr_data;

// Two read channels
input wire [4:0] rd_addr0, rd_addr1;
output logic [31:0] rd_data0, rd_data1;

logic [31:0] x00; 
always_comb x00 = 32'd0; // ties x00 to ground. 

logic [31:0] wr_addr_internal;

// If writing is disabled, then set the wr_addr to 0x00. Since writes to 0x00 are ignored, it all
// works out (and saves a trivial number of gates).
always_comb wr_addr_internal = wr_ena ? wr_addr : 5'b0;

// DON'T DO THIS:
// logic [31:0] register_file_registers [31:0]
// CAN'T: because that's a RAM. Works in simulation, fails miserably in synthesis.

// Hint - use a scripting language if you get tired of copying and pasting the logic 32 times - e.g. python: print(",".join(["x%02d"%i for i in range(0,32)]))
wire [31:0] x01,x02,x03,x04,x05,x06,x07,x08,x09,x10,x11,x12,x13,x14,x15,x16,x17,x18,x19,x20,x21,x22,x23,x24,x25,x26,x27,x28,x29,x30,x31;

mux32 #(.N(32)) out0_mux(
  // >>> print(' '.join(f".in{i:02d}(x{i:02d})," for i in range(0, 32)))
  .in00(x00), .in01(x01), .in02(x02), .in03(x03), .in04(x04), .in05(x05), .in06(x06), .in07(x07),
  .in08(x08), .in09(x09), .in10(x10), .in11(x11), .in12(x12), .in13(x13), .in14(x14), .in15(x15),
  .in16(x16), .in17(x17), .in18(x18), .in19(x19), .in20(x20), .in21(x21), .in22(x22), .in23(x23),
  .in24(x24), .in25(x25), .in26(x26), .in27(x27), .in28(x28), .in29(x29), .in30(x30), .in31(x31),

  .select(rd_addr0),
  .out(rd_data0)
);

mux32 #(.N(32)) out1_mux(
  // >>> print(' '.join(f".in{i:02d}(x{i:02d})," for i in range(0, 32)))
  .in00(x00), .in01(x01), .in02(x02), .in03(x03), .in04(x04), .in05(x05), .in06(x06), .in07(x07),
  .in08(x08), .in09(x09), .in10(x10), .in11(x11), .in12(x12), .in13(x13), .in14(x14), .in15(x15),
  .in16(x16), .in17(x17), .in18(x18), .in19(x19), .in20(x20), .in21(x21), .in22(x22), .in23(x23),
  .in24(x24), .in25(x25), .in26(x26), .in27(x27), .in28(x28), .in29(x29), .in30(x30), .in31(x31),

  .select(rd_addr1),
  .out(rd_data1)
);

// >>> print("\n".join(f"register #(.N(32)) reg{i:02d}(.clk(clk), .ena(&(wr_addr ~^ 5'd{i:02d})), .rst(1'b0), .d(wr_data), .q(x{i:02d}));" for i in range(1, 32)))
register #(.N(32)) reg01(.clk(clk), .ena(&(wr_addr_internal ~^ 5'd01)), .rst(1'b0), .d(wr_data), .q(x01));
register #(.N(32)) reg02(.clk(clk), .ena(&(wr_addr_internal ~^ 5'd02)), .rst(1'b0), .d(wr_data), .q(x02));
register #(.N(32)) reg03(.clk(clk), .ena(&(wr_addr_internal ~^ 5'd03)), .rst(1'b0), .d(wr_data), .q(x03));
register #(.N(32)) reg04(.clk(clk), .ena(&(wr_addr_internal ~^ 5'd04)), .rst(1'b0), .d(wr_data), .q(x04));
register #(.N(32)) reg05(.clk(clk), .ena(&(wr_addr_internal ~^ 5'd05)), .rst(1'b0), .d(wr_data), .q(x05));
register #(.N(32)) reg06(.clk(clk), .ena(&(wr_addr_internal ~^ 5'd06)), .rst(1'b0), .d(wr_data), .q(x06));
register #(.N(32)) reg07(.clk(clk), .ena(&(wr_addr_internal ~^ 5'd07)), .rst(1'b0), .d(wr_data), .q(x07));
register #(.N(32)) reg08(.clk(clk), .ena(&(wr_addr_internal ~^ 5'd08)), .rst(1'b0), .d(wr_data), .q(x08));
register #(.N(32)) reg09(.clk(clk), .ena(&(wr_addr_internal ~^ 5'd09)), .rst(1'b0), .d(wr_data), .q(x09));
register #(.N(32)) reg10(.clk(clk), .ena(&(wr_addr_internal ~^ 5'd10)), .rst(1'b0), .d(wr_data), .q(x10));
register #(.N(32)) reg11(.clk(clk), .ena(&(wr_addr_internal ~^ 5'd11)), .rst(1'b0), .d(wr_data), .q(x11));
register #(.N(32)) reg12(.clk(clk), .ena(&(wr_addr_internal ~^ 5'd12)), .rst(1'b0), .d(wr_data), .q(x12));
register #(.N(32)) reg13(.clk(clk), .ena(&(wr_addr_internal ~^ 5'd13)), .rst(1'b0), .d(wr_data), .q(x13));
register #(.N(32)) reg14(.clk(clk), .ena(&(wr_addr_internal ~^ 5'd14)), .rst(1'b0), .d(wr_data), .q(x14));
register #(.N(32)) reg15(.clk(clk), .ena(&(wr_addr_internal ~^ 5'd15)), .rst(1'b0), .d(wr_data), .q(x15));
register #(.N(32)) reg16(.clk(clk), .ena(&(wr_addr_internal ~^ 5'd16)), .rst(1'b0), .d(wr_data), .q(x16));
register #(.N(32)) reg17(.clk(clk), .ena(&(wr_addr_internal ~^ 5'd17)), .rst(1'b0), .d(wr_data), .q(x17));
register #(.N(32)) reg18(.clk(clk), .ena(&(wr_addr_internal ~^ 5'd18)), .rst(1'b0), .d(wr_data), .q(x18));
register #(.N(32)) reg19(.clk(clk), .ena(&(wr_addr_internal ~^ 5'd19)), .rst(1'b0), .d(wr_data), .q(x19));
register #(.N(32)) reg20(.clk(clk), .ena(&(wr_addr_internal ~^ 5'd20)), .rst(1'b0), .d(wr_data), .q(x20));
register #(.N(32)) reg21(.clk(clk), .ena(&(wr_addr_internal ~^ 5'd21)), .rst(1'b0), .d(wr_data), .q(x21));
register #(.N(32)) reg22(.clk(clk), .ena(&(wr_addr_internal ~^ 5'd22)), .rst(1'b0), .d(wr_data), .q(x22));
register #(.N(32)) reg23(.clk(clk), .ena(&(wr_addr_internal ~^ 5'd23)), .rst(1'b0), .d(wr_data), .q(x23));
register #(.N(32)) reg24(.clk(clk), .ena(&(wr_addr_internal ~^ 5'd24)), .rst(1'b0), .d(wr_data), .q(x24));
register #(.N(32)) reg25(.clk(clk), .ena(&(wr_addr_internal ~^ 5'd25)), .rst(1'b0), .d(wr_data), .q(x25));
register #(.N(32)) reg26(.clk(clk), .ena(&(wr_addr_internal ~^ 5'd26)), .rst(1'b0), .d(wr_data), .q(x26));
register #(.N(32)) reg27(.clk(clk), .ena(&(wr_addr_internal ~^ 5'd27)), .rst(1'b0), .d(wr_data), .q(x27));
register #(.N(32)) reg28(.clk(clk), .ena(&(wr_addr_internal ~^ 5'd28)), .rst(1'b0), .d(wr_data), .q(x28));
register #(.N(32)) reg29(.clk(clk), .ena(&(wr_addr_internal ~^ 5'd29)), .rst(1'b0), .d(wr_data), .q(x29));
register #(.N(32)) reg30(.clk(clk), .ena(&(wr_addr_internal ~^ 5'd30)), .rst(1'b0), .d(wr_data), .q(x30));
register #(.N(32)) reg31(.clk(clk), .ena(&(wr_addr_internal ~^ 5'd31)), .rst(1'b0), .d(wr_data), .q(x31));

endmodule