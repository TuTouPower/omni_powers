#!/usr/bin/env bash
# install：唯一安装脚本（heavy + lite 共用）。
# 用法: bash install.sh [--link] [--set-ophome]
#   --link       用软链代替拷贝同步到 OP_HOME（开发期，改仓库即生效）
#   --set-ophome 强制写 OP_HOME 到 ~/.claude/settings.json（即使已存在）
#
# OP_HOME 确定顺序：
#   1. settings.json 已有 OP_HOME → 沿用
#   2. 否则默认 ~/.config/omni_powers
#
# 安装内容：
#   - skills/ agents/ scripts/ hooks/ docs/ docs_template/ → OP_HOME
#   - 全局仅软链 opinit + oplinit → ~/.claude/skills/（业务 skill 由 init 绑到项目）
#   - agents 只留 OP_HOME（提示词模板，不注册 ~/.claude/agents/）
#   - scripts/ hooks/ docs/ docs_template/ 经 $OP_HOME 引用
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_HOME="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
DEFAULT_OP_HOME="$HOME/.config/omni_powers"
MODE="cp"
FORCE_OPHOME=0

for arg in "$@"; do
    case "$arg" in
        --link) MODE="link" ;;
        --set-ophome) FORCE_OPHOME=1 ;;
        *) echo "[WARN] 未知参数: $arg" ;;
    esac
done

die() { echo "[FAIL] $*" >&2; exit 1; }
warn() { echo "[WARN] $*" >&2; }

command -v jq >/dev/null 2>&1 || warn "未装 jq——运行时需要"
command -v git >/dev/null 2>&1 || warn "未装 git——运行时需要"

# ── 确定 OP_HOME ──
SETTINGS="$CLAUDE_HOME/settings.json"
EXISTING_OH=""
if [ -f "$SETTINGS" ]; then
    EXISTING_OH="$(jq -r '.env.OP_HOME // empty' "$SETTINGS" 2>/dev/null || true)"
fi

if [ -n "${EXISTING_OH:-}" ]; then
    OP_HOME="$EXISTING_OH"
    echo "[INFO] OP_HOME 已设置: $OP_HOME"
else
    OP_HOME="$DEFAULT_OP_HOME"
    echo "[INFO] OP_HOME 未设置，默认: $OP_HOME"
fi

# ── 辅助：安装目录/文件到目标 ──
install_item() {
    local src="$1" dst="$2"
    [ -e "$src" ] || die "源不存在: $src"
    rm -rf "$dst"
    if [ "$MODE" = "link" ]; then
        ln -s "$src" "$dst"
        echo "  [LINK] $dst → $src"
    else
        cp -r "$src" "$dst"
        echo "  [COPY] $dst"
    fi
}

# ── 填充 OP_HOME ──
if [ "$REPO_ROOT" = "$OP_HOME" ]; then
    echo "=== OP_HOME 即当前仓库，跳过同步 ==="
else
    if [ ! -d "$OP_HOME" ]; then
        echo "=== 首次安装：创建 OP_HOME ($OP_HOME) ==="
        mkdir -p "$OP_HOME"
    fi

    echo "=== 同步 repo → OP_HOME ==="
    for d in skills agents scripts hooks; do
        if [ -e "$REPO_ROOT/$d" ]; then
            install_item "$REPO_ROOT/$d" "$OP_HOME/$d"
        fi
    done

    for d in docs; do
        if [ -e "$REPO_ROOT/$d" ] && [ ! -e "$OP_HOME/$d" ]; then
            install_item "$REPO_ROOT/$d" "$OP_HOME/$d"
        fi
    done

    for d in docs_template; do
        if [ -e "$REPO_ROOT/$d" ]; then
            install_item "$REPO_ROOT/$d" "$OP_HOME/$d"
        fi
    done

    for f in CLAUDE.md RULES.md; do
        if [ -f "$REPO_ROOT/$f" ]; then
            cp "$REPO_ROOT/$f" "$OP_HOME/$f"
            echo "  [CP] $OP_HOME/$f"
        fi
    done
