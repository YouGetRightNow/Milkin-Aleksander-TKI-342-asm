section .data
	fname db "seed.txt", 0;
section .bss
	data resw 512
	timev resd 2
	startv resd 1
	buf resb 3076

section .text
global _start
_start:
	mov eax, 78
	lea ebx, [timev]
	xor ecx, ecx
	int 0x80
	mov eax, [timev+4]
	xor eax, [timev]
	shl eax, 7
	xor eax, [timev]
	mov [startv], eax

	xor esi, esi
	xor edi, edi
	xor ebx, ebx
	xor ecx, ecx
loop:
	push ebx
	push ecx
	push esi
	push edi
	call random
	pop edi
	pop esi
	pop ecx
	pop ebx

	test ax, 1
	jnz nechet
	mov [data + esi*2], ax
	inc esi
	jmp size
nechet:
	mov [data + 256 + edi*2], ax
	inc edi
size:
	cmp ax, 50000
	jb few
	mov [data + 512 + ebx*2], ax
	inc ebx
few:
	cmp ax, 10000
	jae check
	mov [data + 768 + ecx*2], ax
	inc ecx
check:
	cmp esi, 127
	ja output
	cmp edi, 127
	ja output
	cmp ebx, 127
	ja output
	cmp ecx, 127
	jbe loop

output:
	mov edi, buf
	xor ebp, ebp
print:
	movzx eax, word [data + ebp*2]
	call tekst
	inc ebp
	test ebp, 127
	jnz print
	mov byte [edi], 10
	inc edi
	cmp ebp, 512
	jb print

	mov eax, 4
	mov ebx, 1
	mov ecx, buf
	mov edx, 3076
	int 0x80
	mov eax, 8
	mov ebx, fname
	mov ecx, 644o
	int 0x80
	mov ebx, eax
	mov eax, 4
	mov ecx, buf
	int 0x80
	mov eax, 6
	int 0x80

	mov eax, 1
	xor ebx, ebx
	int 0x80

random:
	mov eax, [startv]
	imul eax, 1103515245
	add eax, 12345
	mov [startv], eax
	shr eax, 16
	ret

tekst:
	mov ebx, 10
	mov ecx, 5
number:
	xor edx, edx
	div ebx
	add dl, '0'
	mov [edi + ecx -1], dl
	loop number
	mov byte [edi + 5], ' '
	add edi, 6
	ret
