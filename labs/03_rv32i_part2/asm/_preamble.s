PREAMBLE: # This is the only thing added from CE
        # Set 4 high bits of sp to 0b0011 (bottom of data memory)
        li sp, 3
        slli sp, sp, 16
        # Now make sp actually start at the top of the data memory (1024 words * 4 bytes):
        addi sp, sp, 1
        slli sp, sp, 12
        call main
        halt