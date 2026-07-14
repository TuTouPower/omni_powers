# Sonnet 审阅报告：lite skills/scripts 分块

## 当前模型判断依据

- 可观测来源：主会话 `powered by default_sonnet`（默认档位 sonnet = default_sonnet[1m]）；`model_override_authorized` 已授权调用 sonnet 视角。
- 本报告以 sonnet 独立判断撰写，不调用其他 Agent。

## 审阅范围

- `skills/oplinit/SKILL.md` + `scripts/oplinit_skeleton.sh` + `scripts/op_check_env.sh`
- `skills/oplintake/SKILL.md` + `scripts/op_check_env.sh`
- `skills/oplrun/SKILL.md` + `scripts/close_check.sh` + `scripts/op_assemble_eval_brief.sh` + `scripts/op_check_env.sh` + `scripts/op_check_p0.sh` + `scripts/op_close_post.sh` + `scripts/op_coder_check.sh` + `scripts/op_jq.sh` + `scripts/op_read_verdict.sh` + `scripts/op_status.sh`

核心参考：`docs/omni_powers_design.md`（全文，重点 §5 lite 模式）。

---

## 高优先级问题

### 1. op_close_post.sh 传入中文「完成」给 op_status.sh，导致收口步骤必现失败

- **位置**：`skills/oplrun/scripts/op_close_post.sh` 第 55 行
- **现象**：代码为 `bash "$SCRIPT_DIR/op_status.sh" "$TID" 完成`，传入中文 `完成`。但 `op_status.sh` 的 case 语句只接受 ASCII 枚举（`pending|ready|in_progress|reviewing|done|blocked|obsolete|suspended`），传入 `完成` 落入 `*) die "无效 status: $status…"` 分支，脚本 exit 非 0。`op_close_post.sh` 用 `|| die` 链接，因此整个收口步骤失败。
- **影响**：**per-task 收口永远无法完成**——review PASS、evaluator PASS 之后，`op_close_post.sh` 在更新状态到 `done` 时崩溃。task 归档（git mv）、progress 追加、状态标 `done` 全部中断。实际效果等同于 lite 闭环的最后一步断路。
- **建议**：将 `完成` 改为 `done`：`bash "$SCRIPT_DIR/op_status.sh" "$TID" done`。同时 grep 全仓库检查是否还有其他位置传入中文状态值给 op_status.sh。
- **置信度**：高（脚本静态分析确认，非推测）
- **优先级**：高（阻断性 bug）

### 2. oplintake tasks_list.json 示例使用中文状态值「待开始」，与 design §1.1 ASCII 枚举冲突

- **位置**：`skills/oplintake/SKILL.md` 第 83-88 行，`"status": "待开始"`
- **现象**：示例 JSON 中 task 状态写为中文 `"待开始"`，而 design §1.1 明确要求 `tasks_list.json.status` 使用 ASCII 枚举（`pending`/`ready`/`in_progress` 等），脚本内 jq/grep 比较一律用左列 ASCII 值。`op_jq.sh pending`（实际查 `select(.status=="ready")`）将永远找不到用中文写入的 task，oplrun 选 task 逻辑失效。
- **影响**：oplrun 循环无法选中 task，表现为「无可跑 task」而实际有待开始 task。数据静默不一致，排查困难。
- **建议**：将示例改为 `"status": "ready"`，其余三处提及「待开始」的说明文字改为 `status=ready`（机读值），附带渲染中文标注对齐 design §1.1。
- **置信度**：高
- **优先级**：高

### 3. oplintake spec 模板缺少「可测性契约」段

