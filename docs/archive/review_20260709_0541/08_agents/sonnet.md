# Sonnet 审阅报告：模块 08_agents

## 当前模型判断依据

- `/home/karon/.claude/settings.json` 顶层 `model=haiku`
- `env.ANTHROPIC_MODEL=default_model`
- `ANTHROPIC_DEFAULT_SONNET_MODEL=default_sonnet`
- 主会话环境提示当前由 `default_model` 驱动
- 本审阅以 `default_sonnet` 身份独立判断，不参考 haiku/opus/fable 路审阅

## 审阅范围

| 文件 | 路径 |
|---|---|
| op-closer | `/home/karon/karson_ubuntu/omni_powers/agents/op-closer.md` |
| op-evaluator | `/home/karon/karson_ubuntu/omni_powers/agents/op-evaluator.md` |
| op-implementer | `/home/karon/karson_ubuntu/omni_powers/agents/op-implementer.md` |
| op-reviewer | `/home/karon/karson_ubuntu/omni_powers/agents/op-reviewer.md` |

对照基准：`docs/omni_powers_design.md`（作为上下文，不重复审阅）。

---

## 高优先级问题（CRITICAL / HIGH）

### CRITICAL-1: op-implementer.md 内部自相矛盾 —— review.md 写入权归属冲突

- **位置**：`agents/op-implementer.md` 第 113 行 vs 第 23、54 行
- **现象**：
  - 第 23 行（核心规则 #5）明确 "不写 review.md（单写者=leader，design §1.1/§2.4）"
  - 第 54 行（FAIL 轮流程）再次强调 "不写 review.md（单写者=leader）"
  - **第 113 行**（收到 review 反馈时的处理）却写 "不合理 → 在 review.md 追加'此项不改因为 Y'，附技术理由"
- **影响**：implementer 收到此提示后会尝试写 review.md。在 heavy 模式下 review.md 单写者是 leader（merge gate 白名单 REJECT implementer 对 review.md 的任何变更）；在 lite 模式下 implementer 直写 review.md 会破坏单写者协议，且与自身规则矛盾。implementer 的反驳理由本应写入 `report.md` 的对应 Round 段，而非 review.md。
- **建议**：将第 113 行改为 "不合理 → 在 **report.md** 当前 Round 段追加'此项不改因为 Y'，附技术理由"。与第 54 行 FAIL 轮格式 `已改 X / 此项不改因为 Y / review 判断有误因为 Z` 保持一致。
- **置信度**：高（文本明确自相矛盾）
- **优先级**：CRITICAL

### HIGH-1: op-implementer.md FAIL 轮假定能读 review.md，与 heavy 模式 worktree 挂载范围冲突

- **位置**：`agents/op-implementer.md` 第 50 行
- **现象**：FAIL 轮流程第 1 步为 "读 review.md 正文 + git diff 了解当前改动"。Design §3.4 明确：流程文件（含 review.md）"只在主 worktree 一份物理副本"，implementer worktree 挂载 `tasks/{TID}/` 仅用于写 report.md，"不含 review.md——review.md 单写者 = leader，主分支落盘"。在 heavy 模式下 implementer worktree 物理上没有 review.md。
- **影响**：heavy 模式下 implementer 进入 FAIL 轮后无法执行第一步，工作流卡住。lite 模式下无此问题（主分支直改，review.md 可读）。
- **建议**：增加 profile 分支。heavy 下改为 "读 leader dispatch prompt 中注入的 review 反馈摘要（review.md 不挂你的 worktree）"；lite 下保持 "读 review.md 正文"。
- **置信度**：高（design §3.4 明确声明 review.md 不挂 implementer worktree）
- **优先级**：HIGH

### HIGH-2: op-evaluator.md 范围外发现输出文件路径不一致（eval.md vs acceptance_report.md）

