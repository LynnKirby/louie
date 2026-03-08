#include "src/parse.h"

#include <stddef.h>
#include <stdint.h>

int LLVMFuzzerTestOneInput(uint8_t const* data, size_t size) {
    AstContext* ast_context = ast_context_new();

    Arena ast_arena;
    arena_init(&ast_arena);

    ParseResult parse_result;
    parse_bytes(
        &parse_result, ast_context, &ast_arena, (char const*)data, size
    );

    arena_destroy(&ast_arena);
    ast_context_delete(ast_context);

    return 0;
}
