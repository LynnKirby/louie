#ifndef _louie_src_parsing_lex_h
#define _louie_src_parsing_lex_h

#include <stddef.h>
#include <stdint.h>

struct AstContext;
struct AstString;

typedef enum TokenKind {
    #define TOKEN_KIND(name) TokenKind_##name,
    #include "src/parsing/token_kind.def"
} TokenKind;

typedef struct Token {
    TokenKind kind;
    int line;
    int column;
    union {
        struct AstString* string;
        int integer;
    } as;
} Token;

typedef struct Lexer {
    uint8_t const* cursor;
    uint8_t const* limit;
    struct AstContext* ast_context;
    int cursor_line;
    int cursor_column;
} Lexer;

void lexer_init(
    Lexer* lexer,
    char const* data,
    size_t size,
    struct AstContext* ast_context
);

void lexer_destroy(Lexer* lexer);

void lexer_next(Lexer* lexer, Token* token);

#endif
