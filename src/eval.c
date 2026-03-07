#include "src/eval.h"

#include <assert.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>

typedef union AnyValue {
    bool b;
} AnyValue;

typedef enum ValueTag {
    ValueTag_Bool,
} ValueTag;

typedef struct TaggedValue {
    AnyValue value;
    ValueTag tag;
} TaggedValue;

#define TRUE ((TaggedValue){ .value.b = true, .tag = ValueTag_Bool })
#define FALSE ((TaggedValue){ .value.b = false, .tag = ValueTag_Bool })

static bool equal(TaggedValue left, TaggedValue right) {
    assert(left.tag == right.tag);

    switch (left.tag) {
    case ValueTag_Bool:
        return left.value.b == right.value.b;
    }

    assert(0);
}

typedef struct Variable {
    struct Variable* next;
    AstString* name;
    TaggedValue value;
    bool defined;
} Variable;

typedef struct Scope {
    struct Scope* parent;
    Variable* variables;
} Scope;

static Variable* find_variable_in_this_scope(Scope* scope, AstString* name) {
    Variable* v = scope->variables;

    while (v != NULL) {
        if (name == v->name) {
            return v;
        }
        v = v->next;
    }

    return NULL;
}

static Variable* find_variable_in_any_scope(Scope* scope, AstString* name) {
    while (scope != NULL) {
        Variable* v = find_variable_in_this_scope(scope, name);
        if (v != NULL) return v;
        scope = scope->parent;
    }
    return NULL;
}

static Variable* declare_variable(Scope* scope, AstString* name) {
    Variable* variable = find_variable_in_this_scope(scope, name);

    if (variable == NULL) {
        variable = malloc(sizeof(Variable));
        variable->name = name;
        variable->next = scope->variables;
        scope->variables = variable;
    }

    variable->defined = false;
    return variable;
}

static void eval_stmt(Scope* scope, Stmt* stmt);
static void eval_stmt_seq(Scope* scope, Stmt* stmt_seq);
static TaggedValue eval_expr(Scope* scope, Expr* expr);

static TaggedValue eval_expr(Scope* scope, Expr* expr) {
    switch (expr->kind) {
    case ExprKind_TrueLiteral: return TRUE;
    case ExprKind_FalseLiteral: return FALSE;

    case ExprKind_Id: {
        IdExpr* id_expr = (IdExpr*)expr;
        Variable* variable = find_variable_in_any_scope(scope, id_expr->name);
        assert(variable != NULL);
        assert(variable->defined);
        return variable->value;
    }

    case ExprKind_Unary: {
        UnaryExpr* unary_expr = (UnaryExpr*)expr;
        TaggedValue operand = eval_expr(scope, unary_expr->operand);

        switch (unary_expr->operator) {
        case UnaryOp_LogicalNot:
            assert(operand.tag == ValueTag_Bool);
            operand.value.b = !operand.value.b;
            return operand;
        }

        break;
    }

    case ExprKind_Binary: {
        BinaryExpr* binary_expr = (BinaryExpr*)expr;
        TaggedValue left_operand = eval_expr(scope, binary_expr->left_operand);

        switch (binary_expr->operator) {
        case BinaryOp_LogicalAnd: {
            assert(left_operand.tag == ValueTag_Bool);
            if (!left_operand.value.b) {
                return FALSE;
            }
            TaggedValue right_operand = eval_expr(
                scope, binary_expr->right_operand
            );
            assert(right_operand.tag == ValueTag_Bool);
            if (right_operand.value.b) {
                return TRUE;
            }
            return FALSE;
        }

        case BinaryOp_LogicalOr: {
            assert(left_operand.tag == ValueTag_Bool);
            if (left_operand.value.b) {
                return TRUE;
            }
            TaggedValue right_operand = eval_expr(
                scope, binary_expr->right_operand
            );
            assert(right_operand.tag == ValueTag_Bool);
            if (right_operand.value.b) {
                return TRUE;
            }
            return FALSE;
        }

        case BinaryOp_Equal: {
            TaggedValue right_operand = eval_expr(
                scope, binary_expr->right_operand
            );
            return equal(left_operand, right_operand) ? TRUE : FALSE;
        }

        case BinaryOp_NotEqual: {
            TaggedValue right_operand = eval_expr(
                scope, binary_expr->right_operand
            );
            return !equal(left_operand, right_operand) ? TRUE : FALSE;
        }
        }

        break;
    }
    }

    assert(0);
}

static void eval_stmt(Scope* scope, Stmt* stmt) {
    switch (stmt->kind) {
    case StmtKind_Assign: {
        AssignStmt* assign_stmt = (AssignStmt*)stmt;
        Variable* variable = find_variable_in_any_scope(
            scope, assign_stmt->name
        );
        assert(variable != NULL);
        variable->value = eval_expr(scope, assign_stmt->value);
        variable->defined = true;
        break;
    }

    case StmtKind_If: {
        IfStmt* if_stmt = (IfStmt*)stmt;
        IfArm* arm = if_stmt->if_arms;
        while (arm != NULL) {
            TaggedValue condition = eval_expr(scope, arm->condition);
            assert(condition.tag == ValueTag_Bool);
            if (condition.value.b) {
                eval_stmt_seq(scope, arm->body);
                return;
            }
            arm = arm->next;
        }
        if (if_stmt->else_body != NULL) {
            eval_stmt_seq(scope, if_stmt->else_body);
        }
        break;
    }

    case StmtKind_Var: {
        VarStmt* var_stmt = (VarStmt*)stmt;
        Variable* v = declare_variable(scope, var_stmt->name);
        if (var_stmt->value != NULL) {
            v->value = eval_expr(scope, var_stmt->value);
            v->defined = true;
        }
        break;
    }

    case StmtKind_Print: {
        TaggedValue value = eval_expr(scope, ((PrintStmt*)stmt)->value);
        switch (value.tag) {
        case ValueTag_Bool:
            if (value.value.b) {
                printf("true\n");
            } else {
                printf("false\n");
            }
            return;
        }
    }
    }
}

static void eval_stmt_seq(Scope* parent_scope, Stmt* stmt_seq) {
    Scope scope = {
        .parent = parent_scope,
        .variables = NULL,
    };

    while (stmt_seq != NULL) {
        Stmt* stmt = stmt_seq;
        stmt_seq = stmt_seq->next;
        eval_stmt(&scope, stmt);
    }

    while (scope.variables != NULL) {
        Variable* next = scope.variables->next;
        free(scope.variables);
        scope.variables = next;
    }
}

void eval(Stmt* stmt_seq) {
    eval_stmt_seq(NULL, stmt_seq);
}
