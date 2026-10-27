; lexer.asm — лексер языка «Дота»: разбивает текст программы на токены
; (словарь и раздел Tokens из lexer.md).
;
; Сборка и запуск (Linux, 32 бита, из папки compiler):
;     nasm -f elf32 lexer.asm -o lexer.o
;     ld -m elf_i386 lexer.o -o lexer
;     ./lexer                          (файл из FILE_PATH)
;     ./lexer examples/arithmetic.dota
;
; Что делает: читает файл .dota, выводит его как есть, потом таблицу токенов
; и список лексических ошибок. parser.asm подключает этот файл целиком.
;
; Внутри лексера: esi — текущий байт текста, ebx — конец текста.

; ================= ввод-вывод (int 0x80) =================

SYS_EXIT    equ 1
SYS_READ    equ 3
SYS_WRITE   equ 4
SYS_OPEN    equ 5
SYS_CLOSE   equ 6
STDOUT      equ 1
O_RDONLY    equ 0

; PRINT метка — напечатать строку, которая кончается нулём
%macro PRINT 1
    push esi
    mov esi, %1
    call print_z
    pop esi
%endmacro

section .data
spaces      times 64 db ' '

section .bss
char_buf    resb 1
num_text    resb 12

section .text

; write: ecx = адрес, edx = длина в байтах
write:
    push eax
    push ebx
    mov eax, SYS_WRITE
    mov ebx, STDOUT
    int 0x80
    pop ebx
    pop eax
    ret

; strlen: esi = строка с нулём на конце -> ecx = длина
strlen:
    xor ecx, ecx
.next:
    cmp byte [esi + ecx], 0
    je .done
    inc ecx
    jmp .next
.done:
    ret

; print_z: esi = строка с нулём на конце
print_z:
    push ecx
    push edx
    call strlen
    mov edx, ecx
    mov ecx, esi
    call write
    pop edx
    pop ecx
    ret

; print_char: al = символ
print_char:
    push ecx
    push edx
    mov [char_buf], al
    mov ecx, char_buf
    mov edx, 1
    call write
    pop edx
    pop ecx
    ret

newline:
    push eax
    mov al, 10
    call print_char
    pop eax
    ret

; print_spaces: ecx = сколько пробелов (0 и меньше — ничего)
print_spaces:
    push ecx
    push edx
.next:
    cmp ecx, 0
    jle .done
    mov edx, ecx
    cmp edx, 64
    jbe .write
    mov edx, 64
.write:
    sub ecx, edx
    push ecx
    mov ecx, spaces
    call write
    pop ecx
    jmp .next
.done:
    pop edx
    pop ecx
    ret

; uint_to_text: eax = число -> ecx = адрес цифр, edx = сколько цифр
uint_to_text:
    push eax
    push ebx
    push esi
    lea esi, [num_text + 12]
    mov ebx, 10
    xor ecx, ecx
.digit:
    xor edx, edx
    div ebx                 ; eax = eax / 10, edx = последняя цифра
    add dl, '0'
    dec esi
    mov [esi], dl
    inc ecx
    test eax, eax
    jnz .digit
    mov edx, ecx
    mov ecx, esi
    pop esi
    pop ebx
    pop eax
    ret

; print_uint: eax = число
print_uint:
    push ecx
    push edx
    call uint_to_text
    call write
    pop edx
    pop ecx
    ret

; utf8_chars: esi = адрес, ecx = длина в байтах -> eax = число символов.
; Русская буква в UTF-8 занимает 2 байта; второй байт вида 10xxxxxx не считаем.
utf8_chars:
    push ecx
    push edx
    push esi
    xor eax, eax
.next:
    test ecx, ecx
    jz .done
    mov dl, [esi]
    and dl, 0xC0
    cmp dl, 0x80
    je .skip
    inc eax
.skip:
    inc esi
    dec ecx
    jmp .next
.done:
    pop esi
    pop edx
    pop ecx
    ret

