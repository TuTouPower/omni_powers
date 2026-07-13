# 文档导航

> `$OP_DOCS_DIR` 由项目 `.claude/settings.json.env.OP_DOCS_DIR` 指定；未配置时默认 `docs/omni_powers`。


> 给 agent 看的目录页（SessionStart hook 注入其摘要）。三态模型 + 各文档定位。
> 设计理由见 omni_powers 插件目录 `$OP_HOME/docs/omni_powers_design.md`；运行时操作见 `$OP_HOME/RULES.md`。`$OP_HOME` 是插件安装目录，不是目标项目根目录。

## 三态模型

| 目录 | 含义 | 规则 |
|---|---|---|
| `op_blueprint/` | 稳定真相 | 系统当前样貌，就地更新，长期有效 |
| `op_execution/` | 流动工作区 | 正在做什么，高频变动，会话间交接 |
| `op_record/` | 冻结历史 | 曾经发生什么，只追加/只读，永不修改 |

## op_blueprint/ — 稳定真相（"应该是什么"）

| 文档 | 内容 |
|---|---|
| `prd.md` | 产品需求纪要：为什么做、给谁、成功标准 |
| `spec_index.md` | specs/ 目录索引：功能清单 + 一句话说明 + 文件指引 |
| `specs/{feature}.md` | 各功能当前生效规格（per-task 收尾时整理，含 baselines 引用） |
| `architecture.md` | 技术架构：模块、分层、跨模块契约 |
| `conventions.md` | 编码约定、命名、技术栈 |
| `domain.md` | 领域知识：术语表 + 跨功能全局不变量|
| `test.md` | 测试宪章：可写性矩阵、红灯归因、危险模式 |
| `baselines/baselines_index.md` | 基准文件索引：功能名→验收标准→文件（结构化硬门 + 视觉 advisory，与 specs/ 同键） |

## op_execution/ — 流动工作区（"现在在干什么"）

| 文档 | 内容 |
|---|---|
| `specs/{TID}_{slug}.md` | 工作 spec（task:spec 1:1，每 task 一份自足，验收标准/不变量/边界/技术决策/可测性契约） |
| `tasks_list.json` | 唯一 task 真相源（jq 查，禁 Read 整文件） |
| `tasks/{TID}/` | 活跃 task 二文件：report.md / review.md |
| `acceptance/{TID}/` | 验收工作区：evaluator 产出（baselines 临时区 + 验收报告）+ closer per-task 提案 |
| `issues/` | 问题登记（含 tech-debt 标签，转 task 走 change type 流程） |
| `leader_checkpoint.md` | compact 恢复断点（机器读）+ 会话交接（人读"关键上下文"段） |

## op_record/ — 冻结历史（"发生过什么"，append-only）

| 文档 | 内容 |
|---|---|
| `decisions.md` | 决策记录（spec 编写者设计探索 + closer 执行期自决，append-only） |
| `progress.md` | 每 task 完成一行（commit 区间 + review 结论 + 验收标准覆盖） |
| `specs/` | 已归档工作 spec（按 TID，TID 永不复用） |
| `tasks/` | 已归档 task 的 report/review（无 brief，design §1.1） |
| `acceptance/{TID}/` | 已归档 task 验收工作区（blueprint_update.md + baselines 快照） |

## 引用

| 文档 | 定位 |
|---|---|
| `$OP_HOME/RULES.md` | 运行时操作手册（compact 恢复入口 + 全局状态机） |
| `$OP_HOME/docs/omni_powers_design.md` | 设计档案（为什么这么设计，不进运行时） |
