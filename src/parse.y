// Yacc-based parser.
// Requires Berkeley Yacc (byacc) or Bison.

%define api.pure full
%locations
%lex-param {ParseContext* context}
%parse-param {ParseContext* context}

%code top {
#include "src/parse.h"

typedef struct ParseContext ParseContext;
}

%code provides {

typedef YYLTYPE YaccLocation;
typedef YYSTYPE YaccValue;

static void yyerror(YaccLocation* loc, ParseContext* context, char const* message);

static int yylex(YaccValue* val, YaccLocation* loc, ParseContext* context);

static void set_result(ParseContext* context, StmtSeq seq);

static Arena* ast_arena(ParseContext* context);

#define SET_RESULT(...) set_result(context, __VA_ARGS__)
#define PRINT_STMT(...) (Stmt*)print_stmt_new(ast_arena(context), __VA_ARGS__)
#define VAR_STMT(...) (Stmt*)var_stmt_new(ast_arena(context), __VA_ARGS__)
#define ASSIGN_STMT(...) (Stmt*)assign_stmt_new(ast_arena(context), __VA_ARGS__)
#define IF_STMT(...) (Stmt*)if_stmt_new(ast_arena(context), __VA_ARGS__)
#define IF_ARM(...) if_arm_new(ast_arena(context), __VA_ARGS__)
#define UNARY_EXPR(...) (Expr*)unary_expr_new(ast_arena(context), __VA_ARGS__)
#define BINARY_EXPR(...) (Expr*)binary_expr_new(ast_arena(context), __VA_ARGS__)
#define ID_EXPR(...) (Expr*)id_expr_new(ast_arena(context), __VA_ARGS__)
#define TRUE_EXPR(...) bool_literal_expr_new(ast_arena(context), true)
#define FALSE_EXPR(...) bool_literal_expr_new(ast_arena(context), false)
#define INT_LITERAL_EXPR(...) (Expr*)int_literal_expr_new(ast_arena(context), __VA_ARGS__)

}

%union {
    StmtSeq stmt_seq;
    int i;
    Stmt* stmt;
    Expr* expr;
    IfArm* if_arm;
    AstString* str;
    BinaryOp bin_op;
    UnaryOp un_op;
}

// General.
%token <str> ID
%token <i> INT_LITERAL

// Keywords.
%token ELSE
%token ELSEIF
%token END
%token FALSE
%token IF
%token PRINT
%token THEN
%token TRUE
%token VAR

// Multi-character symbols.
%token AMP_AMP
%token BAR_BAR
%token EQ_EQ
%token NOT_EQ

// Non-terminal types.
%type <stmt_seq> StmtSeq
%type <stmt> Stmt
%type <stmt> PrintStmt
%type <stmt> VarStmt
%type <stmt> AssignStmt
%type <stmt> IfStmt
%type <if_arm> IfArms
%type <if_arm> IfArm
%type <expr> Expr
%type <expr> LogicalAndExpr
%type <expr> LogicalOrExpr
%type <expr> TermExpr
%type <expr> UnaryExpr
%type <expr> PrimaryExpr
%type <bin_op> CompareOp
%type <bin_op> TermOp
%type <un_op> UnaryOp

%start File

%%

File:
      StmtSeq { SET_RESULT($1); }

StmtSeq:
      StmtSeq Stmt
        {
            $$ = $1;
            if ($2 != NULL) {
                stmt_seq_push(&$$, $2);
            }
        }
    | /* empty */ { $$ = stmt_seq_empty(); }

Stmt:
      PrintStmt  { $$ = $1; }
    | VarStmt    { $$ = $1; }
    | AssignStmt { $$ = $1; }
    | IfStmt     { $$ = $1; }
    | ';'        { $$ = NULL; }

PrintStmt:
      PRINT '(' Expr ')' { $$ = PRINT_STMT($3); }

VarStmt:
      VAR ID          { $$ = VAR_STMT($2, NULL); }
    | VAR ID '=' Expr { $$ = VAR_STMT($2, $4); }

AssignStmt:
      ID '=' Expr { $$ = ASSIGN_STMT($1, $3); }

IfStmt:
      IF IfArms END              { $$ = IF_STMT($2, stmt_seq_empty()); }
    | IF IfArms ELSE StmtSeq END { $$ = IF_STMT($2, $4); }

IfArms:
      IfArm ELSEIF IfArms { $$ = $1; $1->next = $3; }
    | IfArm               { $$ = $1; }

