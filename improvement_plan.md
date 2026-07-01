# omni_powers 宏观改进计划

> 范围：收口拆分（机械/判断分层）、DAG 并行执行、中英状态映射清理。
> 三项相互独立，可单独落地。按风险从低到高排序：C（映射）< A（收口）< B（并行）。

---

## A. 收口拆分：机械步骤脚本化，判断步骤留 agent

### 现状

op-closer（单 agent）扛 6 步：spec 盖戳 + git mv 归档 + 改 status + 整理 blueprint + tech_debt/progress/decisions + git add。
机械步骤占 5/7，却全靠 LLM 自律执行——存在漏 git add、状态值写错、归档漏文件的风险。

### 步骤分类

| 步 | 内容 | 性质 | 归属 |
|---|---|---|---|
| 1 | spec 盖戳（固定文案） | 机械 | 脚本 |
| 2 | git mv 工作区→归档 | 机械 | 脚本（须放最后） |
| 3 | status=完成 | 机械 | 脚本（复用 op_status.sh） |
| 4 | 整理 blueprint 相关文档 | **判断** | agent |
| 5a | tech_debt 追加 | 半判断 | agent（脚本仅占位兜底） |
| 5b | progress 追加 | 半机械 | 脚本（模板填充） |
| 5c | decisions 追加 | **判断** | agent |
| 6 | git add 指定目录 | 机械 | 脚本 |

### 顺序依赖（关键）

agent 整理 blueprint（4）要读**未归档**的 task 工作区（spec/context）。
若先 git mv（2）走，路径失效。故 **mv 必须在 agent 之后**。新顺序：

```
1. 脚本 op_close_pre.sh {TID}    → 盖戳 + status=收口中
2. agent op-closer               → 整理 blueprint + tech_debt + decisions（读未归档工作区）
3. 脚本 op_close_post.sh {TID} {feature} → git mv 归档 + progress 行 + status=完成 + git add
4. leader                        → commit + op-checkpoint.sh + close_check.sh
```

### 改动文件

- **新建** `scripts/op_close_pre.sh {TID}`
  - spec.md 顶部插入盖戳文案（"历史快照，以 op_blueprint/specs/ 为准"）
  - `op_status.sh {TID} 收口中`
  - 幂等：已盖戳则跳过
- **新建** `scripts/op_close_post.sh {TID} {feature}`
  - `git mv docs/.../op_execution/tasks/{TID} docs/.../op_record/tasks/{TID}`
  - progress.md 追加一行（模板：`- {TID} {title} | {date} | {commit 待 leader 填}`）
  - `op_status.sh {TID} 完成`
  - `git add op_execution/ op_record/ op_blueprint/`
  - 前置校验：归档前确认 review_*.md 三件存在且末行 verdict=PASS，否则 die
- **改** `agents/op-closer.md`
  - 删除机械步骤（盖戳/mv/改status/add）描述
  - 只保留：整理 blueprint、tech_debt 内容判断、decisions 判断
  - 明确"不碰 git、不改 status、不归档"
- **改** `skills/op-start/SKILL.md` 子步骤 3.5
  - 收口序列改为 pre 脚本 → agent → post 脚本 → commit
  - dispatch prompt 精简（去掉机械步骤交代）
- **改** `RULES.md` 角色表 op-closer 行 + 文件分层"闭环整理"段
  - op-closer 职责改为纯判断
  - 新增脚本层说明

### 验证

- 跑一个真实 task 收口：pre→agent→post 全链
- `close_check.sh {TID}` 通过（盖戳/归档六件/tech_debt 段/checkpoint）
- 故意制造 review FAIL 残留，确认 post 脚本 die 拦截
- agent prompt 不再出现 git/mv/status 字样

### 风险

- post 脚本 die 后状态停在"收口中"，需 leader 介入——可接受，比静默归档错误好。
- progress 行的 commit hash 此刻未知（commit 在步骤 4）。方案：post 写占位，op-checkpoint.sh 回填；或 progress 行只记 task 不记 hash（hash 已在 checkpoint）。**推荐后者**，避免回填复杂度。

---

## B. DAG 并行执行：同层无依赖 task 并发

