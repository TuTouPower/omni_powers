---
name: opinit
description: >
  一次性安装：生成 omni_powers 三区骨架 + hooks 注册。在一个已有项目中初始化工作流目录与规范文档。
  触发：/opinit。
---

# Op Init Skill

`/opinit` 在已有项目中初始化 omni_powers 工作流骨架，归档旧文档，注册 hooks。一次性。

> **问询原则**：步骤零先浏览所有文档 + 整理所有问题，AskUserQuestion **一次问完**。后续步骤（二/六等）按零答案执行，**不再问**——除非遇严重阻塞（OP_HOME 未设 / 插件资源缺失 / 关键文件读不到，直接 die 提示，不是问）。

## 步骤零：浏览 + 一次问

跑前全面浏览现状，整理所有需用户决策的点，**一次问完**（不要逐个问）。

```bash
echo "=== 现有文档 ==="; ls docs/ 2>/dev/null | head -30
echo "=== 已归档 ==="; ls docs/archive/ 2>/dev/null
echo "=== .claude 配置 ==="; ls .claude/ 2>/dev/null
echo "=== 近期 commit ==="; git log --oneline -20 2>/dev/null
echo "=== OP_HOME ==="; [ -n "${OP_HOME:-}" ] && echo "OP_HOME=$OP_HOME" || echo "未设（步骤五会 die 提示）"
echo "=== 代码结构 ==="; ls src/ 2>/dev/null | head
echo "=== 旧 md 候选 ==="; find . -maxdepth 1 -name '*.md' -not -name 'README.md' -not -name 'CLAUDE.md' -not -name 'RULES.md' 2>/dev/null; find docs -maxdepth 1 -name '*.md' 2>/dev/null
echo "=== 未执行计划候选 ==="; ls docs/archive/ 2>/dev/null | grep -iE 'task|plan|todo' || echo "无"
```

据浏览结果整理需问的点，用 **AskUserQuestion 一次问完**（合并多问题到一个 AskUserQuestion 调用）：

1. **旧文档归档**：列出候选（find 结果），问归档哪些（默认全归 docs/archive/，README/CLAUDE/RULES 保留原位）
2. **未执行计划提取**：docs/archive/ 有 task/plan/todo 文件？问是否提取为 tasks_list.json 的 task
3. **其他歧义**：多个冲突 SPEC / 现有三区已存在 / CLAUDE.md 重复范围等

记下答案，后续步骤按答案执行，**不再问**。

## 步骤一：创建标准目录结构

```bash
mkdir -p docs/omni_powers/op_blueprint/{specs,baselines}
mkdir -p docs/omni_powers/op_execution/{specs,tasks,issues,acceptance}
mkdir -p docs/omni_powers/op_record/{specs,tasks,acceptance}
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

## 步骤二：归档旧文档（按步骤零答案）

将步骤零确认归档的文件移入 `docs/archive/`（README/CLAUDE/RULES 保留原位）。**不再次问**——按步骤零答案执行。

```bash
# leader 据步骤零用户确认的清单展开文件列表，逐个移
# for f in <步骤零确认归档的文件>; do mv "$f" docs/archive/; done
```

## 步骤三：生成 Blueprint（按职责矩阵分工 + specs 不空）

派发 Agent 读归档区 + git log + 现有代码，提炼"现在是什么"，按 `$OP_HOME/docs/omni_powers_design.md §3.3` 文档职责矩阵生成（各文档单一职责，重复内容独占一份，其他"详见 X.md"）：

```js
Agent({
  name: "blueprint-generator", model: "sonnet",
  prompt: "读 docs/archive/ + 近期 git log（git log --oneline -50）+ 现有代码（src/ 结构 + 关键模块），提炼项目'现在是什么'，按 design §3.3 职责矩阵生成 docs/omni_powers/op_blueprint/ 文档（避免重复）：\n- prd.md：产品需求（定位/用户/功能/成功标准/不做）\n- architecture.md：技术栈 + 目录结构 + 模块 + 数据流（唯一目录/技术栈真相）\n- domain.md：术语表 + 跨功能业务不变量\n- conventions.md：命名/风格/文件组织/浏览器 API/日志/适配器步骤（编码独占，技术栈不在此）\n- test.md：测试分层/覆盖/Mock/调试入口\n- spec_index.md：纯 specs/ 索引（功能清单 + 文件指引，不塞技术栈/架构/安全）\n- specs/{feature}.md：从 archive + 代码 + commit 提炼**已实现功能**，每功能一份（接口/数据模型/行为——'现在是什么'）。已实现功能逐个生成，不遗留空；新增功能（未实现）不生成，留 /opintake 拆分时补。\n丢弃过期内容。重复内容只留独占者，其他文档'详见 X.md'。" })
