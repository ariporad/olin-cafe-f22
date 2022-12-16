PREAMBLE:
	# This will always be the first instruction, so it's where execution will begin

	# First, we need to initialize the stack pointer
	# Our MMU uses the highest 4 bits of the address to differentiate memory banks (see memmap.sv),
	# so data memory addresses look like:
	# 	0b0011xxxxxxxxxxxxxxxxxxxxxxxxxxxx
	# The first one is:
	# 	0b00110000000000000000000000000000
	#
	# However, we need our stack pointer to start at the *top* of data memory, so the stack can grow
	# downwards (and the heap grows upwards). We have 1024 words of data memory (again, see
	# memmap.sv), and a word is 32-bits long, or 4 bytes, so we have 4096 bytes of data memory total.
	# Note that our memory is byte-addressable.
	#
	# This gives us the following for the top of data memory (and therefore the starting value of
	# our stack pointer):
	# 	0b00110000000000000001000000000000
	#

	li sp, 0b00110000000000000001000000000000

	# Now we can call main
	# By using a proper call (pseudo-)instruction, ra will be set so main can return like normal
    call main

	# When main returns, we'll jump back here and halt the CPU
    halt