IfArm:
      Expr THEN StmtSeq { $$ = IF_ARM($1, $3); }

Expr:
      UnaryExpr      { $$ = $1; }
    | LogicalAndExpr { $$ = $1; }
    | LogicalOrExpr  { $$ = $1; }
    | UnaryExpr CompareOp UnaryExpr { $$ = BINARY_EXPR($1, $3, $2); }
    | TermExpr       { $$ = $1; }

CompareOp:
      EQ_EQ  { $$ = BinaryOp_Equal; }
    | NOT_EQ { $$ = BinaryOp_NotEqual; }

LogicalAndExpr:
      LogicalAndExpr AMP_AMP UnaryExpr
        { $$ = BINARY_EXPR($1, $3, BinaryOp_LogicalAnd); }
    | UnaryExpr AMP_AMP UnaryExpr
        { $$ = BINARY_EXPR($1, $3, BinaryOp_LogicalAnd); }

LogicalOrExpr:
      LogicalOrExpr BAR_BAR UnaryExpr
        { $$ = BINARY_EXPR($1, $3, BinaryOp_LogicalOr); }
    | UnaryExpr BAR_BAR UnaryExpr
        { $$ = BINARY_EXPR($1, $3, BinaryOp_LogicalOr); }

TermExpr:
      TermExpr TermOp UnaryExpr
        { $$ = BINARY_EXPR($1, $3, $2); }
    | UnaryExpr TermOp UnaryExpr
        { $$ = BINARY_EXPR($1, $3, $2); }

TermOp:
      '+' { $$ = BinaryOp_Add; }
    | '-' { $$ = BinaryOp_Subtract; }

UnaryExpr:
      PrimaryExpr       { $$ = $1; }
    | UnaryOp UnaryExpr { $$ = UNARY_EXPR($2, $1); }

UnaryOp:
      '!' { $$ = UnaryOp_LogicalNot; }
    | '-' { $$ = UnaryOp_Negate; }

PrimaryExpr:
      '(' Expr ')' { $$ = $2; }
    | ID           { $$ = ID_EXPR($1); }
    | TRUE         { $$ = TRUE_EXPR(); }
    | FALSE        { $$ = FALSE_EXPR(); }
    | INT_LITERAL  { $$ = INT_LITERAL_EXPR($1); }

%%

#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

struct ParseContext {
    AstContext* ast_context;
    Arena* arena;

    uint8_t const* cursor;
    uint8_t const* limit;
    int cursor_line;
    int cursor_column;

    YaccLocation error_loc;
    bool has_unexpected_character;

    ParseResult* result;
};

static bool is_id_start(uint8_t c) {
    return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c == '_');
}

static bool is_id_continue(uint8_t c) {
    return is_id_start(c) || (c >= '0' && c <= '9');
}

static int keyword_or_id(uint8_t const* data, size_t size) {
    #define KEYWORD(n, s) \
        if (sizeof(s) - 1 == size && memcmp(s, data, size) == 0) return n;

    KEYWORD(ELSE, "else")
    KEYWORD(ELSEIF, "elseif")
    KEYWORD(END, "end")
    KEYWORD(FALSE, "false")
    KEYWORD(IF, "if")
    KEYWORD(PRINT, "print")
    KEYWORD(THEN, "then")
    KEYWORD(TRUE, "true")
    KEYWORD(VAR, "var")

    #undef KEYWORD

    return ID;
}

static void yyerror(
    YaccLocation* loc, ParseContext* context, char const* message
) {
    (void)message; // unused
    context->error_loc = *loc;
}