### 现状

`dag_gen.sh` 算了拓扑分层，但 op-start 循环 3.1 每轮只选 **ID 最小的一个** task 串行跑。
分层结果只用于画图，并行能力闲置。大项目线性慢。

### 核心约束（决定方案复杂度）

worktree 模式**全 session 共用一个工作目录**。多个 coder 同时改同一目录的代码 → 必然冲突。
真正的执行并行要求**每个并行 task 各自隔离的 worktree + 分支**，最后按依赖顺序 merge。这是结构性改动，不是循环改几行能解决。

### 分阶段方案

**阶段 1（低风险，先做）：spec/plan 生成并行**
- 仅并行"待规划 → 待开始"的 spec/plan 生成（op-task 快速模式已支持子代理并发）。
- 此阶段只写 task 工作区文档，**不碰代码**，无 git 冲突。
- 收益：批量 task 的规划阶段提速，零冲突风险。
- 改动：op-task 快速模式已具备，补充 op-start 入口在发现多个"待规划"时建议批量生成。

**阶段 2（高风险，按需做）：coder 执行并行**
- 选 task 改为"选当前可跑层的全部 task"（depends_on 全完成、不在阻塞范围）。
- 每个并行 task：`Agent({ isolation: "worktree" })` 独立 worktree + 独立分支。
- review 仍后台并行（本就隔离，无碍）。
- **收口串行化**：merge 必须按依赖拓扑序逐个进行，持 tasks_list.json 的 flock（op_status.sh 已有锁）。
- merge 冲突处理：后 merge 的 task 若与已 merge 的冲突 → 该 task 回 fail 轮（在最新 base 上重跑），不直接阻塞。

### 改动文件（阶段 2）

- **改** `skills/op-start/SKILL.md`
  - 3.1 选 task：单个 → 一层（返回可跑 TID 列表）
  - 循环结构：派 N 个 coder（各自 worktree）→ 各自 review → 按拓扑序逐个收口 merge
- **新建** `skills/op-start/scripts/op-ready-layer.sh`
  - 输出当前可跑层的全部 TID（而非 op_jq pending 的全集）
  - 排除：依赖未完成、阻塞范围、已在进行中
- **改** `RULES.md`
  - 工作区段：补充并行 worktree 隔离规则 + 收口串行 merge 规则
  - "不做"段：原"中间状态不 commit"在并行下需细化（各 worktree 内可 commit，merge 点串行）

### 验证

- 造 3 个无依赖 task，确认 3 个 worktree 并发跑、互不干扰
- 造 A→B→C 链 + 旁支 D，确认 D 与 A 并行、B 等 A
- 制造 merge 冲突，确认冲突 task 回 fail 轮而非阻塞

### 风险与建议

- 阶段 2 复杂度高（worktree 生命周期、merge 序、冲突回退）。**建议先只做阶段 1**，阶段 2 等阶段 1 验证稳定、确有大批量并行需求时再上。
- 并行度上限按 CPU 核数或固定值（如 4），避免 worktree 爆炸。

---

## C. 中英状态映射清理

### 现状

- tasks_list.json 用**中文** status（待规划/待开始/...）
- 所有脚本（op_status/op_jq/dag_gen/checkpoint/close_check）全用**中文**比较
- RULES.md 维护一张中英映射表（45-58 行）+ 状态机图，声称给"compact 恢复、跨文档引用"用

### 判断

英文映射表是**孤儿**——没有任何脚本或文档真正消费英文值，全链路是中文。
映射表只增加维护负担和歧义（两套术语指同一状态）。

### 两个选项

| 选项 | 改动面 | 成本 |
|---|---|---|
| **C1：删英文，全中文**（推荐） | 仅删 RULES.md 映射表 + 状态机图统一中文 | 极低，零脚本改动 |
| C2：全英文 enum | 改 tasks_list 数据 + 6 个脚本所有比较 + 全部 SKILL.md 引用 + 数据迁移 | 高，机械但易漏 |

C2 收益（英文更规范）不抵改动风险。**选 C1**。

### 改动文件（C1）

