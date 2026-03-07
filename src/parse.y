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

static Stmt* reverse_stmt_seq(Stmt* stmt_seq);
static void set_result(ParseContext* context, Stmt* stmt_seq);

static Stmt* new_print_stmt(ParseContext* context, Expr* value);
static Stmt* new_var_stmt(ParseContext* context, AstString* name, Expr* value);
static Stmt* new_assign_stmt(ParseContext* context, AstString* name, Expr* value);
static Stmt* new_if_stmt(ParseContext* context, IfArm* if_arms, Stmt* else_part);
static IfArm* new_if_arm(ParseContext* context, Expr* condition, Stmt* body);
static Expr* new_unary_expr(ParseContext* context, Expr* operand, UnaryOp operator);
static Expr* new_binary_expr(ParseContext* context, Expr* left, Expr* right, BinaryOp operator);
static Expr* new_id_expr(ParseContext* context, AstString* name);
static Expr* new_true_expr(ParseContext* context);
static Expr* new_false_expr(ParseContext* context);

#define SET_RESULT(...) set_result(context, __VA_ARGS__)
#define PRINT_STMT(...) new_print_stmt(context, __VA_ARGS__)
#define VAR_STMT(...) new_var_stmt(context, __VA_ARGS__)
#define ASSIGN_STMT(...) new_assign_stmt(context, __VA_ARGS__)
#define IF_STMT(...) new_if_stmt(context, __VA_ARGS__)
#define IF_ARM(...) new_if_arm(context, __VA_ARGS__)
#define UNARY_EXPR(...) new_unary_expr(context, __VA_ARGS__)
#define BINARY_EXPR(...) new_binary_expr(context, __VA_ARGS__)
#define ID_EXPR(...) new_id_expr(context, __VA_ARGS__)
#define TRUE_EXPR(...) new_true_expr(context)
#define FALSE_EXPR(...) new_false_expr(context)

}

%union {
    Stmt* stmt;
    Expr* expr;
    IfArm* if_arm;
    AstString* str;
}

// General.
%token <str> ID

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
%type <stmt> StmtSeq
%type <stmt> StmtSeq_inner
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
%type <expr> UnaryExpr
%type <expr> PrimaryExpr

%start File

%%

File:
    StmtSeq { SET_RESULT($1); }

StmtSeq: StmtSeq_inner { $$ = reverse_stmt_seq($1); }
StmtSeq_inner:
      StmtSeq_inner Stmt { $2->next = $1; $$ = $2; }
    | /* empty */  { $$ = NULL; }

Stmt:
      PrintStmt  { $$ = $1; }
    | VarStmt    { $$ = $1; }
    | AssignStmt { $$ = $1; }
    | IfStmt     { $$ = $1; }

PrintStmt:
    PRINT '(' Expr ')' { $$ = PRINT_STMT($3); }

VarStmt:
      VAR ID          { $$ = VAR_STMT($2, NULL); }
    | VAR ID '=' Expr { $$ = VAR_STMT($2, $4); }

AssignStmt:
    ID '=' Expr { $$ = ASSIGN_STMT($1, $3); }

IfStmt:
      IF IfArms END              { $$ = IF_STMT($2, NULL); }
    | IF IfArms ELSE StmtSeq END { $$ = IF_STMT($2, $4); }

IfArms:
      IfArm ELSEIF IfArms { $$ = $1; $1->next = $3; }
    | IfArm               { $$ = $1; }

IfArm:
    Expr THEN StmtSeq { $$ = IF_ARM($1, $3); }

Expr:
      UnaryExpr { $$ = $1; }
    | LogicalAndExpr { $$ = $1; }
    | LogicalOrExpr { $$ = $1; }
    | UnaryExpr EQ_EQ UnaryExpr
        { $$ = BINARY_EXPR($1, $3, BinaryOp_Equal); }
    | UnaryExpr NOT_EQ UnaryExpr
        { $$ = BINARY_EXPR($1, $3, BinaryOp_NotEqual); }

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

UnaryExpr:
      PrimaryExpr   { $$ = $1; }
    | '!' UnaryExpr { $$ = UNARY_EXPR($2, UnaryOp_LogicalNot); }

PrimaryExpr:
      '(' Expr ')' { $$ = $2; }
    | ID           { $$ = ID_EXPR($1); }
    | TRUE         { $$ = TRUE_EXPR(); }
    | FALSE        { $$ = FALSE_EXPR(); }

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

    Stmt* result;
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

        while (is_id_continue(*context->cursor)) {
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

    case '(': case ')':
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

    // TODO: don't abort
    fprintf(
        stderr,
        "error: unexpected character at %i:%i\n",
        loc->first_line,
        loc->first_column
    );
    exit(1);
}

