# Sonnet 视角 — Agents 审阅报告

## 当前模型判断依据

当前会话环境提示 `powered by default_model`，未设置 model 覆盖，继承主会话。`~/.claude/settings.json` 顶层 `model=default_model`，`env.ANTHROPIC_MODEL=default_model`。本路不覆盖 model 参数，以该模型视角独立判断。

## 审阅范围

- `agents/op-closer.md`
- `agents/op-evaluator.md`
- `agents/op-implementer.md`
- `agents/op-reviewer.md`

对照核心规格 `docs/omni_powers_design.md`，逐文件、逐段审查角色职责、权限边界、heavy/lite 分支、状态机、测试/验收/收口协议的一致性。

---

## 高优先级问题（CRITICAL / HIGH）

### 1. [HIGH] op-implementer.md — review.md 写入权与 design 单写者模型冲突

**位置**: `agents/op-implementer.md` 第 2 行（description frontmatter）、第 4 行（核心规则 4）、第 54-55 行（FAIL 轮工作流）、第 68 行（文件约定表格）

**现象**: implementer agent 多处声称 FAIL 轮应在 `review.md` 末尾追加 Fix-N 修改记录：

- description: `"FAIL 轮修复后在 review.md 追加修改记录"`
- 核心规则 4: `"FAIL 轮只改 review.md 的 Fix-N 段"`
- FAIL 轮工作流第 5 步: `"在 review.md 末尾追加修改记录（Fix-N 段）"`
- 文件约定表格: `"review.md | op-reviewer + 你 | FAIL 轮你在末尾追加 Fix-N"`

**与 design 的冲突**:

- design §1.1（task 工作区）: `"FAIL 轮 Fix-N 修复说明（不进 review.md）"`
- design §2.4 第 2 步: `"review.md 单写者 = leader，主分支落盘；task 分支对 review.md 的任何变更被 merge gate 白名单 REJECT"`
- design §2.4 review 循环: `"FAIL 轮的 Fix-N 修复说明也追加到 report.md，不进 review.md——review.md 单写者 = leader"`
- design §3.4 merge gate 白名单: `review.md` 明确在黑名单侧，`"task 分支对 review.md 的任何变更被 merge gate 白名单 REJECT"`

**影响**: implementer 若按 agent 提示词写 review.md，merge gate 将直接 REJECT 该 task 分支合并。这是一个结构性错误——design 的意图是 review.md 只有 leader 能在主分支写入，implementer 的所有修复记录（含 Fix-N）全部进 report.md。

**建议**: 将 agent 中所有对 review.md 的写入描述改为 report.md。删除 description 中的 `"在 review.md 追加修改记录"`，改为 `"在 report.md 追加 Fix-N"`。文件约定表格中 review.md 写者列应为 `"op-reviewer（leader 落盘）"`，不是 `"op-reviewer + 你"`。

**置信度**: 高

**优先级**: HIGH

---

### 2. [HIGH] op-evaluator.md — DOM/a11y 信号分类与 design 基线三层模型矛盾

**位置**: `agents/op-evaluator.md` 第 124-126 行（步骤 2 存基准快照）

**现象**: evaluator agent 将 "DOM/a11y tree" 归类为 **结构化/语义信号（硬门主体，可机械断言、零放水）**:

```markdown
- **结构化/语义信号**（硬门主体，可机械断言、零放水）：DOM/a11y tree、stdout/stderr/exit code、...
```

**与 design 的冲突**:

design §2.5 基线三层表明确将 DOM/a11y 归入 **视觉/DOM 层（不进机械硬门，advisory）**:

| 层 | 性质 | 进硬门 | 例子 |
|---|---|---|---|
| 结构化/语义 | 可机械断言 | 硬门主体 | stdout/API/DB/进程/消息 |
| 视觉/DOM | 多模态对照 | 不进机械硬门（advisory） | 截图；DOM/a11y tree——CSS/组件重组/兄弟节点增减触发不匹配且通常非行为回归，advisory 不阻断（D7） |

design §2.5 硬门信号段也明确: `"能拿结构化语义（stdout/API/DB/进程/消息——DOM/a11y 除外，flaky 降 advisory）的优先它进硬门"`。

**影响**: evaluator 若按 agent 提示词将 DOM/a11y snapshot 当作硬门信号，会导致 DOM 结构微小变化（CSS 重构、组件重组、兄弟节点增删）触发机械 FAIL，而这些变化通常非行为回归（design 原意 advisory 不阻断）。这会大幅增加假阳性阻断。

**建议**: 将 "DOM/a11y tree" 从结构化/语义信号列表中移除，归入下方视觉锚点段（或另立一段说明其 advisory 性质）。在 baseline 文件格式说明中标注 `.dom.html` 文件为 advisory 信号（不进机械硬门）。

**置信度**: 高

**优先级**: HIGH

---

### 3. [HIGH] op-implementer.md + op-reviewer.md — tasks_list.json 直接读取与 design 访问隔离冲突

