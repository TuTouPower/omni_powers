#!/usr/bin/env bash
# opinit_skeleton：建 omni_powers 三区骨架（目录 + baselines_index 模板 + tasks_list + checkpoint + .test_locks）
# 用法: 在使用方项目根跑 bash "$OP_HOME/scripts/opinit_skeleton.sh"
# 重跑幂等：已存在的 tasks_list/checkpoint/.test_locks/baselines_index 保留不覆盖（只补缺）
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT"

OP_HOME="${OP_HOME:?全局 settings.json 未设 OP_HOME（opinit 步骤五校验，此处假设已设）}"

# 三区目录
mkdir -p docs/omni_powers/op_blueprint/{specs,baselines}
mkdir -p docs/omni_powers/op_execution/{specs,tasks,issues,acceptance}
mkdir -p docs/omni_powers/op_record/{specs,tasks,acceptance}
mkdir -p docs/archive e2e

# baselines 索引骨架（首次空，验收后填——blueprint-generator 不生成此文件，首次无基准数据）
if [ ! -f docs/omni_powers/op_blueprint/baselines/baselines_index.md ]; then
  cp "$OP_HOME/docs_template/omni_powers/op_blueprint/baselines/baselines_index.md" \
     docs/omni_powers/op_blueprint/baselines/baselines_index.md 2>/dev/null \
    || echo "# baselines 索引（首次空，验收后填）" > docs/omni_powers/op_blueprint/baselines/baselines_index.md
fi

# progress + decisions（append-only，touch 不破坏已有内容）
touch docs/omni_powers/op_record/progress.md
touch docs/omni_powers/op_record/decisions.md

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
<!-- AUTO：op-checkpoint.sh 追加 "- {TID} "{title}" ✅ {hash}" -->

## tasks_list 状态
<!-- AUTO：op-checkpoint.sh 更新（完成/待开始/待规划/阻塞/跳过/挂起）-->
EOF
fi

# .test_locks（重跑不覆盖）
[ -f docs/omni_powers/op_execution/.test_locks ] \
  || cat > docs/omni_powers/op_execution/.test_locks << 'EOF'
# 锁定的行为层测试文件路径（每行一个），归 op-evaluator 所有
EOF

echo "[OK] 三区骨架已建（已存在文件保留不覆盖，只补缺）"