Stmt* parse_bytes(
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
        .result = NULL,
        .cursor_line = 1,
        .cursor_column = 1,
    };

    // Note: these values are correct for byacc and Bison. They might not work
    // elsewhere.
    switch (yyparse(&context)) {
    case 0:
        break;

    case 1:
        // TODO: don't abort
        fprintf(
            stderr,
            "error: unexpected token at %i:%i\n",
            context.error_loc.first_line,
            context.error_loc.first_column
        );
        exit(1);
        break;

    case 2:
        // TODO: don't abort
        fprintf(stderr, "error: out of memory while parsing\n");
        exit(1);
        break;

    default:
        assert(!"unexpected yyparse() result code");
        break;
    }

    return context.result;
}

static void set_result(ParseContext* context, Stmt* stmt_seq) {
    context->result = stmt_seq;
}

static Stmt* reverse_stmt_seq(Stmt* stmt_seq) {
    Stmt* prev = NULL;
    Stmt* stmt = stmt_seq;

    while (stmt != NULL) {
        Stmt* next = stmt->next;
        stmt->next = prev;
        prev = stmt;
        stmt = next;
    }

    return prev;
}

static Stmt* new_print_stmt(ParseContext* context, Expr* value) {
    PrintStmt* stmt = arena_allocate(context->arena, sizeof(PrintStmt));
    stmt->base.kind = StmtKind_Print;
    stmt->base.next = NULL;
    stmt->value = value;
    return (Stmt*)stmt;
}

static Stmt* new_var_stmt(ParseContext* context, AstString* name, Expr* value) {
    VarStmt* stmt = arena_allocate(context->arena, sizeof(VarStmt));
    stmt->base.kind = StmtKind_Var;
    stmt->base.next = NULL;
    stmt->name = name;
    stmt->value = value;
    return (Stmt*)stmt;
}

static Stmt* new_assign_stmt(
    ParseContext* context, AstString* name, Expr* value
) {
    AssignStmt* stmt = arena_allocate(context->arena, sizeof(AssignStmt));
    stmt->base.kind = StmtKind_Assign;
    stmt->base.next = NULL;
    stmt->name = name;
    stmt->value = value;
    return (Stmt*)stmt;
}

static Stmt* new_if_stmt(
    ParseContext* context, IfArm* if_arms, Stmt* else_body
) {
    IfStmt* stmt = arena_allocate(context->arena, sizeof(IfStmt));
    stmt->base.kind = StmtKind_If;
    stmt->base.next = NULL;
    stmt->if_arms = if_arms;
    stmt->else_body = else_body;
    return (Stmt*)stmt;
}

static IfArm* new_if_arm(ParseContext* context, Expr* condition, Stmt* body) {
    IfArm* part = arena_allocate(context->arena, sizeof(IfArm));
    part->next = NULL;
    part->condition = condition;
    part->body = body;
    return part;
}

static Expr* new_unary_expr(
    ParseContext* context, Expr* operand, UnaryOp operator
) {
    UnaryExpr* expr = arena_allocate(context->arena, sizeof(UnaryExpr));
    expr->base.kind = ExprKind_Unary;
    expr->operand = operand;
    expr->operator = operator;
    return (Expr*)expr;
}

static Expr* new_binary_expr(
    ParseContext* context, Expr* left, Expr* right, BinaryOp operator
) {
    BinaryExpr* expr = arena_allocate(context->arena, sizeof(BinaryExpr));
    expr->base.kind = ExprKind_Binary;
    expr->left_operand = left;
    expr->right_operand = right;
    expr->operator = operator;
    return (Expr*)expr;
}

static Expr* new_id_expr(ParseContext* context, AstString* name) {
    IdExpr* expr = arena_allocate(context->arena, sizeof(IdExpr));
    expr->base.kind = ExprKind_Id;
    expr->name = name;
    return (Expr*)expr;
}

static Expr* new_true_expr(ParseContext* context) {
    Expr* expr = arena_allocate(context->arena, sizeof(Expr));
    expr->kind = ExprKind_TrueLiteral;
    return expr;
}

static Expr* new_false_expr(ParseContext* context) {
    Expr* expr = arena_allocate(context->arena, sizeof(Expr));
    expr->kind = ExprKind_FalseLiteral;
    return expr;
}