**位置**:
- `agents/op-implementer.md` 第 40 行: `"jq 查 tasks_list.json 取该 task 元数据"`
- `agents/op-reviewer.md` 第 63 行: `"jq 查 tasks_list.json 取 workset"`

**现象**: implementer 和 reviewer agent 都声称要直接 jq 读取 `tasks_list.json`。

**与 design 的冲突**:

design §1.1（task 工作区）: `"tasks_list.json 不挂 agent worktree"`，`"dispatch 时 leader 在 prompt 给指针（TID + spec 路径 + workset/depends_on 由 dispatch 脚本从 tasks_list.json 提取注入，§2.4；tasks_list.json 不挂 agent worktree）"`

design §3.4（角色 × 文件系统视图）: `"流程文件（tasks_list.json / checkpoint / issues / decisions.md / review.md）只在主 worktree 一份物理副本，implementer/evaluator worktree 不挂 op_execution/ + op_record/"`

design §2.4 第 1 步: `"dispatch 脚本从 tasks_list.json 提取注入，agent 不自行 jq 现读——tasks_list.json 不挂给 implementer worktree"`

**影响**: agent 提示词要求的行为与文件系统隔离策略冲突——agent worktree 里根本没有 tasks_list.json。agent 若严格按提示词尝试 jq 读取会失败。这属于提示词承诺了不可用的数据源，会导致 agent 启动时就报错或产生不可预期的行为。

**建议**: implementer agent: 删除 "jq 查 tasks_list.json" 的表述，改为 "读取 dispatch prompt 中注入的 workset 和 depends_on"。reviewer agent: 同样删除 jq 引用，改为 "workset 对照表已在 review-package 中（由脚本生成）"。

**置信度**: 高

**优先级**: HIGH

---

### 4. [HIGH] op-closer.md — feature 归属判断 vs 引用（与 D10 决策矛盾）

**位置**: `agents/op-closer.md` 第 57 行（blueprint 提案模板）、第 119-121 行（输入格式）

**现象**: closer agent 要求 closer **自行判断** feature 归属:

- 第 57 行: `"> feature 归属：{closer 从 task spec 内容判断的功能名——op_blueprint/specs 按功能划分，归属是判断性工作非机械字段}"`
- 第 119 行（输入格式）: `"specs 归属：{closer 从 task spec 判断的功能名}"`

**与 design 的冲突**:

design §2.6（baselines 合入流程）: `"feature_key 闸门 A 阶段确定，入 task spec frontmatter / tasks_list，closer 只能引用不能重新判断，D10"`

design D10 决策明确否定了 closer 自行判断功能归属的做法，要求 feature_key 在闸门 A 阶段就确定好并写入 task 元数据。

**影响**: closer 若自行判断功能归属，可能与闸门 A 阶段的判定不一致，导致 baselines 合入到错误的功能目录、spec 归属混乱。design §5.7 的 lite opspec profile 参数段也强调 `"功能归属（feature_key）闸门 A 阶段入 task spec frontmatter，closer/leader 只引用（D10）"`。

**建议**: 将 closer 模板中的 `"{closer 从 task spec 内容判断的功能名}"` 改为 `"{从 task spec frontmatter / tasks_list 读取的 feature_key}"`，并添加说明 "不自行判断——feature_key 由闸门 A 确定"。输入格式中同样修改。如果 spec frontmatter / tasks_list 中没有 feature_key，应回报 leader 而非自行判断。

**置信度**: 高

**优先级**: HIGH

---

## 中低优先级问题（MEDIUM / LOW）

### 5. [MEDIUM] op-closer.md — decisions.md 追加格式缺少 Round-N 标识

**位置**: `agents/op-closer.md` 第 44-46 行

**现象**: closer 的 decisions.md append 格式为:

```markdown
## {TID} {title}（{ISO 时间}）[red-attribution]
```

**与 design 的对比**:

design §2.6（decisions.md append 协议）: `"每个 append 块头部带机械标识 [来源标记 | TID | Round-N | 日期]——中断/重试/恢复场景按标识判重（同 TID+来源+轮次已存在则跳过）"`

**影响**: 缺少 Round-N 会导致中断/重试/恢复场景下无法判重——系统无法区分同 TID 同来源的多次 append 是否为重复写入。这在 crash 恢复场景下会造成 decisions.md 内容重复。

**建议**: 在 closer 的 append 格式和输入格式中增加 Round-N。例如 `"## {TID} {title}（Round: N, {ISO 时间}）[red-attribution]"`。

**置信度**: 中

**优先级**: MEDIUM

---

### 6. [MEDIUM] op-evaluator.md — 范围外发现写入路径描述不够精确

**位置**: `agents/op-evaluator.md` 第 117 行（步骤 1 第 6 条）

**现象**: evaluator agent 步骤 1 第 6 条写 `"范围外发现 → 落 issues/"`，未说明 evaluator 不能直接写 `issues/` 目录。

