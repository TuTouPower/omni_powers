# 文档模板

> 对照 `docs/ref/agent_protocol.md` 的文件分层。新建文件时拷对应模板。
> 模板里 `{TID}` `{标题}` `{功能}` 等是占位符，用实际值替换。

## 目录

### task 工作区（闭环后归档到 `docs/log/tasks/{TID}/`）

| 模板 | 用途 | 谁写 |
|---|---|---|
| [work/tasks/{TID}/spec.md](work/tasks/{TID}/spec.md) | 单 task 规格（brainstorming 生成） | leader |
| [work/tasks/{TID}/plan.md](work/tasks/{TID}/plan.md) | 实施计划（writing-plans 生成） | leader |
| [work/tasks/{TID}/steps.md](work/tasks/{TID}/steps.md) | 大 plan 拆分（可选） | leader |
| [work/tasks/{TID}/context.md](work/tasks/{TID}/context.md) | coder 开发记录，每轮追加 | coder |
| [work/tasks/{TID}/review_code.md](work/tasks/{TID}/review_code.md) | 代码审查 + coder 修改记录（只追加） | reviewer + coder |
| [work/tasks/{TID}/review_test.md](work/tasks/{TID}/review_test.md) | 测试审查 + coder 修改记录（只追加） | test-reviewer + coder |

### 持久文件

| 模板 | 路径 | 用途 |
|---|---|---|
| [index.md](index.md) | `docs/index.md` | 文档导航总图（三态模型 + 目录索引） |
| [work/tasks_list.json](work/tasks_list.json) | `docs/work/tasks_list.json` | task 清单 + 依赖 + status（核心） |
| [work/tech_debt.md](work/tech_debt.md) | `docs/work/tech_debt.md` | 技术债（每 task 闭环强制追加） |
| [work/leader_checkpoint.md](work/leader_checkpoint.md) | `docs/work/leader_checkpoint.md` | compact 恢复断点（机器读） |
| [log/progress.md](log/progress.md) | `docs/log/progress.md` | 进度日志 |
| [log/decisions.md](log/decisions.md) | `docs/log/decisions.md` | 架构决策 |
| [work/issues/{TID}_quality.md](work/issues/{TID}_quality.md) | `docs/work/issues/{TID}_quality.md` | 质量阻塞记录 |
| [ref/prd.md](ref/prd.md) | `docs/ref/prd.md` | 产品需求 |
| [ref/architecture.md](ref/architecture.md) | `docs/ref/architecture.md` | 系统架构 |
| [ref/domain.md](ref/domain.md) | `docs/ref/domain.md` | 领域模型 |
| [ref/test.md](ref/test.md) | `docs/ref/test.md` | 测试策略 |
| [ref/conventions.md](ref/conventions.md) | `docs/ref/conventions.md` | 编码约定 |
| [ref/spec.md](ref/spec.md) | `docs/ref/spec.md` | 全局总纲 + specs/ 索引 |
| [ref/specs/{功能}.md](ref/specs/{功能}.md) | `docs/ref/specs/{功能}.md` | 各功能当前生效规格 |

## 命名约定

- task 目录：`{TID}` 如 `T05`
- 文件名：snake_case（`review_code.md` 非 `review-code.md`）
- 归档路径：`docs/log/tasks/{TID}/`（注意是 `log/` 单数，非 `logs/`）