- **位置**：`skills/oplintake/SKILL.md` 步骤二（第 52-58 行）
- **现象**：SKILL.md 列出的 spec 必含内容为「假设清单 / 不变量INV / 验收标准AC / 边界 / 技术决策」，缺少 design §2.2 要求的「可测性契约」段。可测性契约含应用启动方式、每条 AC 的验收信号与通道、测试缝、预期失败模式——这是 evaluator 的唯一操作手册。oplintake 是 lite 模式唯一 spec 入口，若此处不要求填写，spec 将缺失 evaluator 关键信息。
- **影响**：evaluator 裸评时不知道应用如何启动、每条 AC 用什么通道验收——只能自行猜测，验收质量显著下降。`op_assemble_eval_brief.sh` 也只能输出「从上方工作 spec 的可测性契约段提取」而实际上 spec 里根本没有这段。
- **建议**：在步骤二的 spec 正文必含清单中增加「可测性契约：应用启动方式 + 每条 AC 验收信号与通道 + 测试缝 + 预期失败模式（best effort）」。lite 无 blueprint 定向包，spec 是 implementer/evaluator 唯一契约源，可测性契约更不可省。
- **置信度**：高
- **优先级**：高

### 4. oplrun review diff 缺少 dispatch 锚点 sha，reviewer 可能看到空 diff

- **位置**：`skills/oplrun/SKILL.md` 步骤 3.4（第 125-134 行）
- **现象**：dispatch reviewer 时 prompt 写 `代码变更：git diff`，未指定锚点。design §5.9 明确要求「dispatch implementer 时记 HEAD sha，reviewer git diff 锚定该 sha 而非 HEAD——防 implementer 自行 commit 致 diff 空」。lite 无 worktree 隔离，implementer 在主工作树直接修改——如果 implementer 在返回前自行 `git add && git commit`，则 `git diff`（当前工作区对 HEAD）输出为空，reviewer 看不到任何变更，双裁决完全失明。
- **影响**：reviewer 收到空 diff，只能靠 report.md 文字描述判断，无法独立验证代码变更——测试可信裁决形同虚设。
- **建议**：在步骤 3.2 dispatch implementer 时记录 `DISPATCH_SHA=$(git rev-parse HEAD)`，步骤 3.4 dispatch reviewer 时用 `git diff $DISPATCH_SHA` 而非裸 `git diff`。新增文件也需 `git diff $DISPATCH_SHA --diff-filter=A --name-only` 纳入 review-package。
- **置信度**：高
- **优先级**：高

### 5. oplrun `git add -A` 过度宽泛，lite 安全边界退化为零

- **位置**：`skills/oplrun/SKILL.md` 步骤 3.6 第 182 行
- **现象**：`git add -A` 会暂存所有变更（含未跟踪文件、删除），不加区分地收纳一切。lite 无 worktree 隔离、无 merge gate、无 hook——`git add -A` 是写入侧唯一收集点。leader 可能在循环中遗留临时文件、调试输出、遗漏的 `node_modules` 等，全部被收入 commit。
- **影响**：意外文件（临时脚本、调试日志、`.env` 泄露风险）被提交到 git 历史。注释写「越界靠 reviewer advisory」，但 reviewer 审的是 implementer 产出阶段的 diff，不是 leader 收口阶段的 `git add -A` 范围。
- **建议**：将 `git add -A` 收紧为 `git add -u`（只暂存已跟踪文件的修改+删除）+ 显式 `git add` 新增文件列表（从 `git diff --name-only --diff-filter=A $DISPATCH_SHA` 获取）。或至少在 `git add` 前跑 `git status --short` 让 leader 确认改动面。
- **置信度**：中高
- **优先级**：高

---

## 中优先级问题

### 6. op_assemble_eval_brief.sh 启动方式未机械提取，eval_brief 不完整

- **位置**：`skills/oplrun/scripts/op_assemble_eval_brief.sh` 第 37-39 行
- **现象**：「应用启动方式」段写的是「从上方工作 spec 的「可测性契约」段提取」——这是一条给人/agent 看的指令，不是机械提取。design §2.5 要求 eval_brief 由脚本机械组装（内容源全固定路径 cat），leader 不参与内容生成。当前脚本把「找到启动方式」的责任推给了 evaluator 阅读 spec 全文。
- **影响**：evaluator 可能漏掉启动方式（spec 撰写不规范/可测性契约段命名不统一），导致验收无法启动应用。机械组装的本意是消除此类人工误差。
- **建议**：约定 spec 内可测性契约的启动方式用固定标记（如 `应用启动方式:` 行），脚本用 sed/awk 从 spec 提取该行。若 spec 缺此标记，脚本 die 而非生成不完整 brief——倒逼 spec 填写完整。
- **置信度**：中
- **优先级**：中

