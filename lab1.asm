section .data
	x32 dd 0x11223344
	y32 dd 0xAABBCCDD
	x16 dw 0x1122
	y16 dw 0xAABB
	x8 db 0x11
	y8 db 0xAA

section .text
	global _start

_start:

	mov eax, [x32]
	mov ebx, [y32]
	mov ecx, eax
	mov eax, ebx
	mov ebx, ecx

	mov eax, [x32]
	mov ebx, [y32]
	xchg eax, ebx

	mov eax, [x32]
	mov ebx, [y32]
	xor eax, ebx
	xor ebx, eax
	xor eax, ebx

	mov eax, [x32]
	mov ebx, [y32]
	add eax, ebx
	sub ebx, eax
	neg ebx
	sub eax, ebx

	xor eax, eax
	xor ebx, ebx
	xor ecx, ecx

	mov ax, [x16]
	mov bx, [y16]
	mov cx, ax
	mov ax, bx
	mov bx, cx

	mov ax, [x16]
	mov bx, [y16]
	xchg ax, bx

	mov ax, [x16]
	mov bx, [y16]
	xor ax, bx
	xor bx, ax
	xor ax, bx

	mov ax, [x16]
	mov bx, [y16]
	add ax, bx
	sub bx, ax
	neg bx
	sub ax, bx

	xor eax, eax
	xor ebx, ebx
	xor ecx, ecx

	mov al, [x8]
	mov bl, [y8]
	mov cl, al
	mov al, bl
	mov bl, cl

	mov al, [x8]
	mov bl, [y8]
	xchg al, bl

	mov al, [x8]
	mov bl, [y8]
	xor al, bl
	xor bl, al
	xor al, bl

	mov al, [x8]
	mov bl, [y8]
	add al, bl
	sub bl, al
	neg bl
	sub al, bl

	mov eax, 1
	xor ebx, ebx
	int 0x80
