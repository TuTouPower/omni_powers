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
#   - 按项目 env.OP_DOCS_DIR 清理 OP 资产；根为 docs 时保留宿主文档
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
        echo "  [项目] 按 .claude/settings.json 的 env.OP_DOCS_DIR 清理 OP 资产"
        echo "  [项目] 清 .claude/settings.json 中 omni_powers hook + env.OP_DOCS_DIR"
        echo "  [项目] 删 .git/hooks/ 下 omni_powers 生成的 git hook/helper"
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
remove_managed_block() {
    local file="$1"
    local label="$2"
    local begin="<!-- omni_powers managed start: $label -->"
    local end="<!-- omni_powers managed end: $label -->"
    [ -f "$file" ] || return 0
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "  [DRY] 移除 $file 的 omni_powers managed block"
        return 0
    fi
    local tmp
    tmp="$(mktemp "$(dirname "$file")/.op-uninstall.XXXXXX")"
    awk -v begin="$begin" -v end="$end" '
        $0 == begin {skip=1; next}
        $0 == end {skip=0; next}
        !skip {print}
    ' "$file" > "$tmp"
    mv "$tmp" "$file"
    [ -s "$file" ] || rm -f "$file"
}

purge_project() {
    echo "=== 项目级清理（$(pwd)）==="
    local root settings docs_dir docs_root
    root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
    settings="$root/.claude/settings.json"
    docs_dir="docs/omni_powers"

    if [ -f "$settings" ]; then
        command -v jq >/dev/null 2>&1 || { echo "[FAIL] 缺 jq，无法安全解析 $settings" >&2; return 1; }
        jq -e '
            type == "object" and
            ((.env? // {}) | type == "object") and
            (((.env? // {}) | has("OP_DOCS_DIR") | not) or
             (((.env.OP_DOCS_DIR | type) == "string") and ((.env.OP_DOCS_DIR | length) > 0)))
        ' "$settings" >/dev/null 2>&1 || { echo "[FAIL] $settings 中 env 或 env.OP_DOCS_DIR 类型/值非法" >&2; return 1; }
        configured="$(jq -r '(.env? // {}).OP_DOCS_DIR // empty' "$settings")"
        [ -z "$configured" ] || docs_dir="$configured"
    fi

    source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/scripts/op_paths.sh"
    docs_dir="$(op_normalize_docs_dir "$docs_dir")" || return 1
    op_reject_symlink_path "$root" ".claude" || return 1
    op_reject_symlink_path "$root" ".claude/settings.json" || return 1
    op_reject_symlink_path "$root" "$docs_dir" || return 1
    docs_root="$root/$docs_dir"

    if [ "$docs_dir" = "docs" ]; then
        local item
        for item in op_blueprint op_execution op_record e2e profile op_readme.md op_index.md; do
            del "$docs_root/$item"
        done
        remove_managed_block "$docs_root/README.md" README.md
        remove_managed_block "$docs_root/index.md" index.md
        remove_managed_block "$docs_root/.gitignore" gitignore
    else
        del "$docs_root"
    fi

    if [ -f "$settings" ]; then
        if [ "$DRY_RUN" -eq 1 ]; then
            echo "  [DRY] 清理 $settings 的 omni_powers hook + env.OP_DOCS_DIR"
        else
            backup_settings "$settings"
            tmp="$(mktemp "$root/.claude/.settings.XXXXXX")"
            jq '
                def is_op: (.command // "") | test("omni_powers|\\$OP_HOME/hooks/run-hook\\.cmd|OP_HOME/hooks/run-hook\\.cmd");
                def clean_matcher:
                    if (.hooks? | type) == "array" then
                        .hooks |= map(select(. | is_op | not))
                    else . end;
                if (.hooks? | type) == "object" then
                    .hooks |= with_entries(
                        if (.value | type) == "array" then
                            .value |= map(clean_matcher | select((.hooks? // []) | length > 0))
                        else . end
                    )
                    | .hooks |= with_entries(select((.value | type) != "array" or (.value | length) > 0))
                else . end
                | if (.env? | type) == "object" then del(.env.OP_DOCS_DIR) else . end
                | if .env == {} then del(.env) else . end
                | if .hooks == {} then del(.hooks) else . end
            ' "$settings" > "$tmp"
            mv "$tmp" "$settings"
            echo "  [OK] 清理 $settings 中 omni_powers 配置"
        fi
    fi

    local git_hooks git_dir gh
    git_hooks="$(git -C "$root" rev-parse --path-format=absolute --git-path hooks 2>/dev/null || true)"
    git_dir="$(git -C "$root" rev-parse --absolute-git-dir 2>/dev/null || true)"
    if [ -n "$git_hooks" ] && [ -d "$git_hooks" ]; then
        case "$git_hooks/" in
            "$git_dir/"*) ;;
            *)
                echo "  [WARN] core.hooksPath 位于 Git dir 外，拒绝自动删除: $git_hooks" >&2
                return 0
                ;;
        esac
        del "$git_hooks/op_paths.sh"
        for gh in "$git_hooks"/*; do
            [ -f "$gh" ] || continue
            if grep -q "omni_powers" "$gh" 2>/dev/null; then
                del "$gh"
            fi
        done
    else
        echo "  [SKIP] 非 git 仓库或无 hooks 目录"
    fi
    return 0
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
    if [ "$PURGE_PROJECT" -eq 0 ]; then
        echo "  如需清理某项目的 OP 资产与 hook：在该项目根跑 bash uninstall.sh --purge-project -y"
    fi
fi

exit 0
