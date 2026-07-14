#!/usr/bin/env bash
# OP 资产所有权判定（install / uninstall / bind 共用）。
# 调用方先设 OP_HOME（可空）；再 source 本文件。
#
# 规则：仅当路径不存在，或为指向 $OP_HOME/skills|agents 下对应名的软链（或路径形如 */skills/<name> 且含 SKILL.md）时视为 OP 资产。
# 非软链目录/文件、指向他处的软链 → 非 OP，禁止静默删除/覆盖。

op_realpath() {
    local p="$1"
    if command -v realpath >/dev/null 2>&1; then
        realpath -m "$p" 2>/dev/null || realpath "$p" 2>/dev/null || readlink -f "$p" 2>/dev/null || printf '%s\n' "$p"
    else
        readlink -f "$p" 2>/dev/null || printf '%s\n' "$p"
    fi
}

# 路径不存在 → 0（可安全写入）
# 是 OP skill 软链 → 0
# 否则 → 1
op_is_owned_skill() {
    local path="$1"
    local name="$2"
    if [ ! -e "$path" ] && [ ! -L "$path" ]; then
        return 0
    fi
    [ -L "$path" ] || return 1
    local target expected
    target="$(op_realpath "$path")"
    [ -n "$target" ] || return 1
    if [ -n "${OP_HOME:-}" ] && [ -d "$OP_HOME/skills/$name" ]; then
        expected="$(op_realpath "$OP_HOME/skills/$name")"
        [ "$target" = "$expected" ] && return 0
    fi
    case "$target" in
        */skills/"$name")
            [ -f "$target/SKILL.md" ] && return 0
            ;;
    esac
    return 1
}

op_is_owned_agent() {
    local path="$1"
    local name="$2" # e.g. op-implementer.md
    if [ ! -e "$path" ] && [ ! -L "$path" ]; then
        return 0
    fi
    [ -L "$path" ] || return 1
    local target expected
    target="$(op_realpath "$path")"
    [ -n "$target" ] || return 1
    if [ -n "${OP_HOME:-}" ] && [ -f "$OP_HOME/agents/$name" ]; then
        expected="$(op_realpath "$OP_HOME/agents/$name")"
        [ "$target" = "$expected" ] && return 0
    fi
    case "$target" in
        */agents/"$name") return 0 ;;
    esac
    return 1
}

# 仅删除 OP 拥有的 skill；非 OP → 打印 WARN 并返回 1（调用方可 die）
# 用法: op_rm_owned_skill path name [dry_run=0|1]
# 返回: 0 已删/不存在/dry；2 非 OP 跳过
op_rm_owned_skill() {
    local path="$1" name="$2" dry="${3:-0}"
    if [ ! -e "$path" ] && [ ! -L "$path" ]; then
        return 0
    fi
    if ! op_is_owned_skill "$path" "$name"; then
        echo "  [SKIP] 非 OP skill（保留用户资产）: $path" >&2
        return 2
    fi
    if [ "$dry" = "1" ]; then
        echo "  [DRY] del $path"
        return 0
    fi
    rm -rf "$path"
    echo "  [DEL] $path"
    return 0
}

op_rm_owned_agent() {
    local path="$1" name="$2" dry="${3:-0}"
    if [ ! -e "$path" ] && [ ! -L "$path" ]; then
        return 0
    fi
    if ! op_is_owned_agent "$path" "$name"; then
        echo "  [SKIP] 非 OP agent（保留用户资产）: $path" >&2
        return 2
    fi
    if [ "$dry" = "1" ]; then
        echo "  [DRY] del $path"
        return 0
    fi
    rm -rf "$path"
    echo "  [DEL] $path"
    return 0
}