; print_pad: esi = адрес, ecx = длина в байтах, edx = ширина колонки в символах.
; Печатает текст и добивает пробелами до ширины колонки.
print_pad:
    push eax
    push ecx
    push edx
    call utf8_chars
    push edx
    mov edx, ecx
    mov ecx, esi
    call write
    pop edx
    sub edx, eax
    mov ecx, edx
    call print_spaces
    pop edx
    pop ecx
    pop eax
    ret

; print_z_pad: esi = строка с нулём, edx = ширина колонки
print_z_pad:
    push ecx
    call strlen
    call print_pad
    pop ecx
    ret

; exit: ebx = код завершения
exit:
    mov eax, SYS_EXIT
    int 0x80

; ================= этап 1: читаем файл и выводим как есть =================

section .data
FILE_PATH   db "examples/factorial.dota", 0     ; какой файл читаем (пока константа)
EXTENSION   db ".dota", 0
f_title     db "=== Файл ", 0
f_title_end db " ===", 10, 0
f_error     db "Ошибка: ", 0
f_file      db "файл ", 0
f_quote     db "'", 0
f_not_dota  db "' — не программа на «Доте»: нужно расширение .dota", 10, 0
f_not_found db "' не найден (запускайте программу из папки compiler)", 10, 0
f_too_big   db "' слишком большой", 10, 0

section .bss
path        resd 1
fd          resd 1

section .text

; read_file: прочитать файл [path] в src, длина — в src_len
read_file:
    mov esi, [path]                 ; расширение должно быть .dota
    call strlen
    cmp ecx, 5
    jb .not_dota
    add esi, ecx
    sub esi, 5
    mov edi, EXTENSION
    mov ecx, 5
    repe cmpsb
    jne .not_dota

    mov eax, SYS_OPEN
    mov ebx, [path]
    mov ecx, O_RDONLY
    xor edx, edx
    int 0x80
    test eax, eax
    js .not_found                   ; отрицательный ответ — файла нет
    mov [fd], eax

    xor esi, esi                    ; esi = сколько байт уже прочитали
.read:
    mov edx, MAX_SRC
    sub edx, esi
    jz .too_big
    mov eax, SYS_READ
    mov ebx, [fd]
    lea ecx, [src + esi]
    int 0x80
    test eax, eax
    jle .end                        ; 0 — файл кончился
    add esi, eax
    jmp .read
.end:
    mov [src_len], esi
    mov eax, SYS_CLOSE
    mov ebx, [fd]
    int 0x80
    ret

.not_dota:
    PRINT f_error
    PRINT f_quote
    mov esi, [path]
    call print_z
    PRINT f_not_dota
    mov ebx, 1
    call exit
.not_found:
    PRINT f_error
    PRINT f_file
    PRINT f_quote
    mov esi, [path]
    call print_z
    PRINT f_not_found
    mov ebx, 1
    call exit
.too_big:
    PRINT f_error
    PRINT f_file
    PRINT f_quote
    mov esi, [path]
    call print_z
    PRINT f_too_big
    mov ebx, 1
    call exit

; print_source: вывести текст программы без изменений
print_source:
    PRINT f_title
    mov esi, [path]
    call print_z
    PRINT f_title_end
    mov ecx, src
    mov edx, [src_len]
    call write
    mov eax, [src_len]              ; нет перевода строки в конце — добавим
    test eax, eax
    jz .newline
    cmp byte [src + eax - 1], 10
    je .done
.newline:
    call newline
.done:
    ret

; ================= лексер =================

MAX_SRC     equ 65536
MAX_TOKENS  equ MAX_SRC + 1     ; токен — хотя бы 1 байт, плюс EOF

; ---------- типы токенов ----------
T_EOF       equ 0
T_IDENT     equ 1
T_NUMBER    equ 2
T_STRING    equ 3
T_ERROR     equ 9

; ключевые слова (10..23)
K_PIK       equ 10
K_GG        equ 11
K_GEROY     equ 12
K_AEGIS     equ 13
K_INVENTAR  equ 14
K_VARD      equ 15
K_TUMAN     equ 16
K_FARMIT    equ 17
K_VOLNA     equ 18
K_DO        equ 19
K_SKILL     equ 20
K_TP        equ 21
K_PING      equ 22
K_ZAKUP     equ 23