- **改** `RULES.md`
  - 删除 45-58 行"英文/中文映射"整段
  - 状态机 ASCII 图：确认全用中文（当前已是中文，仅删英文注解）
  - 全文搜索 pending/coding/reviewing 等英文 status 词，替换为中文或删除
- 其他文件：搜索确认无英文 status 残留引用

### 验证

- `grep -rE 'pending|coding|reviewing|closing|blocked|skipped|suspended' RULES.md skills/ agents/` → 仅剩 blocked_by 的值（key/quality/spawn 等，与 status 无关），无 status 英文词
- 脚本零改动，跑一遍现有流程确认无回归

---

## D. 外部 CLI reviewer 异构（暂不做）

### 设想

把三个 reviewer 之一（首选 op-code-reviewer）换成调 codex cli / antigravity cli，用
**异构模型抓 Claude 自己的盲区**（council 思路）。coder/closer/leader 全部不动。

### 为何架构可行

本系统核心心智「磁盘是真状态，agent 上下文是可重建缓存，每次 fresh dispatch」本就
**进程无关**。外部 CLI 只要守两个契约即可替换任何 sub agent：
1. 读写同一 `work_dir` 下文件（spec/plan/context/review）
2. review 文件末行 `verdict: PASS|FAIL`

`op-read-verdict.sh` 只认文件末行 verdict，**不关心是谁写的**——编排逻辑 3.3/3.4 几乎不变。

### 为何暂时不做

| 维度 | 当前 Task sub agent | 换外部 CLI 后 |
|---|---|---|
| 返回值 | 结构化，leader 直接拿 | 退化成 Bash 解析 stdout/exit |
| 并行 review | `background:true` 原生 | 靠 `run_in_background`+轮询文件 |
| verdict 纪律 | prompt 直控末行格式 | CLI 不保证末行，需适配器 grep 兜底补写 |
| 可观测/重试 | Task 内可见 | 黑盒，调试难 |

- coder/closer 是机械流程（TDD、git mv、状态流转），换 CLI **收益≈0，复杂度大涨**。
  仅 reviewer 受益于模型多样性。
- 价值未验证：异构 reviewer 实际能否抓到 Claude reviewer 漏的问题，需真实对比才知道。
- 引入跨厂商 CLI 调用语法适配、verdict 格式翻车兜底、轮询编排，复杂度增量明显。

### 启动前提（确有需求时再做）

1. 探明 `codex` / `antigravity` CLI 的非交互单次执行语法（读 prompt 文件方式）
2. 新建「外部 CLI reviewer 适配器」脚本：输入 work_dir+TID+review 类型 → 调 CLI →
   写 `review_{type}.md`，**适配器兜底补写末行 verdict**
3. 把 `agents/op-code-reviewer.md` 的 system prompt 转成传给 CLI 的 instruction 文件
4. **只换一个** reviewer 试水，对比「异构抓到的问题 vs Claude 漏的 / verdict 翻车率 /
   编排复杂度增量」，值了再扩到三个

### 结论

**暂不做。** 等系统跑稳、确有「Claude reviewer 盲区导致质量问题」的实证后，再按上述前提
小步试水单个 reviewer。优先级低于 A/B/C。

---

## 落地顺序建议

1. **C1**（映射清理）——最快，清理认知负担，无回归风险
2. **A**（收口拆分）——中等，提升收口确定性
3. **B 阶段 1**（规划并行）——低风险提速
4. **B 阶段 2**（执行并行）——按需，最后做

A 与 C 完全独立可并行改。B 依赖 A 落地后的收口流程更清晰，建议 A 后做。

---

# 远期规划（暂不做，记录待办）

> 本段不在当前迭代范围。需要做，但排在 A/B/C 之后。

## D. init 双模式：嵌入 / 覆盖

### 动机

当前 op-init 是**强制覆盖**——把用户原有 md 全 mv 进 docs/archive，重新生成 blueprint。
对已有成熟文档体系的项目过于侵入。需要一个非破坏性的接入方式。

### D1. 嵌入模式（embed，新增，推荐默认）

不动用户原本文档结构。只在用户 `docs/` 下新建 `omni_powers/`，仅放工作流自有的两层：

