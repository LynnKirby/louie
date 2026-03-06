#undef NDEBUG

#include "src/arena.h"

#include <assert.h>
#include <stdint.h>
#include <stdlib.h>

#define SEED UINT64_C(123456789)
#define BLOCK_COUNT 1000
#define MAX_SIZE (1024*8)
#define REPEAT 3

static uint64_t pcg_state = SEED;

static uint32_t random(void) {
    uint32_t xor_shift =
        ((pcg_state >> UINT32_C(18)) ^ pcg_state) >> UINT32_C(27);
    uint32_t rotate = pcg_state >> UINT32_C(59);
    uint32_t result = (xor_shift >> rotate) | (xor_shift << ((-rotate) & 31));
    pcg_state = pcg_state * UINT64_C(6364136223846793005) + 1;
    return result;
}

typedef struct Block {
    uint32_t* data;
    size_t size;
    uint32_t pattern;
} Block;

int main(void) {
    Arena arena;
    arena_init(&arena);

    Block blocks[BLOCK_COUNT] = {0};

    for (int r = 0; r < REPEAT; r += 1) {
        if (r != 0) {
            arena_reset(&arena);
        }

        for (size_t i = 0; i < BLOCK_COUNT; i += 1) {
            size_t size = random() % MAX_SIZE;
            uint32_t pattern = random();

            uint32_t* data = arena_allocate(&arena, size * sizeof(uint32_t));
            assert(data != NULL);

            blocks[i].data = data;
            blocks[i].pattern = pattern;
            blocks[i].size = size;

            // Write a random pattern into the memory block.
            for (size_t j = 0; j < size; j += 1) {
                blocks[i].data[j] = pattern + j;
            }
        }

        // Check that each block still has the expected memory pattern.
        for (size_t i = 0; i < BLOCK_COUNT; i += 1) {
            uint32_t pattern = blocks[i].pattern;
            uint32_t* data = blocks[i].data;

            for (size_t j = 0; j < blocks[i].size; j += 1) {
                assert(data[j] == pattern + j);
            }
        }
    }

    arena_destroy(&arena);

    return 0;
}