; операторы (30..46)
O_HIL       equ 30
O_URON      equ 31
O_KRIT      equ 32
O_SPLIT     equ 33
O_LAST      equ 34
O_AND       equ 35
O_OR        equ 36
O_NOT       equ 37
O_ASSIGN    equ 40      ; =
O_EQ        equ 41      ; ==
O_NEQ       equ 42      ; !=
O_LT        equ 43      ; <
O_LE        equ 44      ; <=
O_GT        equ 45      ; >
O_GE        equ 46      ; >=

; разделители (50..57)
D_SEMI      equ 50      ; ;
D_COMMA     equ 51      ; ,
D_LPAREN    equ 52      ; (
D_RPAREN    equ 53      ; )
D_LBRACE    equ 54      ; {
D_RBRACE    equ 55      ; }
D_LBRACKET  equ 56      ; [
D_RBRACKET  equ 57      ; ]

; ---------- токен: 6 полей по 4 байта ----------
TK_TYPE     equ 0       ; тип
TK_START    equ 4       ; адрес первого байта в тексте
TK_LEN      equ 8       ; длина в байтах
TK_LINE     equ 12      ; строка
TK_COL      equ 16      ; столбец
TK_MSG      equ 20      ; смысл (или текст ошибки), строка с нулём
TOKEN_SIZE  equ 24

section .data

; ---------- словарь: слово, код, смысл ----------
w_pik       db "пик", 0
w_gg        db "гг", 0
w_geroy     db "герой", 0
w_aegis     db "аегис", 0
w_inventar  db "инвентарь", 0
w_vard      db "вард", 0
w_tuman     db "туман", 0
w_farmit    db "фармить", 0
w_volna     db "волна", 0
w_do        db "до", 0
w_skill     db "скилл", 0
w_tp        db "тп", 0
w_ping      db "пинг", 0
w_zakup     db "закуп", 0
w_hil       db "хил", 0
w_uron      db "урон", 0
w_krit      db "крит", 0
w_split     db "сплит", 0
w_last      db "ласт", 0
w_and       db "и", 0
w_or        db "или", 0
w_not       db "не", 0

m_pik       db "начало программы", 0
m_gg        db "конец программы", 0
m_geroy     db "объявление переменной", 0
m_aegis     db "объявление константы", 0
m_inventar  db "объявление массива", 0
m_vard      db "условие (если)", 0
m_tuman     db "иначе", 0
m_farmit    db "цикл (пока)", 0
m_volna     db "цикл со счётчиком", 0
m_do        db "граница цикла", 0
m_skill     db "объявление функции", 0
m_tp        db "возврат из функции", 0
m_ping      db "вывод", 0
m_zakup     db "ввод", 0
m_hil       db "сложение (+)", 0
m_uron      db "вычитание (-)", 0
m_krit      db "умножение (*)", 0
m_split     db "деление (/)", 0
m_last      db "остаток (%)", 0
m_and       db "логическое И", 0
m_or        db "логическое ИЛИ", 0
m_not       db "логическое НЕ", 0

word_table:
    dd w_pik,      K_PIK,      m_pik
    dd w_gg,       K_GG,       m_gg
    dd w_geroy,    K_GEROY,    m_geroy
    dd w_aegis,    K_AEGIS,    m_aegis
    dd w_inventar, K_INVENTAR, m_inventar
    dd w_vard,     K_VARD,     m_vard
    dd w_tuman,    K_TUMAN,    m_tuman
    dd w_farmit,   K_FARMIT,   m_farmit
    dd w_volna,    K_VOLNA,    m_volna
    dd w_do,       K_DO,       m_do
    dd w_skill,    K_SKILL,    m_skill
    dd w_tp,       K_TP,       m_tp
    dd w_ping,     K_PING,     m_ping
    dd w_zakup,    K_ZAKUP,    m_zakup
    dd w_hil,      O_HIL,      m_hil
    dd w_uron,     O_URON,     m_uron
    dd w_krit,     O_KRIT,     m_krit
    dd w_split,    O_SPLIT,    m_split
    dd w_last,     O_LAST,     m_last
    dd w_and,      O_AND,      m_and
    dd w_or,       O_OR,       m_or
    dd w_not,      O_NOT,      m_not
    dd 0

