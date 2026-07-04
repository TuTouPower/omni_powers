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

## 步骤三：生成 Blueprint（按职责矩阵分工 + specs 不空）

派发 Agent 读归档区 + git log + 现有代码，提炼"现在是什么"，按 `$OP_HOME/docs/omni_powers_design.md §3.3` 文档职责矩阵生成（各文档单一职责，重复内容独占一份，其他"详见 X.md"）：

```js
Agent({
  name: "blueprint-generator", model: "sonnet",
  prompt: "读 docs/archive/ + 近期 git log（git log --oneline -50）+ 现有代码（src/ 结构 + 关键模块），提炼项目'现在是什么'，按 design §3.3 职责矩阵生成 docs/omni_powers/op_blueprint/ 文档（避免重复）：\n- prd.md：产品需求（定位/用户/功能/成功标准/不做）\n- architecture.md：技术栈 + 目录结构 + 模块 + 数据流（唯一目录/技术栈真相）\n- domain.md：术语表 + 跨功能业务不变量\n- conventions.md：命名/风格/文件组织/浏览器 API/日志/适配器步骤（编码独占，技术栈不在此）\n- test.md：测试分层/覆盖/Mock/调试入口\n- spec_index.md：纯 specs/ 索引（功能清单 + 文件指引，不塞技术栈/架构/安全）\n- specs/{feature}.md：从 archive + 代码 + commit 提炼**已实现功能**，每功能一份（接口/数据模型/行为——'现在是什么'）。已实现功能逐个生成，不遗留空；新增功能（未实现）不生成，留 /opintake 拆分时补。\n丢弃过期内容。重复内容只留独占者，其他文档'详见 X.md'。" })
```

完成后**提示用户瘦身心 CLAUDE.md**：CLAUDE.md 是"门牌"，只留项目一句话定位 + dev/build/test 命令 + 指向 `docs/omni_powers/op_blueprint/` 各文档；与 blueprint 重复的段（技术栈/目录树/架构约束/命名/日志）删，改为"详见 architecture.md / conventions.md / ..."。

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
