#!/usr/bin/env bash
# 将 OP skill 软链到当前项目 .claude/skills/（业务 skill 项目级发现路径）。
# 用法（在项目根）:
#   bash "$OP_HOME/scripts/op_bind_project_skills.sh" --profile heavy|lite [--dry-run]
#
# 不写 .claude/agents/。软链失败直接 die（无 cp fallback，D30 升级契约）。
# 覆盖前校验所有权；profile 冲突零写入。
set -euo pipefail

die() { echo "[FAIL] $*" >&2; exit 1; }

PROFILE=""
DRY_RUN=0

while [ $# -gt 0 ]; do
    case "$1" in
        --profile)
            [ $# -ge 2 ] || die "--profile 需要值 heavy|lite"
            PROFILE="$2"
            shift 2
            ;;
        --profile=*)
            PROFILE="${1#--profile=}"
            shift
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        -h|--help)
            sed -n '2,9p' "$0"
            exit 0
            ;;
        *)
            die "未知参数: $1（用法: --profile heavy|lite [--dry-run]）"
            ;;
    esac
done

[ -n "$PROFILE" ] || die "必须指定 --profile heavy|lite"
case "$PROFILE" in
    heavy|lite) ;;
    *) die "profile 必须是 heavy 或 lite，收到: $PROFILE" ;;
esac

[ -n "${OP_HOME:-}" ] || die "OP_HOME 未设（先 bash install.sh --set-ophome）"
[ -d "$OP_HOME/skills" ] || die "OP_HOME/skills 不存在: $OP_HOME/skills"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=op_asset_ownership.sh
source "$SCRIPT_DIR/op_asset_ownership.sh"
# shellcheck source=op_paths.sh
source "$SCRIPT_DIR/op_paths.sh"

PROJECT_ROOT="$(pwd)"
if git rev-parse --show-toplevel >/dev/null 2>&1; then
    PROJECT_ROOT="$(git rev-parse --show-toplevel)"
fi
PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd)"

# ── profile 互斥（任何写入之前）──
op_load_paths "" "$PROJECT_ROOT" || die "无法解析 OP_DOCS_DIR（检查 .claude/settings.json）"
if [ -f "$OP_PROFILE_FILE" ]; then
    existing="$(tr -d '[:space:]' < "$OP_PROFILE_FILE" || true)"
    if [ -n "$existing" ] && [ "$existing" != "$PROFILE" ]; then
        die "profile 冲突：项目已是 $existing，拒绝 bind $PROFILE（同一项目只认一个 profile；不清场不转换）"
    fi
fi

if [ "$PROFILE" = "heavy" ]; then
    NAMES=(opinit opintake oprun opstatus optriage opspec opred)
else
    NAMES=(oplinit oplintake oplrun opstatus optriage opspec opred)
fi

SKILLS_DST="$PROJECT_ROOT/.claude/skills"

# ── 预检：源存在 + 目标可覆盖（无写入）──
for name in "${NAMES[@]}"; do
    src="$OP_HOME/skills/$name"
    dst="$SKILLS_DST/$name"
    [ -d "$src" ] || die "源 skill 不存在: $src"
    if ! op_is_owned_skill "$dst" "$name"; then
        die "目标已被非 OP 资产占用，拒绝覆盖: $dst（请用户处理同名 skill 后再 bind）"
    fi
done

if [ "$DRY_RUN" -eq 1 ]; then
    echo "=== dry-run bind project skills (profile=$PROFILE) → $SKILLS_DST ==="
    for name in "${NAMES[@]}"; do
        echo "  [DRY] $SKILLS_DST/$name → $OP_HOME/skills/$name"
    done
    echo "[OK] dry-run：将绑定 ${#NAMES[@]} 个 skill（零写入）"
    exit 0
fi

mkdir -p "$SKILLS_DST"

echo "=== bind project skills (profile=$PROFILE) → $SKILLS_DST ==="
for name in "${NAMES[@]}"; do
    src="$OP_HOME/skills/$name"
    dst="$SKILLS_DST/$name"
    # 再次所有权（防 TOCTOU 弱防护）
    op_is_owned_skill "$dst" "$name" || die "目标非 OP 资产: $dst"
    rm -rf "$dst"
    if ! ln -s "$src" "$dst"; then
        die "软链失败: $dst → $src（D30 要求软链；不 fallback 拷贝。检查文件系统/权限）"
    fi
    echo "  [LINK] $dst → $src"
done

echo "[OK] 已绑定 ${#NAMES[@]} 个 skill（未写 agents）"
echo "  下一步: heavy 用 /opintake /oprun；lite 用 /oplintake /oplrun"
