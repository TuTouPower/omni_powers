---
name: opinit
description: >
  一次性初始化（heavy）：生成 omni_powers 三区骨架 + 写 profile=heavy + hooks 注册。在一个已有项目中初始化工作流目录与规范文档。
  触发：/opinit。
  前置：已跑仓库 install.sh --set-ophome（唯一安装脚本，heavy/lite 共用）。
---

# Op Init Skill

> **运行前检查环境**：`bash "$OP_HOME/scripts/op_check_env.sh"`（jq/git/OP_HOME，缺失 die + 装法）——Windows 无 jq 是常见坑

`/opinit` 在已有项目中初始化 omni_powers 工作流骨架，归档旧文档，注册 hooks。一次性。

> **问询原则**：步骤零先浏览所有文档 + 整理所有问题，**一次性向用户提问**。后续步骤（二/六等）按零答案执行，**不再问**——除非遇严重阻塞（插件资源缺失 / 关键文件读不到，直接 die 提示，不是问）。

## 步骤零：浏览 + 一次问

先解析现有配置；首次初始化默认 `docs/omni_powers`。把 **OP 根目录** 纳入本次一次性问询：默认值 `docs/omni_powers`，可选 `docs`，也可填安全项目相对路径。若目标与现有根不同，必须同时取得迁移确认，后续执行传 `--yes`。

```bash
source "$OP_HOME/scripts/op_paths.sh"
op_load_paths "" "$(git rev-parse --show-toplevel)"
printf '当前 OP 根: %s（来源: %s）\n' "$OP_DOCS_DIR" "$OP_DOCS_DIR_SOURCE"
```

跑前全面浏览现状，整理所有需用户决策的点，**一次问完**（不要逐个问；OP 根计入一次提问上限）。

```bash
# 浏览用户项目现有文档（不预设位置——docs/archive 是 opinit 要建的归档目标，不是用户已有的）
echo "=== 项目根 md ==="; ls *.md 2>/dev/null
echo "=== docs/ 下所有 md（排除 omni_powers 三区）==="; find docs -name '*.md' -not -path "$OP_DOCS_DIR/*" 2>/dev/null | head -40
echo "=== .claude 配置 ==="; ls .claude/ 2>/dev/null
echo "=== 近期 commit ==="; git log --oneline -20 2>/dev/null
echo "=== OP_HOME ==="; echo "OP_HOME=$OP_HOME"
echo "=== 代码结构 ==="; ls src/ 2>/dev/null | head
echo "=== 未执行计划候选（扫现有 md 里 task/plan/todo 关键词）==="; grep -rilE 'task|plan|todo' docs *.md 2>/dev/null | awk -v prefix="$OP_DOCS_DIR/" 'index($0, prefix) != 1' | head
```

据浏览结果整理需问的点，**一次问完**（合并多问题到一次用户提问）：

1. **旧文档归档 + 有效/废弃分类**（**用户指令优先 + 列计划让用户一次批准**）：
   - 先听用户初始指令（如"重构所有文档"/"归档所有"）——**用户说"所有"则所有进候选，不偷偷排除**
   - 列全部归档候选：根 md + docs md + docs 子目录（含 `design/`/`superpowers/` 等全部，**不预设排除**）
   - **agent 据文件名/路径判有效/废弃（不读内容）**：路径或文件名含 `deprecated`/`archive`（非本次 opinit 建的 `docs/archive`）/`archive_spec`/`old`/`legacy`/`旧`/`废弃` → 废弃；否则 → 有效。有效文档归 `archive_valid/`（步骤六 issues 提取的可信矿藏），废弃文档归 `archive/`
   - 标注"建议保留"（仅供用户参考，**用户指令覆盖**）：`README.md`（项目入口）/ `CLAUDE.md`（步骤三重构）/ `$OP_DOCS_DIR/`（本次生成）。`docs/design/` 默认建议保留（UI 真相源），但**用户说"所有"则归档**，不擅自排除
   - 向用户呈现计划（候选 + agent 分类 + 建议保留），**用户一次批准或调整分类**。用户已说"所有/全部"时**不要二次确认每一个**
