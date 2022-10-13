# -Wall turns on all warnings
# -g2012 selects the 2012 version of iVerilog
IVERILOG=iverilog -g2012 -Wall -y ./ -I ./
VVP=vvp
VVP_POST=-fst

# On MacOS, we need to use a different GTKWave incantation. I've set this up in my .zshrc, but for
# some reason I don't think make is detecting it.
GTKWAVE=gtkwave
UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
	GTKWAVE=/Applications/gtkwave.app/Contents/Resources/bin/gtkwave
endif

# VIVADO=vivado -mode batch -source

# Look up .PHONY rules for Makefiles
.PHONY: clean submission test

%_test : %.sv %.test.sv
	${IVERILOG} -o $*_test.bin $^ && ${VVP} $*_test.bin ${VVP_POST}
%_waves : %_test
	${GTKWAVE} $*.test.sv.fst -a $*.gtkw

# Call this to clean up all your generated files
clean:
	rm -f *.bin *.vcd *.fst vivado*.log *.jou vivado*.str *.log *.checkpoint *.bit *.html *.xml submission.zip
	rm -rf .Xil

# Call this to generate your submission zip file.
submission:
	zip submission.zip Makefile *.sv README.md *.pdf
