#include "src/base/arena.h"

#include <stdlib.h>

// TODO: Actually support arena allocation.
// This implementation using data separated from the slab list should be kept
// as a build option because it's useful when combined with sanitizers that
// check for buffer overflow.

struct ArenaSlab {
    ArenaSlab* next;
    void* data;
};

void arena_init(Arena* arena) {
    arena->full = NULL;
    arena->partial = NULL;
}

static void free_slab_list(ArenaSlab* slab) {
    while (slab != NULL) {
        ArenaSlab* next = slab->next;
        free(slab->data);
        free(slab);
        slab = next;
    }
}

void arena_destroy(Arena* arena) {
    free_slab_list(arena->full);
    free_slab_list(arena->partial);
}

void* arena_allocate(Arena* arena, size_t size) {
    void* data = malloc(size);

    if (data == NULL) {
        return NULL;
    }

    ArenaSlab* slab = malloc(sizeof(ArenaSlab));

    if (slab == NULL) {
        free(data);
        return NULL;
    }

    slab->data = data;
    slab->next = arena->full;
    arena->full = slab;
    return data;
}

void arena_reset(Arena* arena) {
    free_slab_list(arena->full);
    free_slab_list(arena->partial);
    arena->full = NULL;
    arena->partial = NULL;
}
