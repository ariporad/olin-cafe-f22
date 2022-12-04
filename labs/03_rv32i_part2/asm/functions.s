call main
halt

func(int):

        addi    sp, sp, -16
        sw      ra, 12(sp)                      # 4-byte Folded Spill
        sw      s0, 8(sp)                       # 4-byte Folded Spill
        addi    s0, sp, 16
        sw      a0, -12(s0)
        lw      a0, -12(s0)
        add     a0, a0, a0
        lw      ra, 12(sp)                      # 4-byte Folded Reload
        lw      s0, 8(sp)                       # 4-byte Folded Reload
        addi    sp, sp, 16
        ret
main:                                   # @main
        addi    sp, sp, -32
        sw      ra, 28(sp)                      # 4-byte Folded Spill
        sw      s0, 24(sp)                      # 4-byte Folded Spill
        addi    s0, sp, 32
        li      a0, 0
        sw      a0, -24(s0)                     # 4-byte Folded Spill
        sw      a0, -12(s0)
        li      a0, 17
        sw      a0, -16(s0)
        lw      a0, -16(s0)
        call    double_an_int(int)
        mv      a1, a0
        lw      a0, -24(s0)                     # 4-byte Folded Reload
        sw      a1, -20(s0)
        lw      ra, 28(sp)                      # 4-byte Folded Reload
        lw      s0, 24(sp)                      # 4-byte Folded Reload
        addi    sp, sp, 32
        ret