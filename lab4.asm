%macro PRINT 1
    mov  ecx, %1
    mov  edx, %{1}_len
    call print
%endmacro

section .data
    num     dd 0x1245DBCC
    ones1   dd 0
    zeros1  dd 0
    ones2   dd 0
    zeros2  dd 0
    pairs0  dd 0
    pairs1  dd 0
    result  dd 0

    hex     db "0123456789ABCDEF"

    t_num       db "Число:                 0x"
    t_num_len   equ $ - t_num
    t_bin       db "В двоичном виде:       "
    t_bin_len   equ $ - t_bin
    t_way1      db "Способ 1 (SHR + CF):   единиц "
    t_way1_len  equ $ - t_way1
    t_way2      db "Способ 2 (TEST маска): единиц "
    t_way2_len  equ $ - t_way2
    t_zeros     db ", нулей "
    t_zeros_len equ $ - t_zeros
    t_pairs     db "Пары битов:            пар 00 - "
    t_pairs_len equ $ - t_pairs
    t_pairs1    db ", пар 11 - "
    t_pairs1_len equ $ - t_pairs1
    t_swap      db "После обмена битов:    0x"
    t_swap_len  equ $ - t_swap
    t_nl        db 10
    t_nl_len    equ 1

section .bss
    buf     resb 40

section .text
    global _start

_start:
    mov  eax, [num]
    mov  ecx, 32
bits1:
    shr  eax, 1
    jc   one1
    inc  dword [zeros1]
    jmp  next1
one1:
    inc  dword [ones1]
next1:
    loop bits1

    mov  eax, [num]
    mov  edx, 1
bits2:
    test eax, edx
    jz   zero2
    inc  dword [ones2]
    jmp  next2
zero2:
    inc  dword [zeros2]
next2:
    shl  edx, 1
    jnz  bits2

    mov  eax, [num]
    mov  ecx, 16
pairs:
    mov  ebx, eax
    and  ebx, 3
    jnz  not00
    inc  dword [pairs0]
    jmp  next_pair
not00:
    cmp  ebx, 3
    jne  next_pair
    inc  dword [pairs1]
next_pair:
    shr  eax, 2
    loop pairs

    mov  eax, [num]
    xor  ecx, ecx
    mov  edx, 7
swap:
    bt   eax, ecx
    setc bl
    bt   eax, edx
    setc bh
    cmp  bl, bh
    je   same
    btc  eax, ecx
    btc  eax, edx
same:
    inc  ecx
    dec  edx
    cmp  ecx, edx
    jb   swap
    mov  [result], eax

    PRINT t_num
    mov  eax, [num]
    call print_hex
    PRINT t_nl
    PRINT t_bin
    mov  eax, [num]
    call print_bin
    PRINT t_nl

    PRINT t_way1
    mov  eax, [ones1]
    call print_dec
    PRINT t_zeros
    mov  eax, [zeros1]
    call print_dec
    PRINT t_nl

    PRINT t_way2
    mov  eax, [ones2]
    call print_dec
    PRINT t_zeros
    mov  eax, [zeros2]
    call print_dec
    PRINT t_nl

    PRINT t_pairs
    mov  eax, [pairs0]
    call print_dec
    PRINT t_pairs1
    mov  eax, [pairs1]
    call print_dec
    PRINT t_nl

    PRINT t_swap
    mov  eax, [result]
    call print_hex
    PRINT t_nl
    PRINT t_bin
    mov  eax, [result]
    call print_bin
    PRINT t_nl

finish:
    mov  eax, 1
    xor  ebx, ebx
    int  0x80

print:
    mov  eax, 4
    mov  ebx, 1
    int  0x80
    ret

print_dec:
    mov  edi, buf + 39
    mov  ebx, 10
    xor  ecx, ecx
dec_digit:
    xor  edx, edx
    div  ebx
    add  dl, '0'
    mov  [edi], dl
    dec  edi
    inc  ecx
    test eax, eax
    jnz  dec_digit
    inc  edi
    mov  edx, ecx
    mov  ecx, edi
    call print
    ret

print_hex:
    mov  edi, buf
    mov  ecx, 8
hex_digit:
    rol  eax, 4
    mov  ebx, eax
    and  ebx, 0Fh
    mov  bl, [hex + ebx]
    mov  [edi], bl
    inc  edi
    loop hex_digit
    mov  ecx, buf
    mov  edx, 8
    call print
    ret

print_bin:
    mov  edi, buf
    mov  ecx, 32
bin_digit:
    shl  eax, 1
    mov  bl, '0'
    adc  bl, 0
    mov  [edi], bl
    inc  edi
    dec  ecx
    jz   bin_done
    test ecx, 3
    jnz  bin_digit
    mov  byte [edi], ' '
    inc  edi
    jmp  bin_digit
bin_done:
    mov  ecx, buf
    mov  edx, edi
    sub  edx, buf
    call print
    ret
