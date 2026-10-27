; parser.asm — парсер языка «Дота» (рекурсивный спуск) и дерево разбора.
; Подключает lexer.asm: файл -> токены -> дерево.
;
; Сборка и запуск (Linux, 32 бита, из папки compiler):
;     nasm -f elf32 parser.asm -o parser.o
;     ld -m elf_i386 parser.o -o parser
;     ./parser                          (файл из FILE_PATH в lexer.asm)
;     ./parser examples/arithmetic.dota
;
; Одно правило из lexer.md = одна процедура parse_<правило>.
; Процедура создаёт узел дерева со своим именем, кладёт в него детей
; (узлы от вложенных правил и токены-листья) и возвращает узел в eax.
; Процедуры сохраняют ebx, esi, edi, ebp; меняют только eax, ecx, edx.
; edi — узел, который сейчас собирается.

%define PARSER
%include "lexer.asm"

; ---------- номера правил (имена узлов) ----------
R_LEAF        equ 0             ; лист — токен
R_PROGRAM     equ 1
R_FUNCTION    equ 2
R_BLOCK       equ 3
R_STATEMENT   equ 4
R_VAR_STMT    equ 5
R_CONST_STMT  equ 6
R_ARRAY_STMT  equ 7
R_ASSIGN_STMT equ 8
R_IF_STMT     equ 9
R_WHILE_STMT  equ 10
R_FOR_STMT    equ 11
R_RETURN_STMT equ 12
R_PRINT_STMT  equ 13
R_INPUT_STMT  equ 14
R_CALL_STMT   equ 15
R_TARGET      equ 16
R_CALL        equ 17
R_EXPRESSION  equ 18
R_AND_EXPR    equ 19
R_EQUALITY    equ 20
R_COMPARISON  equ 21
R_SUM         equ 22
R_TERM        equ 23
R_UNARY       equ 24
R_FACTOR      equ 25

; ---------- узел дерева: 5 полей по 4 байта ----------
ND_RULE     equ 0               ; номер правила (0 — лист)
ND_TOKEN    equ 4               ; токен (у листа)
ND_FIRST    equ 8               ; первый ребёнок
ND_LAST     equ 12              ; последний ребёнок
ND_NEXT     equ 16              ; следующий брат
NODE_SIZE   equ 20
MAX_NODES   equ 65536
MAX_DEPTH   equ 5000            ; сколько правил может быть вложено друг в друга
NUM_BUF     equ 32768

; CHECK код — сравнить тип текущего токена с кодом (дальше je / jne)
%macro CHECK 1
    xor eax, eax
    call peek
    cmp eax, %1
%endmacro

; CHECK_NEXT код — то же для следующего токена
%macro CHECK_NEXT 1
    mov eax, 1
    call peek
    cmp eax, %1
%endmacro

; EXPECT код — обязательный токен: забрать и добавить в узел edi, иначе ошибка
%macro EXPECT 1
    mov eax, %1
    call expect
%endmacro

; EXPECT_KIND тип, что — обязательный IDENT / NUMBER; «что» — для текста ошибки
%macro EXPECT_KIND 2
    mov eax, %1
    mov ecx, %2
    call expect_kind
%endmacro

; TAKE — забрать текущий токен листом в узел edi
%macro TAKE 0
    call take
    call add_child
%endmacro

; RULE номер — начало процедуры: новый узел в edi
%macro RULE 1
    push edi
    call enter_rule
    mov eax, %1
    call new_node
    mov edi, eax
%endmacro

; DONE — конец процедуры: вернуть узел edi
%macro DONE 0
    dec dword [depth]
    mov eax, edi
    pop edi
    ret
%endmacro

section .data

