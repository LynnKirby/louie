#ifndef _louie_src_parse_h
#define _louie_src_parse_h

#include "src/ast.h"
#include "src/arena.h"

#include <stddef.h>

Stmt* parse_bytes(
    AstContext* context,
    Arena* arena,
    char const* data,
    size_t size
);

#endif
