#include "src/ast/ast.h"

char const* stmt_kind_name(StmtKind kind) {
    static char const* const names[] = {
        #define X(name) #name,
        STMT_KIND_LIST(X)
        #undef X
    };
    return names[kind];
}

char const* expr_kind_name(ExprKind kind) {
    static char const* const names[] = {
        #define X(name) #name,
        EXPR_KIND_LIST(X)
        #undef X
    };
    return names[kind];
}

char const* unary_op_name(UnaryOp op) {
    static char const* const names[] = {
        #define X(name) #name,
        UNARY_OP_LIST(X)
        #undef X
    };
    return names[op];
}

char const* binary_op_name(BinaryOp op) {
    static char const* const names[] = {
        #define X(name) #name,
        BINARY_OP_LIST(X)
        #undef X
    };
    return names[op];
}

static void print_indent(FILE* file, int indent) {
    while (indent > 0) {
        fprintf(file, "  ");
        indent -= 1;
    }
}

static void print_string(FILE* file, AstString* str) {
    // TODO: escape characters
    fprintf(file, "\"%s\"", ast_string_data(str));
}

void dump_file(FILE* file, AstFile* ast_file, int indent) {
    print_indent(file, indent);
    fprintf(file, "File\n");
    dump_stmt_seq(file, ast_file->body, indent + 1);
}

//
// Statements
//

void dump_stmt_seq(FILE* file, StmtSeq seq, int indent) {
    Stmt const* stmt = seq.first;

    if (stmt == NULL) {
        return;
    }

    if (stmt->next == NULL) {
        dump_stmt(file, stmt, indent);
        return;
    }

    print_indent(file, indent);
    fprintf(file, "StmtSeq\n");
    while (stmt != NULL) {
        dump_stmt(file, stmt, indent + 1);
        stmt = stmt->next;
    }
}

static void dump_assign_stmt(
    FILE* file, AssignStmt const* stmt, int indent
) {
    print_indent(file, indent);
    fprintf(file, "AssignStmt\n");

    print_indent(file, indent + 1);
    print_string(file, stmt->name);
    fprintf(file, "\n");

    dump_expr(file, stmt->value, indent + 1);
}

static void dump_if_arm(FILE* file, IfArm const* arm, int indent) {
    print_indent(file, indent);
    fprintf(file, "IfArm\n");
    dump_expr(file, arm->condition, indent + 1);
    dump_stmt_seq(file, arm->body, indent + 1);
}

static void dump_if_stmt(FILE* file, IfStmt const* stmt, int indent) {
    print_indent(file, indent);
    fprintf(file, "IfStmt\n");

    IfArm* arm = stmt->if_arms;

    while (arm != NULL) {
        dump_if_arm(file, arm, indent + 1);
        arm = arm->next;
    }

    dump_stmt_seq(file, stmt->else_body, indent + 1);
}

static void dump_var_stmt(FILE* file, VarStmt const* stmt, int indent) {
    print_indent(file, indent);
    fprintf(file, "VarStmt ");
    print_string(file, stmt->name);
    fprintf(file, "\n");

    if (stmt->value != NULL) {
        dump_expr(file, stmt->value, indent + 1);
    }
}

void dump_stmt(FILE* file, Stmt const* stmt, int indent) {
    switch (stmt->kind) {
    case StmtKind_Assign:
        dump_assign_stmt(file, (AssignStmt const*)stmt, indent);
        return;

    case StmtKind_If:
        dump_if_stmt(file, (IfStmt const*)stmt, indent);
        break;

    case StmtKind_Var:
        dump_var_stmt(file, (VarStmt const*)stmt, indent);
        break;

    case StmtKind_Print: {
        PrintStmt const* print_stmt = (PrintStmt const*)stmt;
        print_indent(file, indent);
        fprintf(file, "PrintStmt\n");
        dump_expr(file, print_stmt->value, indent + 1);
        break;
    }
    }
}

//
// Expressions
//

static void dump_id_expr(FILE* file, IdExpr const* expr, int indent) {
    print_indent(file, indent);
    fprintf(file, "IdExpr ");
    print_string(file, expr->name);
    fprintf(file, "\n");
}

static void dump_unary_expr(FILE* file, UnaryExpr const* expr, int indent) {
    print_indent(file, indent);
    fprintf(file, "UnaryExpr %s\n", unary_op_name(expr->operator));
    dump_expr(file, expr->operand, indent + 1);
}

static void dump_binary_expr(FILE* file, BinaryExpr const* expr, int indent) {
    print_indent(file, indent);
    fprintf(file, "BinaryExpr %s\n", binary_op_name(expr->operator));
    dump_expr(file, expr->left_operand, indent + 1);
    dump_expr(file, expr->right_operand, indent + 1);
}

void dump_expr(FILE* file, Expr const* expr, int indent) {
    switch (expr->kind) {
    case ExprKind_FalseLiteral:
        print_indent(file, indent);
        fprintf(file, "BoolLiteral false\n");
        break;

    case ExprKind_TrueLiteral:
        print_indent(file, indent);
        fprintf(file, "BoolLiteral true\n");
        break;

    case ExprKind_IntLiteral:
        print_indent(file, indent);
        fprintf(file, "IntLiteral %i\n", ((IntLiteralExpr*)expr)->value);
        break;

    case ExprKind_Unary:
        dump_unary_expr(file, (UnaryExpr const*)expr, indent);
        break;

    case ExprKind_Binary:
        dump_binary_expr(file, (BinaryExpr const*)expr, indent);
        break;

    case ExprKind_Id:
        dump_id_expr(file, (IdExpr const*)expr, indent);
        break;
    }
}