n_program     db "program", 0
n_function    db "function", 0
n_block       db "block", 0
n_statement   db "statement", 0
n_var_stmt    db "var_stmt", 0
n_const_stmt  db "const_stmt", 0
n_array_stmt  db "array_stmt", 0
n_assign_stmt db "assign_stmt", 0
n_if_stmt     db "if_stmt", 0
n_while_stmt  db "while_stmt", 0
n_for_stmt    db "for_stmt", 0
n_return_stmt db "return_stmt", 0
n_print_stmt  db "print_stmt", 0
n_input_stmt  db "input_stmt", 0
n_call_stmt   db "call_stmt", 0
n_target      db "target", 0
n_call        db "call", 0
n_expression  db "expression", 0
n_and_expr    db "and_expr", 0
n_equality    db "equality", 0
n_comparison  db "comparison", 0
n_sum         db "sum", 0
n_term        db "term", 0
n_unary       db "unary", 0
n_factor      db "factor", 0

rule_names:
    dd 0, n_program, n_function, n_block, n_statement
    dd n_var_stmt, n_const_stmt, n_array_stmt, n_assign_stmt, n_if_stmt
    dd n_while_stmt, n_for_stmt, n_return_stmt, n_print_stmt, n_input_stmt
    dd n_call_stmt, n_target, n_call, n_expression, n_and_expr
    dd n_equality, n_comparison, n_sum, n_term, n_unary, n_factor

; операторы каждого уровня выражений (0 — конец списка)
ops_or      dd O_OR, 0
ops_and     dd O_AND, 0
ops_eq      dd O_EQ, O_NEQ, 0
ops_cmp     dd O_LT, O_LE, O_GT, O_GE, 0
ops_sum     dd O_HIL, O_URON, 0
ops_term    dd O_KRIT, O_SPLIT, O_LAST, 0

; что называть в ошибке «ожидалось ...»
x_func      db "имя функции", 0
x_param     db "имя параметра", 0
x_var       db "имя переменной", 0
x_const     db "имя константы", 0
x_array     db "имя массива", 0
x_size      db "размер массива (число)", 0
x_counter   db "имя счётчика", 0
x_name      db "имя", 0

e_syntax    db 10, "Синтаксическая ошибка (строка ", 0
e_col       db ", столбец ", 0
e_colon     db "): ", 0
e_expected  db "ожидалось ", 0
e_found     db ", а встретилось ", 0
e_eof       db "конец файла", 0
e_lquote    db "«", 0
e_rquote    db "»", 0
e_command   db "ожидалась команда (герой, аегис, инвентарь, вард, фармить, волна, тп, пинг, закуп, присваивание или вызов)", 0
e_factor    db "ожидалось число, имя или «(»", 0
e_no_gg     db "ожидалось «гг» (конец программы)", 0
e_after_gg  db "после «гг» ничего быть не должно", 0
e_block     db "не закрыт блок: ожидалось «}»", 0
e_too_big   db 10, "Ошибка: слишком большая программа", 10, 0
e_deep      db "слишком глубокая вложенность", 0

tree_title  db 10, "=== Дерево программы ===", 10, 0
arrow       db " → ", 0
l_ident     db "IDENT (", 0
l_number    db "NUMBER (", 0
l_string    db "STRING (", 0
l_close     db ")", 0

section .bss
nodes       resb MAX_NODES * NODE_SIZE
node_top    resd 1              ; следующий свободный узел
cur_tok     resd 1              ; текущий токен
last_tok    resd 1              ; последний токен (EOF)
depth       resd 1              ; сколько правил сейчас вложено
num_buf     resb NUM_BUF        ; номер узла при печати: "2.4.3"
num_len     resd 1

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

    call read_file                  ; этап 1: файл
    call print_source
    call lex                        ; лексер: токены
    call print_tokens
    cmp dword [lex_errors], 0
    jne .fail

    call parse                      ; парсер: дерево
    push eax
    PRINT tree_title
    pop eax
    call print_tree

    xor ebx, ebx
    call exit
.fail:
    mov ebx, 1
    call exit

; ================= вспомогательные процедуры =================

; parse: разобрать все токены -> eax = корень дерева (program)
parse:
    mov dword [node_top], nodes
    mov dword [depth], 0
    mov dword [cur_tok], tokens
    mov eax, [tok_count]
    dec eax
    imul eax, TOKEN_SIZE
    add eax, tokens
    mov [last_tok], eax
    call parse_program
    ret