```

完成后**提示用户瘦身心 CLAUDE.md**：CLAUDE.md 是"门牌"，只留项目一句话定位 + dev/build/test 命令 + 指向 `docs/omni_powers/op_blueprint/` 各文档；与 blueprint 重复的段（技术栈/目录树/架构约束/命名/日志）删，改为"详见 architecture.md / conventions.md / ..."。

## 步骤四：重写导航（index.md + README.md）

```js
Agent({
  name: "index-generator", model: "haiku",
  prompt: "读 docs/omni_powers/op_blueprint/ 文档列表，生成两个导航：\n(1) docs/omni_powers/index.md（给 agent）：三态模型 + 各文档定位，SessionStart 注入其摘要\n(2) docs/omni_powers/README.md（给人）：项目用 omni_powers 工作流 + 三区一句话说明 + 指向 index.md + 常用命令（/opintake '/需求/' /oprun /opstatus）" })
```

## 步骤五：注册 hooks（到使用方 .claude/settings.json）

> `$OP_HOME` 由用户**全局** settings.json 设（一次性，所有项目共享，subagent 继承）。**opinit 不写项目级 OP_HOME**——只校验全局已设 + 合并 hooks 到项目。

```bash
# 1. 校验全局 OP_HOME 已设 + 指向正确（不写项目级）
[ -n "${OP_HOME:-}" ] || { echo "[FAIL] 全局 settings.json 未设 OP_HOME。请在全局配置（如 ~/.claude/settings.json）env 段加 \"OP_HOME\": \"/path/to/omni_powers\"，重启 Claude Code 后重跑 /opinit" >&2; exit 1; }
[ -d "$OP_HOME/hooks" ] || { echo "[FAIL] \$OP_HOME/hooks 不存在（OP_HOME=$OP_HOME 指向错误，应为 omni_powers 仓库根）" >&2; exit 1; }
echo "[OK] 全局 OP_HOME=$OP_HOME（不写项目级，全局共享）"

# 2. 合并 hooks 配置到项目 .claude/settings.json（P1-1：按事件 concat，不覆盖用户已有 hooks）
# hook command 用 $OP_HOME/hooks/run-hook.cmd（polyglot wrapper，Claude Code 跑时从全局 env 展开 $OP_HOME）
mkdir -p .claude
if [ -f .claude/settings.json ]; then
  cp .claude/settings.json ".claude/settings.json.bak.$(date +%s)"
  jq -s '
    .[0] as $u | .[1] as $t
    | $u
    | .hooks = (reduce ($t.hooks // {} | to_entries[]) as $e ($u.hooks // {});
        .[$e.key] = ((.[$e.key] // []) + $e.value)
      ))
  ' .claude/settings.json hooks/settings.template.json > .claude/settings.json.tmp
  mv .claude/settings.json.tmp .claude/settings.json
else
  cp hooks/settings.template.json .claude/settings.json
fi
chmod +x "$OP_HOME/hooks/"*.sh "$OP_HOME/hooks/run-hook.cmd" 2>/dev/null
echo "[OK] hooks 已注册到项目（OP_HOME 走全局 env）"
```

> hook 与脚本统一通过 `$OP_HOME`（全局 settings.json 设，subagent 继承）引用：`$OP_HOME/hooks/run-hook.cmd`、`$OP_HOME/scripts/*.sh`。使用方项目数据走 `$CLAUDE_PROJECT_DIR`（Claude 内置）。废弃 `$CLAUDE_PLUGIN_ROOT` / plugin 机制。

## 步骤六：提取未执行计划（按步骤零答案）

若步骤零用户**确认提取**，派 Agent 从 `docs/archive/` 的 task/plan/todo 文件提取【还没做】的 task（严格过滤已完成），加入 tasks_list.json，每项调 `bash "$OP_HOME/scripts/op_new_task.sh" "标题" "详情"`。否则跳过。**不再次问**。

## 步骤七：完成报告

输出：
1. 归档了哪些文件
2. 生成了哪些 blueprint
3. hooks 注册位置
4. 提取了多少未执行 task

提示用户：`/opintake "<需求>"` 开始新需求，或 `/oprun` 续跑已有 task，`/opstatus` 看状态。
