# Generated from the following, on Compiler Explorer:
#
# int fibonacci(int n) {
#     if (n <= 0) return 0;
#     if (n == 1) return 1;
#     return fibonacci(n-1) + fibonacci(n-2);
# }
# 
# int main() {
#     return fibonacci(10);
# }

PREAMBLE: # This is the only thing added from CE
        # Set 4 high bits of sp to 0b0011 (bottom of data memory)
        li sp, 3
        slli sp, sp, 16
        # Now make sp actually start at the top of the data memory (1024 words * 4 bytes):
        addi sp, sp, 1
        slli sp, sp, 12
        call main
        halt

fibonacci(int):                          # @fibonacci(int)
        addi    sp, sp, -32
        sw      ra, 28(sp)                      # 4-byte Folded Spill
        sw      s0, 24(sp)                      # 4-byte Folded Spill
        addi    s0, sp, 32
        sw      a0, -16(s0)
        lw      a1, -16(s0)
        li      a0, 0
        blt     a0, a1, .gt_zero
        j       .ret_zero
.ret_zero:
        li      a0, 0
        sw      a0, -12(s0)
        j       .ret
.gt_zero:
        lw      a0, -16(s0)
        li      a1, 1
        bne     a0, a1, .gt_1
        j       .ret_1
.ret_1:
        li      a0, 1
        sw      a0, -12(s0)
        j       .ret
.gt_1:
        lw      a0, -16(s0)
        addi    a0, a0, -1
        call    fibonacci(int)
        sw      a0, -20(s0)                     # 4-byte Folded Spill
        lw      a0, -16(s0)
        addi    a0, a0, -2
        call    fibonacci(int)
        mv      a1, a0
        lw      a0, -20(s0)                     # 4-byte Folded Reload
        add     a0, a0, a1
        sw      a0, -12(s0)
        j       .ret
.ret:
        lw      a0, -12(s0)
        lw      ra, 28(sp)                      # 4-byte Folded Reload
        lw      s0, 24(sp)                      # 4-byte Folded Reload
        addi    sp, sp, 32
        ret
main:                                   # @main
        addi    sp, sp, -16
        sw      ra, 12(sp)                      # 4-byte Folded Spill
        sw      s0, 8(sp)                       # 4-byte Folded Spill
        addi    s0, sp, 16
        li      a0, 0
        sw      a0, -12(s0)
        li      a0, 10
        call    fibonacci(int)
        lw      ra, 12(sp)                      # 4-byte Folded Reload
        lw      s0, 8(sp)                       # 4-byte Folded Reload
        addi    sp, sp, 16
        ret