; new_node: eax = номер правила -> eax = новый пустой узел
new_node:
    mov edx, [node_top]
    cmp edx, nodes + MAX_NODES * NODE_SIZE
    jae .full
    mov [edx + ND_RULE], eax
    mov dword [edx + ND_TOKEN], 0
    mov dword [edx + ND_FIRST], 0
    mov dword [edx + ND_LAST], 0
    mov dword [edx + ND_NEXT], 0
    lea ecx, [edx + NODE_SIZE]
    mov [node_top], ecx
    mov eax, edx
    ret
.full:
    PRINT e_too_big
    mov ebx, 1
    call exit

; enter_rule: ещё одно вложенное правило; слишком глубоко — ошибка
enter_rule:
    inc dword [depth]
    cmp dword [depth], MAX_DEPTH
    ja .too_deep
    ret
.too_deep:
    mov esi, e_deep
    jmp error_text

; add_child: eax = ребёнок, edi = родитель
add_child:
    cmp dword [edi + ND_FIRST], 0
    jne .append
    mov [edi + ND_FIRST], eax
    mov [edi + ND_LAST], eax
    ret
.append:
    mov edx, [edi + ND_LAST]
    mov [edx + ND_NEXT], eax
    mov [edi + ND_LAST], eax
    ret

; peek: eax = на сколько токенов вперёд (0 — текущий) -> eax = тип токена
peek:
    imul eax, TOKEN_SIZE
    add eax, [cur_tok]
    cmp eax, [last_tok]
    jbe .ok
    mov eax, [last_tok]             ; дальше EOF не заглядываем
.ok:
    mov eax, [eax + TK_TYPE]
    ret

; take: забрать текущий токен -> eax = лист с этим токеном
take:
    mov eax, R_LEAF
    call new_node
    mov edx, [cur_tok]
    mov [eax + ND_TOKEN], edx
    cmp dword [edx + TK_TYPE], T_EOF
    je .done                        ; EOF не пропускаем
    add dword [cur_tok], TOKEN_SIZE
.done:
    ret

; expect: eax = код обязательного токена
expect:
    mov ecx, eax
    xor eax, eax
    call peek
    cmp eax, ecx
    jne .error
    TAKE
    ret
.error:
    mov eax, ecx
    jmp error_code

; expect_kind: eax = тип (T_IDENT / T_NUMBER), ecx = что ожидалось (для ошибки)
expect_kind:
    push ecx
    mov ecx, eax
    xor eax, eax
    call peek
    cmp eax, ecx
    pop ecx
    jne .error
    TAKE
    ret
.error:
    mov esi, ecx
    jmp error_what

; ================= синтаксические ошибки =================

; error_begin: "Синтаксическая ошибка (строка 3, столбец 5): "
error_begin:
    mov ebx, [cur_tok]
    PRINT e_syntax
    mov eax, [ebx + TK_LINE]
    call print_uint
    PRINT e_col
    mov eax, [ebx + TK_COL]
    call print_uint
    PRINT e_colon
    ret

; error_end: ", а встретилось «пинг»" и выход
error_end:
    PRINT e_found
    mov ebx, [cur_tok]
    cmp dword [ebx + TK_TYPE], T_EOF
    jne .token
    PRINT e_eof
    jmp .exit
.token:
    PRINT e_lquote
    mov ecx, [ebx + TK_START]
    mov edx, [ebx + TK_LEN]
    call write
    PRINT e_rquote
.exit:
    call newline
    mov ebx, 1
    call exit

; error_text: esi = сообщение целиком
error_text:
    push esi
    call error_begin
    pop esi
    call print_z
    jmp error_end

; error_what: esi = что ожидалось ("имя переменной")
error_what:
    push esi
    call error_begin
    PRINT e_expected
    pop esi
    call print_z
    jmp error_end