; ---------- знаки: сначала двухсимвольные, иначе "==" прочитается как "=" "=" ----------
s_eq        db "==", 0
s_neq       db "!=", 0
s_le        db "<=", 0
s_ge        db ">=", 0
s_assign    db "=", 0
s_lt        db "<", 0
s_gt        db ">", 0
s_semi      db ";", 0
s_comma     db ",", 0
s_lparen    db "(", 0
s_rparen    db ")", 0
s_lbrace    db "{", 0
s_rbrace    db "}", 0
s_lbracket  db "[", 0
s_rbracket  db "]", 0

m_eq        db "равно", 0
m_neq       db "не равно", 0
m_le        db "меньше или равно", 0
m_ge        db "больше или равно", 0
m_assign    db "присваивание", 0
m_lt        db "меньше", 0
m_gt        db "больше", 0
m_semi      db "конец команды", 0
m_comma     db "запятая", 0
m_lparen    db "открывающая скобка", 0
m_rparen    db "закрывающая скобка", 0
m_lbrace    db "начало блока", 0
m_rbrace    db "конец блока", 0
m_lbracket  db "начало индекса", 0
m_rbracket  db "конец индекса", 0

sym_table:
    dd s_eq,       O_EQ,       m_eq
    dd s_neq,      O_NEQ,      m_neq
    dd s_le,       O_LE,       m_le
    dd s_ge,       O_GE,       m_ge
    dd s_assign,   O_ASSIGN,   m_assign
    dd s_lt,       O_LT,       m_lt
    dd s_gt,       O_GT,       m_gt
    dd s_semi,     D_SEMI,     m_semi
    dd s_comma,    D_COMMA,    m_comma
    dd s_lparen,   D_LPAREN,   m_lparen
    dd s_rparen,   D_RPAREN,   m_rparen
    dd s_lbrace,   D_LBRACE,   m_lbrace
    dd s_rbrace,   D_RBRACE,   m_rbrace
    dd s_lbracket, D_LBRACKET, m_lbracket
    dd s_rbracket, D_RBRACKET, m_rbracket
    dd 0

; ---------- подсказки для символов, которых в языке нет ----------
h_plus      db "сложение пишется словом «хил»", 0
h_minus     db "вычитание пишется словом «урон»", 0
h_star      db "умножение пишется словом «крит»", 0
h_slash     db "деление пишется словом «сплит»", 0
h_percent   db "остаток пишется словом «ласт»", 0
h_excl      db "отрицание пишется словом «не»", 0

hint_table:
    dd '+', h_plus
    dd '-', h_minus
    dd '*', h_star
    dd '/', h_slash
    dd '%', h_percent
    dd '!', h_excl
    dd 0

m_ident     db "имя", 0
m_number    db "целое число", 0
m_string    db "текст для вывода", 0
m_empty     db 0

e_big       db "число больше 2147483647", 0
e_digit     db "имя не может начинаться с цифры", 0
e_string    db "строка не закрыта кавычкой", 0
e_unknown   db "неизвестный символ", 0
e_too_many  db 10, "Ошибка: слишком много токенов", 10, 0

; ---------- категории для таблицы ----------
c_keyword   db "ключевое слово", 0
c_operator  db "оператор", 0
c_delim     db "разделитель", 0
c_ident     db "идентификатор", 0
c_number    db "число", 0
c_string    db "строка", 0
c_eof       db "конец файла", 0
c_error     db "ОШИБКА", 0

t_title     db 10, "=== Токены ===", 10, 0
t_pos       db "Позиция", 0
t_lexeme    db "Лексема", 0
t_category  db "Категория", 0
t_meaning   db "Смысл", 10, 0
t_line      times 75 db '-'
            db 10, 0
t_total     db 10, "Всего токенов: ", 0
t_ok        db "Лексических ошибок нет. GG WP!", 10, 0
t_errors    db "Лексических ошибок: ", 0
t_err_line  db "  строка ", 0
t_err_col   db ", столбец ", 0
t_colon     db ": ", 0
t_ellipsis  db "…", 0

