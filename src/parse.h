#ifndef _louie_src_parse_h
#define _louie_src_parse_h

#include "src/ast.h"
#include "src/arena.h"

#include <stddef.h>

typedef enum SyntaxErrorKind {
    SyntaxErrorKind_UnexpectedCharacter,
    SyntaxErrorKind_UnexpectedToken,
} SyntaxErrorKind;

typedef struct SyntaxError {
    SyntaxErrorKind kind;
    int line;
    int column;
} SyntaxError;

typedef enum ParseResultKind {
    ParseResultKind_Success,
    ParseResultKind_SyntaxError,
    ParseResultKind_OutOfMemory,
} ParseResultKind;

typedef struct ParseResult {
    ParseResultKind kind;
    union {
        AstFile* file;
        SyntaxError syntax_error;
    } as;
} ParseResult;

void parse_bytes(
    ParseResult* result,
    AstContext* context,
    Arena* arena,
    char const* data,
    size_t size
);

#endif
