#include "src/ast/ast.h"

AstFile* ast_file_new(Arena* arena, StmtSeq body) {
    AstFile* file = arena_allocate(arena, sizeof(AstFile));
    if (file != NULL) {
        file->body = body;
    }
    return file;
}

IfArm* if_arm_new(Arena* arena, Expr* condition, StmtSeq body) {
    IfArm* arm = arena_allocate(arena, sizeof(IfArm));
    if (arm != NULL) {
        arm->next = NULL;
        arm->condition = condition;
        arm->body = body;
    }
    return arm;
}

IfStmt* if_stmt_new(Arena* arena, IfArm* if_arms, StmtSeq else_body) {
    IfStmt* stmt = arena_allocate(arena, sizeof(IfStmt));
    if (stmt != NULL) {
        stmt->base.kind = StmtKind_If;
        stmt->base.next = NULL;
        stmt->if_arms = if_arms;
        stmt->else_body = else_body;
    }
    return stmt;
}

VarStmt* var_stmt_new(Arena* arena, AstString* name, Expr* value) {
    VarStmt* stmt = arena_allocate(arena, sizeof(VarStmt));
    if (stmt != NULL) {
        stmt->base.kind = StmtKind_Var;
        stmt->base.next = NULL;
        stmt->name = name;
        stmt->value = value;
    }
    return stmt;
}

AssignStmt* assign_stmt_new(Arena* arena, AstString* name, Expr* value) {
    AssignStmt* stmt = arena_allocate(arena, sizeof(AssignStmt));
    if (stmt != NULL) {
        stmt->base.kind = StmtKind_Assign;
        stmt->base.next = NULL;
        stmt->name = name;
        stmt->value = value;
    }
    return stmt;
}

PrintStmt* print_stmt_new(Arena* arena, Expr* value) {
    PrintStmt* stmt = arena_allocate(arena, sizeof(PrintStmt));
    if (stmt != NULL) {
        stmt->base.kind = StmtKind_Print;
        stmt->base.next = NULL;
        stmt->value = value;
    }
    return stmt;
}

Expr* bool_literal_expr_new(Arena* arena, bool value) {
    Expr* expr = arena_allocate(arena, sizeof(Expr));
    if (expr != NULL) {
        expr->kind = value ? ExprKind_TrueLiteral : ExprKind_FalseLiteral;
    }
    return expr;
}

IntLiteralExpr* int_literal_expr_new(Arena* arena, int value) {
    IntLiteralExpr* expr = arena_allocate(arena, sizeof(IntLiteralExpr));
    if (expr != NULL) {
        expr->base.kind = ExprKind_IntLiteral;
        expr->value = value;
    }
    return expr;
}

IdExpr* id_expr_new(Arena* arena, AstString* name) {
    IdExpr* expr = arena_allocate(arena, sizeof(IdExpr));
    if (expr != NULL) {
        expr->base.kind = ExprKind_Id;
        expr->name = name;
    }
    return expr;
}

UnaryExpr* unary_expr_new(
    Arena* arena, Expr* operand, UnaryOp operator
) {
    UnaryExpr* expr = arena_allocate(arena, sizeof(UnaryExpr));
    if (expr != NULL) {
        expr->base.kind = ExprKind_Unary;
        expr->operator = operator;
        expr->operand = operand;
    }
    return expr;
}

BinaryExpr* binary_expr_new(
    Arena* arena, Expr* left, Expr* right, BinaryOp operator
) {
    BinaryExpr* expr = arena_allocate(arena, sizeof(BinaryExpr));
    if (expr != NULL) {
        expr->base.kind = ExprKind_Binary;
        expr->operator = operator;
        expr->left_operand = left;
        expr->right_operand = right;
    }
    return expr;
}
