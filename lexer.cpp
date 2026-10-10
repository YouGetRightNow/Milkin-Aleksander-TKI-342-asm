#include "lexer.h"

#include <unordered_map>

// Русские слова в этом файле должны попасть в программу в кодировке UTF-8 (как и файлы .dota).
// В Visual Studio для этого нужен флаг /utf-8, иначе сборка остановится здесь.
static_assert(static_cast<unsigned char>("п"[0]) == 0xD0 && static_cast<unsigned char>("п"[1]) == 0xBF,
              "Compile with /utf-8 (Project Properties -> C/C++ -> Command Line -> Additional Options)");

// Ключевые слова и операторы-слова языка
static const std::unordered_map<std::string, TokenKind> KEYWORDS =
{
    {"пик",       TokenKind::Pick},
    {"гг",        TokenKind::GG},
    {"герой",     TokenKind::Hero},
    {"аегис",     TokenKind::Aegis},
    {"инвентарь", TokenKind::Inventory},
    {"вард",      TokenKind::Ward},
    {"туман",     TokenKind::Fog},
    {"фармить",   TokenKind::Farm},
    {"волна",     TokenKind::Wave},
    {"до",        TokenKind::To},
    {"скилл",     TokenKind::Skill},
    {"тп",        TokenKind::Tp},
    {"пинг",      TokenKind::Ping},
    {"закуп",     TokenKind::Buy},
    {"хил",       TokenKind::Heal},
    {"урон",      TokenKind::Damage},
    {"крит",      TokenKind::Crit},
    {"сплит",     TokenKind::Split},
    {"ласт",      TokenKind::LastHit},
    {"и",         TokenKind::And},
    {"или",       TokenKind::Or},
    {"не",        TokenKind::Not},
};

Lexer::Lexer(const std::string& source)
    : src(source)
{
    // Блокнот Windows иногда пишет в начало файла метку UTF-8 (BOM) - пропускаем её
    if (src.compare(0, 3, "\xEF\xBB\xBF") == 0)
    {
        pos = 3;
    }
}

const std::vector<std::string>& Lexer::errors() const
{
    return errorList;
}

std::vector<Token> Lexer::tokenize()
{
    std::vector<Token> tokens;
    while (true)
    {
        skipSpacesAndComments();
        if (atEnd())
        {
            tokens.push_back({TokenKind::EndOfFile, "", line, column});
            break;
        }

        if (isLetterAt(pos))
            tokens.push_back(readWord());
        else if (isDigitAt(pos))
            tokens.push_back(readNumber());
        else if (peek() == '"')
            tokens.push_back(readString());
        else
            tokens.push_back(readSymbol());
    }
    return tokens;
}

// ---------- перемещение по тексту ----------

bool Lexer::atEnd() const
{
    return pos >= src.size();
}

unsigned char Lexer::peek(size_t offset) const
{
    if (pos + offset >= src.size())
        return 0;
    return static_cast<unsigned char>(src[pos + offset]);
}

void Lexer::advance()
{
    unsigned char c = peek();
    pos++;
    if (c == '\n')
    {
        line++;
        column = 1;
    }
    else if ((c & 0xC0) != 0x80) // байты-продолжения UTF-8 (10xxxxxx) не считаем
    {
        column++;
    }
}

void Lexer::advanceChar()
{
    advance();
    while (!atEnd() && (peek() & 0xC0) == 0x80)
        advance();
}

// Буква: латинская, русская (в UTF-8 начинается с байта D0 или D1) или '_'
bool Lexer::isLetterAt(size_t p) const
{
    if (p >= src.size())
        return false;
    unsigned char c = static_cast<unsigned char>(src[p]);
    if ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_')
        return true;
    if ((c == 0xD0 || c == 0xD1) && p + 1 < src.size())
        return (static_cast<unsigned char>(src[p + 1]) & 0xC0) == 0x80;
    return false;
}

bool Lexer::isDigitAt(size_t p) const
{
    return p < src.size() && src[p] >= '0' && src[p] <= '9';
}

// ---------- пропуск пробелов и комментариев ----------

void Lexer::skipSpacesAndComments()
{
    while (!atEnd())
    {
        unsigned char c = peek();
        if (c == ' ' || c == '\t' || c == '\r' || c == '\n')
        {
            advance();
        }
        else if (c == '/' && peek(1) == '/') // комментарий до конца строки
        {
            while (!atEnd() && peek() != '\n')
                advance();
        }
        else
        {
            break;
        }
    }
}

// ---------- чтение токенов ----------

