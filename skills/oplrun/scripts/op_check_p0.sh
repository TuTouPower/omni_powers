#!/usr/bin/env bash
# op_check_p0.sh: lite P0 阻断检查（代闸门 C 缺失的 P0 阻断语义，design §5.8）
#
# 扫 docs/omni_powers/op_execution/issues/*.md，找 severity: P0 且 status: open 的。
# exit 0 = 无 open P0，可归档
# exit 1 = 有 open P0，oplrun 停下呈报用户三选一（转修复 task / 显式豁免记 decisions / 中止归档）
#
# 用法：oplrun Stage 4 PASS 后、归档叶子前调本脚本。

set -uo pipefail

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

issues_dir="docs/omni_powers/op_execution/issues"
if [ ! -d "$issues_dir" ]; then
    echo "=== P0 阻断检查：无 issues 目录，可归档 ==="
    exit 0
fi

p0_list=""
for f in "$issues_dir"/*.md; do
    [ -f "$f" ] || continue
    sev="$(awk -F': *' '/^severity:/{print $2; exit}' "$f" 2>/dev/null | tr -d ' ')"
    stat="$(awk -F': *' '/^status:/{print $2; exit}' "$f" 2>/dev/null | tr -d ' ')"
    [ "$sev" = "P0" ] && [ "$stat" = "open" ] || continue
    title="$(awk -F': *' '/^title:/{gsub(/^title: */, ""); print; exit}' "$f" 2>/dev/null | sed 's/[[:space:]]*$//')"
    id="$(awk -F': *' '/^id:/{print $2; exit}' "$f" 2>/dev/null | tr -d ' ')"
    p0_list+="  - ${id:-$(basename "$f" .md)}: ${title:-无标题} ($(basename "$f"))"$'\n'
done

if [ -n "$p0_list" ]; then
    echo "=== P0 阻断检查：发现 open P0 issue，归档前必须处置 ===" >&2
    printf "%s" "$p0_list" >&2
    echo "" >&2
    echo "用户三选一：" >&2
    echo "  1. 转修复 task 回流（走 task 循环，fix 带回归测试先红后绿）" >&2
    echo "  2. 显式豁免——leader append decisions.md（来源标记 leader-close，记豁免理由）" >&2
    echo "  3. 中止归档（保留验收工作区，待 P0 处置）" >&2
    exit 1
fi

echo "=== P0 阻断检查：无 open P0，可归档 ==="
exit 0
