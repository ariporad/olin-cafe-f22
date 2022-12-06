	.file	"fibonacci_cpp.c"
	.option nopic
	.text
	.align	2
	.globl	fibonacci
	.type	fibonacci, @function
fibonacci:
	add	sp,sp,-32
	sw	ra,28(sp)
	sw	s0,24(sp)
	sw	s1,20(sp)
	add	s0,sp,32
	sw	a0,-20(s0)
	lui	a5,%hi(count.1384)
	lw	a5,%lo(count.1384)(a5)
	add	a4,a5,1
	lui	a5,%hi(count.1384)
	sw	a4,%lo(count.1384)(a5)
	lw	a5,-20(s0)
	bgtz	a5,.L2
	li	a5,0
	j	.L3
.L2:
	lw	a4,-20(s0)
	li	a5,1
	bne	a4,a5,.L4
	li	a5,1
	j	.L3
.L4:
	lw	a5,-20(s0)
	add	a5,a5,-1
	mv	a0,a5
	call	fibonacci
	mv	s1,a0
	lw	a5,-20(s0)
	add	a5,a5,-2
	mv	a0,a5
	call	fibonacci
	mv	a5,a0
	add	a5,s1,a5
.L3:
	mv	a0,a5
	lw	ra,28(sp)
	lw	s0,24(sp)
	lw	s1,20(sp)
	add	sp,sp,32
	jr	ra
	.size	fibonacci, .-fibonacci
	.align	2
	.globl	main
	.type	main, @function
main:
	add	sp,sp,-32
	sw	ra,28(sp)
	sw	s0,24(sp)
	add	s0,sp,32
	sw	a0,-20(s0)
	lw	a0,-20(s0)
	call	fibonacci
	mv	a5,a0
	mv	a0,a5
	lw	ra,28(sp)
	lw	s0,24(sp)
	add	sp,sp,32
	jr	ra
	.size	main, .-main
	.local	count.1384
	.comm	count.1384,4,4
	.ident	"GCC: (GNU) 7.1.1 20170509"
