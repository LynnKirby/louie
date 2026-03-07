#ifndef _louie_src_ast_h
#define _louie_src_ast_h

#include <stddef.h>
#include <stdio.h>

//
// AstContext
//

typedef struct AstContext AstContext;

AstContext* ast_context_new(void);
void ast_context_delete(AstContext* context);

//
// AstString
//

/// Interned string.
typedef struct AstString AstString;

AstString* ast_string_new(AstContext* context, char const* data, size_t size);
size_t ast_string_size(AstString* string);
char const* ast_string_data(AstString* string);

//
// AST basics
//

typedef struct Stmt Stmt;
typedef struct Expr Expr;

#define STMT_KIND_LIST(X) \
    X(If)                 \
    X(Var)                \
    X(Assign)             \
    X(Print)

#define EXPR_KIND_LIST(X) \
    X(TrueLiteral)        \
    X(FalseLiteral)       \
    X(Id)                 \
    X(Unary)              \
    X(Binary)

#define UNARY_OP_LIST(X) \
    X(LogicalNot)

#define BINARY_OP_LIST(X) \
    X(LogicalAnd)         \
    X(LogicalOr)          \
    X(Equal)              \
    X(NotEqual)

typedef enum StmtKind {
    #define X(name) StmtKind_##name,
    STMT_KIND_LIST(X)
    #undef X
} StmtKind;

typedef enum ExprKind {
    #define X(name) ExprKind_##name,
    EXPR_KIND_LIST(X)
    #undef X
} ExprKind;

typedef enum UnaryOp {
    #define X(name) UnaryOp_##name,
    UNARY_OP_LIST(X)
    #undef X
} UnaryOp;

typedef enum BinaryOp {
    #define X(name) BinaryOp_##name,
    BINARY_OP_LIST(X)
    #undef X
} BinaryOp;

char const* stmt_kind_name(StmtKind kind);
char const* expr_kind_name(ExprKind kind);
char const* unary_op_name(UnaryOp op);
char const* binary_op_name(BinaryOp op);

void dump_stmt_seq(FILE* file, Stmt const* stmt_seq, int indent);
void dump_stmt(FILE* file, Stmt const* stmt, int indent);
void dump_expr(FILE* file, Expr const* expr, int indent);

//
// Statements
//

struct Stmt {
    Stmt* next; // nullable
    StmtKind kind;
};

typedef struct IfArm {
    struct IfArm* next; // nullable
    Expr* condition;
    Stmt* body;
} IfArm;

typedef struct IfStmt {
    Stmt base;
    IfArm* if_arms;
    Stmt* else_body; // nullable
} IfStmt;

typedef struct VarStmt {
    Stmt base;
    AstString* name;
    Expr* value; // nullable
} VarStmt;

typedef struct AssignStmt {
    Stmt base;
    AstString* name;
    Expr* value;
} AssignStmt;

typedef struct PrintStmt {
    Stmt base;
    Expr* value;
} PrintStmt;

//
// Expressions
//

struct Expr {
    ExprKind kind;
};

typedef struct IdExpr {
    Expr base;
    AstString* name;
} IdExpr;

typedef struct UnaryExpr {
    Expr base;
    UnaryOp operator;
    Expr* operand;
} UnaryExpr;

typedef struct BinaryExpr {
    Expr base;
    BinaryOp operator;
    Expr* left_operand;
    Expr* right_operand;
} BinaryExpr;

#endif