- **位置**：`agents/op-evaluator.md` 第 117 行 vs 第 149 行
- **现象**：
  - 第 117 行（步骤 1 评估）：范围外发现 "写入 `acceptance/{TID}/eval.md` 范围外发现段（草稿）"
  - 第 149 行（输出）：主验收报告写入 `docs/omni_powers/op_execution/acceptance/{TID}/acceptance_report.md`，且报告模板（第 174 行）已包含「范围外发现（落 issues）」段
  - `eval.md` 与 `acceptance_report.md` 职责重叠——前者标为"草稿"，后者也有同名段。closer（op-closer.md 第 35 行）只读 `acceptance_report.md`，不知 `eval.md` 存在。
- **影响**：evaluator 可能将范围外发现写入 `eval.md`，而 closer 读 `acceptance_report.md` 漏掉范围外发现，导致问题丢失。或者 evaluator 两边都写，造成重复/不一致。
- **建议**：二选一。(A) 删除 `eval.md`，范围外发现统一写入 `acceptance_report.md` 的「范围外发现」段；closer 从此处提取。(B) 保留 `eval.md` 作为详细草稿，`acceptance_report.md` 的「范围外发现」段改为摘要+指针。推荐 A——减少文件数，消除歧义。
- **置信度**：高（两处文本明确指向不同文件名）
- **优先级**：HIGH

### HIGH-3: op-closer.md 引用的验收报告文件名未与 evaluator 对齐

- **位置**：`agents/op-closer.md` 第 35 行
- **现象**：closer 读 "验收报告 `op_execution/acceptance/{TID}/acceptance_report.md`"，但未声明此文件由 evaluator 产出、closer 不做存在性校验。若 evaluator 验收 FAIL（未产报告）或写了不同文件名（见 HIGH-2），closer 会静默失败。
- **影响**：closer 找不到验收报告时行为未定义。当前提示词没有"文件缺失则回报 leader"的防御逻辑。
- **建议**：在 closer 步骤 1 增加防御："若 `acceptance_report.md` 不存在，回报 leader '验收报告缺失，收口中止'，不继续。"
- **置信度**：中（依赖链断裂场景概率低但后果重——收口提案缺少验收结果）
- **优先级**：HIGH

---

## 中低优先级问题（MEDIUM / LOW）

### MEDIUM-1: op-reviewer.md heavy 模式下的只读立场与 tools 列表存在张力

- **位置**：`agents/op-reviewer.md` 第 21 行 + frontmatter `tools:` 字段
- **现象**：reviewer frontmatter 声明 `tools: [Read, Write, Edit, Bash, Grep, Glob]`，但 heavy 模式下 reviewer "无 checkout、不需要工作目录"、"由 leader 落盘 review.md（你一般不直接 Write）"。`Bash` 和 `Write`/`Edit` 在 heavy 模式下无合法用途，但仍可用。
- **影响**：reviewer 在 heavy 模式下若误解指令自行 Write 文件，可能写错位置（没有工作目录，路径解析不确定）。
- **建议**：在 heavy 分支流程中显式声明 "heavy 下禁用 Write/Edit/Bash——你只读 review-package，结论写入返回文本末行"。tools 列表无法按 profile 动态裁剪（Claude Code 限制），故需在提示词内补强约束。
- **置信度**：中（reviewer 主动写文件概率低，但约束不完整）
- **优先级**：MEDIUM

### MEDIUM-2: op-closer.md 拥有 Bash 工具但设计明确禁止跑脚本

- **位置**：`agents/op-closer.md` frontmatter `tools:` + 第 110 行 "不跑脚本"
- **现象**：closer tools 包含 `Bash`，但铁律/权限清单（第 15-20 行）和"你不管"段（第 107-114 行）都明确 closer 不跑脚本、不碰 git、不 stage。`Bash` 工具的存在为越界操作留了通道（closer 在主 worktree 完整 checkout，物理能执行任意命令）。
- **影响**：虽然有 `op_closer_gate.sh`（leader 跑）做事后机械校验，但 closer 在 gate 运行前已可执行任意 Bash。closer 是四角色中"权限最大约束最少"的角色（design §2.6 原话），Bash 工具与"不跑脚本"的约束存在张力。
- **建议**：如 Claude Code 支持，考虑从 closer tools 中移除 `Bash`。若工具列表因平台限制无法裁剪，至少在提示词中增加 "禁止使用 Bash 工具——你的全部操作限定于 Read/Write/Edit/Grep/Glob；使用 Bash 将被 closer gate 检测并撤销"。
- **置信度**：中（closer gate 提供事后补救，但预防优于补救）
- **优先级**：MEDIUM