2. **未执行计划提取**：docs/archive/ 有 task/plan/todo 文件？问是否提取为 tasks_list.json 的 task
3. **其他歧义**（有则问，无则跳过）：
   - 三区已存在（重跑 opinit）：保留不覆盖（步骤一脚本幂等），只补缺——无需问
   - 多个冲突 SPEC（如 SPEC.md vs SPEC_旧.md）：问以哪个为准（归档其他）
   - CLAUDE.md 不存在：步骤三 CLAUDE 重构跳过（无文件可改）——无需问
   - **一次提问上限 4 题**：候选多于 4 时按主题聚类（如"归档"合并所有归档候选为一题多选）

记下答案，后续步骤按答案执行，**不再问**。

## 步骤一：配置 OP 根 + 创建标准目录结构

```bash
bash "$OP_HOME/scripts/op_configure_project.sh" --target "<步骤零确认的 OP 根>" --yes
source "$OP_HOME/scripts/op_paths.sh"
op_load_paths "" "$(git rev-parse --show-toplevel)"
bash "$OP_HOME/skills/opinit/scripts/opinit_skeleton.sh"
```

> 首次初始化写项目 `.claude/settings.json.env.OP_DOCS_DIR`。迁移时 `op_configure_project.sh` 先预检、再迁移、最后原子更新 settings；冲突或失败回滚。旧项目无配置仍按默认 `docs/omni_powers` 运行。

> 脚本建三区目录 + **profile=heavy**（已有 `profile=lite` 则 die 防混跑；旧项目无 profile 补写）+ baselines_index 模板 + tasks_list + checkpoint + progress/decisions 初始说明。**重跑幂等**：已存在的 tasks_list/checkpoint/progress/decisions/baselines_index 保留不覆盖（只补缺）——opinit 在已有 omni_powers 项目重跑不破坏数据。

技术债登记为 issue 加 `tech-debt` 标签，不单独建文件。依赖走 `depends_on` + jq，不单独建图文件。

## 步骤二：归档旧文档（按步骤零答案）

将步骤零用户确认归档的文件**按分类**移入：有效 → `docs/archive_valid/`，废弃 → `docs/archive/`。**不再次问**——按零答案执行。

```bash
mkdir -p docs/archive_valid
# leader 据步骤零确认的分类逐个移：有效进 archive_valid（步骤六 issues 矿藏），废弃进 archive
for f in <有效文档>; do mv "$f" docs/archive_valid/; done
for f in <废弃文档>; do mv "$f" docs/archive/; done
```

- **三区已存在的文件保留**（步骤一脚本幂等，不破坏）——只归档用户确认的旧文档，不动 `$OP_DOCS_DIR/`
- `README.md` / `CLAUDE.md`（步骤三重构）/ `RULES.md` 默认保留原位（除非用户在零里明确说归档）

## 步骤三：生成 Blueprint（按职责矩阵分工 + specs 不空）

派发 Agent 读归档区 + git log + 现有代码，提炼"现在是什么"，按 `$OP_HOME/docs/omni_powers_design.md §1.3` 文档职责矩阵生成（各文档单一职责，重复内容独占一份，其他"详见 X.md"）：

