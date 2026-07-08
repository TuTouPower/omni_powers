# 文档模板

> 对照 `RULES.md` 的文件分层。新建文件时拷对应模板。
> 模板里 `{TID}` `{title}` `{feature}` 等是占位符，用实际值替换。

## 目录

### task 工作区（闭环后归档到 `docs/omni_powers/op_record/tasks/{TID}/`）

| 模板 | 用途 | 谁写 |
|---|---|---|
| [op_execution/tasks/{TID}/report.md](op_execution/tasks/{TID}/report.md) | 顶部总报告（每轮覆盖）+ 分 Round 追加 | op-implementer |
| [op_execution/tasks/{TID}/review.md](op_execution/tasks/{TID}/review.md) | 双裁决审查（单写者 = leader，主分支落盘；Fix-N 并入 report.md） | op-reviewer（leader 落盘） |

### 持久文件

| 模板 | 路径 | 用途 |
|---|---|---|
| [index.md](index.md) | `docs/omni_powers/index.md` | 文档导航总图（三态模型 + 目录索引） |
| [op_execution/tasks_list.json](op_execution/tasks_list.json) | `docs/omni_powers/op_execution/tasks_list.json` | task 清单 + 依赖 + status（核心） |
| [op_execution/leader_checkpoint.md](op_execution/leader_checkpoint.md) | `docs/omni_powers/op_execution/leader_checkpoint.md` | compact 恢复断点（机器读） |
| [op_execution/acceptance/](op_execution/acceptance/) | `docs/omni_powers/op_execution/acceptance/{TID}/` | evaluator 验收工作区（运行时生成） |
| [op_execution/issues/I-{YYYYMMDD}-{NN}.md](op_execution/issues/I-{YYYYMMDD}-{NN}.md) | `docs/omni_powers/op_execution/issues/I-{YYYYMMDD}-{NN}.md` | 泛 issue 模板（范围外发现/暂存项/夜跑/体检） |
| [op_execution/issues/{TID}_quality.md](op_execution/issues/{TID}_quality.md) | `docs/omni_powers/op_execution/issues/{TID}_quality.md` | 质量阻塞记录（技术债加 `tech-debt` 标签） |
| [op_record/progress.md](op_record/progress.md) | `docs/omni_powers/op_record/progress.md` | 进度日志 |
| [op_record/decisions.md](op_record/decisions.md) | `docs/omni_powers/op_record/decisions.md` | 设计探索 + spec-delta（leader 变更子流程）+ 红灯归因（closer 提取），append-only |
| [op_blueprint/prd.md](op_blueprint/prd.md) | `docs/omni_powers/op_blueprint/prd.md` | 产品需求（opinit blueprint-generator 初始化，后续由需求澄清流程维护） |
| [op_blueprint/architecture.md](op_blueprint/architecture.md) | `docs/omni_powers/op_blueprint/architecture.md` | 系统架构 |
| [op_blueprint/domain.md](op_blueprint/domain.md) | `docs/omni_powers/op_blueprint/domain.md` | 领域模型 + 跨功能不变量|
| [op_blueprint/test.md](op_blueprint/test.md) | `docs/omni_powers/op_blueprint/test.md` | 测试策略 |
| [op_blueprint/conventions.md](op_blueprint/conventions.md) | `docs/omni_powers/op_blueprint/conventions.md` | 编码约定 |
| [op_blueprint/spec_index.md](op_blueprint/spec_index.md) | `docs/omni_powers/op_blueprint/spec_index.md` | specs/ 目录索引（功能清单） |
| [op_blueprint/specs/{feature}.md](op_blueprint/specs/{feature}.md) | `docs/omni_powers/op_blueprint/specs/{feature}.md` | 各功能当前生效规格 |
| [op_blueprint/baselines/baselines_index.md](op_blueprint/baselines/baselines_index.md) | `docs/omni_powers/op_blueprint/baselines/baselines_index.md` | 基准快照索引（按功能名，与 specs/ 同键） |

## 命名约定

- task 目录：`{TID}` 如 `T05`
- 文件名：snake_case（`report.md` 非 `report-code.md`）
- 归档路径：`docs/omni_powers/op_record/tasks/{TID}/`（注意是 `op_record/`）
- **归档无独立模板**：闭环时 `git mv` 把 `op_execution/tasks/{TID}/` 整个移到 `op_record/tasks/{TID}/`，文件结构沿用 tasks 工作区模板原样。故 template 下不放 `op_record/tasks/` 模板。
