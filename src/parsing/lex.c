#include "src/parsing/lex.h"
#include "src/ast/ast.h"

#include <stdbool.h>
#include <string.h>

void lexer_init(
    Lexer* lexer,
    char const* data,
    size_t size,
    struct AstContext* ast_context
) {
    lexer->cursor = (uint8_t const*)data;
    lexer->limit = lexer->cursor + size;
    lexer->ast_context = ast_context;
    lexer->cursor_line = 1;
    lexer->cursor_column = 1;
}

void lexer_destroy(Lexer* lexer) {
    (void)lexer;
    // Currently a no-op.
}

static bool is_id_start(uint8_t c) {
    return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c == '_');
}

static bool is_id_continue(uint8_t c) {
    return is_id_start(c) || (c >= '0' && c <= '9');
}

static TokenKind keyword_or_id(uint8_t const* data, size_t size) {
    #define KEYWORD_TOKEN_KIND(name, spelling)  \
        if (                                    \
            (sizeof(spelling) - 1 == size) &&   \
            (memcmp(spelling, data, size) == 0) \
        ) {                                     \
            return TokenKind_##name;            \
        }

    #include "src/parsing/token_kind.def"

    return TokenKind_Identifier;
}

void lexer_next(Lexer* lexer, Token* token) {
loop:
    token->line = lexer->cursor_line;
    token->column = lexer->cursor_column;

    if (lexer->cursor == lexer->limit) {
        token->kind = TokenKind_EndOfFile;
        return;
    }

    if (is_id_start(*lexer->cursor)) {
        uint8_t const* start = lexer->cursor;
        lexer->cursor += 1;
        lexer->cursor_column += 1;

        while (
            (lexer->cursor < lexer->limit) &&
            is_id_continue(*lexer->cursor)
        ) {
            lexer->cursor += 1;
            lexer->cursor_column += 1;
        }

        size_t size = lexer->cursor - start;
        token->kind = keyword_or_id(start, size);

        if (token->kind == TokenKind_Identifier) {
            token->as.string = ast_string_new(
                lexer->ast_context, (char const*)start, size
            );
        }

        return;
    }

    uint8_t c = *lexer->cursor;

    if (c == '0') {
        // TODO: report actual error (leading zero not allowed)
        goto unexpected_character;
    }

    if (c >= '1' && c <= '9') {
        unsigned i = c - '0';
        lexer->cursor += 1;
        lexer->cursor_column += 1;
        for (;;) {
            if (lexer->cursor == lexer->limit) break;
            c = *lexer->cursor;
            if (c < '0' || c > '9') break;
            i *= 10;
            i += c - '0';
            lexer->cursor += 1;
            lexer->cursor_column += 1;
        }

        if (lexer->cursor < lexer->limit) {
            c = *lexer->cursor;
            if (is_id_continue(c)) {
                // TODO: report the actual error (trailing junk after literal)
                goto unexpected_character;
            }
        }

        token->kind = TokenKind_IntLiteral;
        token->as.integer = i;
        return;
    }

    switch (c) {
    // Line comment.
    case '#':
        lexer->cursor += 1;
        lexer->cursor_column += 1;
        for (;;) {
            if (lexer->cursor == lexer->limit) break;
            if (*lexer->cursor == '\r') break;
            if (*lexer->cursor == '\n') break;
            lexer->cursor += 1;
            lexer->cursor_column += 1;
        }
        goto loop;

    // Whitespace.
    case ' ':
    case '\t':
        lexer->cursor += 1;
        lexer->cursor_column += 1;
        goto loop;

    // Newline.
    case '\r':
        if (lexer->cursor + 1 < lexer->limit && *lexer->cursor == '\n') {
            // CR LF
            lexer->cursor += 1;
        }
        // fallthrough
    case '\n':
        lexer->cursor += 1;
        lexer->cursor_line += 1;
        lexer->cursor_column = 1;
        goto loop;

    #define SYMBOL_X(name, ch)              \
        case ch:                            \
            lexer->cursor += 1;             \
            lexer->cursor_column += 1;      \
            token->kind = TokenKind_##name; \
            return;

    #define SYMBOL_XE(name, ch)                                          \
        case ch:                                                         \
            lexer->cursor += 1;                                          \
            lexer->cursor_column += 1;                                   \
            if (lexer->cursor < lexer->limit && *lexer->cursor == '=') { \
                lexer->cursor += 1;                                      \
                lexer->cursor_column += 1;                               \
                token->kind = TokenKind_##name##Equal;                   \
                return;                                                  \
            }                                                            \
            token->kind = TokenKind_##name;                              \
            return;

    SYMBOL_X(OpenParen, '(')
    SYMBOL_X(CloseParen, ')')
    SYMBOL_X(Semicolon, ';')
    SYMBOL_X(Plus, '+')
    SYMBOL_X(Minus, '-')

    SYMBOL_XE(Equal, '=')
    SYMBOL_XE(Exclaim, '!')

    case '&':
        if (lexer->cursor + 1 < lexer->limit) {
            if (lexer->cursor[1] == '&') {
                lexer->cursor += 2;
                lexer->cursor_column += 2;
                token->kind = TokenKind_AmpAmp;
                return;
            }
        }
        break;

    case '|':
        if (lexer->cursor + 1 < lexer->limit) {
            if (lexer->cursor[1] == '|') {
                lexer->cursor += 2;
                lexer->cursor_column += 2;
                token->kind = TokenKind_BarBar;
                return;
            }
        }
        break;
    }

unexpected_character:
    // TODO: report character
    token->line = lexer->cursor_line;
    token->column = lexer->cursor_column;
    token->kind = TokenKind_UnexpectedCharacter;
    lexer->cursor += 1;
    lexer->cursor_column += 1;
}
