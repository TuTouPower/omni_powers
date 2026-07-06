#!/usr/bin/env bash
# op_worktree_teardown.sh: 清理隔离 worktree（+ 可选删分支）
# 用法: op_worktree_teardown.sh <path> [branch]

set -uo pipefail

wt_path="${1:?usage: op_worktree_teardown.sh <path> [branch]}"
branch="${2:-}"

if git worktree list 2>/dev/null | grep -q "$wt_path"; then
    git worktree remove "$wt_path" --force 2>/dev/null && echo "[OK] worktree removed: $wt_path"
else
    rm -rf "$wt_path" 2>/dev/null && echo "[OK] worktree dir removed: $wt_path"
fi

if [ -n "$branch" ]; then
    git branch -D "$branch" 2>/dev/null && echo "[OK] branch deleted: $branch" || true
fi
