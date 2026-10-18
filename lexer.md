# Лексер Рошан

## Словарь
| Слово | Значение | Аналог |
|---|---|---|
| `пик` | начало программы | `main` / `begin` |
| `гг` | конец программы | `end` |
| `герой` | объявление переменной | `int x` |
| `аегис` | объявление константы | `const` |
| `инвентарь` | объявление массива | `int a[6]` |
| `вард` | условие «если» | `if` |
| `туман` | «иначе» | `else` |
| `фармить` | цикл «пока» | `while` |
| `волна` | цикл со счётчиком | `for` |
| `до` | до какого значения идёт счётчик (включительно) | `i <= 10` |
| `скилл` | объявление функции | `def` / `function` |
| `тп` | возврат из функции | `return` |
| `пинг` | вывод на экран | `print` |
| `закуп` | ввод с клавиатуры | `input` / `scanf` |
| `хил` | сложение | `+` |
| `урон` | вычитание, минус перед числом | `-` |
| `крит` | умножение | `*` |
| `сплит` | деление нацело | `/` |
| `ласт` | остаток от деления | `%` |
| `и` | логическое И | `&&` / `and` |
| `или` | логическое ИЛИ | `\|\|` / `or` |
| `не` | логическое НЕ | `!` / `not` |

| Знак | Значение |
|---|---|
| `=` | присваивание |
| `==` `!=` | равно, не равно |
| `<` `<=` `>` `>=` | меньше, меньше или равно, больше, больше или равно |
| `;` | конец команды |
| `,` | разделяет параметры и аргументы функции |
| `( )` | условие, параметры функции, порядок вычислений |
| `{ }` | начало и конец блока |
| `[ ]` | размер и индекс массива |
| `//` | комментарий до конца строки |

## Program
```roshan
program = { function } "пик" { statement } "гг"
block = "{" { statement } "}"
```

## Values
```roshan
var_stmt = "герой" IDENT [ "=" expression ] ";"
const_stmt = "аегис" IDENT "=" expression ";"
array_stmt = "инвентарь" IDENT "[" NUMBER "]" ";"
assign_stmt = target "=" expression ";"
target = IDENT [ "[" expression "]" ]
```

## Expressions
```roshan
expression = and_expr { "или" and_expr }
and_expr = equality { "и" equality }
equality = comparison { ( "==" | "!=" ) comparison }
comparison = sum { ( "<" | "<=" | ">" | ">=" ) sum }
sum = term { ( "хил" | "урон" ) term }
term = unary { ( "крит" | "сплит" | "ласт" ) unary }
unary = ( "урон" | "не" ) unary | factor
factor = NUMBER | call | target | "(" expression ")"
```

## Condition constructions
```roshan
if_stmt = "вард" "(" expression ")" block [ "туман" ( block | if_stmt ) ]
```

## Cycles
```roshan
while_stmt = "фармить" "(" expression ")" block
for_stmt = "волна" IDENT "=" expression "до" expression block
```

## Functions
```roshan
function = "скилл" IDENT "(" [ IDENT { "," IDENT } ] ")" block
return_stmt = "тп" [ expression ] ";"
call = IDENT "(" [ expression { "," expression } ] ")"
call_stmt = call ";"
```

## Base
```roshan
print_stmt = "пинг" ( expression | STRING ) ";"
input_stmt = "закуп" target ";"
statement = var_stmt | const_stmt | array_stmt | assign_stmt | if_stmt | while_stmt | for_stmt | return_stmt | print_stmt | input_stmt | call_stmt
```

## Tokens
```roshan
IDENT = letter { letter | digit }
NUMBER = digit { digit }
STRING = '"' { ? любой символ, кроме кавычки и перевода строки ? } '"'
letter = ? русская или латинская буква ? | "_"
digit = "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9"
KEYWORD = "пик" | "гг" | "герой" | "аегис" | "инвентарь" | "вард" | "туман" | "фармить" | "волна" | "до" | "скилл" | "тп" | "пинг" | "закуп"
OPERATOR = "хил" | "урон" | "крит" | "сплит" | "ласт" | "и" | "или" | "не" | "=" | "==" | "!=" | "<" | "<=" | ">" | ">="
DELIMITER = ";" | "," | "(" | ")" | "{" | "}" | "[" | "]"
COMMENT = "//" { ? любой символ, кроме перевода строки ? }
```
