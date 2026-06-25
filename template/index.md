# 文档导航

## 三态模型

| 目录 | 含义 | 规则 |
|---|---|---|
| `ref/` | 稳定真相 | 系统当前样貌，就地更新，长期有效 |
| `work/` | 流动工作区 | 正在做什么，高频变动，会话间交接 |
| `log/` | 冻结历史 | 曾经发生什么，只追加/只读，永不修改 |

## ref/ — 稳定真相

| 文档 | 内容 |
|---|---|
| `ref/prd.md` | 产品需求：为什么做、给谁、成功标准 |
| `ref/spec.md` | 全局总纲 + specs/ 目录索引 |
| `ref/specs/{功能}.md` | 各功能当前生效规格（每 task 闭环整理） |
| `ref/architecture.md` | 技术架构：模块、分层、数据流 |
| `ref/conventions.md` | 编码约定、命名、技术栈 |
| `ref/domain.md` | 领域知识：术语表、业务规则 |
| `ref/test.md` | 测试策略、关键用例 |
| `harness/agent_protocol.md` | 多 Agent 协作工作流协议 |

## work/ — 流动工作区

| 文档 | 内容 |
|---|---|
| `work/tasks_list.json` | task 清单 + 依赖 + status（用查询不整体读） |
| `work/tasks/{TID}/` | 进行中 task 的 spec/plan/steps/context/review_* |
| `work/tech_debt.md` | 已知技术债（每 task 闭环强制追加） |
| `work/leader_checkpoint.md` | compact 恢复断点（机器读） |
| `work/handoff.md` | 最新会话交接（给人读） |

## log/ — 冻结历史

| 文档 | 内容 |
|---|---|
| `log/progress.md` | 进度日志（每 task 闭环追加） |
| `log/decisions.md` | 架构决策（ADR 精简，只追加） |
| `log/tasks/{TID}/` | 已完成 task 的 spec/plan/context/review_* 归档 |
| `log/issues/{TID}_quality.md` | 质量阻塞记录 |