### MEDIUM-3: op-evaluator.md 写权白名单靠提示词约束，无机械强制

- **位置**：`agents/op-evaluator.md` 第 27 行
- **现象**：evaluator 声明"写权白名单：只写 `e2e/` + `op_execution/acceptance/{TID}/`，其余禁止写（尤其 `op_blueprint/`）"。但 tools 列表包含 `Write` 和 `Edit`，可写 worktree 内任意路径。Design §0.1 承认 sparse-checkout 是 advisory 级别（防无意耦合），写权约束全靠提示词纪律。
- **影响**：evaluator 若误解指令或产生幻觉，可能写 `op_blueprint/` 或 `src/`（lite 模式下 worktree 无隔离，此风险更高）。heavy 模式下 merge gate 最终拦截，lite 模式无此防线。
- **建议**：当前约束对 heavy 模式可接受（merge gate 兜底）。lite 模式需在 evaluator.md 的 lite 分支中强化写权警告，并在 oplrun 收口前加 `git diff -- op_blueprint/` 检查（已部分覆盖于 A19 spec 写保护机械校验）。
- **置信度**：中
- **优先级**：MEDIUM

### LOW-1: op-implementer.md 第 40 行 "不 jq 读 tasks_list.json" 的表述缺失 profile 上下文

- **位置**：`agents/op-implementer.md` 第 40 行
- **现象**："不 jq 读 tasks_list.json（不挂你 worktree，design §1.1/§2.4）"——括号内的理由仅适用于 heavy 模式。lite 模式下 implementer 在主 worktree 工作，tasks_list.json 物理可读。指令仍然正确（leader dispatch prompt 已注入 workset/depends_on，implementer 无需读 tasks_list），但理由用词（"不挂你 worktree"）在 lite 下不准确。
- **影响**：lite 模式下 implementer 可能困惑"明明文件在，为什么说不挂"。
- **建议**：改为 "不 jq 读 tasks_list.json（leader dispatch 已注入 workset/depends_on；无需自行读取）"——理由与模式无关。
- **置信度**：高（文本可改进但不造成功能错误）
- **优先级**：LOW

### LOW-2: op-reviewer.md 第 64 行 report.md 路径在 heavy 模式下的可达性存疑

- **位置**：`agents/op-reviewer.md` 第 64 行
- **现象**：review 流程第 2 步 "读 `docs/omni_powers/op_execution/tasks/{TID}/report.md`"。heavy 模式下 reviewer 无 checkout，report.md 应来自 review-package（脚本打包注入），而非 reviewer 自行 Read 文件系统路径。当前写法暗示 reviewer 可自行 Read，与 heavy 模式的实际交付方式不一致。
- **影响**：若 reviewer 尝试自行 Read 而 review-package 已包含 report 内容，可能重复读取但不会出错。问题是新 reviewer 实例可能不清楚 review-package 已包含这些文件。
- **建议**：在 heavy 分支明确 "review-package 已包含 report.md 全文，直接从 package 读取，不自行 Read 文件系统"。
- **置信度**：中（功能不阻塞但指令不够精确）
- **优先级**：LOW

### LOW-3: op-evaluator.md lite 分支的提示词级隔离约束与实际 tools 权限不匹配

- **位置**：`agents/op-evaluator.md` 第 19 行
- **现象**：lite 分支声明 "禁止主动 Read `src/**` 与 task 目录的实现细节，E2E 期望只能从 spec 推导"，并自评 "是 lite 唯一防线，弱于 heavy 结构隔离，无法机械拦截有意规避"。此声明诚实，但 `Grep` 和 `Glob` 工具同样可触及 src/——提示词只禁了 Read，未提 Grep/Glob。
- **影响**：evaluator 可能用 Grep 搜索 src/ 下的实现细节（如函数名、错误消息字符串）来"推导"E2E 期望，虽然不如直接 Read 完整，但仍构成信息泄漏。
- **建议**：lite 分支约束扩展为 "禁止主动 Read/Grep/Glob `src/**` 与 task 目录的实现细节"。
- **置信度**：中（Grep 搜实现细节是现实风险）
- **优先级**：LOW

