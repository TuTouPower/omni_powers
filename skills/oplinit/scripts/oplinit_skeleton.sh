#!/usr/bin/env bash
# oplinit_skeleton（lite）：建 omni_powers 三区骨架 + 写 profile=lite。
# 用法: 在使用方项目根跑 bash <skill>/scripts/oplinit_skeleton.sh
# 零侵入：只建 docs/omni_powers/ 自己的子目录（含 e2e/），不碰宿主已有文件。
# 重跑幂等：已存在文件保留不覆盖，只补缺。
# 自包含：模板内联生成，不依赖 OP_HOME / docs_template。
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT"

PROFILE_FILE="docs/omni_powers/profile"

die() { echo "[FAIL] $*" >&2; exit 1; }

# ── profile 互斥保护（§6 判定表 + #12 edge case）──
if [ -f "$PROFILE_FILE" ]; then
    cur="$(head -1 "$PROFILE_FILE" | tr -d '[:space:]')"
    case "$cur" in
        lite) echo "[INFO] profile=lite 已存在，补缺模式" ;;
        heavy) die "本项目 profile=heavy，不可用 lite 入口混跑。请用 /oprun 或显式处理后重来" ;;
        *) die "profile 值异常: '$cur'（期望 lite）" ;;
    esac
elif [ -d docs/omni_powers/op_execution ] && [ -f docs/omni_powers/op_execution/tasks_list.json ]; then
    # 有三区但无 profile：疑似 heavy 残留（#12）
    die "检测到 docs/omni_powers/ 已存在但无 profile 文件——疑似 heavy 项目残留。请确认后手动写 docs/omni_powers/profile"
fi

# ── 三区目录 + lite 验收 E2E（docs/omni_powers/e2e/，零侵入，design §5.3）──
mkdir -p docs/omni_powers/op_blueprint/{specs,baselines}
mkdir -p docs/omni_powers/op_execution/{specs,tasks,issues,acceptance}
mkdir -p docs/omni_powers/op_record/{specs,tasks,acceptance}
mkdir -p docs/omni_powers/e2e   # lite 验收 E2E 默认落点（不进用户测试 runner 自动发现；用户显式同意才改用顶层 e2e/）

# ── profile ──
[ -f "$PROFILE_FILE" ] || echo "lite" > "$PROFILE_FILE"

# ── .gitignore（忽略 flock 锁残留；只写自己子目录，不碰用户根 .gitignore）──
GI="docs/omni_powers/.gitignore"
[ -f "$GI" ] || printf '*.lock\n' > "$GI"

# ── op_blueprint 占位说明（lite 空壳，明令不当契约源）──
BP_README="docs/omni_powers/op_blueprint/README.md"
[ -f "$BP_README" ] || cat > "$BP_README" << 'EOF'
# op_blueprint（lite 占位）

lite 模式下本目录为**空壳，仅路径兼容占位**。
implementer / reviewer / evaluator **一律不读此目录当契约源**。
生效规格在 `op_execution/specs/`，判定依据内联进 agent prompt。
EOF

# ── tasks_list.json（不覆盖）──
[ -f docs/omni_powers/op_execution/tasks_list.json ] \
    || echo '{"tasks":[]}' > docs/omni_powers/op_execution/tasks_list.json

# ── leader_checkpoint.md（不覆盖）──
if [ ! -f docs/omni_powers/op_execution/leader_checkpoint.md ]; then
    cat > docs/omni_powers/op_execution/leader_checkpoint.md << 'EOF'
# Leader Checkpoint (lite)

current_task:
last_completed:
next_step:

## 已完成 task

<!-- leader 每 task 收口后追加: "- {TID} {title} ✅ {hash}" -->

## 关键上下文（leader 手动填）

- 当前目标：...
- 下一步：...
- 卡点 / 待决策：...
EOF
fi

# ── progress.md（不覆盖）──
if [ ! -f docs/omni_powers/op_record/progress.md ]; then
    cat > docs/omni_powers/op_record/progress.md << 'EOF'
# 进度日志

> 每 task 闭环后机械追加一行（op_close_post.sh 写）。不删不改历史。
> 格式：`- {TID} | {feature} | {date} | 完成`
EOF
fi

# ── decisions.md（不覆盖）──
if [ ! -f docs/omni_powers/op_record/decisions.md ]; then
    cat > docs/omni_powers/op_record/decisions.md << 'EOF'
# 历史决策

> 有架构决策才追加。记"为什么这样选"。带来源标记（lite 收口用 leader-close）。

EOF
fi

echo "[OK] lite 三区骨架已建（profile=lite；已存在文件保留不覆盖）"