### 7. op_close_post.sh 不归档 spec 到 op_record/specs/

- **位置**：`skills/oplrun/scripts/op_close_post.sh` 全文 + `skills/oplrun/SKILL.md` 步骤 3.6
- **现象**：脚本归档了 `tasks/{TID}/`（report.md + review.md）到 `op_record/tasks/{TID}/`，追加了 progress.md，更新了 tasks_list.json 状态。但 design §1.2 明确「lite：无 closer/blueprint，leader 直接归档 spec 原文」。当前 `op_execution/specs/{TID}_{slug}.md` 在 task 闭环后仍留在原地，永不移入 `op_record/specs/`。SKILL.md 步骤 3.6 也未提及 spec 归档。
- **影响**：`op_execution/specs/` 随时间积累所有历史 spec，与 design 归档约定不符。对功能无直接影响，但长期堆积后 `ls specs/T0*_*.md` 会返回大量已关闭 task 的 spec。
- **建议**：在 op_close_post.sh 或 SKILL.md 步骤 3.6 中增加 `git mv docs/omni_powers/op_execution/specs/{TID}_*.md docs/omni_powers/op_record/specs/`。
- **置信度**：中
- **优先级**：中

### 8. op_check_p0.sh 未接入 oplrun 主流程，定位与 design 矛盾

- **位置**：`skills/oplrun/scripts/op_check_p0.sh` + `skills/oplrun/SKILL.md`
- **现象**：脚本注释写「oplrun per-task 裸评 PASS 后、归档 task 前调本脚本」，脚本 exit 1 时输出「归档前必须处置」。但 oplrun SKILL.md 步骤 3.5/3.6 完全没有调用此脚本，P0 处置按 design §5.8 进「结束报告不事中阻断」。
- **影响**：脚本存在但从未被调用——要么是死代码，要么是意图未落地。若未来接入，exit 1 阻断行为与 design「不事中阻断」矛盾（除非 leader 无视 exit code，但这不是脚本设计的预期用法）。
- **建议**：二选一：a) 若 P0 检查确实在 per-task 归档前调用，则脚本 exit code 应改为 advisory（始终 exit 0，仅输出 P0 列表供 leader 决策）；b) 若 P0 只在结束报告汇总，则修改脚本注释去掉「归档 task 前调本脚本」，注明「供结束报告汇总扫描用」。无论哪种，SKILL.md 应显式说明调用时机。
- **置信度**：中
- **优先级**：中

### 9. 三份 op_check_env.sh 副本完全相同，维护负担已落地

- **位置**：`skills/oplinit/scripts/op_check_env.sh`、`skills/oplintake/scripts/op_check_env.sh`、`skills/oplrun/scripts/op_check_env.sh`（三份逐字节一致，已通过 diff 验证）
- **现象**：design §5.5 描述共享目录 `~/.claude/scripts/omni_powers/` 作为 lite 脚本归宿，并承认「副本同步淘汰（渐进，D5）——完整归并待重构」。当前状态是 design 已知的过渡期，但三份独立副本确实存在。
- **影响**：修改 op_check_env.sh 需同步三份，遗漏则行为分裂。三份当前完全一致，短期内无实际故障。
- **建议**：作为 D5 的待办项追踪。在归并完成前，建议在 `build_lite.sh` 中增加此文件的三方一致性校验。
- **置信度**：中
- **优先级**：中低（已知过渡态）

---

## 低优先级问题

### 10. oplintake tasks_list.json 示例含 schema 外字段 `type`

- **位置**：`skills/oplintake/SKILL.md` 第 85 行，`"type": "实现"`
- **现象**：design §2.3 tasks_list.json schema 定义字段为 `id/title/status/spec/depends_on/workset`，不含 `type` 字段。示例多了一个 `"type": "实现"`。
- **影响**：op_jq.sh 不查询此字段，不造成功能问题。但若开发者误以为 `type` 是标准字段并写入逻辑依赖，后续可能断裂。
- **建议**：移除示例中的 `type` 字段，或将其正式加入 design schema 并说明语义（与 change type 的关系）。
- **置信度**：中
- **优先级**：低

