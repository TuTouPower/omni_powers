#!/usr/bin/env bash
# 共享路径真相源。调用方 source 后执行 op_load_paths [显式根] [项目根]。

OP_DOCS_DIR_DEFAULT="docs/omni_powers"

op_paths_die() {
    echo "[FAIL] $*" >&2
    return 1
}

op_clear_paths() {
    unset OP_PROJECT_ROOT OP_DOCS_DIR OP_DOCS_DIR_SOURCE OP_DOCS_ROOT
    unset OP_BLUEPRINT_DIR_REL OP_EXECUTION_DIR_REL OP_RECORD_DIR_REL
    unset OP_PROFILE_FILE_REL OP_README_FILE_REL OP_INDEX_FILE_REL OP_GITIGNORE_FILE_REL OP_LITE_E2E_DIR_REL
    unset OP_BLUEPRINT_DIR OP_EXECUTION_DIR OP_RECORD_DIR OP_PROFILE_FILE
    unset OP_README_FILE OP_INDEX_FILE OP_GITIGNORE_FILE OP_LITE_E2E_DIR
}

op_has_control_char() {
    local value="$1"
    [[ "$value" == *$'\n'* || "$value" == *$'\r'* || "$value" == *$'\t'* ]] && return 0
    LC_ALL=C printf '%s' "$value" | grep -q '[[:cntrl:]]'
}

