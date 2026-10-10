# Лабораторная работа №1. Обмен значений

Поменять местами два числа в регистрах для 32, 16 и 8 бит, по 4 способа:

1. Через временный регистр (`mov`)
2. Командой `xchg`
3. Через `xor`
4. Через `add` / `sub`

Числа: `0x11223344` и `0xAABBCCDD` (32 бита), `0x1122` и `0xAABB` (16 бит), `0x11` и `0xAA` (8 бит).

## Запуск

```bash
nasm -f elf32 -g -F dwarf lab1.asm -o lab1.o
ld -m elf_i386 lab1.o -o lab1
gdb -q ./lab1
```

В отладчике:

```
break _start
run
layout regs
next
```

Дальше `Enter` выполняет следующую строку, регистры видны в верхнем окне.

## Состояние регистров

Скриншоты отладчика GDB после каждого обмена.

32 бита
Способ 1 — MOV через временный регистр

<img width="796" height="403" alt="Screenshot 2026-10-10 172749" src="https://github.com/user-attachments/assets/01da1acd-2004-4f09-9de7-6cfcf4a5b7e6" />


Способ 2 — XCHG

<img width="810" height="424" alt="Screenshot 2026-10-10 172909" src="https://github.com/user-attachments/assets/d0c68be9-988a-497a-ba86-3676417ef653" />


Способ 3 — XOR

<img width="787" height="401" alt="image" src="https://github.com/user-attachments/assets/c3f723b2-1ec8-4f4f-8d5b-724c0b8bcd92" />


Способ 4 — ADD/SUB

<img width="816" height="410" alt="Screenshot 2026-10-10 173014" src="https://github.com/user-attachments/assets/e37bd54d-6263-421c-83de-2f1bade23d28" />


16 бит
Способ 1 — MOV через временный регистр

<img width="795" height="419" alt="Screenshot 2026-10-10 173107" src="https://github.com/user-attachments/assets/29c7e473-21dd-4a4d-b6d0-6c7b769a5260" />


Способ 2 — XCHG

<img width="800" height="414" alt="Screenshot 2026-10-10 173124" src="https://github.com/user-attachments/assets/fb8962f1-5b7f-4a0e-ac21-aaa8a5152336" />


Способ 3 — XOR

<img width="799" height="407" alt="Screenshot 2026-10-10 173143" src="https://github.com/user-attachments/assets/31744e03-e4da-49d7-bb0d-9c6e25f47f41" />


Способ 4 — ADD/SUB

<img width="770" height="384" alt="Screenshot 2026-10-10 174508" src="https://github.com/user-attachments/assets/9fa30a01-57c3-4c9c-82b8-4efc1a6f52b4" />


8 бит
Способ 1 — MOV через временный регистр

<img width="777" height="420" alt="Screenshot 2026-10-10 174536" src="https://github.com/user-attachments/assets/79ae68dc-fe77-4576-a94a-ca3cf48b2222" />


Способ 2 — XCHG

<img width="789" height="412" alt="Screenshot 2026-10-10 174556" src="https://github.com/user-attachments/assets/322717d1-087b-4f27-9434-0a71e6dbd9ce" />


Способ 3 — XOR

<img width="785" height="407" alt="Screenshot 2026-10-10 174618" src="https://github.com/user-attachments/assets/05d84eb5-efeb-43a8-89cb-68918e778086" />


Способ 4 — ADD/SUB

<img width="787" height="402" alt="Screenshot 2026-10-10 174637" src="https://github.com/user-attachments/assets/8beffd5a-5954-408d-b5ba-84953561c81a" />

