import re
import sys
from dataclasses import dataclass
from enum import Enum


class Kind(Enum):
    """Категории токенов."""
    KEYWORD = "ключевое слово"
    OPERATOR = "оператор"
    DELIMITER = "разделитель"
    IDENTIFIER = "идентификатор"
    NUMBER = "число"
    STRING = "строка"
    EOF = "конец файла"
    ERROR = "ОШИБКА"


KEYWORDS = {
    "пик":       "начало программы",
    "гг":        "конец программы",
    "герой":     "объявление переменной",
    "аегис":     "объявление константы",
    "инвентарь": "объявление массива",
    "вард":      "условие (если)",
    "туман":     "иначе",
    "фармить":   "цикл (пока)",
    "волна":     "цикл со счётчиком",
    "до":        "граница цикла",
    "скилл":     "объявление функции",
    "тп":        "возврат из функции",
    "пинг":      "вывод",
    "закуп":     "ввод",
}

WORD_OPERATORS = {
    "хил":  "сложение (+)",
    "урон": "вычитание (-)",
    "крит": "умножение (*)",
    "сплит": "деление (/)",
    "ласт": "остаток (%)",
    "и":    "логическое И",
    "или":  "логическое ИЛИ",
    "не":   "логическое НЕ",
}

SYMBOL_OPERATORS = {
    "=":  "присваивание",
    "==": "равно",
    "!=": "не равно",
    "<":  "меньше",
    "<=": "меньше или равно",
    ">":  "больше",
    ">=": "больше или равно",
}

DELIMITERS = {
    ";": "конец команды",
    ",": "запятая",
    "(": "открывающая скобка",
    ")": "закрывающая скобка",
    "{": "начало блока",
    "}": "конец блока",
    "[": "начало индекса",
    "]": "конец индекса",
}

HINTS = {
    "+": "сложение пишется словом «хил»",
    "-": "вычитание пишется словом «урон»",
    "*": "умножение пишется словом «крит»",
    "/": "деление пишется словом «сплит»",
    "%": "остаток пишется словом «ласт»",
    "!": "отрицание пишется словом «не»",
}

MAX_NUMBER = 2147483647  # самое большое число, которое помещается в 32-битный регистр

# Одно регулярное выражение на все виды лексем.
LETTER = "A-Za-zА-Яа-яЁё_"
TOKEN_REGEX = re.compile(rf"""
    (?P<space>    [ \t\r\n]+ )                    # пробелы и переводы строк
  | (?P<comment>  //[^\n]* )                      # комментарий до конца строки
  | (?P<badnum>   [0-9]+[{LETTER}][{LETTER}0-9]* ) # имя с цифры: 5крипов
  | (?P<number>   [0-9]+ )                        # целое число
  | (?P<word>     [{LETTER}][{LETTER}0-9]* )      # слово: ключевое, оператор или имя
  | (?P<string>   "(?:\\.|[^"\\\r\n])*" )         # строка в кавычках, внутри можно \" и \n
  | (?P<badstr>   "[^\r\n]* )                     # строка без закрывающей кавычки
  | (?P<symbol>   ==|!=|<=|>=|[=<>;,(){{}}\[\]] ) # операторы-символы и разделители
  | (?P<bad>      . )                             # любой другой символ - ошибка
""", re.VERBOSE)


@dataclass
class Token:
    kind: Kind      # категория
    text: str       # как записано в программе
    line: int       # строка
    column: int     # столбец
    meaning: str    # что это значит (или текст ошибки)

