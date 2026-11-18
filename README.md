# Лабораторная работа №4. Логические команды и команды манипулирования битами

Вариант 17: число `1245DBCC`

1. Занести число в память.
2. Подсчитать количество нулей и единиц двумя способами.
3. Подсчитать количество парных нулей и парных единиц.
4. В младшем байте обменять биты 0-7, 1-6, 2-5, 3-4.

## Результат

- единиц 15, нулей 17 (оба способа)
- пар `00` — 5, пар `11` — 4
- после обмена битов: `1245DB33`

## Запуск

```bash
nasm -f elf32 -g -F dwarf lab4.asm -o lab4.o
ld -m elf_i386 lab4.o -o lab4
./lab4
```

## Терминал

<img width="526" height="130" alt="image" src="https://github.com/user-attachments/assets/ef1c81cd-affe-4b57-9d8f-4d7c318c47ca" />


## Память

```
gdb -q ./lab4
break finish
run
x/8xw &num
```

<img width="617" height="36" alt="image" src="https://github.com/user-attachments/assets/bb3a7982-2edc-4b81-99a7-cb601bbf78f5" />


## Проверка на калькуляторе

<img width="866" height="333" alt="image" src="https://github.com/user-attachments/assets/50b5a7a4-223a-4943-a542-8ebfe2acf903" />


