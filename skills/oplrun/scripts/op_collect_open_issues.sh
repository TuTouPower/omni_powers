#!/usr/bin/env bash
# op_collect_open_issues：扫 open issue 汇总（结束报告用，A18 事后）
# 改自 op_check_p0.sh——去阻断语义（A18：P0 不事中阻断），只汇总返回 0
# 用法：oplrun 结束报告时调，输出 open P0/P1 清单（P0 标注供用户优先处置）
set -uo pipefail

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

issues_dir="docs/omni_powers/op_execution/issues"
[ -d "$issues_dir" ] || { echo "(无 issues 目录)"; exit 0; }

found=0
for sev in P0 P1; do
    for f in "$issues_dir"/*.md; do
        [ -f "$f" ] || continue
        s="$(awk -F': *' '/^severity:/{print $2; exit}' "$f" 2>/dev/null | tr -d ' \r')"
        st="$(awk -F': *' '/^status:/{print $2; exit}' "$f" 2>/dev/null | tr -d ' \r')"
        [ "$s" = "$sev" ] && [ "$st" = "open" ] || continue
        title="$(awk -F': *' '/^title:/{gsub(/^title: */, ""); print; exit}' "$f" 2>/dev/null | sed 's/[[:space:]]*$//')"
        id="$(awk -F': *' '/^id:/{print $2; exit}' "$f" 2>/dev/null | tr -d ' \r')"
        echo "  [$sev] ${id:-$(basename "$f" .md)}: ${title:-无标题} ($(basename "$f"))"
        found=1
    done
done

[ "$found" -eq 0 ] && echo "(无 open P0/P1 issue)"
exit 0
