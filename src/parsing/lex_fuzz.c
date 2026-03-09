#include "src/parsing/lex.h"
#include "src/ast/ast.h"

#include <assert.h>
#include <stddef.h>
#include <stdint.h>

int LLVMFuzzerTestOneInput(uint8_t const* data, size_t size) {
    AstContext* ast_context = ast_context_new();

    Lexer lexer;
    lexer_init(&lexer, (char const*)data, size, ast_context);

    for (;;) {
        Token token;
        lexer_next(&lexer, &token);
        // TODO: validate token state.
        if (token.kind == TokenKind_EndOfFile) {
            break;
        }
    }

    lexer_destroy(&lexer);

    ast_context_delete(ast_context);

    return 0;
}
