#include "src/parse.h"
#include "src/eval.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(int argc, char const* argv[]) {
    int status = 0;

    if (argc != 2) {
        fprintf(stderr, "usage: %s <file>\n", "louie");
        return 1;
    }

    char const* path = argv[1];

    FILE* f = fopen(path, "rb");
    if (f == NULL) {
        fprintf(stderr, "error: could not open '%s'\n", path);
        return 1;
    }

    char* data = NULL;
    size_t size = 0;
    AstContext* ast_context = NULL;

    for (;;) {
        char chunk[1024];
        size_t res = fread(chunk, 1, sizeof(chunk), f);

        if (res > 0) {
            char* new_data = realloc(data, size + res);
            if (new_data == NULL) {
                fprintf(stderr, "error: out of memory\n");
                status = 1;
                goto exit;
            }
            data = new_data;
            memcpy(data + size, chunk, res);
            size += res;
        }

        if (res < sizeof(chunk)) {
            if (feof(f)) break;
            fprintf(stderr, "error: failed reading '%s'\n", path);
            status = 1;
            goto exit;
        }
    }

    fclose(f);

    ast_context = ast_context_new();
    if (ast_context == NULL) {
        fprintf(stderr, "error: out of memory\n");
        goto exit;
    }

    Arena ast_arena;
    arena_init(&ast_arena);

    printf("=== PARSE ===\n");
    Stmt* file_stmts = parse_bytes(ast_context, &ast_arena, data, size);
    dump_stmt_seq(stdout, file_stmts, 0);

    printf("=== EVAL ===\n");
    eval(file_stmts);

    arena_destroy(&ast_arena);

exit:
    ast_context_delete(ast_context);
    free(data);

    return status;
}