// Слово: ключевое слово, оператор-слово или имя
Token Lexer::readWord()
{
    int startLine = line, startColumn = column;
    size_t start = pos;
    while (isLetterAt(pos) || isDigitAt(pos))
        advanceChar();

    std::string word = src.substr(start, pos - start);
    auto it = KEYWORDS.find(word);
    TokenKind kind = (it != KEYWORDS.end()) ? it->second : TokenKind::Identifier;
    return {kind, word, startLine, startColumn};
}

// Целое число от 0 до 2147483647 (помещается в 32-битный регистр)
Token Lexer::readNumber()
{
    int startLine = line, startColumn = column;
    size_t start = pos;
    while (isDigitAt(pos))
        advance();

    if (isLetterAt(pos)) // например, 5крипов
    {
        while (isLetterAt(pos) || isDigitAt(pos))
            advanceChar();
        return makeError(src.substr(start, pos - start), startLine, startColumn,
                         "имя не может начинаться с цифры");
    }

    std::string text = src.substr(start, pos - start);
    size_t firstNonZero = text.find_first_not_of('0');
    std::string digits = (firstNonZero == std::string::npos) ? "0" : text.substr(firstNonZero);
    if (digits.size() > 10 || (digits.size() == 10 && digits > "2147483647"))
    {
        return makeError(text, startLine, startColumn, "число больше 2147483647");
    }
    return {TokenKind::Number, text, startLine, startColumn};
}

// Строка в двойных кавычках, внутри можно \" и \n
Token Lexer::readString()
{
    int startLine = line, startColumn = column;
    size_t start = pos;
    advance(); // открывающая кавычка
    while (!atEnd() && peek() != '"' && peek() != '\n')
    {
        if (peek() == '\\' && peek(1) != 0 && peek(1) != '\n')
            advance(); // пропускаем обратную косую черту, следующий символ берём как есть
        advanceChar();
    }

    if (atEnd() || peek() == '\n')
    {
        return makeError(src.substr(start, pos - start), startLine, startColumn,
                         "строка не закрыта кавычкой");
    }
    advance(); // закрывающая кавычка
    return {TokenKind::String, src.substr(start, pos - start), startLine, startColumn};
}

// Операторы-символы и разделители
Token Lexer::readSymbol()
{
    int startLine = line, startColumn = column;
    unsigned char c = peek();
    unsigned char next = peek(1);

    // двухсимвольные операторы
    if (next == '=' && (c == '=' || c == '!' || c == '<' || c == '>'))
    {
        advance();
        advance();
        TokenKind kind = (c == '=') ? TokenKind::Equal
                       : (c == '!') ? TokenKind::NotEqual
                       : (c == '<') ? TokenKind::LessEqual
                       :              TokenKind::GreaterEqual;
        return {kind, std::string(1, static_cast<char>(c)) + "=", startLine, startColumn};
    }

    TokenKind kind;
    switch (c)
    {
    case '=': kind = TokenKind::Assign;    break;
    case '<': kind = TokenKind::Less;      break;
    case '>': kind = TokenKind::Greater;   break;
    case ';': kind = TokenKind::Semicolon; break;
    case ',': kind = TokenKind::Comma;     break;
    case '(': kind = TokenKind::LParen;    break;
    case ')': kind = TokenKind::RParen;    break;
    case '{': kind = TokenKind::LBrace;    break;
    case '}': kind = TokenKind::RBrace;    break;
    case '[': kind = TokenKind::LBracket;  break;
    case ']': kind = TokenKind::RBracket;  break;
    default:
    {
        // в «Рошане» арифметика пишется словами - подсказываем, каким
        std::string hint;
        switch (c)
        {
        case '+': hint = "сложение пишется словом «хил»";   break;
        case '-': hint = "вычитание пишется словом «урон»"; break;
        case '*': hint = "умножение пишется словом «крит»"; break;
        case '/': hint = "деление пишется словом «сплит»";  break;
        case '%': hint = "остаток пишется словом «ласт»";   break;
        case '!': hint = "отрицание пишется словом «не»";   break;
        default:  hint = "неизвестный символ";              break;
        }
        size_t start = pos;
        advanceChar();
        return makeError(src.substr(start, pos - start), startLine, startColumn, hint);
    }
    }

    advance();
    return {kind, std::string(1, static_cast<char>(c)), startLine, startColumn};
}

Token Lexer::makeError(const std::string& text, int errLine, int errColumn, const std::string& message)
{
    errorList.push_back("строка " + std::to_string(errLine) + ", столбец " + std::to_string(errColumn)
                        + ": " + message + ": " + text);
    return {TokenKind::Error, text, errLine, errColumn};
}
