section .data
	a dd 5678901
	b dd 6789012
	c dd 7890123
	d dd 8901234
	e dd 9012345
	f dd 10123456
	res dd 0

section .text
	global _start

_start:
	mov eax, [c]
	imul eax, 2
	mov ebx, [d]
	imul ebx, 51
	add eax, ebx

	mov ecx, [d]
	sub ecx, [a]
	dec ecx

	cdq
	idiv ecx
	mov [res], eax

	mov eax, 1
	xor ebx, ebx
	int 0x80
