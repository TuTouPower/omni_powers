# 文档模板

> 对照 `RULES.md` 的文件分层。新建文件时拷对应模板。
> 模板里 `{TID}` `{title}` `{feature}` 等是占位符，用实际值替换。

## 目录

### task 工作区（闭环后归档到 `docs/op_record/tasks/{TID}/`）

| 模板 | 用途 | 谁写 |
|---|---|---|
| [op_execution/tasks/{TID}/spec.md](op_execution/tasks/{TID}/spec.md) | 单 task 规格（op-generate-spec 生成） | leader |
| [op_execution/tasks/{TID}/plan.md](op_execution/tasks/{TID}/plan.md) | 实施计划（op-generate-plan 生成） | leader |
| [op_execution/tasks/{TID}/steps.md](op_execution/tasks/{TID}/steps.md) | 大 plan 拆分（可选） | leader |
| [op_execution/tasks/{TID}/context.md](op_execution/tasks/{TID}/context.md) | op-op-coder 开发记录，每轮追加 | op-coder |
| [op_execution/tasks/{TID}/review_code.md](op_execution/tasks/{TID}/review_code.md) | 代码审查 + op-coder 修改记录（只追加） op-code-reviewer + op-coder |
| [op_execution/tasks/{TID}/review_test.md](op_execution/tasks/{TID}/review_test.md) | 测试审查 + op-coder 修改记录（只追加） | op-test-reviewer + op-coder |

### 持久文件

| 模板 | 路径 | 用途 |
|---|---|---|
| [.gitignore](.gitignore) | 项目根目录 `.gitignore` | 含 `.superpowers/` 等 harness 通用忽略项 |
| [index.md](index.md) | `docs/index.md` | 文档导航总图（三态模型 + 目录索引） |
| [op_execution/tasks_list.json](op_execution/tasks_list.json) | `docs/op_execution/tasks_list.json` | task 清单 + 依赖 + status（核心） |
| [op_execution/tech_debt.md](op_execution/tech_debt.md) | `docs/op_execution/tech_debt.md` | 技术债（每 task 闭环强制追加） |
| [op_execution/leader_checkpoint.md](op_execution/leader_checkpoint.md) | `docs/op_execution/leader_checkpoint.md` | compact 恢复断点（机器读） |
| [op_record/progress.md](op_record/progress.md) | `docs/op_record/progress.md` | 进度日志 |
| [op_record/decisions.md](op_record/decisions.md) | `docs/op_record/decisions.md` | 架构决策 |
| [op_execution/issues/{TID}_quality.md](op_execution/issues/{TID}_quality.md) | `docs/op_execution/issues/{TID}_quality.md` | 质量阻塞记录 |
| [op_blueprint/prd.md](op_blueprint/prd.md) | `docs/op_blueprint/prd.md` | 产品需求 |
| [op_blueprint/architecture.md](op_blueprint/architecture.md) | `docs/op_blueprint/architecture.md` | 系统架构 |
| [op_blueprint/domain.md](op_blueprint/domain.md) | `docs/op_blueprint/domain.md` | 领域模型 |
| [op_blueprint/test.md](op_blueprint/test.md) | `docs/op_blueprint/test.md` | 测试策略 |
| [op_blueprint/conventions.md](op_blueprint/conventions.md) | `docs/op_blueprint/conventions.md` | 编码约定 |
| [op_blueprint/spec.md](op_blueprint/spec.md) | `docs/op_blueprint/spec.md` | 全局总纲 + specs/ 索引 |
| [op_blueprint/specs/{feature}.md](op_blueprint/specs/{feature}.md) | `docs/op_blueprint/specs/{feature}.md` | 各功能当前生效规格 |

## 命名约定

- task 目录：`{TID}` 如 `T05`
- 文件名：snake_case（`review_code.md` 非 `review-code.md`）
- 归档路径：`docs/op_record/tasks/{TID}/`（注意是 `op_record/` 单数，非 `logs/`）
- **归档无独立模板**：闭环时 `git mv` 把 `op_execution/tasks/{TID}/` 整个移到 `op_record/tasks/{TID}/`，文件结构沿用 tasks 工作区模板原样，仅在 `spec.md` 顶部盖戳"⚠️ 历史快照，以 docs/op_blueprint/specs/ 为准"。故 template 下不放 `op_record/tasks/` 模板。
