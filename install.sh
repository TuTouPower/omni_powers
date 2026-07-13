#!/usr/bin/env bash
# install：唯一安装脚本（heavy + lite 共用），全量装 omni_powers 到 OP_HOME。
# 用法: bash install.sh [--link] [--set-ophome]
#   --link       用软链代替拷贝（开发期，改仓库即生效）
#   --set-ophome 强制写 OP_HOME 到 ~/.claude/settings.json（即使已存在）
#
# OP_HOME 确定顺序：
#   1. settings.json 已有 OP_HOME → 沿用
#   2. 否则默认 ~/.config/omni_powers
#
# 安装内容：
#   - skills/ agents/ scripts/ hooks/ docs/ docs_template/ → OP_HOME
#   - skills/* → ~/.claude/skills/（软链，Claude Code 查找路径）
#   - agents/*.md → ~/.claude/agents/（软链，Claude Code 查找路径）
#   - scripts/ hooks/ docs/ docs_template/ 留在 OP_HOME，通过 $OP_HOME 引用
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

    # docs 只放不覆盖（用户项目可能有自己的 docs/）
    for d in docs; do
        if [ -e "$REPO_ROOT/$d" ] && [ ! -e "$OP_HOME/$d" ]; then
            install_item "$REPO_ROOT/$d" "$OP_HOME/$d"
        fi
    done

    # docs_template 属发布资产，每次原子覆盖（MEDIUM-4：升级不刷新已安装模板）
    for d in docs_template; do
        if [ -e "$REPO_ROOT/$d" ]; then
            install_item "$REPO_ROOT/$d" "$OP_HOME/$d"
        fi
    done

    # 顶层文件（CLAUDE.md / RULES.md）
    for f in CLAUDE.md RULES.md; do
        if [ -f "$REPO_ROOT/$f" ]; then
            cp "$REPO_ROOT/$f" "$OP_HOME/$f"
            echo "  [CP] $OP_HOME/$f"
        fi
    done
fi

# 脚本 + hook 加执行权限
find "$OP_HOME/scripts" -name '*.sh' -exec chmod +x {} + 2>/dev/null || true
find "$OP_HOME/hooks" -name '*.sh' -exec chmod +x {} + 2>/dev/null || true

# ── 从 OP_HOME 软链 skills + agents 到 ~/.claude/ ──
SKILLS_DST="$CLAUDE_HOME/skills"
AGENTS_DST="$CLAUDE_HOME/agents"
mkdir -p "$SKILLS_DST" "$AGENTS_DST"

echo "=== 注册 skills → ~/.claude/skills/ ==="
for s in "$OP_HOME/skills/"*; do
    [ -d "$s" ] || continue
    name="$(basename "$s")"
    rm -rf "$SKILLS_DST/$name"
    ln -s "$s" "$SKILLS_DST/$name"
    echo "  [LINK] $SKILLS_DST/$name → $s"
done

echo "=== 注册 agents → ~/.claude/agents/ ==="
for a in "$OP_HOME/agents/"*.md; do
    [ -f "$a" ] || continue
    name="$(basename "$a")"
    rm -rf "$AGENTS_DST/$name"
    ln -s "$a" "$AGENTS_DST/$name"
    echo "  [LINK] $AGENTS_DST/$name → $a"
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
echo "  按项目选模式："
echo "    heavy  : /opinit → /opintake → /oprun"
echo "    lite   : /oplinit → /oplintake → /oplrun"
