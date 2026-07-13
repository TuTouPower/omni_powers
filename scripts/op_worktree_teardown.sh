#!/usr/bin/env bash
# op_worktree_teardown.sh: 清理隔离 worktree（+ 可选删分支）
# 用法: op_worktree_teardown.sh <path> [branch] [--force]
#
# 防成果蒸发闸（本轮改进）：teardown 前查未 commit 改动 + 分支未合并 commit。
#   有脏工作区或未合并 commit → 拒绝清理并列出，除非显式 --force。
#   根因：T0002 事故中 op-dev/op-eval 两 worktree 全部成果零 commit，teardown 即全丢。

set -uo pipefail

wt_path=""
branch=""
force=false
for arg in "$@"; do
    case "$arg" in
        --force) force=true ;;
        *) if [ -z "$wt_path" ]; then wt_path="$arg"; elif [ -z "$branch" ]; then branch="$arg"; fi ;;
    esac
done

[ -n "$wt_path" ] || { echo "usage: op_worktree_teardown.sh <path> [branch] [--force]" >&2; exit 1; }

die() { echo "[FAIL] $*" >&2; exit 1; }

# ── 防蒸发检查（--force 跳过）──
if ! $force && [ -d "$wt_path" ]; then
    # 1. 未 commit 改动（含 untracked）
    dirty="$(git -C "$wt_path" status --porcelain 2>/dev/null)"
    if [ -n "$dirty" ]; then
        echo "[FAIL] worktree 有未 commit 改动，拒绝清理（防成果蒸发）: $wt_path" >&2
        echo "$dirty" | head -30 >&2
        echo "[HINT] 先 commit/合并这些改动，或确认丢弃后加 --force 重跑" >&2
        exit 2
    fi
    # 2. 分支相对主分支的未合并 commit
    if [ -n "$branch" ]; then
        base="$(git branch -r 2>/dev/null | grep -oE 'origin/(main|master)$' | head -1)"
        base="${base:-main}"
        base_local="${base#origin/}"
        # 优先本地主分支，退化到 remote
        if git rev-parse --verify "$base_local" >/dev/null 2>&1; then cmp="$base_local"
        elif git rev-parse --verify "$base" >/dev/null 2>&1; then cmp="$base"
        else cmp=""; fi
        if [ -n "$cmp" ]; then
            unmerged="$(git -C "$wt_path" log --oneline "$cmp".."$branch" 2>/dev/null)"
            if [ -n "$unmerged" ]; then
                # ancestry 不通过时判 tree 等价（squash-merge：内容已入主分支但 commit 非祖先）
                if git diff --quiet "$branch" "$cmp" -- . ':!e2e/' 2>/dev/null; then
                    echo "[OK] squash-merge 检测: $branch 内容已等价于 $cmp（tree diff 空，e2e/ 除外）"
                else
                    echo "[FAIL] 分支 $branch 有未合并到 $cmp 的 commit，拒绝删除（防成果蒸发）:" >&2
                    echo "$unmerged" | head -30 >&2
                    echo "[HINT] 先 merge 回 $cmp，或确认丢弃后加 --force 重跑" >&2
                    exit 2
                fi
            fi
        fi
    fi
fi

if git worktree list 2>/dev/null | grep -q "$wt_path"; then
    git worktree remove "$wt_path" --force 2>/dev/null && echo "[OK] worktree removed: $wt_path"
else
    rm -rf "$wt_path" 2>/dev/null && echo "[OK] worktree dir removed: $wt_path"
fi

if [ -n "$branch" ]; then
    git branch -D "$branch" 2>/dev/null && echo "[OK] branch deleted: $branch" || true
fi
