#!/usr/bin/env bash
# 配置项目 OP 根，并在根变化时迁移 OP 独占资产。
# 用法: op_configure_project.sh --target <repo-relative-path> [--root <repo>] [--yes]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/op_paths.sh"

root=""
target=""
yes=0
while [ "$#" -gt 0 ]; do
    case "$1" in
        --root) root="${2:?--root 缺值}"; shift 2 ;;
        --target) target="${2:?--target 缺值}"; shift 2 ;;
        --yes|-y) yes=1; shift ;;
        *) echo "[FAIL] 未知参数: $1" >&2; exit 1 ;;
    esac
done

root="${root:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
root="$(cd "$root" && pwd)"
target="$(op_normalize_docs_dir "${target:-$OP_DOCS_DIR_DEFAULT}")"
lock_dir="$root/.op-configure.lock"
if ! mkdir "$lock_dir" 2>/dev/null; then
    echo "[FAIL] 已有 OP 配置/迁移进程运行: $lock_dir" >&2
    exit 1
fi
cleanup_lock() { rmdir "$lock_dir" 2>/dev/null || true; }
trap cleanup_lock EXIT
settings="$root/.claude/settings.json"
owned=(op_blueprint op_execution op_record e2e profile op_readme.md op_index.md)
shared=(.gitignore)

op_reject_symlink_path "$root" "$target"
op_reject_symlink_path "$root" ".claude"
op_reject_symlink_path "$root" ".claude/settings.json"

