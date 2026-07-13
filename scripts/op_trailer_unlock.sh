#!/usr/bin/env bash
# op_trailer_unlock.sh: leader 生成 E2E 提交解锁 trailer
# 用法：staged E2E 文件后执行本脚本，把输出 trailer 加到 commit message 末尾。

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/op_paths.sh"
repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
op_load_paths "" "$repo_root" || exit 1

secret_dir="$HOME/.claude/omni_powers"
secret_file="$secret_dir/e2e_secret"

mkdir -p "$secret_dir"
chmod 700 "$secret_dir" 2>/dev/null

if [ ! -f "$secret_file" ]; then
    if command -v openssl >/dev/null 2>&1; then
        openssl rand -hex 32 > "$secret_file" || { echo "[op_trailer_unlock] FATAL: openssl rand 失败" >&2; exit 1; }
    else
        head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n' > "$secret_file" || { echo "[op_trailer_unlock] FATAL: /dev/urandom 读失败" >&2; exit 1; }
    fi
    chmod 600 "$secret_file"
    echo "[op_trailer_unlock] 首次生成 secret: $secret_file（mode 600，勿提交、勿进 agent 上下文）" >&2
fi

secret="$(cat "$secret_file")"
against="$(git rev-parse --verify HEAD >/dev/null 2>&1 && echo HEAD || echo "$(git hash-object -t tree /dev/null)")"
hmac_data="$(op_staged_e2e_fingerprint "$against")"

if [ -z "$hmac_data" ]; then
    echo "[op_trailer_unlock] FATAL: staged 无 e2e/E2E 文件，无需解锁。" >&2
    echo "  先 git add E2E 文件再跑本脚本。" >&2
    exit 1
fi

trailer="$(printf '%s' "$hmac_data" | openssl dgst -sha256 -hmac "$secret" 2>/dev/null | awk '{print $NF}')"
if [ -z "$trailer" ]; then
    trailer="$(printf '%s' "$hmac_data" | openssl mac -digest sha256 -macopt key:"$secret" HMAC 2>/dev/null)"
fi
if [ -z "$trailer" ]; then
    echo "[op_trailer_unlock] FATAL: openssl HMAC 计算失败。需 openssl 1.1+。" >&2
    exit 1
fi

echo "Op-E2e-Unlock: $trailer"
echo "[op_trailer_unlock] 把上面这行加到 commit message 末尾。trailer 绑本次 E2E 文件清单，staged 变了需重跑。" >&2
