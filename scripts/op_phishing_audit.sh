#!/usr/bin/env bash
# op_phishing_audit.sh: 钓鱼审计植 bug 骨架（design §2.5 防放水第4层）
#
# leader 定期钓鱼：在独立验证环境副本（op-eval worktree）植一个已知 bug，
# 跑 evaluator 看抓不抓得到。测的是 evaluator 判别力本身，不随上游质量起伏。
#
# 本脚本只做「植 bug」+「提示对照」，不跑 evaluator（evaluator 是 Stage 4
# 多模态操作，需 leader dispatch）。植 bug 后 leader：
#   1. 在 op-eval worktree 同步植同 bug（脚本在主工作树植，worktree 需重植或同步）
#   2. dispatch op-evaluator 评估受影响 AC
#   3. evaluator FAIL = 抓到（好）；PASS = 漏钓 → 补 few-shot 校准
#   4. 审计完恢复：mv <src>.phishing-backup <src>
#
# bug-type（针对 JS/C 系语法，Python 等无分号语言需手改 sed）:
#   comment-assert  注释掉 assert/expect 行（[line-keyword] 限定具体行，空=全部）
#   flip-cond       反转条件（== ↔ !=）
#   drop-check      注释掉含 line-keyword 的 return/if 守卫行
#
# 用法: op_phishing_audit.sh <src-file> <bug-type> [line-keyword]

set -uo pipefail

src="${1:?usage: op_phishing_audit.sh <src-file> <bug-type> [line-keyword]}"
bug_type="${2:?bug-type: comment-assert | flip-cond | drop-check}"
keyword="${3:-}"

[ -f "$src" ] || { echo "[FATAL] $src 不存在" >&2; exit 2; }

backup="${src}.phishing-backup"
cp "$src" "$backup"
echo "[phishing] 备份: $backup（审计完恢复：mv $backup $src）"

case "$bug_type" in
    comment-assert)
        if [ -n "$keyword" ]; then
            sed -i -E "/$keyword/ s,(assert|expect)[^;]*;,/* PHISHING: & */,I" "$src"
        else
            sed -i -E 's,(assert|expect)[^;]*;,/* PHISHING: & */,Ig' "$src"
        fi
        ;;
    flip-cond)
        sed -i -E 's/==/__PHISH_EQ__/g; s/!=/==/g; s/__PHISH_EQ__/!=/g' "$src"
        ;;
    drop-check)
        [ -n "$keyword" ] || { echo "[FATAL] drop-check 需指定 line-keyword" >&2; exit 2; }
        sed -i -E "/$keyword/ s/^(.*return.*)$/\/\/ PHISHING DROPPED: \1/" "$src"
        ;;
    *)
        echo "[FATAL] bug-type 必须是 comment-assert | flip-cond | drop-check" >&2
        exit 2
        ;;
esac

echo "[phishing] 已植 bug（$bug_type）于 $src"
echo "[phishing] leader 后续："
echo "  1. 在 op-eval worktree 同步此 bug（或在 worktree 内重跑本脚本）"
echo "  2. dispatch op-evaluator 评估受影响 AC"
echo "  3. evaluator FAIL=抓到（好）；PASS=漏钓（补 few-shot 校准）"
echo "  4. 审计完恢复：mv '$backup' '$src'"
