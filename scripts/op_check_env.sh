#!/usr/bin/env bash
# op_check_env：检查 omni_powers 运行所需的外部命令 + 环境。缺失 die + 装法提示。
# 用法: op_check_env.sh（在各 skill / agent 入口跑——绝不闷头失败）
# 检查：jq / git / bash / OP_HOME
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

# jq（tasks_list.json 读写、hooks 合并、各脚本 JSON 处理）
check jq "Windows: scoop install jq / choco install jq / https://jqlang.github.io/jq/download/；macOS: brew install jq；Linux: apt/deb 包管理装 jq"

# git（worktree / rev-parse / 归档）
check git "Windows: https://git-scm.com/（Git for Windows，Claude Code Windows 前提）；macOS: xcode-select --install；Linux: apt install git"

# bash（脚本运行前提——非 bash 会出问题）
if [ -z "${BASH_VERSION:-}" ]; then
  echo "[WARN] 非 bash 运行（脚本依赖 bash 4+ 特性）" >&2
fi

# OP_HOME（全局 settings.json 设，subagent 继承）
if [ -z "${OP_HOME:-}" ]; then
  echo "[FAIL] OP_HOME 未设（全局 settings.json env 段，如 ~/.claude/settings.json）" >&2
  missing=1
elif [ ! -d "$OP_HOME" ]; then
  echo "[FAIL] OP_HOME 目录不存在: $OP_HOME（应为 omni_powers 仓库根）" >&2
  missing=1
fi

if [ "$missing" -ne 0 ]; then
  echo "[FAIL] 环境检查未通过，修复后重跑" >&2
  exit 1
fi

echo "[OK] 环境检查通过（jq / git / OP_HOME 就绪）"