### LOW-4: op-closer.md 步骤 1 验收报告引用缺少存在性校验逻辑

- **位置**：`agents/op-closer.md` 第 35 行
- **现象**：同 HIGH-3，此处作为 LOW 补充——即便文件存在，closer 也未校验 `acceptance_report.md` 的内容完整性（验收标准是否全部 PASS、是否有 FAIL 未修复）。当前 closer 信任"验收已 PASS"的前提（leader dispatch 时声明），但如果 leader 误派（验收实际未 PASS），closer 会基于不完整数据产提案。
- **影响**：低概率场景（leader dispatch 逻辑已有验收 PASS 前置检查），但缺少 defense-in-depth。
- **建议**：步骤 1 增加快速 sanity check："确认 acceptance_report.md 中验收结果表无 FAIL 行；若有，回报 leader 不继续"。
- **置信度**：低（leader dispatch 前置已覆盖，此检查属 defense-in-depth）
- **优先级**：LOW

---

## 改进建议

1. **统一 implementer 对 review 反馈的写入目标**：将 implementer.md 所有"写在 review.md"的残留引用收敛为 report.md。涉及行：第 113 行。

2. **为 heavy 模式下的 implementer FAIL 轮增加 review 反馈注入机制**：当前 implementer.md 假设能直接读 review.md（第 50 行）。heavy 模式需在 dispatch prompt 中注入 review 反馈摘要，或让 implementer 通过 `op_script()` 调用脚本读取 leader 提供的反馈文件。

3. **统一 evaluator 输出文件**：删除 `eval.md`，范围外发现全部进入 `acceptance_report.md`，消除 closer 漏读风险。

4. **closer 增加防御性校验**：读验收报告前检查文件存在性 + 快速扫 FAIL 行。提升收口可靠性。

5. **tools 列表与角色权限对齐审查**：
   - closer：评估是否可移除 `Bash`（或加强提示词约束）
   - reviewer（heavy）：评估 `Write`/`Edit`/`Bash` 的必要性
   - evaluator（lite）：`Grep`/`Glob` 约束补全

6. **profile 分支措辞统一**：三执行 agent（implementer/reviewer/evaluator）的"不挂你 worktree"等 heavy 特化理由，在 lite 模式下替换为模式无关的理由（如"leader dispatch 已注入"）。

---

## 不确定项 / 可能误报

1. **CRITICAL-1（第 113 行 review.md 写入）**：存在一种解读——第 113 行的"在 review.md 追加"是指 implementer 在 FAIL 轮的 report.md Round 段中记录反驳理由，措辞用了 review.md 是笔误。若是笔误，优先级降为 LOW。**从上下文判断（第 23/54 行反复强调不写 review.md）大概率是笔误。**

2. **HIGH-1（FAIL 轮读 review.md）**：如果 leader dispatch 时已将 review.md 的内容摘要注入 prompt（类似 workset/depends_on 注入），则 implementer 无需文件系统访问。但当前 agent 提示词未描述此机制，需确认 oprun/oplrun 的 dispatch 脚本是否已做此注入。

3. **MEDIUM-2（closer Bash 工具）**：如果 Claude Code 的 tools 列表不支持按 agent 角色裁剪（所有 agent 共享同一 tools 枚举），则此条为平台限制，非 agent 提示词缺陷。优先级降为 LOW，但提示词内约束仍需补强。

4. **LOW-2（reviewer heavy 下读 report.md）**：如果 review-package 生成脚本已把 report.md 内容内联进 package 文件，reviewer 读 package 即可——此时 reviewer 提示词中"读 report.md"指读 package 内的 report 段。当前措辞不够精确但实际工作流可能不受影响。