**与 design 的对比**:

design §2.5（evaluator 读写权）: `"范围外发现的 issue 草稿——evaluator 不直写 issues/，草稿由 leader 收口时落盘登记并赋 P 级，与 §3.2 落盘者赋 P 级规则一致"`

design §3.2: `"evaluator 范围外发现同走'草稿写 acceptance → leader 收口落盘赋 P'"`

**影响**: evaluator 若按表面含义直接写 `issues/`，绕过了 leader 收口赋 P 级的统一协议。不过 evaluator 的输出模板（`acceptance_report.md`）中包含"范围外发现"段，实际应通过报告反馈给 leader。Agent 文本措辞不够精确可能导致误操作。

**建议**: 将 "落 `issues/`" 改为 "在验收报告中列出范围外发现（含建议 P 级），由 leader 收口时落盘 `issues/`"。对齐 design "草稿 → leader 落盘" 的协议。

**置信度**: 中

**优先级**: MEDIUM

---

### 7. [LOW] op-closer.md — 环境检查未使用两版通用 fallback 模式

**位置**: `agents/op-closer.md` 第 7 行

**现象**: closer 使用 `bash "$OP_HOME/scripts/op_check_env.sh"`，而其他三个 agent 都使用 `${OP_SCRIPT_ROOT:-$OP_HOME}` fallback + `op_script()` resolver 模式。

**与 design 的对比**:

design §5.4: `"仅 closer 保留硬编码 $OP_HOME（heavy 独有，OP_SCRIPT_ROOT 不注入 closer 正确）"`

**影响**: 无功能影响——closer 是 heavy 独有角色，`OP_HOME` 在 heavy 环境始终存在。但从代码一致性角度，与其他三个 agent 的入口模式不统一。design 已明确这是有意为之。

**建议**: 可保留现状，design 已确认这是有意的差异化。若未来 closer 需要支持无 OP_HOME 环境，再改为 fallback 模式。

**置信度**: 高（确认非问题）

**优先级**: LOW（不需修复）

---

### 8. [LOW] op-implementer.md description — "在 review.md 追加修改记录"（与问题 1 同源）

**位置**: `agents/op-implementer.md` frontmatter description

**现象**: description 字段写 `"FAIL 轮修复后在 review.md 追加修改记录"`。此条与问题 1 同源，但 description 是给 leader/调度器看的摘要，含错会误导 dispatch 决策。

**建议**: 改为 `"在 report.md 追加 FAIL 轮修复记录"`。

**置信度**: 高

**优先级**: LOW（合并到问题 1 修复）

---

## 改进建议

### 建议 1: 统一 agent 文件中的状态枚举引用

四个 agent 都涉及 task 状态流转，但散落引用 design §1.1 的状态枚举。建议每个 agent 在相关段显式引用 "状态枚举见 tasks_list.json.status（ASCII 值：pending/ready/in_progress/reviewing/closing/done/suspended/blocked/obsolete）"，确保 agent 不自行发明状态值。

### 建议 2: evaluator agent 补充 cua 固化物 lane 的 CI 行为说明

evaluator 已在步骤 "cua 域固化物 lane 规则" 中标注 `channel: cua` 测试进独立 lane，但未说明 CI/夜跑对这些 lane 的具体处置（开 issue 不阻断）。建议补充一句："CI/夜跑对 cua lane 测试失败开 issue（P2），不阻断流水线"。

### 建议 3: reviewer agent 补充 lite 下 review.md 落盘者说明

reviewer agent 的 "omni_powers 协议适配" 段说 heavy 下 leader 落盘 review.md，lite 下 reviewer 自己写 review.md。但第 63 行的审查流程只说 "写 review.md" 未区分 heavy/lite。建议在审查流程步骤 5 前加 profile 分支说明。

### 建议 4: implementer agent 的 report.md 模板补充 "红灯归因段" 示例

design §2.4（红灯归因协议）要求 implementer 在 report.md 写归因段供 closer 提取。但 implementer agent 的 report.md 模板中没有归因段示例。建议在 "总报告" 节下方加 `"## 归因段（若有）"` 占位说明。

---

## 不确定项 / 可能误报

### 不确定 1: op-implementer.md 的 op_coder_check.sh 引用

`agents/op-implementer.md` 第 33 行引用 `op_coder_check.sh {TID}` 脚本，design §4.1 scripts 列表中未列出 `op_coder_check.sh`。可能是实现层新增脚本但 design 未同步更新，也可能是废弃引用。不确定此脚本当前是否存在。

### 不确定 2: op-reviewer.md 的 leader_checkpoint 读取

reviewer agent 审查流程未提及读取 `leader_checkpoint.md`，但 checkpoint 含跨 task 上下文（当前活跃 spec 等）。不确定 reviewer 是否需要此信息做 scope 判断。当前 design §2.4 未要求 reviewer 读 checkpoint——可能是设计意图（reviewer 只看单 task 的 spec + diff）。
