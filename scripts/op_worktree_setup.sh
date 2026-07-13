#!/usr/bin/env bash
# op_worktree_setup.sh: 创建隔离 worktree（sparse-checkout，绕过 subagent deny 失效）
#
# 用法:
#   op_worktree_setup.sh dev  <path> <branch>   # implementer/reviewer/closer，排除 e2e/
#   op_worktree_setup.sh eval <path> <branch>   # evaluator per-task 验收（Stage 3 循环内），排除 src/、tasks/、decisions.md（防抄实现）
#
# 依赖: git 2.25+（sparse-checkout）。
# 设计: design §2.5 evaluator 访问隔离层 + §0.2 能力矩阵「implementer e2e 对称隔离 / evaluator 无 src」

set -uo pipefail

type="${1:?usage: op_worktree_setup.sh <dev|eval> <path> <branch>}"
wt_path="${2:?}"
branch="${3:?}"

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
OP_PATHS_SCRIPT="${OP_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}/scripts/op_paths.sh"
source "$OP_PATHS_SCRIPT"
op_load_paths "" "$ROOT"

# 校验 git 版本（sparse-checkout 需 2.25+）
git version | grep -qE 'git version (2\.(2[5-9]|[3-9])|[3-9])' 2>/dev/null || {
    echo "[WARN] git < 2.25，sparse-checkout 可能不可用，worktree 退化为普通（隔离失效）" >&2
}

# 创建 worktree（--no-checkout 避免 checkout 全部）；分支不存在则 -b 创建，已存在则直接 checkout
if git show-ref --verify --quiet "refs/heads/$branch" 2>/dev/null; then
    git worktree add --no-checkout "$wt_path" "$branch" 2>/dev/null || {
        echo "[FATAL] git worktree add $wt_path（分支 $branch 已存在）失败——目录已存在？" >&2
        exit 1
    }
else
    git worktree add --no-checkout -b "$branch" "$wt_path" 2>/dev/null || {
        echo "[FATAL] git worktree add -b $branch $wt_path 失败" >&2
        exit 1
    }
fi

cd "$wt_path" || { echo "[FATAL] cd $wt_path 失败" >&2; exit 1; }

# 启用 sparse-checkout（非 cone 模式，支持 ! 否定 pattern）
git sparse-checkout init --no-cone 2>/dev/null || git sparse-checkout init

sparse_file="$(git rev-parse --git-path info/sparse-checkout)"

case "$type" in
    dev)
        # implementer/reviewer/closer worktree：排除统一 E2E 集合（行为层归 evaluator，design §3.1）
        cat > "$sparse_file" <<EOF
/*
!/e2e/
!/tests/e2e/
!/tests/*/e2e/
!/$OP_LITE_E2E_DIR_REL/
EOF
        ;;
    eval)
        # evaluator worktree：排除 src/、task 目录、decisions.md（防抄实现，design §2.5）
        # src/ 排除用通配覆盖子目录 src 与 monorepo packages/*/src
        cat > "$sparse_file" <<EOF
/*
!/src/
!/packages/*/src/
!/$OP_DOCS_DIR/op_execution/tasks/
!/$OP_DOCS_DIR/op_record/tasks/
!/$OP_DOCS_DIR/op_record/decisions.md
EOF
        ;;
    *)
        echo "[FATAL] type must be dev|eval，got: $type" >&2
        exit 1
        ;;
esac

# 应用 sparse-checkout
git read-tree -mu HEAD 2>/dev/null || git checkout HEAD -- . 2>/dev/null || true

# 验证排除生效（advisory，pattern 失效时 WARN）
case "$type" in
    dev)
        leak=""
        [ -d "e2e" ] && leak="$leak e2e/"
        [ -d "tests/e2e" ] && leak="$leak tests/e2e/"
        while IFS= read -r e2e_dir; do leak="$leak $e2e_dir"; done < <(find tests -mindepth 2 -maxdepth 2 -type d -name e2e -print 2>/dev/null)
        [ -d "$OP_LITE_E2E_DIR_REL" ] && leak="$leak $OP_LITE_E2E_DIR_REL/"
        if [ -n "$leak" ]; then
            echo "[WARN] dev worktree 仍有 E2E 目录:$leak——sparse-checkout 未生效" >&2
        else
            echo "[OK] dev worktree @ $wt_path：E2E 集合已排除（行为层隔离）"
        fi
        ;;
    eval)
        leak=""
        [ -d "src" ] && leak="$leak src/"
        [ -d "$OP_DOCS_DIR/op_execution/tasks" ] && leak="$leak op_execution/tasks/"
        [ -d "$OP_DOCS_DIR/op_record/tasks" ] && leak="$leak op_record/tasks/"
        [ -f "$OP_DOCS_DIR/op_record/decisions.md" ] && leak="$leak decisions.md"
        if [ -n "$leak" ]; then
            echo "[WARN] eval worktree 仍有敏感目录:$leak——sparse-checkout 未完全生效，evaluator 不可信赖此隔离" >&2
        else
            echo "[OK] eval worktree @ $wt_path：src/tasks/decisions 已排除（防抄实现）"
        fi
        ;;
esac
