#ifndef _louie_src_arena_h
#define _louie_src_arena_h

#include <stddef.h>

typedef struct ArenaSlab ArenaSlab;

/// Arena allocator.
typedef struct Arena {
    ArenaSlab* full;
    ArenaSlab* partial;
} Arena;

void arena_init(Arena* arena);
void arena_destroy(Arena* arena);
void* arena_allocate(Arena* arena, size_t size);
void arena_reset(Arena* arena);

#endif
