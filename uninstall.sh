#!/usr/bin/env bash
# uninstall：反向 uninstall install.sh 的产物。
# 用法: bash uninstall.sh [--dry-run] [-y] [--purge-project]
#
# 默认（全局卸载）：
#   - 删 ~/.claude/skills/{opinit,opintake,oprun,opspec,opred,opstatus,optriage,oplinit,oplintake,oplrun}
#   - 删 ~/.claude/agents/{op-implementer,op-reviewer,op-evaluator,op-closer}.md
#   - 从 ~/.claude/settings.json 的 env 段移除 OP_HOME（备份后改）
#
# --purge-project（在已初始化的项目根跑，额外清理该项目的 omni_powers 产物）：
#   - 删 docs/omni_powers/
#   - 从项目 .claude/settings.json 的 hooks 段移除 omni_powers 注册的 hook（command 命中 OP_HOME/hooks/run-hook.cmd 或含 omni_powers）
#   - 删 .git/hooks/ 下含 omni_powers 标记的 git hook 文件
#
# 不动用户其它 skill/agent/hook。软链与拷贝两种安装形态均处理（删目标，不动源仓库）。
set -euo pipefail

CLAUDE_HOME="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
DRY_RUN=0
ASSUME_YES=0
PURGE_PROJECT=0
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
        -y|--yes) ASSUME_YES=1 ;;
        --purge-project) PURGE_PROJECT=1 ;;
        -h|--help)
            sed -n '2,20p' "$0"; exit 0 ;;
        *) echo "[WARN] 未知参数: $arg" ;;
    esac
done

SKILLS=(opinit opintake oprun opspec opred opstatus optriage oplinit oplintake oplrun)
AGENTS=(op-implementer op-reviewer op-evaluator op-closer)

# del <path>：删文件或目录，dry-run 只打印不删。软链/文件/目录统一处理。
del() {
    local dst="$1"
    if [ -e "$dst" ] || [ -L "$dst" ]; then
        if [ "$DRY_RUN" -eq 1 ]; then echo "  [DRY] del $dst"
        else rm -rf "$dst"; echo "  [DEL] $dst"; fi
    fi
}

backup_settings() {
    local f="$1"
    [ -f "$f" ] || return 0
    local bak="$f.bak.$(date +%s)"
    cp "$f" "$bak"
    echo "  [BAK] $f → $bak"
}

print_plan() {
    echo "=== 将执行 ==="
    echo "  [全局] 删 skill（${#SKILLS[@]} 个）：${SKILLS[*]}"
    echo "         路径前缀：$CLAUDE_HOME/skills/"
    echo "  [全局] 删 agent（${#AGENTS[@]} 个）：${AGENTS[*]}"
    echo "         路径前缀：$CLAUDE_HOME/agents/"
    echo "  [全局] 移除 $CLAUDE_HOME/settings.json 的 env.OP_HOME"
    if [ "$PURGE_PROJECT" -eq 1 ]; then
        echo "  [项目] 删 docs/omni_powers/（当前目录）"
        echo "  [项目] 清 .claude/settings.json 中 omni_powers 注册的 hook"
        echo "  [项目] 删 .git/hooks/ 下 omni_powers 生成的 git hook"
    fi
}

# ── 全局卸载 ──
remove_global() {
    echo "=== 全局卸载 → $CLAUDE_HOME ==="
    for s in "${SKILLS[@]}"; do
        del "$CLAUDE_HOME/skills/$s"
    done
    for a in "${AGENTS[@]}"; do
        del "$CLAUDE_HOME/agents/$a.md"
    done

    # 共享 scripts 目录（D5 install 装的，A6 反向清理）
    del "$CLAUDE_HOME/scripts/omni_powers"

    local settings="$CLAUDE_HOME/settings.json"
    if [ -f "$settings" ] && command -v jq >/dev/null 2>&1; then
        if jq -e '.env.OP_HOME' "$settings" >/dev/null 2>&1; then
            if [ "$DRY_RUN" -eq 1 ]; then
                echo "  [DRY] 移除 env.OP_HOME"
            else
                backup_settings "$settings"
                tmp="$(mktemp)"
                jq 'del(.env.OP_HOME)' "$settings" > "$tmp" && mv "$tmp" "$settings"
                echo "  [OK] 移除 env.OP_HOME"
            fi
        else
            echo "  [SKIP] env.OP_HOME 未设"
        fi
    elif [ -f "$settings" ]; then
        echo "  [WARN] 缺 jq，未动 $settings（手动删 env.OP_HOME）"
    fi
}

# ── 项目级清理 ──
purge_project() {
    echo "=== 项目级清理（$(pwd)）==="
    local docs_op="docs/omni_powers"
    del "$docs_op"

    # 项目 .claude/settings.json hooks 清理
    local ps=".claude/settings.json"
    if [ -f "$ps" ] && command -v jq >/dev/null 2>&1; then
        if jq -e '.hooks' "$ps" >/dev/null 2>&1; then
            if [ "$DRY_RUN" -eq 1 ]; then
                echo "  [DRY] 清理 .claude/settings.json 的 omni_powers hook"
            else
                backup_settings "$ps"
                tmp="$(mktemp)"
                # 各 hook 事件数组里，丢弃 command 命中 omni_powers / OP_HOME/hooks/run-hook.cmd 的项
                jq '
                    def is_op: (.command // "") | test("omni_powers|\\$OP_HOME/hooks/run-hook\\.cmd|OP_HOME/hooks/run-hook\\.cmd");
                    .hooks |= with_entries(
                        .value |= map(select(. | is_op | not))
                    )
                    | .hooks |= with_entries(select(.value | length > 0))
                ' "$ps" > "$tmp" && mv "$tmp" "$ps"
                echo "  [OK] 清理 $ps 中 omni_powers hook"
            fi
        else
            echo "  [SKIP] $ps 无 hooks 段"
        fi
    fi

    # git hooks
    local git_hooks
    git_hooks="$(git rev-parse --git-path hooks 2>/dev/null || true)"
    if [ -n "$git_hooks" ] && [ -d "$git_hooks" ]; then
        for gh in "$git_hooks"/*; do
            [ -f "$gh" ] || continue
            if grep -q "omni_powers" "$gh" 2>/dev/null; then
                del "$gh"
            fi
        done
    else
        echo "  [SKIP] 非 git 仓库或无 hooks 目录"
    fi
}

print_plan
echo ""
if [ "$ASSUME_YES" -ne 1 ] && [ "$DRY_RUN" -ne 1 ]; then
    printf "确认执行？[y/N] "
    read -r ans
    case "$ans" in
        y|Y|yes|YES) ;;
        *) echo "[ABORT] 用户取消"; exit 0 ;;
    esac
fi

remove_global
[ "$PURGE_PROJECT" -eq 1 ] && purge_project

echo ""
if [ "$DRY_RUN" -eq 1 ]; then
    echo "[OK] dry-run 预览完成（未实际删除，去掉 --dry-run 执行）"
else
    echo "[OK] 卸载完成"
    [ "$PURGE_PROJECT" -eq 0 ] && echo "  如需清理某项目的 docs/omni_powers/ 与 hook：在该项目根跑 bash uninstall.sh --purge-project -y"
fi