section .bss
src         resb MAX_SRC
src_len     resd 1
tokens      resb MAX_TOKENS * TOKEN_SIZE
tok_count   resd 1
lex_errors  resd 1
lex_line    resd 1          ; строка и столбец следующего символа
lex_col     resd 1
tok_start   resd 1          ; где начался текущий токен
tok_line    resd 1
tok_col     resd 1
num_big     resb 1
pos_buf     resb 24

section .text

; ================= lex: весь текст -> массив токенов =================
lex:
    pusha
    mov esi, src
    mov ebx, src
    add ebx, [src_len]
    mov dword [tok_count], 0
    mov dword [lex_errors], 0
    mov dword [lex_line], 1
    mov dword [lex_col], 1

    ; метка BOM (EF BB BF), которую ставит Блокнот, — не часть программы
    mov eax, ebx
    sub eax, esi
    cmp eax, 3
    jb .next
    cmp byte [esi], 0xEF
    jne .next
    cmp byte [esi + 1], 0xBB
    jne .next
    cmp byte [esi + 2], 0xBF
    jne .next
    add esi, 3

.next:
    cmp esi, ebx
    jae .end
    mov [tok_start], esi            ; запоминаем начало токена
    mov eax, [lex_line]
    mov [tok_line], eax
    mov eax, [lex_col]
    mov [tok_col], eax

    mov al, [esi]
    cmp al, ' '                     ; пробелы и переводы строк пропускаем
    je .skip
    cmp al, 9
    je .skip
    cmp al, 13
    je .skip
    cmp al, 10
    je .skip

    cmp al, '/'                     ; комментарий // до конца строки
    jne .not_comment
    lea edx, [esi + 1]
    cmp edx, ebx
    jae .not_comment
    cmp byte [esi + 1], '/'
    jne .not_comment
.comment:
    cmp esi, ebx
    jae .next
    cmp byte [esi], 10
    je .next
    call advance
    jmp .comment

.not_comment:
    cmp al, '0'                     ; цифра — число
    jb .not_number
    cmp al, '9'
    ja .not_number
    call lex_number
    jmp .next

.not_number:
    call letter_len                 ; буква — слово
    test eax, eax
    jz .not_word
    call lex_word
    jmp .next

.not_word:
    cmp byte [esi], '"'             ; кавычка — строка
    jne .not_string
    call lex_string
    jmp .next

.not_string:
    call lex_symbol                 ; знак или разделитель
    test eax, eax
    jnz .next
    call lex_bad                    ; всё остальное — ошибка
    jmp .next

.skip:
    call advance
    jmp .next

.end:                               ; в конце всегда токен EOF
    mov [tok_start], esi
    mov eax, [lex_line]
    mov [tok_line], eax
    mov eax, [lex_col]
    mov [tok_col], eax
    mov eax, T_EOF
    xor ecx, ecx
    mov edx, m_empty
    call emit
    popa
    ret

; advance: перейти к следующему байту и посчитать строку и столбец
advance:
    push eax
    mov al, [esi]
    inc esi
    cmp al, 10
    jne .not_newline
    inc dword [lex_line]
    mov dword [lex_col], 1
    jmp .done
.not_newline:
    and al, 0xC0                    ; второй байт русской буквы — тот же столбец
    cmp al, 0x80
    je .done
    inc dword [lex_col]
.done:
    pop eax
    ret

; emit: добавить токен. eax = тип, edx = смысл; длина = esi - tok_start
emit:
    push ecx
    push edi
    mov edi, [tok_count]
    cmp edi, MAX_TOKENS
    jae .too_many
    imul edi, TOKEN_SIZE
    add edi, tokens
    mov [edi + TK_TYPE], eax
    mov [edi + TK_MSG], edx
    mov ecx, [tok_start]
    mov [edi + TK_START], ecx
    neg ecx
    add ecx, esi
    mov [edi + TK_LEN], ecx
    mov ecx, [tok_line]
    mov [edi + TK_LINE], ecx
    mov ecx, [tok_col]
    mov [edi + TK_COL], ecx
    inc dword [tok_count]
    cmp eax, T_ERROR
    jne .done
    inc dword [lex_errors]
