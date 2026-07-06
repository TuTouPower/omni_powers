#!/usr/bin/env bash
# op_mutation_check.sh: 变异测试体检骨架（design §3.3 第6层定期体检）
#
# 对源文件做 == ↔ != 运算符反转变异，跑测试看红绿：
#   KILLED（变异后测试红）= 测试有效，捕获了运算符变异
#   ESCAPE（变异后测试仍绿）= 测试判假，未覆盖 == / != 分支
#
# 骨架仅做 == ↔ != 一种变异（最常见）。专业变异测试推荐：
#   python: mutmut / cosmic-ray    js/ts: stryker
# 本脚本为轻量自检，无外部依赖。
#
# 用法: op_mutation_check.sh <src-file> <test-cmd...>
# 退出码: 0=KILLED（测试有效）；1=ESCAPE（测试判假）；2=基线红/参数错

set -uo pipefail

src="${1:?usage: op_mutation_check.sh <src-file> <test-cmd...>}"
shift
[ -f "$src" ] || { echo "[FATAL] $src 不存在" >&2; exit 2; }

backup="$(mktemp)"
cp "$src" "$backup"
trap 'cp "$backup" "$src" 2>/dev/null; rm -f "$backup"' EXIT

echo "=== op_mutation_check: $src ==="

# 基线：原文件测试必须绿，否则无法判定变异效果
if "$@" > /dev/null 2>&1; then
    :
else
    echo "[FATAL] 基线测试本就红——先修测试，变异测试无意义" >&2
    exit 2
fi

# 检查源文件是否含可变异运算符
if ! grep -qE '==|!=' "$src"; then
    echo "[SKIP] $src 无 == / != 运算符，无变异点"
    exit 0
fi

# 应用变异：== ↔ !=（占位符防连环替换）
sed -i -E 's/==/__MUT_EQ_PLACEHOLDER__/g; s/!=/==/g; s/__MUT_EQ_PLACEHOLDER__/!=/g' "$src"

# 跑变异后测试
if "$@" > /dev/null 2>&1; then
    echo "[ESCAPE] 变异后测试仍绿——测试可能判假（未覆盖 == / != 分支），该测试需补断言"
    exit 1
else
    echo "[KILLED] 变异后测试红——测试有效（捕获 == / != 变异）"
    exit 0
fi
