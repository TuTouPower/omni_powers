# 文档导航

## 三态模型

| 目录 | 含义 | 规则 |
|---|---|---|
| `op_blueprint/` | 稳定真相 | 系统当前样貌，就地更新，长期有效 |
| `op_execution/` | 流动工作区 | 正在做什么，高频变动，会话间交接 |
| `op_record/` | 冻结历史 | 曾经发生什么，只追加/只读，永不修改 |

## op_blueprint/ — 稳定真相

| 文档 | 内容 |
|---|---|
| `op_blueprint/prd.md` | 产品需求：为什么做、给谁、成功标准 |
| `op_blueprint/spec.md` | 全局总纲 + specs/ 目录索引 |
| `op_blueprint/specs/{feature}.md` | 各功能当前生效规格（每 task 闭环整理） |
| `op_blueprint/architecture.md` | 技术架构：模块、分层、数据流 |
| `op_blueprint/conventions.md` | 编码约定、命名、技术栈 |
| `op_blueprint/domain.md` | 领域知识：术语表、业务规则 |
| `op_blueprint/test.md` | 测试策略、关键用例 |

## op_execution/ — 流动工作区

| 文档 | 内容 |
|---|---|
| `op_execution/tasks_list.json` | task 清单 + 依赖 + status（用查询不整体读） |
| `op_execution/dag.md` | DAG 依赖图（Mermaid + 分层表，由 dag_gen.sh 生成） |
| `op_execution/tasks/{TID}/` | 进行中 task 的 spec/plan/context/review_* |
| `op_execution/tech_debt.md` | 已知技术债（每 task 闭环强制追加） |
| `op_execution/leader_checkpoint.md` | compact 恢复断点（机器读）+ 会话交接（人读"关键上下文"段） |
| `../RULES.md` | 核心协议（compact 恢复必读） |
| `../RULES_DETAIL.md` | 操作细则（jq 示例/回滚/阻塞项） |
| `op_decisions.md` | 决策记录 |
| `op_execution/issues/{TID}_quality.md` | 质量阻塞记录 |

## op_record/ — 冻结历史

| 文档 | 内容 |
|---|---|
| `op_record/progress.md` | 进度日志（每 task 闭环追加） |
| `op_record/decisions.md` | 架构决策（ADR 精简，只追加） |
| `op_record/tasks/{TID}/` | 已完成 task 的 spec/plan/context/review_* 归档 |