### 11. op_coder_check.sh 注释「第 3 轮 → blocked」有歧义

- **位置**：`skills/oplrun/scripts/op_coder_check.sh` 第 7 行
- **现象**：注释写「review ≤ 2 轮（第 3 轮 → blocked）」。代码逻辑：无 verdict → normal round 1，1 个 verdict → fail round 2，2 个 verdict → blocked（exit 1）。即第 3 次 implementer 派发才会 blocked。代码与 design「review ≤ 2 轮」一致，但注释可能被误读为「第 3 轮 review 才 blocked」。
- **影响**：纯注释问题，不影响功能。
- **建议**：改为「review 最多 2 轮（第 3 次 implementer 派发 → blocked）」更精确。
- **置信度**：低
- **优先级**：低

### 12. op_jq.sh `pending` 子命令命名与实际查询不匹配

- **位置**：`skills/oplrun/scripts/op_jq.sh` 第 14-15 行
- **现象**：子命令名为 `pending`，但实际 jq 查询是 `select(.status=="ready")`（查「待开始」的 task，非 status=pending 的 task）。`pending` 在状态枚举中含义是「待规划」，与 `ready`「待开始」不同。
- **影响**：命名可能误导调用者。oplrun SKILL.md 用 `op_jq.sh pending` 选 task，语义是「选下一个待执行的 task」而非「选 pending 状态的 task」。功能正确，命名迷惑。
- **建议**：将子命令改名为 `ready` 或 `next`，或在注释中说明「pending 指待执行（查询 status=ready 的 task）」。注意需同步更新 oplrun SKILL.md 中的调用。
- **置信度**：低
- **优先级**：低

### 13. op_status.sh flock 无降级方案

- **位置**：`skills/oplrun/scripts/op_status.sh` 第 50-52 行
- **现象**：使用 `flock` 做文件锁，若系统无 `flock`（某些精简 Linux 发行版 / 非 GNU 环境），脚本直接 die。
- **影响**：tasks_list.json 并发写保护缺失。但 lite 模式下 leader 串行操作，实际并发风险极低。
- **建议**：加 `command -v flock` 检测，不可用时降级为 WARN + 无锁写（依赖串行纪律）。
- **置信度**：低
- **优先级**：低

### 14. op_check_p0.sh YAML frontmatter 解析用 awk，不够健壮

- **位置**：`skills/oplrun/scripts/op_check_p0.sh` 第 24-28 行
- **现象**：用 `awk -F': *'` 解析 `severity:` 和 `status:` 行。对简单单行值正确，遇多行值、引号包裹值、键名含空格等情况可能误解析。
- **影响**：当前 issue frontmatter 格式简单（单行键值），实际误解析概率低。
- **建议**：可接受现状。若未来 issue frontmatter 复杂化，改用更严格的前置 matter 解析器。
- **置信度**：低
- **优先级**：低

---

## 改进建议

### A. oplrun 步骤 3.2 缺少 dispatch 锚点 sha 的记录动作

design §5.9 要求 dispatch implementer 时记 HEAD sha。当前 SKILL.md 未显式写出此步骤。建议在步骤 3.2 增加：

```bash
DISPATCH_SHA=$(git rev-parse HEAD)
# 写入 checkpoint 或变量，供步骤 3.4 reviewer diff 锚定
```

### B. oplintake 步骤二中 lite spec 自足性提醒可强化

当前写「lite 无 blueprint 定向包——spec 是 implementer 唯一契约源，须自足（含必要的架构/命名约束内联）」。建议进一步细化：如果项目有特定目录结构、命名约定、启动命令、端口号等，必须在 spec 中显式声明——implementer 没有 architecture.md/conventions.md 可参考。

### C. oplrun「看进度」渲染应与 op_jq.sh 查询对齐

当前渲染示例使用 emoji（✅🔄⏳🚫⚫）和中文标签，但 op_jq.sh 只输出原始 JSON。建议在 SKILL.md 中给出从 `op_jq.sh all` 输出到渲染格式的具体映射规则，减少 leader 临场发挥。

