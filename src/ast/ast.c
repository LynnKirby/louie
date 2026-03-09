#include "src/ast/ast.h"
#include "src/base/arena.h"

#include <stdint.h>
#include <string.h>

// TODO: use hash map
struct AstString {
    AstString* next;
    char const* data;
    size_t size;
};

struct AstContext {
    Arena arena;
    AstString* strings;
};

AstContext* ast_context_new(void) {
    Arena arena;
    arena_init(&arena);
    AstContext* context = arena_allocate(&arena, sizeof(AstContext));

    if (context == NULL) {
        arena_destroy(&arena);
        return NULL;
    }

    context->arena = arena;
    context->strings = NULL;
    return context;
}

void ast_context_delete(AstContext* context) {
    if (context != NULL) {
        Arena arena = context->arena;
        arena_destroy(&arena);
    }
}

size_t ast_string_size(AstString* string) {
    return string->size;
}

char const* ast_string_data(AstString* string) {
    return string->data;
}

AstString* ast_string_new(AstContext* context, char const* data, size_t size) {
    AstString* s = context->strings;

    // We include nul terminator in allocated string. Check if size is too big
    // for it. This mostly exists to prevent integer wrap around when doing
    // size + 1 when allocating.
    if (size == SIZE_MAX) {
        return NULL;
    }

    while (s != NULL) {
        if (s->size == size && memcmp(s->data, data, size) == 0) {
            return s;
        }
        s = s->next;
    }

    s = arena_allocate(&context->arena, sizeof(AstString));

    if (s == NULL) {
        return NULL;
    }

    char* new_data = arena_allocate(&context->arena, size + 1);

    if (new_data == NULL) {
        return NULL;
    }

    memcpy(new_data, data, size);
    new_data[size] = 0; // nul terminator

    s->data = new_data;
    s->size = size;
    s->next = context->strings;
    context->strings = s;

    return s;
}