```js
Agent({
  name: "blueprint-generator",
  // model: 不传则继承主会话；如需固定模型由用户配置 OP_*_MODEL
  prompt: "读 docs/archive_valid/ + 近期 git log（git log --oneline -50）+ 现有代码（src/ 结构 + 关键模块），提炼项目'现在是什么'，按 design §1.3 职责矩阵生成 $OP_DOCS_DIR/op_blueprint/ 文档（避免重复）：\n- prd.md：产品需求（定位/用户/功能/成功标准/不做）\n- architecture.md：技术栈 + 目录结构 + 模块 + 数据流（唯一目录/技术栈真相）\n- domain.md：术语表 + 跨功能业务不变量\n- conventions.md：命名/风格/文件组织/浏览器 API/日志/适配器步骤（编码独占，技术栈不在此）\n- test.md：测试分层/覆盖/Mock/调试入口\n- spec_index.md：纯 specs/ 索引（功能清单 + 文件指引，不塞技术栈/架构/安全）。**只列 specs/ 下每功能一行（功能名 + spec 文件路径），无状态列**（op_blueprint 定义即'已实现'，状态恒 done 无信息量）；**禁止'归档文档位置/archive 清单'段**（归档路径归 index.md）。\n- specs/{feature}.md：从 archive + 代码 + commit 提炼**已实现功能**，每功能一份（接口/数据模型/行为——'现在是什么'）。已实现功能逐个生成，不遗留空；新增功能（未实现）不生成，留 /opintake 拆分时补。\n丢弃过期内容。重复内容只留独占者，其他文档'详见 X.md'。\n**全体 blueprint 文档禁止溯源头注释**（'来源：docs/archive/...'、'最后更新：日期'、'文件：src/...' 一律不写）——blueprint 是当前真相源，非 archive 派生物，头注释会误导读者回溯废档。\n**test.md 的测试目录结构必须先 `find tests -type d` + `ls tests/` 核对实际再落笔**（含 e2e 目录实际位置/命名），禁止画理想树；测试/构建/启动命令同样从项目实际提取（CLAUDE.md / README / 旧 test.md / package.json scripts / scripts/ / Makefile 各处都可能），找不到标 NEEDS CLARIFICATION 问用户，**绝勿臆造**。" })
```

完成后**重构 CLAUDE.md**（dispatch agent 改——对齐"重构所有文档"指令，不只是去重，是重新组织）：

```js
Agent({
  name: "claude-md-refactor",
  // model: 不传则继承主会话；如需固定模型由用户配置 OP_*_MODEL
  prompt: "读项目根 CLAUDE.md + $OP_DOCS_DIR/op_blueprint/ 各文档。重构 CLAUDE.md（按职责矩阵重组，非仅去重）：(1) 项目一句话定位 (2) dev/build/test 命令 (3) 指向 $OP_DOCS_DIR/op_blueprint/ 各文档的导航 (4) 项目特有约束（如 CDP 端口等指向 test.md）。删与 blueprint 重复的段（技术栈/目录树/架构约束/命名规范/日志规则/调试规则/适配器步骤），改'详见 architecture.md / conventions.md / domain.md / test.md'。CLAUDE.md 是'门牌'，不重复 blueprint。保留 omni_powers 启用声明。直接改 CLAUDE.md。" })
```

> 重构后 git diff 可回顾；不满意 `git checkout CLAUDE.md` 还原。

## 步骤四：重写导航（op_index.md + op_readme.md）

```js
Agent({
  name: "index-generator",
  // model: 不传则继承主会话；如需固定模型由用户配置 OP_*_MODEL
  prompt: "读 $OP_DOCS_DIR/op_blueprint/ 文档列表，生成两个导航内容：\n(1) op_index.md（给 agent）：三态模型 + 各文档定位，/oprun 启动读其摘要（A17，原 SessionStart 注入已移除）。**禁 profile 段**——profile 有单独文件 `$OP_DOCS_DIR/profile`（机器读，唯一真相源），index 不复写模式说明。**禁溯源头注释**（'最后更新'/'来源'，和 blueprint 一致——稳定文档不带易过期日期）。**禁'关键约束'段重复 design/RULES 内容**——index 只做文档导航。\n(2) op_readme.md（给人）：项目用 omni_powers 工作流 + 三区一句话说明 + 指向 op_index.md + 常用命令（/opintake '/需求/' /oprun /opstatus）。**不重复 index 的详细文档定位**，只做入口概览。\n两文件均为 OP 独占文件，直接写 `$OP_DOCS_DIR/op_index.md` 与 `$OP_DOCS_DIR/op_readme.md`。" })
```

