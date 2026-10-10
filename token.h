#pragma once

#include <string>

// Виды токенов языка «Рошан»
enum class TokenKind
{
    // ключевые слова
    Pick,         // пик       - начало программы
    GG,           // гг        - конец программы
    Hero,         // герой     - переменная
    Aegis,        // аегис     - константа
    Inventory,    // инвентарь - массив
    Ward,         // вард      - если
    Fog,          // туман     - иначе
    Farm,         // фармить   - цикл "пока"
    Wave,         // волна     - цикл со счётчиком
    To,           // до        - граница цикла "волна"
    Skill,        // скилл     - функция
    Tp,           // тп        - возврат из функции
    Ping,         // пинг      - вывод
    Buy,          // закуп     - ввод

    // операторы-слова
    Heal,         // хил   +
    Damage,       // урон  -
    Crit,         // крит  *
    Split,        // сплит /
    LastHit,      // ласт  %
    And,          // и
    Or,           // или
    Not,          // не

    // операторы-символы
    Assign,       // =
    Equal,        // ==
    NotEqual,     // !=
    Less,         // <
    LessEqual,    // <=
    Greater,      // >
    GreaterEqual, // >=

    // разделители
    Semicolon,    // ;
    Comma,        // ,
    LParen,       // (
    RParen,       // )
    LBrace,       // {
    RBrace,       // }
    LBracket,     // [
    RBracket,     // ]

    // значения
    Identifier,   // имя переменной, функции, массива
    Number,       // целое число
    String,       // строка в кавычках

    // служебные
    EndOfFile,
    Error
};

// Один токен: что это, как записано и где стоит в программе
struct Token
{
    TokenKind kind;
    std::string text;
    int line;
    int column;
};

std::string tokenCategory(TokenKind kind); // например, "ключевое слово"
std::string tokenMeaning(TokenKind kind);  // например, "сложение (+)"