current=""
if [ -f "$settings" ]; then
    if ! jq -e '
        type == "object" and
        ((.env? // {}) | type == "object") and
        (((.env? // {}) | has("OP_DOCS_DIR") | not) or
         (((.env.OP_DOCS_DIR | type) == "string") and ((.env.OP_DOCS_DIR | length) > 0)))
    ' "$settings" >/dev/null 2>&1; then
        echo "[FAIL] $settings 中 env 或 env.OP_DOCS_DIR 类型/值非法" >&2
        exit 1
    fi
    current="$(jq -r '(.env? // {}).OP_DOCS_DIR // empty' "$settings")"
fi
if [ -z "$current" ] && [ -f "$root/$OP_DOCS_DIR_DEFAULT/profile" ]; then
    current="$OP_DOCS_DIR_DEFAULT"
fi
[ -n "$current" ] || current="$target"
current="$(op_normalize_docs_dir "$current")"
op_reject_symlink_path "$root" "$current"

source_root="$root/$current"
target_root="$root/$target"
op_reject_tree_symlinks "$source_root"
op_reject_tree_symlinks "$target_root"

managed_merge() {
    local source_file="$1"
    local target_file="$2"
    local label="$3"
    local begin="<!-- omni_powers managed start: $label -->"
    local end="<!-- omni_powers managed end: $label -->"
    local content=""
    [ -f "$source_file" ] && content="$(cat "$source_file")"
    [ -n "$content" ] || { [ "$label" != gitignore ] || content='*.lock'; }
    [ -n "$content" ] || return 0

    mkdir -p "$(dirname "$target_file")"
    local tmp
    tmp="$(mktemp "$(dirname "$target_file")/.op-managed.XXXXXX")"
    if [ -f "$target_file" ]; then
        awk -v begin="$begin" -v end="$end" '
            $0 == begin {skip=1; next}
            $0 == end {skip=0; next}
            !skip {print}
        ' "$target_file" > "$tmp"
    fi
    {
        [ ! -s "$tmp" ] || { cat "$tmp"; printf '\n'; }
        printf '%s\n%s\n%s\n' "$begin" "$content" "$end"
    } > "$tmp.next"
    [ ! -e "$target_file" ] || chmod --reference="$target_file" "$tmp.next" 2>/dev/null || true
    mv "$tmp.next" "$target_file"
    rm -f "$tmp"
}

managed_extract() {
    local file="$1"
    local label="$2"
    local begin="<!-- omni_powers managed start: $label -->"
    local end="<!-- omni_powers managed end: $label -->"
    [ -f "$file" ] || return 0
    awk -v begin="$begin" -v end="$end" '
        $0 == begin {inside=1; next}
        $0 == end {inside=0; next}
        inside {print}
    ' "$file"
}

managed_remove() {
    local file="$1"
    local label="$2"
    local begin="<!-- omni_powers managed start: $label -->"
    local end="<!-- omni_powers managed end: $label -->"
    [ -f "$file" ] || return 0
    local tmp
    tmp="$(mktemp "$(dirname "$file")/.op-managed-remove.XXXXXX")"
    awk -v begin="$begin" -v end="$end" '
        $0 == begin {skip=1; next}
        $0 == end {skip=0; next}
        !skip {print}
    ' "$file" > "$tmp"
    mv "$tmp" "$file"
    [ -s "$file" ] || rm -f "$file"
}

write_exclusive_shared() {
    local source_file="$1"
    local target_file="$2"
    [ -s "$source_file" ] || return 0
    mkdir -p "$(dirname "$target_file")"
    local tmp
    tmp="$(mktemp "$(dirname "$target_file")/.op-shared.XXXXXX")"
    cat "$source_file" > "$tmp"
    mv "$tmp" "$target_file"
}

conflicts=()
if [ "$current" != "$target" ] && [ -d "$source_root" ]; then
    for item in "${owned[@]}"; do
        src="$source_root/$item"
        dst="$target_root/$item"
        [ -e "$src" ] || continue
        [ ! -L "$src" ] || { echo "[FAIL] OP 资产不可为符号链接: $src" >&2; exit 1; }
        if [ -f "$src" ]; then
            if [ -e "$dst" ] && ! cmp -s "$src" "$dst"; then conflicts+=("$target/$item"); fi
        elif [ -d "$src" ]; then
            while IFS= read -r -d '' rel; do
                rel="${rel#./}"
                [ -n "$rel" ] || continue
                if [ -e "$dst/$rel" ] && ! cmp -s "$src/$rel" "$dst/$rel"; then
                    conflicts+=("$target/$item/$rel")
                fi
            done < <(cd "$src" && find . -type f -print0)
        fi
    done
fi
if [ "${#conflicts[@]}" -gt 0 ]; then
    printf '[FAIL] 迁移冲突，未修改任何文件:\n' >&2
    printf '  - %s\n' "${conflicts[@]}" >&2
    exit 1
fi

if [ "$current" != "$target" ] && [ -d "$source_root" ] && [ "$yes" -ne 1 ]; then
    echo "[FAIL] OP 根迁移 $current → $target 需要确认；重跑时传 --yes" >&2
    exit 1
fi

journal="$(mktemp -d "$root/.op-configure.XXXXXX")"
declare -a journal_paths=()
declare -a journal_exists=()
rollback_active=1

snapshot() {
    local path="$1"
    local index="${#journal_paths[@]}"
    journal_paths+=("$path")
    if [ -e "$path" ] || [ -L "$path" ]; then
        journal_exists+=(1)
        cp -a "$path" "$journal/$index"
    else
        journal_exists+=(0)
    fi
}

rollback() {
    local rc="${1:-$?}"
    trap - ERR INT TERM
    if [ "$rollback_active" -eq 1 ]; then
        local index path
        for ((index=${#journal_paths[@]}-1; index>=0; index--)); do
            path="${journal_paths[$index]}"
            rm -rf "$path"
            if [ "${journal_exists[$index]}" -eq 1 ]; then
                mkdir -p "$(dirname "$path")"
                cp -a "$journal/$index" "$path"
            fi
        done
        echo "[FAIL] 配置失败，已回滚" >&2
    fi
    rm -rf "$journal"
    exit "$rc"
}
trap 'rollback $?' ERR
trap 'rollback 130' INT
trap 'rollback 143' TERM

for item in "${owned[@]}" "${shared[@]}"; do
    snapshot "$source_root/$item"
    [ "$source_root/$item" = "$target_root/$item" ] || snapshot "$target_root/$item"
done
for legacy in README.md index.md; do
    snapshot "$source_root/$legacy"
    snapshot "$target_root/$legacy"
done
snapshot "$settings"

_nav_upgrade() {
    # 将旧 README.md/index.md 迁入新 op_readme.md/op_index.md
    local _src_root="$1" _tgt_root="$2" _src_is_docs="$3" _tgt_is_docs="$4" _nav="$5"
    local _old_name _new_name _label _candidate _tgt_file _content
    if [ "$_nav" = "readme" ]; then
        _old_name="README.md" _new_name="op_readme.md" _label="README.md"
    else
        _old_name="index.md" _new_name="op_index.md" _label="index.md"
    fi
    _tgt_file="$_tgt_root/$_new_name"

    _content=""
    if [ "$_src_is_docs" = "yes" ]; then
        _content="$(managed_extract "$_src_root/$_old_name" "$_label")"
    elif [ -f "$_src_root/$_old_name" ]; then
        _content="$(cat "$_src_root/$_old_name")"
    fi
    [ -n "$_content" ] || return 0

    if [ -f "$_tgt_file" ]; then
        if [ "$(cat "$_tgt_file")" = "$_content" ]; then
            # 一致：只需清理旧源
            :
        else
            echo "[FAIL] 导航升级冲突: $_tgt_file 与 $_src_root/$_old_name 内容不同" >&2
            return 1
        fi
    else
        printf '%s\n' "$_content" > "$_tgt_file"
    fi

    if [ "$_src_is_docs" = "yes" ]; then
        managed_remove "$_src_root/$_old_name" "$_label"
    else
        rm -f "$_src_root/$_old_name"
    fi
}

_nav_maybe_upgrade() {
    local _src_root="$1" _src_is_docs="$2"
    _nav_upgrade "$_src_root" "$target_root" "$_src_is_docs" "$([ "$target" = "docs" ] && echo yes || echo no)" readme
    _nav_upgrade "$_src_root" "$target_root" "$_src_is_docs" "$([ "$target" = "docs" ] && echo yes || echo no)" index
}

if [ "$current" != "$target" ] && [ -d "$source_root" ]; then
    op_reject_symlink_path "$root" "$current"
    op_reject_symlink_path "$root" "$target"
    op_reject_tree_symlinks "$source_root"
    op_reject_tree_symlinks "$target_root"
    echo "[INFO] 迁移 OP 根: $current → $target"
    mkdir -p "$target_root"
    for item in "${owned[@]}"; do
        src="$source_root/$item"
        dst="$target_root/$item"
        [ -e "$src" ] || continue
        if [ -d "$src" ]; then
            mkdir -p "$dst"
            cp -a "$src/." "$dst/"
            rm -rf "$src"
        elif [ -e "$dst" ]; then
            rm -f "$src"
        else
            mv "$src" "$dst"
        fi
    done
    [ "${OP_TEST_FAIL_AFTER_STAGE:-}" != owned ] || false
    _nav_maybe_upgrade "$source_root" "$([ "$current" = "docs" ] && echo yes || echo no)"
    [ "${OP_TEST_FAIL_AFTER_STAGE:-}" != nav ] || false
    for item in "${shared[@]}"; do
        label="$item"
        [ "$item" != ".gitignore" ] || label="gitignore"
        shared_tmp="$(mktemp "$journal/shared.XXXXXX")"
        if [ "$current" = "docs" ]; then
            managed_extract "$source_root/$item" "$label" > "$shared_tmp"
        elif [ -f "$source_root/$item" ]; then
            cat "$source_root/$item" > "$shared_tmp"
        fi

        if [ "$target" = "docs" ]; then
            managed_merge "$shared_tmp" "$target_root/$item" "$label"
        else
            write_exclusive_shared "$shared_tmp" "$target_root/$item"
        fi

        if [ "$current" = "docs" ]; then
            managed_remove "$source_root/$item" "$label"
        else
            rm -f "$source_root/$item"
        fi
    done
    rmdir "$source_root" 2>/dev/null || true
else
    mkdir -p "$target_root"
    _nav_maybe_upgrade "$source_root" "$([ "$current" = "docs" ] && echo yes || echo no)"
fi

managed_merge /dev/null "$target_root/.gitignore" gitignore
[ "${OP_TEST_FAIL_AFTER_STAGE:-}" != managed ] || false

mkdir -p "$root/.claude"
op_reject_symlink_path "$root" ".claude"
op_reject_symlink_path "$root" ".claude/settings.json"
if [ ! -f "$settings" ]; then
    printf '{}\n' > "$settings"
fi
settings_tmp="$(mktemp "$root/.claude/.settings.XXXXXX")"
jq --arg value "$target" '.env = (.env // {}) | .env.OP_DOCS_DIR = $value' "$settings" > "$settings_tmp"
mv "$settings_tmp" "$settings"

rollback_active=0
trap - ERR INT TERM
rm -rf "$journal"
echo "[OK] OP_DOCS_DIR=$target 写入 .claude/settings.json"
