# 文档模板

> 对照 `RULES.md` 的文件分层。新建文件时拷对应模板。
> 模板里 `{TID}` `{title}` `{feature}` 等是占位符，用实际值替换。

## 目录

### task 工作区（闭环后归档到 `docs/harness_record/tasks/{TID}/`）

| 模板 | 用途 | 谁写 |
|---|---|---|
| [harness_execution/tasks/{TID}/spec.md](harness_execution/tasks/{TID}/spec.md) | 单 task 规格（brainstorming 生成） | leader |
| [harness_execution/tasks/{TID}/plan.md](harness_execution/tasks/{TID}/plan.md) | 实施计划（writing-plans 生成） | leader |
| [harness_execution/tasks/{TID}/steps.md](harness_execution/tasks/{TID}/steps.md) | 大 plan 拆分（可选） | leader |
| [harness_execution/tasks/{TID}/context.md](harness_execution/tasks/{TID}/context.md) | coder 开发记录，每轮追加 | coder |
| [harness_execution/tasks/{TID}/review_code.md](harness_execution/tasks/{TID}/review_code.md) | 代码审查 + coder 修改记录（只追加） | reviewer + coder |
| [harness_execution/tasks/{TID}/review_test.md](harness_execution/tasks/{TID}/review_test.md) | 测试审查 + coder 修改记录（只追加） | test-reviewer + coder |

### 持久文件

| 模板 | 路径 | 用途 |
|---|---|---|
| [.gitignore](.gitignore) | 项目根目录 `.gitignore` | 含 `.superpowers/` 等 harness 通用忽略项 |
| [index.md](index.md) | `docs/index.md` | 文档导航总图（三态模型 + 目录索引） |
| [harness_execution/tasks_list.json](harness_execution/tasks_list.json) | `docs/harness_execution/tasks_list.json` | task 清单 + 依赖 + status（核心） |
| [harness_execution/tech_debt.md](harness_execution/tech_debt.md) | `docs/harness_execution/tech_debt.md` | 技术债（每 task 闭环强制追加） |
| [harness_execution/leader_checkpoint.md](harness_execution/leader_checkpoint.md) | `docs/harness_execution/leader_checkpoint.md` | compact 恢复断点（机器读） |
| [harness_record/progress.md](harness_record/progress.md) | `docs/harness_record/progress.md` | 进度日志 |
| [harness_record/decisions.md](harness_record/decisions.md) | `docs/harness_record/decisions.md` | 架构决策 |
| [harness_execution/issues/{TID}_quality.md](harness_execution/issues/{TID}_quality.md) | `docs/harness_execution/issues/{TID}_quality.md` | 质量阻塞记录 |
| [harness_blueprint/prd.md](harness_blueprint/prd.md) | `docs/harness_blueprint/prd.md` | 产品需求 |
| [harness_blueprint/architecture.md](harness_blueprint/architecture.md) | `docs/harness_blueprint/architecture.md` | 系统架构 |
| [harness_blueprint/domain.md](harness_blueprint/domain.md) | `docs/harness_blueprint/domain.md` | 领域模型 |
| [harness_blueprint/test.md](harness_blueprint/test.md) | `docs/harness_blueprint/test.md` | 测试策略 |
| [harness_blueprint/conventions.md](harness_blueprint/conventions.md) | `docs/harness_blueprint/conventions.md` | 编码约定 |
| [harness_blueprint/spec.md](harness_blueprint/spec.md) | `docs/harness_blueprint/spec.md` | 全局总纲 + specs/ 索引 |
| [harness_blueprint/specs/{feature}.md](harness_blueprint/specs/{feature}.md) | `docs/harness_blueprint/specs/{feature}.md` | 各功能当前生效规格 |

## 命名约定

- task 目录：`{TID}` 如 `T05`
- 文件名：snake_case（`review_code.md` 非 `review-code.md`）
- 归档路径：`docs/harness_record/tasks/{TID}/`（注意是 `harness_record/` 单数，非 `logs/`）
- **归档无独立模板**：闭环时 `git mv` 把 `harness_execution/tasks/{TID}/` 整个移到 `harness_record/tasks/{TID}/`，文件结构沿用 tasks 工作区模板原样，仅在 `spec.md` 顶部盖戳"⚠️ 历史快照，以 docs/harness_blueprint/specs/ 为准"。故 template 下不放 `harness_record/tasks/` 模板。