static int yylex(YaccValue* val, YaccLocation* loc, ParseContext* context) {
loop:
    if (context->cursor == context->limit) {
        return YYEOF;
    }

    loc->first_line = context->cursor_line;
    loc->first_column = context->cursor_column;

    if (is_id_start(*context->cursor)) {
        uint8_t const* start = context->cursor;
        context->cursor += 1;
        context->cursor_column += 1;

        while (
            (context->cursor < context->limit) &&
            is_id_continue(*context->cursor)
        ) {
            context->cursor += 1;
            context->cursor_column += 1;
        }

        size_t size = context->cursor - start;
        int kind = keyword_or_id(start, size);

        if (kind == ID) {
            val->str = ast_string_new(
                context->ast_context,
                (char const*)start,
                size
            );
        }

        return kind;
    }

    uint8_t c = *context->cursor;

    if (c == '0') {
        // TODO: report actual error (leading zero not allowed)
        goto unexpected_character;
    }

    if (c >= '1' && c <= '9') {
        unsigned i = c - '0';
        context->cursor += 1;
        context->cursor_column += 1;
        for (;;) {
            if (context->cursor == context->limit) break;
            c = *context->cursor;
            if (c < '0' || c > '9') break;
            i *= 10;
            i += c - '0';
            context->cursor += 1;
            context->cursor_column += 1;
        }

        if (context->cursor < context->limit) {
            c = *context->cursor;
            if (is_id_continue(c)) {
                // TODO: report the actual error (trailing junk after literal)
                goto unexpected_character;
            }
        }

        val->i = i;
        return INT_LITERAL;
    }

    switch (c) {
    // Line comment.
    case '#':
        context->cursor += 1;
        context->cursor_column += 1;
        for (;;) {
            if (context->cursor == context->limit) break;
            if (*context->cursor == '\r') break;
            if (*context->cursor == '\n') break;
            context->cursor += 1;
            context->cursor_column += 1;
        }
        goto loop;

    // Whitespace.
    case ' ':
    case '\t':
        context->cursor += 1;
        context->cursor_column += 1;
        goto loop;

    // Newline.
    case '\r':
        if (context->cursor + 1 != context->limit && *context->cursor == '\n') {
            // CR LF
            context->cursor += 1;
        }
        // fallthrough
    case '\n':
        context->cursor += 1;
        context->cursor_line += 1;
        context->cursor_column = 1;
        goto loop;

    // One character symbols that are not a prefix of another symbol.
    case '(': case ')':
    case ';':
    case '+':
    case '-':
        context->cursor += 1;
        context->cursor_column += 1;
        return c;

    case '=':
        if (context->cursor + 1 < context->limit) {
            if (context->cursor[1] == '=') {
                context->cursor += 2;
                context->cursor_column += 2;
                return EQ_EQ;
            }
        }
        context->cursor += 1;
        context->cursor_column += 1;
        return '=';

    case '!':
        if (context->cursor + 1 < context->limit) {
            if (context->cursor[1] == '=') {
                context->cursor += 2;
                context->cursor_column += 2;
                return NOT_EQ;
            }
        }
        context->cursor += 1;
        context->cursor_column += 1;
        return '!';

    case '&':
        if (context->cursor + 1 < context->limit) {
            if (context->cursor[1] == '&') {
                context->cursor += 2;
                context->cursor_column += 2;
                return AMP_AMP;
            }
        }
        break;

    case '|':
        if (context->cursor + 1 < context->limit) {
            if (context->cursor[1] == '|') {
                context->cursor += 2;
                context->cursor_column += 2;
                return BAR_BAR;
            }
        }
        break;
    }

unexpected_character:
    // TODO: report character
    loc->first_line = context->cursor_line;
    loc->first_column = context->cursor_column;
    context->has_unexpected_character = true;
    context->error_loc = *loc;
    return 1;
}

void parse_bytes(
    ParseResult* result,
    AstContext* ast_context,
    Arena* arena,
    char const* data,
    size_t size
) {
    ParseContext context = {
        .ast_context = ast_context,
        .arena = arena,
        .cursor = (uint8_t const*)data,
        .limit = (uint8_t const*)data + size,
        .result = result,
        .cursor_line = 1,
        .cursor_column = 1,
        .has_unexpected_character = false,
    };

    // Note: these values are correct for byacc and Bison. They might not work
    // elsewhere.
    switch (yyparse(&context)) {
    case 0:
        break;

    case 1:
        result->kind = ParseResultKind_SyntaxError;
        result->as.syntax_error.line = context.error_loc.first_line;
        result->as.syntax_error.column = context.error_loc.first_column;
        if (context.has_unexpected_character) {
            result->as.syntax_error.kind = SyntaxErrorKind_UnexpectedCharacter;
        } else {
            // TODO: report token
            result->as.syntax_error.kind = SyntaxErrorKind_UnexpectedToken;
        }
        break;

    case 2:
        result->kind = ParseResultKind_OutOfMemory;
        break;

    default:
        assert(!"unexpected yyparse() result code");
        break;
    }
}

static void set_result(ParseContext* context, StmtSeq seq) {
    context->result->kind = ParseResultKind_Success;
    context->result->as.file = ast_file_new(context->arena, seq);
}

static Arena* ast_arena(ParseContext* context) {
    return context->arena;
}