.done:
    pop edi
    pop ecx
    ret
.too_many:
    PRINT e_too_many
    mov ebx, 1
    call exit

; letter_len: буква ли в esi? eax = 0 (нет), 1 (латиница или _), 2 (русская буква)
letter_len:
    push edx
    xor eax, eax
    cmp esi, ebx
    jae .done
    mov dl, [esi]
    cmp dl, '_'
    je .one
    cmp dl, 'A'
    jb .done
    cmp dl, 'Z'
    jbe .one
    cmp dl, 'a'
    jb .done
    cmp dl, 'z'
    jbe .one
    cmp dl, 0xD0                    ; русские буквы в UTF-8: D0 xx или D1 xx
    je .d0
    cmp dl, 0xD1
    je .d1
    jmp .done
.d0:
    lea edx, [esi + 1]
    cmp edx, ebx
    jae .done
    mov dl, [esi + 1]
    cmp dl, 0x81                    ; Ё
    je .two
    cmp dl, 0x90                    ; А..п = D0 90..D0 BF
    jb .done
    cmp dl, 0xBF
    ja .done
    jmp .two
.d1:
    lea edx, [esi + 1]
    cmp edx, ebx
    jae .done
    mov dl, [esi + 1]
    cmp dl, 0x91                    ; ё
    je .two
    cmp dl, 0x80                    ; р..я = D1 80..D1 8F
    jb .done
    cmp dl, 0x8F
    ja .done
.two:
    mov eax, 2
    jmp .done
.one:
    mov eax, 1
.done:
    pop edx
    ret

; digit_at: цифра ли в esi? eax = 1 или 0
digit_at:
    xor eax, eax
    cmp esi, ebx
    jae .done
    cmp byte [esi], '0'
    jb .done
    cmp byte [esi], '9'
    ja .done
    mov eax, 1
.done:
    ret

; skip_name: пропустить буквы и цифры (продолжение имени)
skip_name:
.next:
    call letter_len
    test eax, eax
    jnz .take
    call digit_at
    test eax, eax
    jz .done
.take:
    call advance
    dec eax
    jnz .take
    jmp .next
.done:
    ret

; ---------- число: NUMBER = digit { digit } ----------
lex_number:
    push edi
    xor edi, edi                    ; edi = значение
    mov byte [num_big], 0
.digit:
    call digit_at
    test eax, eax
    jz .digits_done
    movzx eax, byte [esi]
    sub eax, '0'
    cmp byte [num_big], 0
    jne .skip_digit
    cmp edi, 214748364              ; поместится ли value*10 + digit в 2147483647
    ja .big
    jb .add
    cmp eax, 7
    ja .big
.add:
    imul edi, 10
    add edi, eax
    jmp .skip_digit
.big:
    mov byte [num_big], 1
.skip_digit:
    call advance
    jmp .digit
.digits_done:
    call letter_len                 ; 5крипов — имя с цифры
    test eax, eax
    jnz .bad_name
    cmp byte [num_big], 0
    jne .too_big
    mov eax, T_NUMBER
    mov edx, m_number
    call emit
    pop edi
    ret
.too_big:
    mov eax, T_ERROR
    mov edx, e_big
    call emit
    pop edi
    ret
.bad_name:
    call skip_name
    mov eax, T_ERROR
    mov edx, e_digit
    call emit
    pop edi
    ret

; ---------- слово: IDENT = letter { letter | digit }, или слово из словаря ----------
lex_word:
    call skip_name
    mov edx, [tok_start]
    mov ecx, esi
    sub ecx, edx                    ; edx = начало слова, ecx = длина
    call find_word
    test eax, eax
    jz .ident
    mov edx, [eax + 8]              ; смысл
    mov eax, [eax + 4]              ; код
    call emit
    ret
.ident:
    mov eax, T_IDENT
    mov edx, m_ident
    call emit
    ret

; find_word: edx = слово, ecx = длина -> eax = запись в word_table или 0
find_word:
    push ebx
    push esi
    push edi
    mov ebx, word_table
.entry:
    mov esi, [ebx]
    test esi, esi
    jz .not_found
    push ecx
    mov edi, edx