fi

find "$OP_HOME/scripts" -name '*.sh' -exec chmod +x {} + 2>/dev/null || true
find "$OP_HOME/hooks" -name '*.sh' -exec chmod +x {} + 2>/dev/null || true

# ── 全局仅注册 opinit + oplinit（覆盖前校验 OP 所有权）──
# shellcheck source=scripts/op_asset_ownership.sh
source "$OP_HOME/scripts/op_asset_ownership.sh"
# OP_HOME 已 export 语义：ownership 脚本读环境变量
export OP_HOME

SKILLS_DST="$CLAUDE_HOME/skills"
AGENTS_DST="$CLAUDE_HOME/agents"
mkdir -p "$SKILLS_DST"

GLOBAL_SKILLS=(opinit oplinit)
echo "=== 注册全局 skill（仅 init）→ ~/.claude/skills/ ==="
for name in "${GLOBAL_SKILLS[@]}"; do
    src="$OP_HOME/skills/$name"
    dst="$SKILLS_DST/$name"
    [ -d "$src" ] || die "缺 skill: $src"
    if ! op_is_owned_skill "$dst" "$name"; then
        die "全局 skill 路径已被非 OP 资产占用，拒绝覆盖: $dst"
    fi
    rm -rf "$dst"
    ln -s "$src" "$dst" || die "软链失败: $dst → $src"
    echo "  [LINK] $dst → $src"
done

# 清理旧版业务 skill：仅删 OP 拥有的软链
LEGACY_SKILLS=(oprun opintake opstatus oplrun oplintake opspec opred optriage op)
echo "=== 清理遗留全局业务 skill（仅 OP 资产）==="
for name in "${LEGACY_SKILLS[@]}"; do
    dst="$SKILLS_DST/$name"
    rc=0
    op_rm_owned_skill "$dst" "$name" 0 || rc=$?
    if [ "$rc" -eq 2 ]; then
        warn "保留非 OP 同名路径: $dst"
    fi
done

LEGACY_AGENTS=(op-implementer.md op-reviewer.md op-evaluator.md op-closer.md)
echo "=== 清理遗留 agents（仅 OP 资产）→ ~/.claude/agents/ ==="
for name in "${LEGACY_AGENTS[@]}"; do
    dst="$AGENTS_DST/$name"
    rc=0
    op_rm_owned_agent "$dst" "$name" 0 || rc=$?
    if [ "$rc" -eq 2 ]; then
        warn "保留非 OP 同名 agent: $dst"
    fi
done

# ── OP_HOME 写入 settings.json ──
NEED_WRITE=0
if [ "$FORCE_OPHOME" -eq 1 ]; then
    NEED_WRITE=1
elif [ -z "${EXISTING_OH:-}" ]; then
    NEED_WRITE=1
fi

if [ "$NEED_WRITE" -eq 1 ]; then
    [ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"
    tmp="$(mktemp)"
    jq --arg oh "$OP_HOME" '.env = (.env // {}) | .env.OP_HOME = $oh' "$SETTINGS" > "$tmp" \
        && mv "$tmp" "$SETTINGS" \
        && echo "[OK] OP_HOME=$OP_HOME 写入 $SETTINGS"
else
    echo "[INFO] OP_HOME 已存在，跳过写入（--set-ophome 强制写入）"
fi

echo ""
echo "[OK] 安装完成"
echo "  OP_HOME = $OP_HOME"
echo "  全局 skill：/opinit /oplinit（仅此二者）"
echo "  按项目选模式："
echo "    heavy  : /opinit →（自动 bind 项目 skill）→ /opintake → /oprun"
echo "    lite   : /oplinit →（自动 bind 项目 skill）→ /oplintake → /oplrun"