### D. op_assemble_eval_brief.sh 应校验 spec 存在且含 AC

当前脚本只校验 spec 文件存在（glob 命中），不校验 spec 是否包含 AC 段。若 spec 文件存在但内容为空或缺少 AC，eval_brief 虽然生成但 evaluator 无法工作。建议增加最小内容校验——至少 grep 确认存在 `AC-` 标记或 `验收场景` 标题。

### E. oplrun SKILL.md 步骤 3.6 与 op_close_post.sh 职责边界可更清晰

当前 SKILL.md 步骤 3.6 写了 `git add -A` 然后调 `op_close_post.sh`，但 `op_close_post.sh` 内部也执行 `git add`（只 add 归档目录+progress+tasks_list）。两次 `git add` 的覆盖范围不同（前者是全部，后者是三个特定路径），后者可能覆盖前者的效果——如果 leader 在步骤 3.6 执行了 `git add -A` 再进 `op_close_post.sh`，后者又做了一次更窄的 `git add`，结果取决于 git 的暂存区叠加行为（后 add 不会清除前 add 的内容，只是追加）。实际效果是全部文件都被 staged。建议将 `git add` 职责统一到一处——要么全交给 `op_close_post.sh`（需扩展其 add 范围），要么 SKILL.md 负责 add 而 `op_close_post.sh` 不再 add。

---

## 不确定项

1. **oplintake SKILL.md 步骤四 tasks_list.json 示例**中 `"depends_on": null` 与 design schema 的数组类型 `"depends_on": ["T0001"]` 不一致。无依赖时 design 未定义是 `null` 还是 `[]`。当前 `op_jq.sh deps` 查询用 `depends_on[]?`，空数组和 null 均安全。但语义上有差异——建议统一为 `[]`（空数组），与 design 示例一致。

2. **close_check.sh 的 git status 检查范围**：第三步检查 git status 有无非本 task 归档的改动，但 lite 无 worktree——一个 task 实现阶段必然产生 src/ 变更未提交（验收前置 D6，验收 PASS 前不 commit）。这些 src 变更会被 close_check.sh 的 grep 排除规则漏掉（grep 只排除了 `${arch}` 即 `op_record/tasks/{TID}` 路径），导致每个 task 的 close_check 都报 WARN。建议将 grep 排除模式扩展为同时排除 `docs/omni_powers/` 以外的所有路径（即 src/、配置等实现文件在验收 PASS 前未 commit 是正常的，不应报 WARN）。

---

## 整体评估

**状态机一致性**：lite 状态枚举（去 closing）、op_status.sh 的 closing 拒绝逻辑、op_close_post.sh 的无 closing 前置检查——三处与 design §5.6 一致。op_coder_check.sh 的 2 轮上限与 design §2.4 一致。整体状态机无结构性偏差。

**profile 互斥保护**：oplinit_skeleton.sh 的 profile 冲突检测覆盖了 heavy 残留和缺失 profile 两种情况，与 design §5.2 判定表对齐。

**零侵入边界**：oplinit_skeleton.sh 的写入范围严格限制在 `docs/omni_powers/` 内 + e2e 默认落在 `docs/omni_powers/e2e/`（不进用户测试 runner），与 design §5.3 一致。但 oplrun `git add -A` 在收口时破坏了这条边界——它会把 `docs/omni_powers/` 以外的文件一并 stage（见高优先级问题 5）。

**无 hook 替代**：oplrun 的 leader 自验（步骤 3.3）对应 design §5.9「leader 亲自跑测试命令 + 读关键 diff」，语义到位但缺少 dispatch 锚点 sha 的具体执行细节（见高优先级问题 4）。

**P0 事后报告**：op_check_p0.sh 存在但未接入主流程，（见中优先级问题 8）。oplrun SKILL.md 的结束报告段描述了 P0 汇总逻辑，与 design §5.8 一致。

**最严重问题**：高优先级问题 1（`完成` vs `done`）是**阻断性 bug**，会导致 lite 闭环全部失败。高优先级问题 2/3/4/5 是**契约级偏离**（状态枚举/测试契约/diff 锚点/安全边界），每个都会在特定场景下导致静默错误。