```
docs/
├── {用户原有文档，原样不动}
└── omni_powers/
    ├── op_execution/   # 工作区（tasks_list/task 工作区/tech_debt/checkpoint/dag）
    └── op_record/      # 历史（progress/decisions/归档 task）
```

关键：**不建 op_blueprint/**。所有"读/更新 blueprint"的地方改为指向**用户原本的文档**。

- 需要一个 **blueprint 映射配置**（如 `docs/omni_powers/blueprint_map.yaml`），声明：
  - prd → 用户哪个文件
  - architecture → 用户哪个文件
  - domain / conventions / specs → 用户哪个文件或目录
- op-closer 的"整理 blueprint"步骤改为按映射写入用户文档（需更谨慎，因为是用户的真相源）。
- 无映射的 blueprint 类别：要么跳过，要么提示用户补映射。

### D2. 覆盖模式（overlay，即现有 op-init 行为）

保留当前逻辑：原文档 → docs/archive，强制整理成本项目规范结构（含 op_blueprint/）。
适合新项目或愿意全面迁移的项目。

### 模式选择

op-init 启动时问用户：

```
/opinit

接入方式？
1. 嵌入（推荐）：不动你现有文档，只加 omni_powers 工作区，blueprint 指向你的文档
2. 覆盖：现有文档归档到 docs/archive，重建标准结构
```

### 影响面（大）

- **所有引用 op_blueprint/ 的硬编码路径**需改为"按模式解析"：
  - RULES.md 文件分层段、闭环整理段
  - op-closer（整理 blueprint）
  - op-generate-spec / op-generate-plan（读 prd/architecture/domain 作 ref）
  - op-task（读 ref 文档）
- 引入路径解析层：一个函数/脚本 `resolve_blueprint.sh {category}` → 按当前模式返回实际路径（覆盖模式返回 op_blueprint/xxx，嵌入模式查 blueprint_map.yaml）。
- 模式状态需持久化（如 `docs/omni_powers/.mode`），所有 skill 启动时读。

### 风险

- 嵌入模式下 op-closer 写用户真相源文档，错误成本高于覆盖模式。需更强的 diff 预览/确认机制。
- blueprint_map.yaml 缺项或用户文档结构变化 → 路径解析失败。需兜底与校验。

---

## E. skill 命名去连字符（需要做）

### 动机

当前 skill 名带连字符：op-start / op-init / op-task / op-generate-spec / op-generate-plan / op-debt2tasks。
用户希望**输入三个字母即可定位**，去掉中间 `-`。

### 命名映射

| 现名 | 新名 | 三字母定位 |
|---|---|---|
| op-start | opstart | ops |
| op-init | opinit | opi |
| op-task | optask | opt |
| op-generate-spec | opspec | ops... |
| op-generate-plan | opplan | opp |
| op-debt2tasks | opdebt（建议，原 debt2tasks 太长） | opd |

> 注：opstart 和 opspec 都以 ops 开头，三字母不唯一。建议定位用 4 字母（opst / opsp）或接受补全列表。命名时确认无前缀歧义。

### 改动面

- **目录重命名**：`skills/op-start/` → `skills/opstart/` 等 6 个。
- **每个 SKILL.md 的 `name:` frontmatter** 同步改。
- **所有交叉引用**：
  - SKILL.md 之间互相 `Skill("op-generate-spec")` 调用 → 改新名
  - RULES.md 中的 skill 路径引用
  - op-start/SKILL.md 末尾相关文件表
  - scripts 路径 `skills/op-start/scripts/` → `skills/opstart/scripts/`（脚本内部硬编码路径也要改）
  - CLAUDE.md 项目说明中的 skill 列表
- **install.sh / SessionStart hook** 若引用 skill 路径，同步改。
- description 中的触发词（如"触发：/op-start"）改为新触发词。

### 验证

- `grep -rE 'op-start|op-init|op-task|op-generate-spec|op-generate-plan|op-debt2tasks' .` → 清零（除 git 历史/归档快照）
- 每个 skill 用三/四字母触发能正确加载
- 全链路跑一遍（opinit → optask → opstart → 收口）确认调用链无断裂

### 风险

- 引用点分散（SKILL/RULES/CLAUDE/scripts/install），易漏。需一次性全局替换 + grep 兜底校验。
- 与 D 有路径耦合：若 D 和 E 同期做，先 E（改名）再 D（改路径解析），避免在旧名上建解析层。

---

## F. 全面参数化：模型 + 目录结构走环境变量（暂不做）

### 动机

当前两类硬编码散落全协议，用户无法定制：

1. **每个 agent 用什么模型**——op-start dispatch 里写死 `model: "haiku"` / `"sonnet"`。
2. **规范目录名**——`op_execution` / `op_record` / `op_blueprint` 等硬编码在所有脚本和文档。

目标：用户通过环境变量/配置文件统一设置，无需改协议源码。

### F1. 模型参数化

每个角色的模型可配，且支持**外部 CLI 后端**（不止 Claude 模型）：

| 变量 | 默认 | 说明 |
|---|---|---|
| `OP_MODEL_CODER` | haiku | coder 模型，可设 opus/sonnet |
| `OP_MODEL_REVIEWER` | sonnet | 三个 reviewer 模型 |
| `OP_MODEL_CLOSER` | haiku | closer 模型 |
| `OP_CODER_BACKEND` | claude | 后端类型：claude / codex / 其他外部 CLI |

- **claude 后端**：现有 `Agent({ model: $OP_MODEL_CODER })` 路径。
- **外部 CLI 后端**（如 codex cli）：coder 步骤改为 shell 调用外部工具，传 spec/plan 路径，约定输出落盘格式（代码 + context.md）。需定义**适配层契约**：输入（task 工作区路径）、输出（改动文件 + 摘要写回）、退出码语义。
- dispatch 逻辑改为：读 backend → claude 走 Agent，外部走 `op_invoke_backend.sh {role} {TID}`。

### F2. 目录名参数化

所有规范目录走变量，用户可改名（如 op_execution → op_work）：

| 变量 | 默认 |
|---|---|
| `OP_DIR_ROOT` | docs/omni_powers |
| `OP_DIR_EXECUTION` | op_execution |
| `OP_DIR_RECORD` | op_record |
| `OP_DIR_BLUEPRINT` | op_blueprint |

> 注：op-init 的 SKILL 已出现 `$OMNI_POWERS_DIR_BLUEPRINT` / `$OMNI_POWERS_DIR_TASKS` 等变量雏形——说明方向已埋点，但脚本（op_status/op_jq/dag_gen/checkpoint/close_check）和其他 SKILL 仍硬编码全路径。F2 是把这套变量**贯通全链路**。

### 配置载入

- 单一配置源：`docs/omni_powers/op_config.sh`（或 .env），所有脚本开头 source。
- 所有脚本把硬编码路径 `docs/omni_powers/op_execution/...` 改为 `$OP_DIR_ROOT/$OP_DIR_EXECUTION/...`。
- SKILL.md 中的路径用占位符 + 启动时声明"路径以 op_config 为准"。
- 提供 `op_config.sh.example` + 校验脚本（变量齐全、目录存在）。

### 影响面（最大，全协议）

- 6 个脚本全部改路径引用 → 走变量。
- 全部 SKILL.md 的路径与 model 引用 → 走变量/占位符。
- RULES.md 文件分层表、角色表 model 列 → 改为"见 op_config"。
- 与 D（双模式）强耦合：D 的路径解析层应直接构建在 F2 的变量体系上，而非另起一套。**D 和 F2 应合并设计。**
- 与 E（改名）正交，可独立。

### 风险

- 变量贯通是大面积机械改动，易漏一处导致路径错乱。需 grep 兜底 + 全链路回归。
- 外部 CLI 后端（F1）契约设计是新工作量，非纯参数化——建议 F1 拆为独立子项，先做 F2（纯路径变量），F1 后做。
- 默认值必须与现状完全一致，保证不配置时零行为变化（向后兼容）。

### 与其他远期项的关系

- **F2 ⊃ D 的路径需求**：先定 F2 变量体系，D 在其上加"嵌入模式映射"分支。
- **F1 与 B（并行）**：外部 CLI 后端 + worktree 并行叠加复杂度高，不要同期上。

