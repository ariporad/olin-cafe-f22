call main
halt

func_eql:
	li a0, 17
	ret

func_neq:
	li a0, 34
	ret

main: 
	addi s1, zero, 2
	addi s2, zero, 3
	bne s1, s2, call_func_neq
	call func_eql
	jal zero, after
call_func_neq:
	call func_neq
after:
	addi s1, zero, 3
	halt