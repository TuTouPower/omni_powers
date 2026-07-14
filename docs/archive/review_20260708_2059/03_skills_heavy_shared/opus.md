# Multi-Model Review Report (opus)

## 当前模型判断依据
- 主会话运行模型为 `default_opus[1m]` (Opus 4.5 预览版/等效大模型)。根据 settings 顶层配置和运行环境提示，当前环境继承主会话模型档位。本审计纯属只读分析，未写入任何 secret。

## 审阅范围
本次审计针对 `omni_powers` 项目以下 16 个核心 skill 与 script 文件：
1. `skills/opinit/SKILL.md`
2. `skills/opinit/scripts/opinit_register_hooks.sh`
3. `skills/opinit/scripts/opinit_skeleton.sh`
4. `skills/opintake/SKILL.md`
5. `skills/oprun/SKILL.md`
6. `skills/oprun/scripts/close_check.sh`
7. `skills/oprun/scripts/op_assemble_eval_brief.sh`
8. `skills/oprun/scripts/op_checkpoint.sh`
9. `skills/oprun/scripts/op_close_post.sh`
10. `skills/oprun/scripts/op_close_pre.sh`
11. `skills/oprun/scripts/op_coder_check.sh`
12. `skills/oprun/scripts/op_read_verdict.sh`
13. `skills/opspec/SKILL.md`
14. `skills/opstatus/SKILL.md`
15. `skills/opred/SKILL.md`
16. `skills/optriage/SKILL.md`

同时参考了以下核心设计与横切脚本：
- `docs/omni_powers_design.md` (全量开发方案设计)
- `scripts/op_status.sh` (ASCII 状态控制)
- `scripts/op_jq.sh` (JSON 数据查询)
- `scripts/op_closer_gate.sh` (Closer 越界写入校验)

---

## 高优先级问题

### 问题 1: 状态更新与校验中存在中英文状态值混用，导致执行中断
- **位置**:
  - `skills/oprun/scripts/op_close_pre.sh` (第 12 行)
  - `skills/oprun/scripts/op_close_post.sh` (第 54 行)
  - `skills/oplrun/scripts/op_close_post.sh` (第 55 行)
  - `skills/oprun/SKILL.md` (第 140, 160, 171, 184 行)
  - `skills/optriage/SKILL.md` (第 76 行)
  - `skills/opintake/SKILL.md` (第 64, 81 行)
  - `skills/oplintake/SKILL.md` (第 7, 80, 98 行)
- **现象**: 在最近的重构中，`scripts/op_status.sh` (以及 `skills/oplrun/scripts/op_status.sh`) 被修改为仅接受 ASCII 状态机读值（如 `pending`, `ready`, `in_progress`, `reviewing`, `closing`, `done`, `suspended`, `blocked`, `obsolete`）。但是，上述脚本 and 文档在调用 `op_status.sh` 或写 `tasks_list.json` 时，仍然使用了中文状态值（如 `"完成"`, `"收口中"`, `"进行中"`, `"审阅中"`, `"待开始"`, `"待规划"`）。
- **影响**: 
  1. 当运行 `op_close_pre.sh` 和 `op_close_post.sh` 时，会因为向 `op_status.sh` 传递了中文状态名 `"完成"` 或 `"收口中"` 而报错退出，阻断整个收尾流程的自动执行。
  2. 若 Agent 在 triage 或 intake 阶段按照 `SKILL.md` 的规范将 `"待开始"`、`"待规划"` 直接写入 `tasks_list.json`，将导致 `op_jq.sh` 无法根据 ASCII 状态匹配出对应的 task。
- **建议**:
  - 修改 `skills/oprun/scripts/op_close_pre.sh`：将 `"收口中"` 改为 `"closing"`。
  - 修改 `skills/oprun/scripts/op_close_post.sh` 和 `skills/oplrun/scripts/op_close_post.sh`：将 `"完成"` 改为 `"done"`。
  - 更新所有 Intake, Run, Triage 等 Skill 文档中的指令示例与输出模板，确保 status 字段在 JSON 中使用 ASCII 机读值（`ready`, `pending`, `in_progress`, `reviewing`, `closing`, `done`），并在终端渲染时才转为中文。
- **置信度**: 100%
- **优先级**: High

### 问题 2: `op_checkpoint.sh` 状态提取逻辑依然使用中文，导致 Checkpoint 状态渲染失效
- **位置**: `skills/oprun/scripts/op_checkpoint.sh` (第 31-36 行)
- **现象**: 脚本内对 `tasks_list.json` 的解析代码使用了中文状态值过滤：
  ```bash
  done_ids=$(echo "$status_json" | jq -r '\''[.[] | select(.status == "完成") | .id] | join(", ")'\'' 2>/dev/null || echo "")
  pending_ids=$(echo "$status_json" | jq -r '\''[.[] | select(.status == "待开始") | .id] | join(", ")'\'' 2>/dev/null || echo "")
  # ... (同样包含 待规划、阻塞、跳过、挂起 等中文过滤)
  ```