.compare:
    test ecx, ecx
    jz .word_end
    mov al, [esi]
    cmp al, [edi]
    jne .differ
    inc esi
    inc edi
    dec ecx
    jmp .compare
.word_end:
    cmp byte [esi], 0               ; слово из словаря тоже должно кончиться
    jne .differ
    pop ecx
    mov eax, ebx
    jmp .done
.differ:
    pop ecx
    add ebx, 12
    jmp .entry
.not_found:
    xor eax, eax
.done:
    pop edi
    pop esi
    pop ebx
    ret

; ---------- строка: STRING = '"' { любой символ, кроме кавычки и перевода строки } '"' ----------
lex_string:
    call advance                    ; открывающая кавычка
.next:
    cmp esi, ebx
    jae .unclosed
    mov al, [esi]
    cmp al, '"'
    je .closed
    cmp al, 10
    je .unclosed
    cmp al, 13
    je .unclosed
    cmp al, '\'                     ; \" и \n внутри строки
    jne .char
    lea edx, [esi + 1]
    cmp edx, ebx
    jae .unclosed
    cmp byte [esi + 1], 10
    je .unclosed
    call advance
.char:
    call advance
    jmp .next
.closed:
    call advance
    mov eax, T_STRING
    mov edx, m_string
    call emit
    ret
.unclosed:                          ; ошибка: забираем всё до конца строки
    cmp esi, ebx
    jae .error
    cmp byte [esi], 10
    je .error
    cmp byte [esi], 13
    je .error
    call advance
    jmp .unclosed
.error:
    mov eax, T_ERROR
    mov edx, e_string
    call emit
    ret

; ---------- знак или разделитель -> eax = 1, если нашли ----------
lex_symbol:
    push ebp
    push edi
    mov ebp, sym_table
.entry:
    mov edi, [ebp]
    test edi, edi
    jz .none
    xor ecx, ecx
.compare:
    mov al, [edi + ecx]
    test al, al
    jz .found                       ; знак из таблицы совпал целиком
    lea edx, [esi + ecx]
    cmp edx, ebx
    jae .differ
    cmp al, [esi + ecx]
    jne .differ
    inc ecx
    jmp .compare
.differ:
    add ebp, 12
    jmp .entry
.found:
    call advance
    loop .found                     ; забрать ecx байт
    mov eax, [ebp + 4]
    mov edx, [ebp + 8]
    call emit
    mov eax, 1
    jmp .done
.none:
    xor eax, eax
.done:
    pop edi
    pop ebp
    ret

; ---------- неизвестный символ: ошибка (для + - * / % ! — подсказка) ----------
lex_bad:
    movzx eax, byte [esi]
    mov edx, e_unknown
    push ebp
    mov ebp, hint_table
.hint:
    cmp dword [ebp], 0
    je .hint_done
    cmp eax, [ebp]
    je .hint_found
    add ebp, 8
    jmp .hint
.hint_found:
    mov edx, [ebp + 4]
.hint_done:
    pop ebp
    ; длина символа в UTF-8 по первому байту: 1, 2, 3 или 4 байта
    mov ecx, 1
    cmp al, 0xC0
    jb .len_ok
    mov ecx, 2
    cmp al, 0xE0
    jb .len_ok
    mov ecx, 3
    cmp al, 0xF0
    jb .len_ok
    mov ecx, 4
.len_ok:
    mov eax, ebx                    ; не выходить за конец текста
    sub eax, esi
    cmp ecx, eax
    jbe .take
    mov ecx, eax
.take:
    call advance
    loop .take
    mov eax, T_ERROR
    call emit
    ret

; ================= таблица токенов =================

; category_name: eax = тип токена -> esi = название категории
category_name:
    mov esi, c_eof
    cmp eax, T_EOF
    je .done
    mov esi, c_ident
    cmp eax, T_IDENT
    je .done
    mov esi, c_number
    cmp eax, T_NUMBER
    je .done
    mov esi, c_string
    cmp eax, T_STRING
    je .done
    mov esi, c_error
    cmp eax, T_ERROR
    je .done
    mov esi, c_keyword
    cmp eax, 30
    jb .done
    mov esi, c_operator
    cmp eax, 50
    jb .done
    mov esi, c_delim
