#!/usr/bin/env bash
# opinit_skeleton：建 omni_powers 三区骨架（目录 + baselines_index 模板 + tasks_list + checkpoint + progress/decisions + .test_locks）
# 用法: 在使用方项目根跑 bash "$OP_HOME/skills/opinit/scripts/opinit_skeleton.sh"
# 重跑幂等：已存在的 tasks_list/checkpoint/progress/decisions/.test_locks/baselines_index 保留不覆盖（只补缺）
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT"

OP_HOME="${OP_HOME:?全局 settings.json 未设 OP_HOME（opinit 步骤五校验，此处假设已设）}"

die() { echo "[FAIL] $*" >&2; exit 1; }

# ── profile 互斥保护（lite_design §6 判定表）──
PROFILE_FILE="docs/omni_powers/profile"
if [ -f "$PROFILE_FILE" ]; then
    cur="$(head -1 "$PROFILE_FILE" | tr -d '[:space:]')"
    case "$cur" in
        heavy) echo "[INFO] profile=heavy 已存在，补缺模式" ;;
        lite) die "本项目 profile=lite，不可用 heavy 入口混跑。请用 /oplintake、/oplrun 或显式处理后重来" ;;
        *) die "profile 值异常: '$cur'（期望 heavy）" ;;
    esac
fi

# 三区目录
mkdir -p docs/omni_powers/op_blueprint/{specs,baselines}
mkdir -p docs/omni_powers/op_execution/{specs,tasks,issues,acceptance}
mkdir -p docs/omni_powers/op_record/{specs,tasks,acceptance}
mkdir -p docs/archive

# e2e 目录（heavy 默认 tests/e2e/；已存在则探测提示）
if [ -d tests/e2e ]; then
    echo "[WARN] tests/e2e/ 已存在——将纳入 omni_powers E2E 保护语义（merge gate 拦 task 分支 e2e 变更）" >&2
elif [ -d e2e ]; then
    echo "[WARN] 顶层 e2e/ 已存在，将使用 tests/e2e/ 作为 E2E 落点（已有 e2e/ 不会被纳入保护语义）" >&2
    mkdir -p tests/e2e
else
    mkdir -p tests/e2e
fi

# ── profile（无则写 heavy）──
[ -f "$PROFILE_FILE" ] || echo "heavy" > "$PROFILE_FILE"

# baselines 索引骨架（首次空，验收后填——blueprint-generator 不生成此文件，首次无基准数据）
if [ ! -f docs/omni_powers/op_blueprint/baselines/baselines_index.md ]; then
  cp "$OP_HOME/docs_template/omni_powers/op_blueprint/baselines/baselines_index.md" \
     docs/omni_powers/op_blueprint/baselines/baselines_index.md 2>/dev/null \
    || echo "# baselines 索引（首次空，验收后填）" > docs/omni_powers/op_blueprint/baselines/baselines_index.md
fi

# progress + decisions（首次复制模板；重跑不覆盖已有内容）
if [ ! -f docs/omni_powers/op_record/progress.md ]; then
  cp "$OP_HOME/docs_template/omni_powers/op_record/progress.md" \
     docs/omni_powers/op_record/progress.md 2>/dev/null \
    || touch docs/omni_powers/op_record/progress.md
fi
if [ ! -f docs/omni_powers/op_record/decisions.md ]; then
  cp "$OP_HOME/docs_template/omni_powers/op_record/decisions.md" \
     docs/omni_powers/op_record/decisions.md 2>/dev/null \
    || touch docs/omni_powers/op_record/decisions.md
fi

# tasks_list.json（重跑不覆盖——保留已有 task）
[ -f docs/omni_powers/op_execution/tasks_list.json ] \
  || echo '{"tasks":[]}' > docs/omni_powers/op_execution/tasks_list.json

# leader_checkpoint.md（重跑不覆盖）
if [ ! -f docs/omni_powers/op_execution/leader_checkpoint.md ]; then
  cat > docs/omni_powers/op_execution/leader_checkpoint.md << 'EOF'
# Leader Checkpoint

current_task:
last_completed:
next_step:
关键上下文:

## 已完成 task
<!-- AUTO：op_checkpoint.sh 追加 "- {TID} "{title}" ✅ {hash}" -->

## tasks_list 状态
<!-- AUTO：op_checkpoint.sh 更新（完成/待开始/待规划/阻塞/废弃/挂起，ASCII: done/ready/pending/blocked/obsolete/suspended）-->
EOF
fi

echo "[OK] 三区骨架已建（已存在文件保留不覆盖，只补缺）"