## 步骤五：注册 hooks（到使用方 .claude/settings.json）

```bash
bash "$OP_HOME/skills/opinit/scripts/opinit_register_hooks.sh"
```

> 脚本校验全局 OP_HOME（未设/指向错 die 提示）+ 合并 hooks 到项目 `.claude/settings.json`（按事件 concat，不覆盖用户已有 hooks；保留步骤一写入的 `env.OP_DOCS_DIR`，并补 OP_*_MODEL）。OP_HOME 由用户**全局** settings.json 设，**opinit 不写项目级 OP_HOME**。hook command 用 `$OP_HOME/hooks/run-hook.cmd`（polyglot wrapper，跨平台）。

> hook 与脚本统一通过 `$OP_HOME`（全局 settings.json 设，subagent 继承）引用。使用方项目数据走 `$CLAUDE_PROJECT_DIR`（Claude 内置）。废弃 `$CLAUDE_PLUGIN_ROOT` / plugin 机制。

## 步骤六：提取未执行计划 → issues/（不进 tasks_list）

> **规则**：没拆 task + 没技术方案的"未执行计划" → **issues**（backlog 收件箱），**不进 tasks_list**。tasks_list 是"排好序、随时可领用执行"的队列，塞残缺 task（无验收标准/工作集/依赖）会卡 oprun。拆 task + 写技术方案是 `/opintake` 的活，opinit 只捞进 issue 等消化。
>
> 一句话：issue = "有这事，还没决定怎么做"；task = "决定好了，照着干"。opinit 不负责拆。

若步骤零用户**确认提取**，分两步（leader + agent）：
1. **leader 扫候选**（只扫 `archive_valid/` 有效文档——废弃文档 `archive/` 的待办可能已过期，不捞）：`grep -rilE '待办|未做|todo|待完成|TODO' docs/archive_valid/ 2>/dev/null | head -10`
2. **派 Agent 读候选文件**，提炼【还没做】的项（严格过滤已完成 + 暂缓项），返回清单（title / source 行号 / 一句话 / severity 建议）
3. **leader 据清单写 `$OP_DOCS_DIR/op_execution/issues/`**，每项一个 issue 文件：
   - **文件名 `issue_{slug}.md`**（语义 slug，人读；非 `I-YYYYMMDD-NN`）
   - **frontmatter `id` 强制 `I-{YYYYMMDD}-{NN}`**（机器主键，唯一+排序；与文件名解耦——id 给机器，文件名给人）
   - **`severity` 必须 `P0|P1|P2|P3`**（ASCII，非 medium/low/high）
   - **`created_at` 必填** `YYYY-MM-DD HH:mm:ss UTC+8`
   - 其余字段（title/source/spec/tags/status:open/blocks_merge）按 design §3.2；**`source` 写 `docs/archive/` 最终路径**（步骤七合并后位置，非当前 `archive_valid/`）

否则跳过。**不再次问**。

## 步骤七：合并暂存区 + 完成报告

**合并 `archive_valid` → `archive`**（`archive_valid` 是临时暂存区，步骤六 issues 提取完即归一，不留额外目录）：

```bash
[ -d docs/archive_valid ] && { mv docs/archive_valid/* docs/archive/ 2>/dev/null; rmdir docs/archive_valid 2>/dev/null || true; }
```

输出：
1. 归档了哪些文件
2. 生成了哪些 blueprint
3. hooks 注册位置
4. 提取了多少未执行计划 issue

提示用户：
- **git 未 commit**：opinit 不自动 commit，N 文件变更在工作区。建议 `git add -A && git commit -m "opinit 初始化"` 提交
- `/opintake "<需求>"` 开始新需求，或 `/oprun` 续跑已有 task，`/opstatus` 看状态
