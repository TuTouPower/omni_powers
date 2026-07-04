---
name: opinit
description: >
  一次性安装：生成 omni_powers 三区骨架 + hooks 注册。在一个已有项目中初始化工作流目录与规范文档。
  触发：/opinit。
---

# Op Init Skill

`/opinit` 在已有项目中初始化 omni_powers 工作流骨架，归档旧文档，注册 hooks。一次性。

## 步骤一：创建标准目录结构

```bash
mkdir -p docs/omni_powers/op_blueprint/specs
mkdir -p docs/omni_powers/op_execution/{specs,tasks,issues}
mkdir -p docs/omni_powers/op_record/{specs,tasks}
mkdir -p docs/archive e2e

touch docs/omni_powers/op_record/progress.md
touch docs/omni_powers/op_record/decisions.md
echo '{"tasks":[]}' > docs/omni_powers/op_execution/tasks_list.json
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
cat > docs/omni_powers/op_execution/.test_locks << 'EOF'
# 锁定的行为层测试文件路径（每行一个），归 op-evaluator 所有
EOF
```

技术债登记为 issue 加 `tech-debt` 标签，不单独建文件。依赖走 `depends_on` + jq，不单独建图文件。

## 步骤二：识别并归档旧文档

将非结构化 md 移入 `docs/archive`。排除 `README.md`、`CLAUDE.md`、`RULES.md`。**P1-8：先列清单，AskUserQuestion 逐文件确认，再移**——项目已有的设计文档/规格不要误移，不确定就保留原位。

```bash
# 列候选清单（不直接移）
echo "=== 归档候选（排除 README/CLAUDE/RULES）==="
find . -maxdepth 1 -name "*.md" -not -name "README.md" -not -name "CLAUDE.md" -not -name "RULES.md" -print
find docs -maxdepth 1 -name "*.md" -print 2>/dev/null
```

用 AskUserQuestion 让用户确认每个文件是否归档。用户确认后逐个 `mv {file} docs/archive/`，不确认的保留原位。

## 步骤三：生成 Blueprint

派发 Agent 读取归档区，提炼当前事实：

```js
Agent({
  name: "blueprint-generator", model: "sonnet",
  prompt: "读取 docs/archive/ 中的文档。根据现有业务和架构，生成符合 omni_powers 规范的文档到 docs/omni_powers/op_blueprint/（prd.md、architecture.md、domain.md、conventions.md、test.md）。只描述'现在是什么'，丢弃过时内容。" })
```

## 步骤四：重写导航 (index.md)

```js
Agent({
  name: "index-generator", model: "haiku",
  prompt: "读取 docs/omni_powers/op_blueprint/ 下文档列表，在 docs/omni_powers/index.md 生成全局文档导航图（索引）。" })
```

## 步骤五：注册 hooks

先引导用户确认 `$OP_HOME`（插件安装目录 = 本仓库 git clone 位置）并写入使用方 `.claude/settings.json` 的 `env` 段；再合并 hooks 配置：

```bash
# 1. 引导设 $OP_HOME（opinit 在 $OP_HOME/skills/opinit/，上两级即插件根）
OP_HOME_SUGGESTED="$(cd "$(dirname "$0")/../.." && pwd)"
echo "检测到插件目录: $OP_HOME_SUGGESTED（确认或让用户修正）"
mkdir -p .claude
if [ -f .claude/settings.json ]; then
  jq --arg p "$OP_HOME_SUGGESTED" '.env.OP_HOME = $p' .claude/settings.json > .claude/settings.json.tmp \
    && mv .claude/settings.json.tmp .claude/settings.json
else
  printf '{"env":{"OP_HOME":"%s"}}' "$OP_HOME_SUGGESTED" | jq . > .claude/settings.json
fi

# 2. 合并 hooks 配置（P1-1：按事件 concat 数组，不覆盖用户已有 hooks）
# settings.template.json 的 hook 命令用 $OP_HOME/hooks/*.sh
if [ -f .claude/settings.json ]; then
  cp .claude/settings.json ".claude/settings.json.bak.$(date +%s)"
  jq -s '
    .[0] as $u | .[1] as $t
    | $u
    | .hooks = (reduce ($t.hooks // {} | to_entries[]) as $e ($u.hooks // {});
        .[$e.key] = ((.[$e.key] // []) + $e.value)
      ))
    | .env = (($u.env // {}) + ($t.env // {}))
  ' .claude/settings.json hooks/settings.template.json > .claude/settings.json.tmp
  mv .claude/settings.json.tmp .claude/settings.json
else
  cp hooks/settings.template.json .claude/settings.json
fi
chmod +x "$OP_HOME/hooks/"*.sh
echo "[OK] $OP_HOME 写入 env，hooks 已注册"
```

> hook 与脚本统一通过 `$OP_HOME`（插件安装目录）引用：`$OP_HOME/hooks/*.sh`、`$OP_HOME/scripts/*.sh`。使用方项目数据走 `$CLAUDE_PROJECT_DIR`（Claude 内置）。废弃 `$CLAUDE_PLUGIN_ROOT` / plugin 机制（op_install.md 描述的 plugin 模式待 P1 重写为 skill+$OP_HOME）。

## 步骤六：提取未执行计划

```bash
ls docs/archive/ | grep -iE 'task|plan|todo' || echo "无未执行计划文件"
```

发现疑似未执行计划文件 → **停下来问用户**：是否提取【还没做】的 task 加入 tasks_list.json？用户选 `y` 则派 Agent 提取（严格过滤已完成的），每项调 `bash "$OP_HOME/scripts/op_new_task.sh "标题" "详情"`。

## 步骤七：完成报告

输出：
1. 归档了哪些文件
2. 生成了哪些 blueprint
3. hooks 注册位置
4. 提取了多少未执行 task

提示用户：`/opintake "<需求>"` 开始新需求，或 `/oprun` 续跑已有 task，`/opstatus` 看状态。
