#!/usr/bin/env bash
# install：唯一安装脚本（heavy + lite 共用），全量装 omni_powers 到 ~/.claude。
# 用法: bash install.sh [--link] [--set-ophome]
#   --link       用软链代替拷贝（开发期，改仓库即生效）
#   --set-ophome 写 OP_HOME 到 ~/.claude/settings.json 的 env 段（heavy 模式需要）
#
# 安装内容：
#   - 全部 skill（opinit/opintake/oprun/opspec/opred/opstatus/optriage + oplinit/oplintake/oplrun）
#   - 全部 agent（op-implementer/op-reviewer/op-evaluator/op-closer）
# 装一次，按项目选模式（同一项目只认一个 profile）：
#   heavy → /opinit（注册项目 hook，需 --set-ophome）
#   lite  → /oplinit（零侵入，不碰项目配置）
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_HOME="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
MODE="cp"
SET_OPHOME=0
for arg in "$@"; do
    case "$arg" in
        --link) MODE="link" ;;
        --set-ophome) SET_OPHOME=1 ;;
        *) echo "[WARN] 未知参数: $arg" ;;
    esac
done

die() { echo "[FAIL] $*" >&2; exit 1; }

command -v jq >/dev/null 2>&1 || echo "[WARN] 未装 jq——运行时需要"
command -v git >/dev/null 2>&1 || echo "[WARN] 未装 git——运行时需要"

SKILLS_DST="$CLAUDE_HOME/skills"
AGENTS_DST="$CLAUDE_HOME/agents"
mkdir -p "$SKILLS_DST" "$AGENTS_DST"

install_one() {
    local src="$1" dst="$2"
    [ -e "$src" ] || die "源不存在: $src"
    if [ "$MODE" = "link" ]; then
        rm -rf "$dst"; ln -s "$src" "$dst"; echo "[LINK] $dst"
    else
        rm -rf "$dst"; cp -r "$src" "$dst"; echo "[COPY] $dst"
    fi
}

echo "=== 装 skill + agent（全部）==="
for s in opinit opintake oprun opspec opred opstatus optriage oplinit oplintake oplrun; do
    [ -d "$REPO_ROOT/skills/$s" ] && install_one "$REPO_ROOT/skills/$s" "$SKILLS_DST/$s"
done

for a in op-implementer op-reviewer op-evaluator op-closer; do
    install_one "$REPO_ROOT/agents/$a.md" "$AGENTS_DST/$a.md"
done

if [ "$MODE" = "cp" ]; then
    find "$SKILLS_DST"/{opinit,oprun,oplinit,oplintake,oplrun} -name '*.sh' -exec chmod +x {} + 2>/dev/null || true
fi

# ── OP_HOME（两版都需要——脚本统一在 $OP_HOME/scripts/）──
if [ "$SET_OPHOME" -eq 1 ]; then
    SETTINGS="$CLAUDE_HOME/settings.json"
    [ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"
    tmp="$(mktemp)"
    jq --arg oh "$REPO_ROOT" '.env = (.env // {}) | .env.OP_HOME = $oh' "$SETTINGS" > "$tmp" \
        && mv "$tmp" "$SETTINGS" \
        && echo "[OK] OP_HOME=$REPO_ROOT 写入 $SETTINGS（两版共用脚本根）"
else
    echo "[INFO] 未设 OP_HOME（--set-ophome 可写）。两版都需要它定位脚本"
fi

echo ""
echo "[OK] 全量安装完成 → $CLAUDE_HOME"
echo "  按项目选模式："
echo "    heavy（全量）：/opinit → /opintake → /oprun"
echo "    lite （零侵入）：/oplinit → /oplintake → /oplrun"
