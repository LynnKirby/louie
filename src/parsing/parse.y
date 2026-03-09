// Yacc-based parser.
// Requires Berkeley Yacc (byacc) or Bison.

%define api.pure full
%locations
%lex-param {ParseContext* context}
%parse-param {ParseContext* context}

%code top {
#include "src/parsing/parse.h"

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
    int integer;
    Stmt* stmt;
    Expr* expr;
    IfArm* if_arm;
    AstString* string;
    BinaryOp bin_op;
    UnaryOp un_op;
}

// 0 to match YYEOF
%token EndOfFile 0

%token UnexpectedCharacter

// General.
%token <string> Identifier
%token <integer> IntLiteral

// Keywords.
%token Else
%token Elseif
%token End
%token False
%token If
%token Print
%token Then
%token True
%token Var

// Symbols.
%token OpenParen
%token CloseParen
%token Semicolon
%token Equal
%token EqualEqual
%token Exclaim
%token ExclaimEqual
%token Plus
%token Minus
%token AmpAmp
%token BarBar

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
    | Semicolon  { $$ = NULL; }

PrintStmt:
      Print OpenParen Expr CloseParen { $$ = PRINT_STMT($3); }

VarStmt:
      Var Identifier            { $$ = VAR_STMT($2, NULL); }
    | Var Identifier Equal Expr { $$ = VAR_STMT($2, $4); }

AssignStmt:
      Identifier Equal Expr { $$ = ASSIGN_STMT($1, $3); }

IfStmt:
      If IfArms End              { $$ = IF_STMT($2, stmt_seq_empty()); }
    | If IfArms Else StmtSeq End { $$ = IF_STMT($2, $4); }

IfArms:
      IfArm Elseif IfArms { $$ = $1; $1->next = $3; }
    | IfArm               { $$ = $1; }

IfArm:
      Expr Then StmtSeq { $$ = IF_ARM($1, $3); }

Expr:
      UnaryExpr      { $$ = $1; }
    | LogicalAndExpr { $$ = $1; }
    | LogicalOrExpr  { $$ = $1; }
    | UnaryExpr CompareOp UnaryExpr { $$ = BINARY_EXPR($1, $3, $2); }
    | TermExpr       { $$ = $1; }

CompareOp:
      EqualEqual   { $$ = BinaryOp_Equal; }
    | ExclaimEqual { $$ = BinaryOp_NotEqual; }

LogicalAndExpr:
      LogicalAndExpr AmpAmp UnaryExpr
        { $$ = BINARY_EXPR($1, $3, BinaryOp_LogicalAnd); }
    | UnaryExpr AmpAmp UnaryExpr
        { $$ = BINARY_EXPR($1, $3, BinaryOp_LogicalAnd); }

LogicalOrExpr:
      LogicalOrExpr BarBar UnaryExpr
        { $$ = BINARY_EXPR($1, $3, BinaryOp_LogicalOr); }
    | UnaryExpr BarBar UnaryExpr
        { $$ = BINARY_EXPR($1, $3, BinaryOp_LogicalOr); }

TermExpr:
      TermExpr TermOp UnaryExpr
        { $$ = BINARY_EXPR($1, $3, $2); }
    | UnaryExpr TermOp UnaryExpr
        { $$ = BINARY_EXPR($1, $3, $2); }

TermOp:
      Plus  { $$ = BinaryOp_Add; }
    | Minus { $$ = BinaryOp_Subtract; }

UnaryExpr:
      PrimaryExpr       { $$ = $1; }
    | UnaryOp UnaryExpr { $$ = UNARY_EXPR($2, $1); }

UnaryOp:
      Exclaim { $$ = UnaryOp_LogicalNot; }
    | Minus   { $$ = UnaryOp_Negate; }

PrimaryExpr:
      OpenParen Expr CloseParen { $$ = $2; }
    | Identifier { $$ = ID_EXPR($1); }
    | True       { $$ = TRUE_EXPR(); }
    | False      { $$ = FALSE_EXPR(); }
    | IntLiteral { $$ = INT_LITERAL_EXPR($1); }

%%

#include "src/parsing/lex.h"

#include <assert.h>
#include <stdint.h>
#include <stdlib.h>

struct ParseContext {
    ParseResult* result;
    Arena* arena;
    Lexer lexer;
    YaccLocation error_loc;
    bool has_unexpected_character;
};

static void yyerror(
    YaccLocation* loc, ParseContext* context, char const* message
) {
    (void)message; // unused
    context->error_loc = *loc;
}

static int yylex(YaccValue* val, YaccLocation* loc, ParseContext* context) {
    // Map TokenKind to yacc token.
    static int const kind_map[] = {
        #define TOKEN_KIND(name) name,
        #include "src/parsing/token_kind.def"
    };

    Token token;
    lexer_next(&context->lexer, &token);

    switch (token.kind) {
    case TokenKind_Identifier:
        val->string = token.as.string;
        break;
    case TokenKind_IntLiteral:
        val->integer = token.as.integer;
        break;
    case TokenKind_UnexpectedCharacter:
        context->has_unexpected_character = true;
        break;
    default:
        break;
    }

    loc->first_line = token.line;
    loc->first_column = token.column;

    return kind_map[token.kind];
}

void parse_bytes(
    ParseResult* result,
    AstContext* ast_context,
    Arena* arena,
    char const* data,
    size_t size
) {
    ParseContext context = {
        .arena = arena,
        .result = result,
        .has_unexpected_character = false,
    };

    lexer_init(&context.lexer, data, size, ast_context);

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

    lexer_destroy(&context.lexer);
}

static void set_result(ParseContext* context, StmtSeq seq) {
    context->result->kind = ParseResultKind_Success;
    context->result->as.file = ast_file_new(context->arena, seq);
}

static Arena* ast_arena(ParseContext* context) {
    return context->arena;
}