- **影响**: 随着 `tasks_list.json` 改为写入 ASCII 状态值（如 `done`, `ready`），`op_checkpoint.sh` 过滤出的各状态列表都将为空（渲染为 "无"），无法正确在 `leader_checkpoint.md` 中展示当前任务的进度状态。
- **建议**: 将 `select(.status == "完成")` 等过滤条件全部修改为对应的 ASCII 机读值（如 `done`, `ready`, `pending`, `blocked`, `suspended`, `obsolete`）。
- **置信度**: 100%
- **优先级**: High

---

## 中低优先级问题

### 问题 3: 归档脚本 `op_close_post.sh` 中未实现 Spec 文件与 Acceptance 目录的归档
- **位置**: `skills/oprun/scripts/op_close_post.sh` 和 `skills/oplrun/scripts/op_close_post.sh`
- **现象**: 按照设计规范 (design §2.6 / §5.6)，task 归档提案通过后，需要归档三类资产：
  1. Task 运行目录（`tasks/{TID}/`）-> 移入 `op_record/tasks/`
  2. Spec 规格原文（`specs/{TID}_{slug}.md`）-> 移入 `op_record/specs/`
  3. Acceptance 验收目录（`acceptance/{TID}/`）-> 移入 `op_record/acceptance/`
  但是 `op_close_post.sh` 只通过 `git mv` 移动了第 1 项 Task 运行目录，没有对 Spec 原文和 Acceptance 目录进行任何归档操作，且在结尾 `git add` 时也漏掉了对这些归档路径的暂存。
- **影响**: 导致 `specs/` 和 `acceptance/` 下的历史工单碎片在执行期结束后一直残留在 `op_execution/` 活跃工作区中，违反了 "活跃工作区只放活的东西，冻结历史归档" 的设计原则，并造成活跃目录混乱。
- **建议**:
  - 在 `op_close_post.sh` (及 `oplrun` 副本) 中增加自动识别并移动 `op_execution/specs/${TID}_*.md` 到 `op_record/specs/` 的逻辑。
  - 在 `op_close_post.sh` 中增加移动 `op_execution/acceptance/${TID}` 目录到 `op_record/acceptance/${TID}` 的逻辑（若该目录存在）。
  - 在最后的 `git add` 中补充对应归档路径的暂存。
- **置信度**: 95%
- **优先级**: Medium

### 问题 4: `tasks_list.json` 中的 `spec` 字段类型定义不一致
- **位置**: `skills/opintake/SKILL.md` (步骤四), `skills/oplintake/SKILL.md` (步骤四) vs `docs/omni_powers_design.md` §2.3
- **现象**: Intake skill 在创建任务时的示例 JSON 写入的是 `"spec": "T0001"` (即 spec 字段直接等于任务 TID/ID)，而设计文件 (design §2.3) 中定义的规范是 `"spec": "specs/T0003_xxx.md"` (指向具体的 Spec 相对路径)。
- **影响**: 虽然目前运行脚本（如 `op_assemble_eval_brief.sh`）在寻找 Spec 文件时是通过 Glob 规则 `specs/${TID}_*.md` 机械匹配，并未直接读取该 JSON 字段，本格式定义的不一致为后续自动化拓展埋下了隐患，且降低了元数据的自洽性。
- **建议**: 统一规范，将 Intake skill 的示例 JSON 中的 `"spec": "T0001"` 修正为规范路径 `"spec": "specs/T0001_xxx.md"`，与设计规范对齐。
- **置信度**: 90%
- **优先级**: Medium

---

## 改进建议

### 建议 1: 清理 `opinit_skeleton.sh` 和 `op_checkpoint.sh` 中废弃的状态语义
- **现象**: `opinit_skeleton.sh` 生成的 checkpoint 模版中依然标明有 `"跳过"` (skipped) 状态的自动更新，`op_checkpoint.sh` 同样保留了对 `skipped_ids` 的提取和渲染。但在最近的 ASCII 重构中，`skipped` 状态已被彻底废除，取而代之的是 `obsolete` (废弃) 状态。
- **改进**:
  - 将 `opinit_skeleton.sh` 模版里的 `"跳过"` 替换为 `"废弃"`。
  - 在 `op_checkpoint.sh` 中移除 `skipped_ids` 变量，增加 `obsolete_ids` 变量并将其在 Checkpoint 中输出为 `- 废弃：${obsolete_ids:-无}`。

### 建议 2: Lite 模式脚本增加对 `OP_PROFILE` 的硬断言校验
- **现象**: Lite 模式的部分脚本在入口没有强制校验 `OP_PROFILE` 是否为 `lite`，容易因为被误调用而导致状态混乱。
- **改进**: 在 `skills/oplrun/scripts/` 下的各核心脚本开头，加一行强校验，如果 `[ "${OP_PROFILE:-}" != "lite" ]` 则直接 die 报错退出，确保环境安全性。

---

## 不确定项
- **关于 `optriage` 的 task 自动合并限制**: `optriage/SKILL.md` 提到 `转 task 总数不超过 10 个。超过则优先合并同模块项`。合并动作需要对代码架构和业务逻辑有深度理解，目前全自动合并同模块 issue 进单个 task 可能会导致拆分出来的 workset 和 depends_on 过于宽泛。由于目前该限制仅写在 prompt/SKILL.md 里由 Agent 自由发挥实现，建议在后续实装中，增加手动确认或者提供预设的合并脚本以保持稳定性。