op_normalize_docs_dir() {
    local value="${1:-}"

    while [[ "$value" == ./* ]]; do value="${value#./}"; done
    while [[ "$value" == */ ]]; do value="${value%/}"; done
    while [[ "$value" == *//* ]]; do value="${value//\/\//\/}"; done

    [ -n "$value" ] || { op_paths_die "OP_DOCS_DIR 不能为空"; return 1; }
    [ "$value" != "." ] || { op_paths_die "OP_DOCS_DIR 不可为项目根"; return 1; }
    [[ "$value" != /* ]] || { op_paths_die "OP_DOCS_DIR 必须是项目相对路径"; return 1; }
    [[ "$value" != *' '* ]] || { op_paths_die "OP_DOCS_DIR 不允许空格"; return 1; }
    ! op_has_control_char "$value" || { op_paths_die "OP_DOCS_DIR 不允许控制字符"; return 1; }
    [[ "$value" != *\\* && "$value" != *:* ]] || { op_paths_die "OP_DOCS_DIR 不允许反斜杠或冒号"; return 1; }
    case "$value" in
        *\**|*\?*|*\[*|*\]*) op_paths_die "OP_DOCS_DIR 不允许 glob 字符"; return 1 ;;
    esac

    local segment remaining="$value"
    while [ -n "$remaining" ]; do
        segment="${remaining%%/*}"
        if [ "$remaining" = "$segment" ]; then
            remaining=""
        else
            remaining="${remaining#*/}"
        fi
        case "$segment" in
            ""|.|..) op_paths_die "OP_DOCS_DIR 含非法路径段: $segment"; return 1 ;;
        esac
    done
    case "/$value/" in
        */.git/*|*/.claude/*) op_paths_die "OP_DOCS_DIR 不可位于 .git 或 .claude"; return 1 ;;
    esac

    printf '%s\n' "$value"
}

op_reject_symlink_path() {
    local root="$1"
    local rel="$2"
    local current="$root"
    local segment remaining="$rel"

    while [ -n "$remaining" ]; do
        segment="${remaining%%/*}"
        if [ "$remaining" = "$segment" ]; then
            remaining=""
        else
            remaining="${remaining#*/}"
        fi
        current="$current/$segment"
        [ ! -L "$current" ] || { op_paths_die "路径含符号链接，拒绝操作: $current"; return 1; }
    done
}

op_reject_tree_symlinks() {
    local path="$1"
    local found=""
    [ -e "$path" ] || return 0
    found="$(find "$path" -type l -print -quit 2>/dev/null)"
    [ -z "$found" ] || { op_paths_die "目录树含符号链接，拒绝操作: $found"; return 1; }
}

op_project_setting_docs_dir() {
    local root="$1"
    local settings="$1/.claude/settings.json"
    op_reject_symlink_path "$root" ".claude" || return 2
    op_reject_symlink_path "$root" ".claude/settings.json" || return 2
    [ -f "$settings" ] || return 1

    if ! jq -e '
        type == "object" and
        ((.env? // {}) | type == "object") and
        (((.env? // {}) | has("OP_DOCS_DIR") | not) or
         (((.env.OP_DOCS_DIR | type) == "string") and ((.env.OP_DOCS_DIR | length) > 0)))
    ' "$settings" >/dev/null 2>&1; then
        op_paths_die "$settings 中 env 或 env.OP_DOCS_DIR 类型/值非法"
        return 2
    fi

    local value
    value="$(jq -r '(.env? // {}).OP_DOCS_DIR // empty' "$settings")" || return 2
    [ -n "$value" ] || return 1
    printf '%s\n' "$value"
}

op_load_paths() {
    local explicit="${1:-}"
    local root="${2:-}"
    local inherited_docs_dir="${OP_DOCS_DIR:-}"
    local selected source setting rc

    op_clear_paths

    if [ -z "$root" ]; then
        root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
    fi
    root="$(cd "$root" 2>/dev/null && pwd)" || {
        op_paths_die "项目根不存在: $root"
        return 1
    }

    if [ -n "$explicit" ]; then
        selected="$explicit"
        source="explicit"
    elif setting="$(op_project_setting_docs_dir "$root")"; then
        selected="$setting"
        source="project_settings"
    else
        rc=$?
        if [ "$rc" -eq 2 ]; then
            return 1
        elif [ -n "$inherited_docs_dir" ]; then
            selected="$inherited_docs_dir"
            source="environment"
        else
            selected="$OP_DOCS_DIR_DEFAULT"
            source="default"
        fi
    fi

    selected="$(op_normalize_docs_dir "$selected")" || return 1
    op_reject_symlink_path "$root" "$selected" || return 1
    local op_asset
    for op_asset in op_blueprint op_execution op_record e2e profile README.md index.md .gitignore; do
        op_reject_symlink_path "$root" "$selected/$op_asset" || return 1
    done

    OP_PROJECT_ROOT="$root"
    OP_DOCS_DIR="$selected"
    OP_DOCS_DIR_SOURCE="$source"
    OP_DOCS_ROOT="$root/$selected"

    OP_BLUEPRINT_DIR_REL="$selected/op_blueprint"
    OP_EXECUTION_DIR_REL="$selected/op_execution"
    OP_RECORD_DIR_REL="$selected/op_record"
    OP_PROFILE_FILE_REL="$selected/profile"
    OP_README_FILE_REL="$selected/README.md"
    OP_INDEX_FILE_REL="$selected/index.md"
    OP_GITIGNORE_FILE_REL="$selected/.gitignore"
    OP_LITE_E2E_DIR_REL="$selected/e2e"

    OP_BLUEPRINT_DIR="$root/$OP_BLUEPRINT_DIR_REL"
    OP_EXECUTION_DIR="$root/$OP_EXECUTION_DIR_REL"
    OP_RECORD_DIR="$root/$OP_RECORD_DIR_REL"
    OP_PROFILE_FILE="$root/$OP_PROFILE_FILE_REL"
    OP_README_FILE="$root/$OP_README_FILE_REL"
    OP_INDEX_FILE="$root/$OP_INDEX_FILE_REL"
    OP_GITIGNORE_FILE="$root/$OP_GITIGNORE_FILE_REL"
    OP_LITE_E2E_DIR="$root/$OP_LITE_E2E_DIR_REL"

    export OP_PROJECT_ROOT OP_DOCS_DIR OP_DOCS_DIR_SOURCE OP_DOCS_ROOT
    export OP_BLUEPRINT_DIR_REL OP_EXECUTION_DIR_REL OP_RECORD_DIR_REL
    export OP_PROFILE_FILE_REL OP_README_FILE_REL OP_INDEX_FILE_REL OP_GITIGNORE_FILE_REL OP_LITE_E2E_DIR_REL
    export OP_BLUEPRINT_DIR OP_EXECUTION_DIR OP_RECORD_DIR OP_PROFILE_FILE
    export OP_README_FILE OP_INDEX_FILE OP_GITIGNORE_FILE OP_LITE_E2E_DIR
}

op_path_is_within() {
    local path="${1#./}"
    local root="${2#./}"
    root="${root%/}"
    [ -n "$root" ] || return 1
    [ "$path" = "$root" ] || [[ "$path" == "$root/"* ]]
}

op_git_literal_pathspec() {
    local path="${1#./}"
    [ -n "$path" ] || { op_paths_die "literal pathspec 不能为空"; return 1; }
    [[ "$path" != /* ]] || { op_paths_die "literal pathspec 必须是项目相对路径"; return 1; }
    ! op_has_control_char "$path" || { op_paths_die "literal pathspec 不允许控制字符"; return 1; }
    case "/$path/" in
        */../*|*/./*) op_paths_die "literal pathspec 含非法路径段"; return 1 ;;
    esac
    printf ':(literal)%s\n' "$path"
}

op_path_hex() {
    LC_ALL=C printf '%s' "$1" | od -An -tx1 | tr -d ' \n'
}

op_staged_e2e_fingerprint() {
    local against="$1"
    local path has_e2e=0

    while IFS= read -r -d '' path; do
        if op_is_e2e_path "$path"; then
            has_e2e=1
            break
        fi
    done < <(git diff-index --cached -z --name-only "$against" 2>/dev/null)
    [ "$has_e2e" -eq 1 ] || return 0

    git diff-index --cached --raw -z "$against" 2>/dev/null | od -An -tx1 | tr -d ' \n'
    printf '\n'
}

op_is_e2e_path() {
    local path="${1#./}"
    case "$path" in
        e2e/*|tests/e2e/*|tests/*/e2e/*) return 0 ;;
    esac
    [ -n "${OP_LITE_E2E_DIR_REL:-}" ] && op_path_is_within "$path" "$OP_LITE_E2E_DIR_REL"
}

op_is_protected_path() {
    local path="${1#./}"
    local tid="${2:-}"
    op_path_is_within "$path" "$OP_BLUEPRINT_DIR_REL" && return 0
    op_path_is_within "$path" "$OP_RECORD_DIR_REL" && return 0
    op_path_is_within "$path" "$OP_EXECUTION_DIR_REL/specs" && return 0
    op_path_is_within "$path" "$OP_EXECUTION_DIR_REL/issues" && return 0
    [ "$path" = "$OP_EXECUTION_DIR_REL/tasks_list.json" ] && return 0
    [ "$path" = "$OP_EXECUTION_DIR_REL/leader_checkpoint.md" ] && return 0
    [ -n "$tid" ] && [ "$path" = "$OP_EXECUTION_DIR_REL/tasks/$tid/review.md" ] && return 0
    op_is_e2e_path "$path"
}
