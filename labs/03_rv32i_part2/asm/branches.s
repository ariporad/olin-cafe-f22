main: 
	addi x3, x0, 5
	addi x1, x0, 2
	addi x2, x0, 2
	bne x1, x2, fail
	jal x0, skip
fail:
	addi x3, x0, 10
skip:
	addi x4, x0, 14