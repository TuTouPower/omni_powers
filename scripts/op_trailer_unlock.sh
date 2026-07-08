#!/usr/bin/env bash
# op_trailer_unlock.sh: leader 生成 e2e 提交的解锁 trailer
#
# 用法（leader 提交 e2e 时）：
#   git add e2e/{TID}/...
#   trailer=$(bash "$OP_HOME/scripts/op_trailer_unlock.sh")   # 输出 trailer 行
#   git commit -m "固化 {TID} AC-N 基准" -m "$trailer"
#
# trailer = HMAC-SHA256(secret, 排序后的 staged e2e 文件清单)
# secret 首次自动生成到 ~/.claude/omni_powers/e2e_secret（mode 600，不进项目仓库）。
#
# 安全模型局限（design §2.5 已标）：
#   secret 存 ~/.claude/——agent 理论可 Bash 读。强隔离需 OS keyring（macOS Keychain /
#   Linux libsecret / Windows Credential Manager），P3 增强。当前靠 mode 600 + 纪律禁止
#   agent 读 ~/.claude/omni_powers/。

set -uo pipefail

secret_dir="$HOME/.claude/omni_powers"
secret_file="$secret_dir/e2e_secret"

mkdir -p "$secret_dir"
chmod 700 "$secret_dir" 2>/dev/null

if [ ! -f "$secret_file" ]; then
    # 首次生成（32 字节随机 hex = 256 bit）
    if command -v openssl >/dev/null 2>&1; then
        openssl rand -hex 32 > "$secret_file" || { echo "[op_trailer_unlock] FATAL: openssl rand 失败" >&2; exit 1; }
    else
        # fallback：/dev/urandom
        head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n' > "$secret_file" || { echo "[op_trailer_unlock] FATAL: /dev/urandom 读失败" >&2; exit 1; }
    fi
    chmod 600 "$secret_file"
    echo "[op_trailer_unlock] 首次生成 secret: $secret_file（mode 600，勿提交、勿进 agent 上下文）" >&2
fi

secret="$(cat "$secret_file")"

# staged e2e 文件清单（排序，与 commit-msg 校验一致）
against="$(git rev-parse --verify HEAD >/dev/null 2>&1 && echo HEAD || echo "$(git hash-object -t tree /dev/null)")"
e2e_paths="$(git diff-index --cached --name-only "$against" 2>/dev/null | grep '^e2e/' || true)"

if [ -z "$e2e_paths" ]; then
    echo "[op_trailer_unlock] FATAL: staged 无 e2e/** 文件，无需解锁。" >&2
    echo "  先 git add e2e/... 再跑本脚本。" >&2
    exit 1
fi

hmac_data="$(printf '%s' "$e2e_paths" | grep . | sort | tr '\n' ':')"

# 兼容 openssl 新旧语法
trailer="$(printf '%s' "$hmac_data" | openssl dgst -sha256 -hmac "$secret" 2>/dev/null | awk '{print $NF}')"
if [ -z "$trailer" ]; then
    trailer="$(printf '%s' "$hmac_data" | openssl mac -digest sha256 -macopt key:"$secret" HMAC 2>/dev/null)"
fi
if [ -z "$trailer" ]; then
    echo "[op_trailer_unlock] FATAL: openssl HMAC 计算失败。需 openssl 1.1+。" >&2
    exit 1
fi

echo "Op-E2e-Unlock: $trailer"
echo "[op_trailer_unlock] 把上面这行加到 commit message 末尾。trailer 绑本次 e2e 文件清单，staged 变了需重跑。" >&2