.done:
    ret

; print_position: ebx = токен. Печатает «строка:столбец» в колонке ширины 10
print_position:
    pusha
    mov edi, pos_buf
    mov eax, [ebx + TK_LINE]
    call uint_to_text
    mov esi, ecx
    mov ecx, edx
    rep movsb
    mov byte [edi], ':'
    inc edi
    mov eax, [ebx + TK_COL]
    call uint_to_text
    mov esi, ecx
    mov ecx, edx
    rep movsb
    mov ecx, edi
    sub ecx, pos_buf
    mov esi, pos_buf
    mov edx, 10
    call print_pad
    popa
    ret

; print_lexeme: esi = текст, ecx = длина. Колонка 24 символа; длиннее 22 — обрезаем «…»
print_lexeme:
    pusha
    call utf8_chars
    cmp eax, 22
    jbe .short
    xor edx, edx                    ; edx = сколько байт печатать
    xor edi, edi                    ; edi = сколько символов прошли
.find:
    mov al, [esi + edx]
    and al, 0xC0
    cmp al, 0x80
    je .continue
    cmp edi, 21
    je .cut
    inc edi
.continue:
    inc edx
    jmp .find
.cut:
    mov ecx, esi
    call write
    PRINT t_ellipsis
    mov ecx, 2
    call print_spaces
    popa
    ret
.short:
    mov edx, 24
    call print_pad
    popa
    ret

; print_tokens: таблица всех токенов и список лексических ошибок
print_tokens:
    pusha
    PRINT t_title
    mov edx, 10
    mov esi, t_pos
    call print_z_pad
    mov edx, 24
    mov esi, t_lexeme
    call print_z_pad
    mov edx, 17
    mov esi, t_category
    call print_z_pad
    PRINT t_meaning
    PRINT t_line

    mov ebx, tokens
    mov ebp, [tok_count]
.row:
    test ebp, ebp
    jz .rows_done
    call print_position
    mov esi, [ebx + TK_START]
    mov ecx, [ebx + TK_LEN]
    call print_lexeme
    mov eax, [ebx + TK_TYPE]
    call category_name
    mov edx, 17
    call print_z_pad
    mov esi, [ebx + TK_MSG]
    call print_z
    call newline
    add ebx, TOKEN_SIZE
    dec ebp
    jmp .row
.rows_done:
    PRINT t_total
    mov eax, [tok_count]
    call print_uint
    call newline
    cmp dword [lex_errors], 0
    jne .errors
    PRINT t_ok
    popa
    ret

.errors:
    PRINT t_errors
    mov eax, [lex_errors]
    call print_uint
    call newline
    mov ebx, tokens
    mov ebp, [tok_count]
.error_row:
    test ebp, ebp
    jz .done
    cmp dword [ebx + TK_TYPE], T_ERROR
    jne .next_error
    PRINT t_err_line                ; "  строка 4, столбец 20: сообщение: текст"
    mov eax, [ebx + TK_LINE]
    call print_uint
    PRINT t_err_col
    mov eax, [ebx + TK_COL]
    call print_uint
    PRINT t_colon
    mov esi, [ebx + TK_MSG]
    call print_z
    PRINT t_colon
    mov ecx, [ebx + TK_START]
    mov edx, [ebx + TK_LEN]
    call write
    call newline
.next_error:
    add ebx, TOKEN_SIZE
    dec ebp
    jmp .error_row
.done:
    popa
    ret

; ================= запуск только лексера =================
; Если файл собирают сам по себе (без parser.asm) — своя точка входа.
%ifndef PARSER
section .text
global _start

_start:
    mov eax, [esp]                  ; argc
    mov ebx, FILE_PATH
    cmp eax, 2
    jb .path_ready
    mov ebx, [esp + 8]              ; argv[1] — путь, если указали при запуске
.path_ready:
    mov [path], ebx

    call read_file
    call print_source
    call lex
    call print_tokens

    xor ebx, ebx
    cmp dword [lex_errors], 0
    je .exit
    mov ebx, 1
.exit:
    call exit
%endif
