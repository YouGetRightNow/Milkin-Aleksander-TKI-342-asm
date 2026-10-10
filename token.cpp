#include "token.h"

std::string tokenCategory(TokenKind kind)
{
    switch (kind)
    {
    case TokenKind::Pick: case TokenKind::GG: case TokenKind::Hero:
    case TokenKind::Aegis: case TokenKind::Inventory: case TokenKind::Ward:
    case TokenKind::Fog: case TokenKind::Farm: case TokenKind::Wave:
    case TokenKind::To: case TokenKind::Skill: case TokenKind::Tp:
    case TokenKind::Ping: case TokenKind::Buy:
        return "ключевое слово";

    case TokenKind::Heal: case TokenKind::Damage: case TokenKind::Crit:
    case TokenKind::Split: case TokenKind::LastHit: case TokenKind::And:
    case TokenKind::Or: case TokenKind::Not:
    case TokenKind::Assign: case TokenKind::Equal: case TokenKind::NotEqual:
    case TokenKind::Less: case TokenKind::LessEqual: case TokenKind::Greater:
    case TokenKind::GreaterEqual:
        return "оператор";

    case TokenKind::Semicolon: case TokenKind::Comma:
    case TokenKind::LParen: case TokenKind::RParen:
    case TokenKind::LBrace: case TokenKind::RBrace:
    case TokenKind::LBracket: case TokenKind::RBracket:
        return "разделитель";

    case TokenKind::Identifier: return "идентификатор";
    case TokenKind::Number:     return "число";
    case TokenKind::String:     return "строка";
    case TokenKind::EndOfFile:  return "конец файла";
    case TokenKind::Error:      return "ОШИБКА";
    }
    return "?";
}

std::string tokenMeaning(TokenKind kind)
{
    switch (kind)
    {
    case TokenKind::Pick:         return "начало программы";
    case TokenKind::GG:           return "конец программы";
    case TokenKind::Hero:         return "объявление переменной";
    case TokenKind::Aegis:        return "объявление константы";
    case TokenKind::Inventory:    return "объявление массива";
    case TokenKind::Ward:         return "условие (если)";
    case TokenKind::Fog:          return "иначе";
    case TokenKind::Farm:         return "цикл (пока)";
    case TokenKind::Wave:         return "цикл со счётчиком";
    case TokenKind::To:           return "граница цикла";
    case TokenKind::Skill:        return "объявление функции";
    case TokenKind::Tp:           return "возврат из функции";
    case TokenKind::Ping:         return "вывод";
    case TokenKind::Buy:          return "ввод";

    case TokenKind::Heal:         return "сложение (+)";
    case TokenKind::Damage:       return "вычитание (-)";
    case TokenKind::Crit:         return "умножение (*)";
    case TokenKind::Split:        return "деление (/)";
    case TokenKind::LastHit:      return "остаток (%)";
    case TokenKind::And:          return "логическое И";
    case TokenKind::Or:           return "логическое ИЛИ";
    case TokenKind::Not:          return "логическое НЕ";

    case TokenKind::Assign:       return "присваивание";
    case TokenKind::Equal:        return "равно";
    case TokenKind::NotEqual:     return "не равно";
    case TokenKind::Less:         return "меньше";
    case TokenKind::LessEqual:    return "меньше или равно";
    case TokenKind::Greater:      return "больше";
    case TokenKind::GreaterEqual: return "больше или равно";

    case TokenKind::Semicolon:    return "конец команды";
    case TokenKind::Comma:        return "запятая";
    case TokenKind::LParen:       return "открывающая скобка";
    case TokenKind::RParen:       return "закрывающая скобка";
    case TokenKind::LBrace:       return "начало блока";
    case TokenKind::RBrace:       return "конец блока";
    case TokenKind::LBracket:     return "начало индекса";
    case TokenKind::RBracket:     return "конец индекса";

    case TokenKind::Identifier:   return "имя";
    case TokenKind::Number:       return "целое число";
    case TokenKind::String:       return "текст для вывода";
    case TokenKind::EndOfFile:    return "";
    case TokenKind::Error:        return "см. список ошибок ниже";
    }
    return "";
}