class Lexer:
    """Разбивает текст программы на токены."""

    def __init__(self, source):
        self.source = source
        self.errors = []

    def tokenize(self):
        tokens = []
        line = 1
        line_start = 0 

        for match in TOKEN_REGEX.finditer(self.source):
            group = match.lastgroup
            text = match.group()
            column = match.start() - line_start + 1

            if group == "space" or group == "comment":
                pass  
            elif group == "word":
                tokens.append(self.word_token(text, line, column))
            elif group == "number":
                if int(text) > MAX_NUMBER:
                    tokens.append(self.error(text, line, column, f"число больше {MAX_NUMBER}"))
                else:
                    tokens.append(Token(Kind.NUMBER, text, line, column, "целое число"))
            elif group == "string":
                tokens.append(Token(Kind.STRING, text, line, column, "текст для вывода"))
            elif group == "symbol":
                tokens.append(self.symbol_token(text, line, column))
            elif group == "badnum":
                tokens.append(self.error(text, line, column, "имя не может начинаться с цифры"))
            elif group == "badstr":
                tokens.append(self.error(text, line, column, "строка не закрыта кавычкой"))
            else: 
                tokens.append(self.error(text, line, column, HINTS.get(text, "неизвестный символ")))

            if "\n" in text:
                line += text.count("\n")
                line_start = match.start() + text.rfind("\n") + 1

        tokens.append(Token(Kind.EOF, "", line, len(self.source) - line_start + 1, ""))
        return tokens

    @staticmethod
    def word_token(text, line, column):
        if text in KEYWORDS:
            return Token(Kind.KEYWORD, text, line, column, KEYWORDS[text])
        if text in WORD_OPERATORS:
            return Token(Kind.OPERATOR, text, line, column, WORD_OPERATORS[text])
        return Token(Kind.IDENTIFIER, text, line, column, "имя")

    @staticmethod
    def symbol_token(text, line, column):
        if text in SYMBOL_OPERATORS:
            return Token(Kind.OPERATOR, text, line, column, SYMBOL_OPERATORS[text])
        return Token(Kind.DELIMITER, text, line, column, DELIMITERS[text])

    def error(self, text, line, column, message):
        self.errors.append(f"строка {line}, столбец {column}: {message}: {text}")
        return Token(Kind.ERROR, text, line, column, message)


def shorten(text, width):
    """Обрезать длинную лексему (например, строку), чтобы не ломать таблицу."""
    return text if len(text) <= width else text[:width - 1] + "…"


def run(path):
    """Прочитать файл, разобрать на токены и напечатать таблицу. Возвращает 0, если ошибок нет."""
    if not path.endswith(".dota"):
        print("Предупреждение: программы на «Рошане» обычно имеют расширение .dota")

    try:
        with open(path, encoding="utf-8-sig") as file:
            source = file.read()
    except OSError:
        print(f"Ошибка: не удалось открыть файл {path}")
        return 1
    except UnicodeDecodeError:
        print(f"Ошибка: файл {path} должен быть в кодировке UTF-8")
        return 1

    lexer = Lexer(source)
    tokens = lexer.tokenize()

    print(f"Файл: {path}\n")
    print(f"{'Позиция':<10}{'Лексема':<24}{'Категория':<17}Смысл")
    print("-" * 75)
    for token in tokens:
        position = f"{token.line}:{token.column}"
        print(f"{position:<10}{shorten(token.text, 22):<24}{token.kind.value:<17}{token.meaning}")

    print(f"\nВсего токенов: {len(tokens)}")
    if not lexer.errors:
        print("Лексических ошибок нет. GG WP!")
        return 0

    print(f"Лексических ошибок: {len(lexer.errors)}")
    for error in lexer.errors:
        print("  " + error)
    return 1


def main():
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")

    interactive = len(sys.argv) < 2 
    try:
        if interactive:
            path = input("Введите путь к файлу .dota (например, examples/factorial.dota): ")
            path = path.strip().strip('"') 
            print()
        else:
            path = sys.argv[1]

        if path:
            result = run(path)
        else:
            print("Использование: python lexer.py программа.dota")
            result = 1

        if interactive:
            input("\nНажмите Enter, чтобы выйти...")
    except EOFError:
        result = 1
    sys.exit(result)


if __name__ == "__main__":
    main()
