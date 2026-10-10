#pragma once

#include <string>
#include <vector>
#include "token.h"

// Лексер: разбивает текст программы на токены
class Lexer
{
public:
    explicit Lexer(const std::string& source);

    std::vector<Token> tokenize();                  // все токены, последний - EndOfFile
    const std::vector<std::string>& errors() const; // найденные ошибки

private:
    std::string src;
    size_t pos = 0;  // текущий байт
    int line = 1;    // текущая строка
    int column = 1;  // текущий столбец (в символах, а не в байтах)
    std::vector<std::string> errorList;

    bool atEnd() const;
    unsigned char peek(size_t offset = 0) const;
    void advance();             // сдвинуться на один байт
    void advanceChar();         // сдвинуться на один символ (русская буква = 2 байта)
    bool isLetterAt(size_t p) const;
    bool isDigitAt(size_t p) const;

    void skipSpacesAndComments();
    Token readWord();
    Token readNumber();
    Token readString();
    Token readSymbol();
    Token makeError(const std::string& text, int errLine, int errColumn, const std::string& message);
};
