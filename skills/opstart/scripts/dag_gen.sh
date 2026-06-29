#!/usr/bin/env bash
# 从 tasks_list.json 生成 DAG 图 + 依赖关系表
# 用法: dag_gen.sh
# 输出: docs/omni_powers/op_execution/dag.md
set -euo pipefail

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

jq_script="$(mktemp)"
trap 'rm -f "$jq_script"' EXIT

cat > "$jq_script" << 'JQEOF'
"# DAG — 任务依赖图\n\n> 生成时间: \(now | strftime("%Y-%m-%d %H:%M:%S"))\n",
"## Mermaid\n",
"",
"```mermaid",
"graph TD",
(.tasks[] | select(.status != "完成") | "  \(.id)[\(.id)<br/>\(.status)]"),
(.tasks[] | select(.status != "完成" and .depends_on != null and (.depends_on | length) > 0) | .depends_on[] as $d | "  \($d) --> \(.id)"),

"```",
"",
"## 依赖关系",
"",
"| Task | 状态 | depends_on |",
"|---|---|---|",
(.tasks[] | "| \(.id) | \(.status) | \(.depends_on // "-" | if type == "array" then join(", ") else . end) |")
JQEOF

jq -r -f "$jq_script" docs/omni_powers/op_execution/tasks_list.json > docs/omni_powers/op_execution/dag.md

[ -s docs/omni_powers/op_execution/dag.md ] || { echo "[FAIL] dag.md 生成失败或为空" >&2; exit 1; }

echo "[OK] dag.md 已生成 ($(wc -l < docs/omni_powers/op_execution/dag.md) 行)"
