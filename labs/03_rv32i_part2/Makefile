####################################################################################################
# Configuration
####################################################################################################

### Verilog & Vivado ###
SHELL=/bin/bash
IVERILOG=iverilog -g2012 -Wall -Wno-sensitivity-entire-vector -Wno-sensitivity-entire-array -y./hdl -y./tests -Y.sv -I./hdl
VVP=vvp
VVP_POST=-fst
VIVADO=vivado -mode batch -source

### Sources #y##
RFILE_SRCS=hdl/register_file.sv hdl/register.sv hdl/decoder*.sv
ALU_SRCS=hdl/alu_behavioural.sv hdl/alu_types.sv
PERIPHERAL_SRCS=hdl/ili9341_display_peripheral.sv hdl/ili9341_defines.sv hdl/spi_controller.sv hdl/spi_types.sv hdl/pwm.sv hdl/pulse_generator.sv
MMU_SRCS=hdl/mmu.sv hdl/block_ram.sv hdl/block_rom.sv hdl/memmap.sv hdl/distributed_ram.sv hdl/dual_port_distributed_ram.sv ${PERIPHERAL_SRCS}
RV32I_SRCS=${RFILE_SRCS} ${ALU_SRCS} ${MMU_SRCS} hdl/rv32i_defines.sv hdl/rv32i_multicycle_core.sv hdl/rv32i_system.sv
ASSEMBLER_SRCS=assembler/*.py

### Execution ###
ARGV = 0 # argument to the CPU's program

MAX_CYCLES = 100_000 # prevent infinite loops
test_rv32i_peripherals: MAX_CYCLES = 1_500_000 # Need extra cycles for perpherals


.PHONY: clean submission remove_solutions waves_rv32i_system analyze_rv32i_system

####################################################################################################
# Compile C -> asm -> memh
####################################################################################################

### Compile asm -> memh ###

# Need a separate rule for assembly files generated by GCC, since they need special handling
asm/compiled/%.memh : asm/compiled/%.s ${ASSEMBLER_SRCS}
	python3 ./assembler --gcc $< -o $@

%.memh : %.s ${ASSEMBLER_SRCS}
	python3 ./assembler $< -o $@

### Compile C -> asm ###

asm/compiled/%.s : csrc/%.c riscv_gcc_docker.sh
	./riscv_gcc_docker.sh -march=rv32i -mabi=ilp32 -S -o ./asm/compiled/$*.s ./csrc/$*.c


####################################################################################################
# Run the CPU 
####################################################################################################

# For compiled assembly
test_rv32i_c_%: tests/test_rv32i_system.sv asm/compiled/%.memh ${RV32I_SRCS}
	${IVERILOG} \
		-DINITIAL_INST_MEM=\"asm/compiled/$*.memh\" \
		-DARGV="$(ARGV)" \
		-DMAX_CYCLES="$(MAX_CYCLES)" \
		-s test_rv32i_system \
		-o test_rv32i_system.bin \
		tests/test_rv32i_system.sv ${RV32I_SRCS} && \
	${VVP} test_rv32i_system.bin ${VVP_POST}

# For manually-written assembly programs
test_rv32i_%: tests/test_rv32i_system.sv asm/%.memh ${RV32I_SRCS}
	${IVERILOG} \
		-DINITIAL_INST_MEM=\"asm/$*.memh\" \
		-DARGV="$(ARGV)" \
		-DMAX_CYCLES="$(MAX_CYCLES)" \
		-s test_rv32i_system \
		-o test_rv32i_system.bin \
		tests/test_rv32i_system.sv ${RV32I_SRCS} && \
	${VVP} test_rv32i_system.bin ${VVP_POST}

# Run GTKWave
waves_rv32i_%: test_rv32i_%
	gtkwave rv32i_system.fst -a tests/rv32i_system.gtkw

# Legacy aliases
test_rv32i_ri_types: test_rv32i_ritypes
	echo "make test_rv32i_ri_types is depricated, please use make test_rv32i_ritypes instead."
test_rv32i_ls_types: test_rv32i_lstypes
	echo "make test_rv32i_ls_types is depricated, please use make test_rv32i_lstypes instead."


####################################################################################################
# Vivado 
####################################################################################################

rv32i_system.bit: ${RV32I_SRCS} build.tcl asm/peripherals.memh
	@echo "########################################"
	@echo "#### Building FPGA bitstream        ####"
	@echo "########################################"
	${VIVADO} build.tcl

analyze_rv32i_system: ${RV32I_SRCS} analysis.tcl asm/peripherals.memh
	${VIVADO} analysis.tcl

program_fpga_vivado: rv32i_system.bit build.tcl program.tcl
	@echo "########################################"
	@echo "#### Programming FPGA (Vivado)      ####"
	@echo "########################################"
	${VIVADO} program.tcl

program_fpga_digilent: rv32i_system.bit build.tcl
	@echo "########################################"
	@echo "#### Programming FPGA (Digilent)    ####"
	@echo "########################################"
	djtgcfg enum
	djtgcfg prog -d CmodA7 -i 0 -f rv32i_system.bit


####################################################################################################
# Linting & Housekeeping
####################################################################################################

lint_all: hdl/*.sv
	verilator --lint-only -DSIMULATION -I./hdl -I./tests $^

# Call this to clean up all your generated files
clean:
	rm -f *.bin *.vcd *.fst vivado*.log *.jou vivado*.str *.log *.checkpoint *.bit *.html *.xml *.out
	rm -rf .Xil
	rm -rf __pycache__
	rm -f asm/*.memh

# Call this to generate your submission zip file.
submission:
	zip submission.zip Makefile asm/*.s hdl/*.sv README.md docs/*.md docs/**/* *.tcl *.xdc tests/*.sv tests/gtkwave_filters/*.txt *.pdf assembler/*.py csrc/*.c 


####################################################################################################
# Other
####################################################################################################

# Not sure what these are. Are they safe to delete?

test_register_file: tests/test_register_file.sv ${RFILE_SRCS}
	${IVERILOG} -o test_register_file.bin $^ && ${VVP} test_register_file.bin ${VVP_POST}

waves_rv32i_system:
	gtkwave rv32i_system.fst -a tests/rv32i_system.gtkw
