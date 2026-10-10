// Лексер языка «Рошан»: читает программу .dota и выводит таблицу токенов
//
// Сборка:  g++ -std=c++17 -Wall -o lexer src/main.cpp src/lexer.cpp src/token.cpp
// Запуск:  ./lexer examples/factorial.dota   (или без параметра - тогда программа спросит путь)

#include <fstream>
#include <iostream>
#include <sstream>
#include <string>
#include <vector>

#include "lexer.h"

#ifdef _WIN32
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#endif

// Длина строки в символах (русская буква в UTF-8 занимает 2 байта)
static size_t textLength(const std::string& s)
{
    size_t length = 0;
    for (unsigned char c : s)
    {
        if ((c & 0xC0) != 0x80)
            length++;
    }
    return length;
}

// Дополнить строку пробелами до нужной ширины, чтобы колонки таблицы были ровными
static std::string pad(const std::string& s, size_t width)
{
    size_t length = textLength(s);
    if (length >= width)
        return s + " ";
    return s + std::string(width - length, ' ');
}

// Обрезать слишком длинную лексему (например, строку), чтобы не ломать таблицу
static std::string shorten(const std::string& s, size_t maxLength)
{
    if (textLength(s) <= maxLength)
        return s;
    std::string result;
    size_t length = 0;
    for (unsigned char c : s)
    {
        if ((c & 0xC0) != 0x80 && ++length > maxLength - 1)
            break;
        result += static_cast<char>(c);
    }
    return result + "…";
}

static bool endsWith(const std::string& s, const std::string& suffix)
{
    return s.size() >= suffix.size() && s.compare(s.size() - suffix.size(), suffix.size(), suffix) == 0;
}

// Разбор файла и вывод таблицы; возвращает 0, если ошибок нет
static int run(const std::string& path);

int main(int argc, char* argv[])
{
#ifdef _WIN32
    SetConsoleOutputCP(CP_UTF8); // чтобы русский текст в консоли Windows не превращался в кракозябры
#endif

    std::string path;
    if (argc >= 2)
    {
        path = argv[1];
    }
    else
    {
        // запуск без параметров (например, из Visual Studio по Ctrl+F5) - спрашиваем путь
        std::cout << "Введите путь к файлу .dota (например, examples/factorial.dota): ";
        std::getline(std::cin, path);
        if (path.size() >= 2 && path.front() == '"' && path.back() == '"')
            path = path.substr(1, path.size() - 2); // Windows добавляет кавычки, если перетащить файл в консоль
        std::cout << "\n";
    }
    int result = 1;
    if (path.empty())
        std::cerr << "Использование: lexer программа.dota" << std::endl;
    else
        result = run(path);

    if (argc < 2)
    {
        std::cout << "\nНажмите Enter, чтобы выйти...";
        std::string dummy;
        std::getline(std::cin, dummy);
    }
    return result;
}

static int run(const std::string& path)
{
    if (!endsWith(path, ".dota"))
    {
        std::cerr << "Предупреждение: программы на «Рошане» обычно имеют расширение .dota" << std::endl;
    }

    std::ifstream file(path, std::ios::binary);
    if (!file)
    {
        std::cerr << "Ошибка: не удалось открыть файл " << path << std::endl;
        return 1;
    }
    std::stringstream buffer;
    buffer << file.rdbuf();

    Lexer lexer(buffer.str());
    std::vector<Token> tokens = lexer.tokenize();

    std::cout << "Файл: " << path << "\n\n";
    std::cout << pad("Позиция", 10) << pad("Лексема", 24) << pad("Категория", 17) << "Смысл\n";
    std::cout << std::string(75, '-') << "\n";
    for (const Token& token : tokens)
    {
        std::string position = std::to_string(token.line) + ":" + std::to_string(token.column);
        std::cout << pad(position, 10)
                  << pad(shorten(token.text, 22), 24)
                  << pad(tokenCategory(token.kind), 17)
                  << tokenMeaning(token.kind) << "\n";
    }

    std::cout << "\nВсего токенов: " << tokens.size() << "\n";

    const std::vector<std::string>& errors = lexer.errors();
    if (errors.empty())
    {
        std::cout << "Лексических ошибок нет. GG WP!\n";
        return 0;
    }

    std::cout << "Лексических ошибок: " << errors.size() << "\n";
    for (const std::string& error : errors)
    {
        std::cout << "  " << error << "\n";
    }
    return 1;
}
