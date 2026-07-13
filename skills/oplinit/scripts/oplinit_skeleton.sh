#!/usr/bin/env bash
# oplinit_skeleton（lite）：建 omni_powers 三区骨架 + 写 profile=lite。
# 用法: 在使用方项目根跑 bash <skill>/scripts/oplinit_skeleton.sh
# 低侵入：只建 $OP_DOCS_DIR OP 资产（含 lite e2e/）并依赖项目 env.OP_DOCS_DIR，不碰宿主已有内容。
# 重跑幂等：已存在文件保留不覆盖，只补缺。
# 模板内联生成；路径解析依赖安装后的 OP_HOME/scripts/op_paths.sh。
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT"

OP_HOME="${OP_HOME:?OP_HOME 未设，先运行 install.sh --set-ophome}"
source "$OP_HOME/scripts/op_paths.sh"
op_load_paths "" "$ROOT"
OP_ROOT="$OP_DOCS_ROOT"
BLUEPRINT="$OP_BLUEPRINT_DIR"
EXECUTION="$OP_EXECUTION_DIR"
RECORD="$OP_RECORD_DIR"
PROFILE_FILE="$OP_PROFILE_FILE"

die() { echo "[FAIL] $*" >&2; exit 1; }

# ── profile 互斥保护（§6 判定表 + #12 edge case）──
if [ -f "$PROFILE_FILE" ]; then
    cur="$(head -1 "$PROFILE_FILE" | tr -d '[:space:]')"
    case "$cur" in
        lite) echo "[INFO] profile=lite 已存在，补缺模式" ;;
        heavy) die "本项目 profile=heavy，不可用 lite 入口混跑。请用 /oprun 或显式处理后重来" ;;
        *) die "profile 值异常: '$cur'（期望 lite）" ;;
    esac
elif [ -d "$EXECUTION" ] && [ -f "$EXECUTION"/tasks_list.json ]; then
    # 有三区但无 profile：疑似 heavy 残留（#12）
    die "检测到 $OP_DOCS_DIR/ 已存在但无 profile 文件——疑似 heavy 项目残留。请确认后手动写 $OP_DOCS_DIR/profile"
fi

# ── 三区目录 + lite 验收 E2E（"$OP_LITE_E2E_DIR"/，零侵入，design §5.3）──
mkdir -p "$BLUEPRINT"/{specs,baselines}
mkdir -p "$EXECUTION"/{specs,tasks,issues,acceptance}
mkdir -p "$RECORD"/{specs,tasks,acceptance}
mkdir -p "$OP_LITE_E2E_DIR"   # lite 验收 E2E 默认落点（不进用户测试 runner 自动发现；用户显式同意才改用顶层 e2e/）

# ── profile ──
[ -f "$PROFILE_FILE" ] || echo "lite" > "$PROFILE_FILE"

# ── .gitignore（忽略 flock 锁残留；只写自己子目录，不碰用户根 .gitignore）──
GI="$OP_GITIGNORE_FILE"
[ -f "$GI" ] || printf '*.lock\n' > "$GI"

# ── op_blueprint 占位说明（lite 空壳，明令不当契约源）──
BP_README=""$BLUEPRINT"/README.md"
[ -f "$BP_README" ] || cat > "$BP_README" << 'EOF'
# op_blueprint（lite 占位）

lite 模式下本目录为**空壳，仅路径兼容占位**。
implementer / reviewer / evaluator **一律不读此目录当契约源**。
生效规格在 `op_execution/specs/`，判定依据内联进 agent prompt。
EOF

# ── tasks_list.json（不覆盖）──
[ -f "$EXECUTION"/tasks_list.json ] \
    || echo '{"tasks":[]}' > "$EXECUTION"/tasks_list.json

# ── leader_checkpoint.md（不覆盖）──
if [ ! -f "$EXECUTION"/leader_checkpoint.md ]; then
    cat > "$EXECUTION"/leader_checkpoint.md << 'EOF'
# Leader Checkpoint (lite)

## 断点

### current_task

### last_completed

### next_step

## 关键上下文

- 当前目标：...
- 卡点 / 待决策：...
EOF
fi

# ── progress.md（不覆盖）──
if [ ! -f "$RECORD"/progress.md ]; then
    cat > "$RECORD"/progress.md << 'EOF'
# 进度日志

> 每 task 闭环后机械追加一行（op_close_post.sh 写）。不删不改历史。
> 格式：`- {TID} | {feature} | {date} | 完成`
EOF
fi

# ── decisions.md（不覆盖）──
if [ ! -f "$RECORD"/decisions.md ]; then
    cat > "$RECORD"/decisions.md << 'EOF'
# 历史决策

> 有架构决策才追加。记"为什么这样选"。带来源标记（lite 收口用 leader-close）。

EOF
fi

echo "[OK] lite 三区骨架已建（profile=lite；已存在文件保留不覆盖）"