; error_code: eax = код токена, который ожидался -> "ожидалось «;»"
error_code:
    push eax
    call error_begin
    PRINT e_expected
    PRINT e_lquote
    pop eax
    call code_text
    call print_z
    PRINT e_rquote
    jmp error_end

; code_text: eax = код слова или знака -> esi = как он пишется
code_text:
    mov edx, word_table
.word:
    mov esi, [edx]
    test esi, esi
    jz .symbols
    cmp eax, [edx + 4]
    je .done
    add edx, 12
    jmp .word
.symbols:
    mov edx, sym_table
.symbol:
    mov esi, [edx]
    test esi, esi
    jz .done
    cmp eax, [edx + 4]
    je .done
    add edx, 12
    jmp .symbol
.done:
    ret

; ================= Program =================

; program = { function } "пик" { statement } "гг"
parse_program:
    RULE R_PROGRAM
.functions:
    CHECK K_SKILL
    jne .pik
    call parse_function
    call add_child
    jmp .functions
.pik:
    EXPECT K_PIK
.statements:
    CHECK K_GG
    je .gg
    CHECK T_EOF
    je .no_gg
    call parse_statement
    call add_child
    jmp .statements
.gg:
    EXPECT K_GG
    CHECK T_EOF
    jne .after_gg
    DONE
.no_gg:
    mov esi, e_no_gg
    jmp error_text
.after_gg:
    mov esi, e_after_gg
    jmp error_text

; block = "{" { statement } "}"
parse_block:
    RULE R_BLOCK
    EXPECT D_LBRACE
.statements:
    CHECK D_RBRACE
    je .close
    CHECK T_EOF
    je .unclosed
    call parse_statement
    call add_child
    jmp .statements
.close:
    EXPECT D_RBRACE
    DONE
.unclosed:
    mov esi, e_block
    jmp error_text

; ================= Base =================

