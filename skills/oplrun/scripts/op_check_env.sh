#!/usr/bin/env bash
# op_check_env（lite）：只校验 jq / git / bash——lite 无 OP_HOME 依赖
# 用法: op_check_env.sh（各 lite skill / agent 入口跑，缺失 die + 装法）
set -uo pipefail

missing=0

check() {
    local cmd="$1"
    local hint="$2"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "[FAIL] 缺失命令: $cmd" >&2
        echo "  装法: $hint" >&2
        missing=1
    fi
}

check jq "Windows: scoop install jq / choco install jq；macOS: brew install jq；Linux: apt install jq"
check git "Windows: https://git-scm.com/；macOS: xcode-select --install；Linux: apt install git"

if [ -z "${BASH_VERSION:-}" ]; then
    echo "[WARN] 非 bash 运行（脚本依赖 bash 特性）" >&2
fi

if [ "$missing" -ne 0 ]; then
    echo "[FAIL] 环境检查未通过，修复后重跑" >&2
    exit 1
fi

echo "[OK] lite 环境检查通过（jq / git 就绪）"
