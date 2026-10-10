# Лабораторная работа №2. Арифметические команды

Вариант 17:

$$X = \frac{2c + 51d}{d - a - 1}$$

a = 5678901, b = 6789012, c = 7890123, d = 8901234, e = 9012345, f = 10123456

## Результат

X = 469743180 / 3222332 = **145**, остаток **2505040**

- `EAX` = 145 — частное
- `EDX` = 2505040 — остаток

## Запуск

```bash
nasm -f elf32 -g -F dwarf lab2.asm -o lab2.o
ld -m elf_i386 lab2.o -o lab2
gdb -q ./lab2
```

В отладчике (строка 29 — `mov eax, 1`, расчёт уже закончен):

```
break 29
run
info registers eax ebx ecx edx
x/7dw &a
```

## Регистры и память

`EAX` = 145 (частное), `EDX` = 2505040 (остаток), `ECX` = 3222332 (знаменатель).
В памяти после чисел a…f лежит результат `res` = 145.

<img width="779" height="393" alt="Screenshot 2026-10-10 180513" src="https://github.com/user-attachments/assets/0e224837-c947-4791-aa0f-baf998242e46" />


## Проверка на калькуляторе

(2·7890123 + 8901234·51) / (8901234 − 5678901 − 1) = 469743180 / 3222332 = 145,777…

- целая часть 145 совпадает с `EAX`;
- остаток: 469743180 − 145·3222332 = 2505040, совпадает с `EDX`.

<img width="364" height="616" alt="Screenshot 2026-10-10 181107" src="https://github.com/user-attachments/assets/22cdc684-000d-48d8-8faf-eed8586a16c0" />
<img width="364" height="622" alt="Screenshot 2026-10-10 181128" src="https://github.com/user-attachments/assets/0f60d94f-4a2f-42ae-a6a1-07d54d1bdfe3" />