; statement = var_stmt | const_stmt | array_stmt | assign_stmt | if_stmt | while_stmt
;           | for_stmt | return_stmt | print_stmt | input_stmt | call_stmt
; Какую команду разбирать — по первому токену.
parse_statement:
    RULE R_STATEMENT
    CHECK K_GEROY
    je .var
    CHECK K_AEGIS
    je .const
    CHECK K_INVENTAR
    je .array
    CHECK K_VARD
    je .if
    CHECK K_FARMIT
    je .while
    CHECK K_VOLNA
    je .for
    CHECK K_TP
    je .return
    CHECK K_PING
    je .print
    CHECK K_ZAKUP
    je .input
    CHECK T_IDENT
    jne .error
    CHECK_NEXT D_LPAREN             ; имя и «(» — вызов, иначе присваивание
    je .call
    call parse_assign_stmt
    jmp .add
.var:
    call parse_var_stmt
    jmp .add
.const:
    call parse_const_stmt
    jmp .add
.array:
    call parse_array_stmt
    jmp .add
.if:
    call parse_if_stmt
    jmp .add
.while:
    call parse_while_stmt
    jmp .add
.for:
    call parse_for_stmt
    jmp .add
.return:
    call parse_return_stmt
    jmp .add
.print:
    call parse_print_stmt
    jmp .add
.input:
    call parse_input_stmt
    jmp .add
.call:
    call parse_call_stmt
.add:
    call add_child
    DONE
.error:
    mov esi, e_command
    jmp error_text

; print_stmt = "пинг" ( expression | STRING ) ";"
parse_print_stmt:
    RULE R_PRINT_STMT
    EXPECT K_PING
    CHECK T_STRING
    jne .expression
    TAKE
    jmp .end
.expression:
    call parse_expression
    call add_child
.end:
    EXPECT D_SEMI
    DONE

; input_stmt = "закуп" target ";"
parse_input_stmt:
    RULE R_INPUT_STMT
    EXPECT K_ZAKUP
    call parse_target
    call add_child
    EXPECT D_SEMI
    DONE

; ================= Values =================

; var_stmt = "герой" IDENT [ "=" expression ] ";"
parse_var_stmt:
    RULE R_VAR_STMT
    EXPECT K_GEROY
    EXPECT_KIND T_IDENT, x_var
    CHECK O_ASSIGN
    jne .end
    TAKE
    call parse_expression
    call add_child
.end:
    EXPECT D_SEMI
    DONE

; const_stmt = "аегис" IDENT "=" expression ";"
parse_const_stmt:
    RULE R_CONST_STMT
    EXPECT K_AEGIS
    EXPECT_KIND T_IDENT, x_const
    EXPECT O_ASSIGN
    call parse_expression
    call add_child
    EXPECT D_SEMI
    DONE

; array_stmt = "инвентарь" IDENT "[" NUMBER "]" ";"
parse_array_stmt:
    RULE R_ARRAY_STMT
    EXPECT K_INVENTAR
    EXPECT_KIND T_IDENT, x_array
    EXPECT D_LBRACKET
    EXPECT_KIND T_NUMBER, x_size
    EXPECT D_RBRACKET
    EXPECT D_SEMI
    DONE

; assign_stmt = target "=" expression ";"
parse_assign_stmt:
    RULE R_ASSIGN_STMT
    call parse_target
    call add_child
    EXPECT O_ASSIGN
    call parse_expression
    call add_child
    EXPECT D_SEMI
    DONE

; target = IDENT [ "[" expression "]" ]
parse_target:
    RULE R_TARGET
    EXPECT_KIND T_IDENT, x_name
    CHECK D_LBRACKET
    jne .end
    TAKE
    call parse_expression
    call add_child
    EXPECT D_RBRACKET
.end:
    DONE

; ================= Condition constructions =================

; if_stmt = "вард" "(" expression ")" block [ "туман" ( block | if_stmt ) ]
parse_if_stmt:
    RULE R_IF_STMT
    EXPECT K_VARD
    EXPECT D_LPAREN
    call parse_expression
    call add_child
    EXPECT D_RPAREN
    call parse_block
    call add_child
    CHECK K_TUMAN
    jne .end
    TAKE
    CHECK K_VARD                    ; «туман вард ...» — снова if_stmt (рекурсия)
    jne .else_block
    call parse_if_stmt
    call add_child
    jmp .end
.else_block:
    call parse_block
    call add_child
.end:
    DONE

; ================= Cycles =================

; while_stmt = "фармить" "(" expression ")" block
parse_while_stmt:
    RULE R_WHILE_STMT
    EXPECT K_FARMIT
    EXPECT D_LPAREN
    call parse_expression
    call add_child
    EXPECT D_RPAREN
    call parse_block
    call add_child
    DONE

; for_stmt = "волна" IDENT "=" expression "до" expression block
parse_for_stmt:
    RULE R_FOR_STMT
    EXPECT K_VOLNA
    EXPECT_KIND T_IDENT, x_counter
    EXPECT O_ASSIGN
    call parse_expression
    call add_child
    EXPECT K_DO
    call parse_expression
    call add_child
    call parse_block
    call add_child
    DONE

; ================= Functions =================

; function = "скилл" IDENT "(" [ IDENT { "," IDENT } ] ")" block
parse_function:
    RULE R_FUNCTION
    EXPECT K_SKILL
    EXPECT_KIND T_IDENT, x_func
    EXPECT D_LPAREN
    CHECK T_IDENT
    jne .close
    TAKE
.params:
    CHECK D_COMMA
    jne .close
    TAKE
    EXPECT_KIND T_IDENT, x_param
    jmp .params
.close:
    EXPECT D_RPAREN
    call parse_block
    call add_child
    DONE

; return_stmt = "тп" [ expression ] ";"
parse_return_stmt:
    RULE R_RETURN_STMT
    EXPECT K_TP
    CHECK D_SEMI
    je .end
    call parse_expression
    call add_child
.end:
    EXPECT D_SEMI
    DONE

; call = IDENT "(" [ expression { "," expression } ] ")"
parse_call:
    RULE R_CALL
    EXPECT_KIND T_IDENT, x_func
    EXPECT D_LPAREN
    CHECK D_RPAREN
    je .close
    call parse_expression
    call add_child
.args:
    CHECK D_COMMA
    jne .close
    TAKE
    call parse_expression
    call add_child
    jmp .args
.close:
    EXPECT D_RPAREN
    DONE

; call_stmt = call ";"
parse_call_stmt:
    RULE R_CALL_STMT
    call parse_call
    call add_child
    EXPECT D_SEMI
    DONE

; ================= Expressions =================
; Уровни одинаковые: правило = операнд { оператор операнд }.
; Разбирает их общая процедура parse_binary.

; expression = and_expr { "или" and_expr }
parse_expression:
    push esi
    push ebx
    mov eax, R_EXPRESSION
    mov esi, parse_and_expr
    mov ebx, ops_or
    call parse_binary
    pop ebx
    pop esi
    ret

; and_expr = equality { "и" equality }
parse_and_expr:
    push esi
    push ebx
    mov eax, R_AND_EXPR
    mov esi, parse_equality
    mov ebx, ops_and
    call parse_binary
    pop ebx
    pop esi
    ret

; equality = comparison { ( "==" | "!=" ) comparison }
parse_equality:
    push esi
    push ebx
    mov eax, R_EQUALITY
    mov esi, parse_comparison
    mov ebx, ops_eq
    call parse_binary
    pop ebx
    pop esi
    ret

; comparison = sum { ( "<" | "<=" | ">" | ">=" ) sum }
parse_comparison:
    push esi
    push ebx
    mov eax, R_COMPARISON
    mov esi, parse_sum
    mov ebx, ops_cmp
    call parse_binary
    pop ebx
    pop esi
    ret

; sum = term { ( "хил" | "урон" ) term }
parse_sum:
    push esi
    push ebx
    mov eax, R_SUM
    mov esi, parse_term
    mov ebx, ops_sum
    call parse_binary
    pop ebx
    pop esi
    ret

; term = unary { ( "крит" | "сплит" | "ласт" ) unary }
parse_term:
    push esi
    push ebx
    mov eax, R_TERM
    mov esi, parse_unary
    mov ebx, ops_term
    call parse_binary
    pop ebx
    pop esi
    ret

; parse_binary: eax = правило, esi = процедура операнда, ebx = список операторов.
; Операнд, потом пока текущий токен — оператор из списка: оператор и ещё операнд.
parse_binary:
    push edi
    push eax
    call enter_rule
    pop eax
    call new_node
    mov edi, eax
    call esi                        ; первый операнд
    call add_child
.loop:
    xor eax, eax
    call peek
    mov edx, ebx
.find_op:
    mov ecx, [edx]
    test ecx, ecx
    jz .done                        ; не оператор этого уровня
    cmp eax, ecx
    je .operator
    add edx, 4
    jmp .find_op
.operator:
    TAKE
    call esi                        ; следующий операнд
    call add_child
    jmp .loop
.done:
    dec dword [depth]
    mov eax, edi
    pop edi
    ret

; unary = ( "урон" | "не" ) unary | factor
parse_unary:
    RULE R_UNARY
    CHECK O_URON
    je .prefix
    CHECK O_NOT
    je .prefix
    call parse_factor
    call add_child
    DONE
.prefix:
    TAKE
    call parse_unary                ; рекурсия: «урон урон 5», «не не флаг»
    call add_child
    DONE

; factor = NUMBER | call | target | "(" expression ")"
parse_factor:
    RULE R_FACTOR
    CHECK T_NUMBER
    je .number
    CHECK T_IDENT
    je .name
    CHECK D_LPAREN
    je .brackets
    mov esi, e_factor
    jmp error_text
.number:
    TAKE
    DONE
.name:
    CHECK_NEXT D_LPAREN             ; имя и «(» — вызов функции
    je .call
    call parse_target
    call add_child
    DONE
.call:
    call parse_call
    call add_child
    DONE
.brackets:
    TAKE
    call parse_expression           ; рекурсия: выражение в скобках
    call add_child
    EXPECT D_RPAREN
    DONE

; ================= печать дерева =================
; Как в my_code_EBNF.txt: номер узла, отступ 4 пробела на уровень.
; Цепочка правил с одним ребёнком-правилом пишется в строку через «→».

; print_tree: eax = корень
print_tree:
    mov dword [num_len], 0
    xor ecx, ecx
    call print_node
    ret

; print_node: eax = узел, ecx = глубина (рекурсивная)
print_node:
    pusha
    mov esi, eax
    mov ebp, ecx
    mov ecx, ebp                    ; отступ
    shl ecx, 2
    call print_spaces
    mov edx, [num_len]              ; номер узла
    test edx, edx
    jz .no_number
    mov ecx, num_buf
    call write
    mov al, ' '
    call print_char
.no_number:
    cmp dword [esi + ND_RULE], R_LEAF
    jne .rule
    call print_leaf
    call newline
    popa
    ret

.rule:
    mov eax, [esi + ND_RULE]
    call print_rule_name
.chain:                             ; ровно один ребёнок, и это правило — в ту же строку
    mov edx, [esi + ND_FIRST]
    test edx, edx
    jz .chain_done
    cmp dword [edx + ND_NEXT], 0
    jne .chain_done
    cmp dword [edx + ND_RULE], R_LEAF
    je .chain_done
    mov esi, edx
    PRINT arrow
    mov eax, [esi + ND_RULE]
    call print_rule_name
    jmp .chain
.chain_done:
    call newline

    mov edi, [num_len]              ; номер этого узла
    mov ebx, 1                      ; номер ребёнка
    mov esi, [esi + ND_FIRST]
.child:
    test esi, esi
    jz .children_done
    mov [num_len], edi              ; номер ребёнка = номер узла + "." + ebx
    test edi, edi
    jz .no_dot
    mov al, '.'
    call num_append_char
.no_dot:
    mov eax, ebx
    call num_append_uint
    mov eax, esi
    lea ecx, [ebp + 1]
    call print_node                 ; рекурсия: ребёнок печатается так же
    inc ebx
    mov esi, [esi + ND_NEXT]
    jmp .child
.children_done:
    mov [num_len], edi
    popa
    ret

; print_rule_name: eax = номер правила
print_rule_name:
    push esi
    mov esi, [rule_names + eax * 4]
    call print_z
    pop esi
    ret

; print_leaf: esi = лист. IDENT (хп), NUMBER (100), STRING ("GG") или «пик»
print_leaf:
    pusha
    mov ebx, [esi + ND_TOKEN]
    mov eax, [ebx + TK_TYPE]
    mov esi, l_ident
    cmp eax, T_IDENT
    je .with_name
    mov esi, l_number
    cmp eax, T_NUMBER
    je .with_name
    mov esi, l_string
    cmp eax, T_STRING
    je .with_name
    PRINT e_lquote
    call print_token
    PRINT e_rquote
    popa
    ret
.with_name:
    call print_z
    call print_token
    PRINT l_close
    popa
    ret

; print_token: ebx = токен — напечатать его текст
print_token:
    mov ecx, [ebx + TK_START]
    mov edx, [ebx + TK_LEN]
    call write
    ret

; num_append_char: al -> в конец num_buf
num_append_char:
    push edx
    mov edx, [num_len]
    cmp edx, NUM_BUF - 16           ; защита от переполнения буфера
    jae .done
    mov [num_buf + edx], al
    inc dword [num_len]
.done:
    pop edx
    ret

; num_append_uint: eax = число -> в конец num_buf
num_append_uint:
    pusha
    cmp dword [num_len], NUM_BUF - 16
    jae .done
    call uint_to_text
    mov esi, ecx
    mov edi, num_buf
    add edi, [num_len]
    add [num_len], edx
    mov ecx, edx
    rep movsb
.done:
    popa
    ret
