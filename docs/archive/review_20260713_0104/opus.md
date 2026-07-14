# 审阅报告（opus 视角）

## 当前模型判断依据

可观测来源：`~/.claude/settings.json` 顶层 `model=haiku`；进程环境 `ANTHROPIC_MODEL=default_model`、`ANTHROPIC_DEFAULT_HAIKU_MODEL=default_haiku[1m]`、`ANTHROPIC_DEFAULT_SONNET_MODEL=default_sonnet[1m]`、`ANTHROPIC_DEFAULT_OPUS_MODEL=default_opus[1m]`；主会话可见标识 `default_model`。均为配置别名，非可解析版本 ID。只能判断：当前会话继承 `default_model`，settings 默认模型配置为 `haiku`，无法从可观测信息确认底层实际模型 ID。本报告按用户显式授权以 opus 审阅视角输出。

## 审阅范围

commit `93aa4c2`（feat: op_merge_gate.sh 写入硬底线）+ `341af55`（fix: 既有脚本 bug + 过时测试）。全量逐文件审阅 14 个目标文件：

- 脚本：op_merge_gate.sh / op_close_post.sh / op_closer_gate.sh / op_jq.sh / opinit_register_hooks.sh / opinit_skeleton.sh
- SKILL：oprun/SKILL.md
- 测试：op_merge_gate.bats / op_close_post.bats / opinit_skeleton.bats / oplrun_lite.bats / subagent_stop.bats / helpers.bash
- 文档：omni_powers_design.md（§0.2 能力矩阵 + §3.4）

审阅方法：逐行读源 + 在 /tmp 隔离 git 仓库实证验证 merge-base diff 行为、review.md 时序、jq 去重幂等、glob 前缀边界、e2e 保护匹配。

---

## 高优先级问题（CRITICAL / HIGH）

### H1 — review.md 未 commit 到主分支时 merge gate 误 REJECT（时序契约缺口）

- **位置**：`scripts/op_merge_gate.sh:131`；`skills/oprun/SKILL.md` 子步骤 3.3 → 3.6 之间
- **现象**：merge gate 用 `git show "$BASE:$REVIEW_PATH"` 从**主分支已提交树**读 verdict。实测（/tmp 验证）：若 leader 已把 review.md 落盘到工作区但**未 commit**，`git show main:review.md` 返回 `fatal: path exists on disk, but not in 'main'`，管道被 `|| true` 吞掉，`review_verdict` 为空 → 判为"verdict 缺失" → REJECT(exit 1)。
- **影响**：SKILL 3.3 只说"verdict 由 leader 落盘到主分支 review.md"，未显式要求在 merge gate（3.6）**之前 commit**。leader 若按字面"落盘"（write 而未 commit）即触发误拒，且报错信息（"reviewer 双裁决未落盘"）会误导排查方向——实际是没 commit，非没写。这是把 verdict 校验绑定到 git 已提交状态却未在流程侧显式化前置动作，属安全机制的可用性硬伤。
- **建议**：二选一。(a) SKILL 3.3/3.4 明确增加"leader 落盘 review.md 后 `git add + commit` 到主分支"步骤，作为 merge gate 的显式前置；(b) merge gate 读 review.md 时增加 fallback：主分支树无则回退读工作区 `$ROOT/$REVIEW_PATH`，并在报错文案中区分"未落盘"与"未 commit"。倾向 (a)，保持"读主分支权威副本"的信任根语义不被工作区可篡改性击穿。
- **置信度**：高（已实证 git show 行为 + 通读 SKILL 未见显式 commit 步骤）
- **优先级**：HIGH

### H2 — skeleton 落点 `tests/e2e/` 不在 merge gate 受保护黑名单，e2e 硬保护存在缺口

- **位置**：`scripts/op_merge_gate.sh:61-70`（PROTECTED 列表）对比 `skills/opinit/scripts/opinit_skeleton.sh:31-39`（e2e 落点建 `tests/e2e/`）
- **现象**：PROTECTED 只含 `"e2e/"` 与 `"docs/omni_powers/e2e/"`。skeleton 默认建的 E2E 落点是 `tests/e2e/`。实测 `is_protected "tests/e2e/foo.test.ts"` 返回 NOT protected。虽然 `is_struct_test` 会因 `*/e2e/*` 分支把它判为非结构层，最终若不在 workset 则走"工作集越界 REJECT"——结果安全；**但一旦某 task 的 workset 恰好包含 `tests/e2e/...` 路径，`in_workset` 命中即放行**，e2e 本应始终受硬保护（design §3.4：`e2e/**` 全在黑名单侧，evaluator 产物走 leader 专属通道）。
- **影响**：design §3.4 声明 e2e 是 evaluator 唯一可写、task 分支一律 REJECT 的受保护资产。但 heavy 实际落点是 `tests/e2e/`，与 gate 黑名单前缀不匹配，保护语义靠"越界"兜底而非"受保护"直判。若 workset 配置失误纳入 e2e 路径，硬底线被击穿——这正是本 commit 要堵的"受保护路径混入主分支"攻击面。
- **建议**：PROTECTED 增加 `"tests/e2e/"`；或统一收敛为对任意 `*/e2e/` 与 `e2e/` 前缀的路径都判受保护（复用 `is_struct_test` 已有的 `e2e/*|*/e2e/*` case 语义）。使 is_protected 与 skeleton 落点、design §3.4 三者对齐。
- **置信度**：高（实测 + 交叉 skeleton/design）
- **优先级**：HIGH

---

## 中低优先级问题（MEDIUM / LOW）

### M1 — hooks 去重在"组内命令部分重叠"时产生重复 hook（非完全幂等）

- **位置**：`skills/opinit/scripts/opinit_register_hooks.sh:56-68`
- **现象**：去重判据是"template 组内 `hooks[].command` 是否**全部**已在 user 侧存在"（`all(. != null) | not` 保留未全命中的组）。实测：template 组 `[cmdA,cmdB]`、user 已有 `[cmdA]` 时，整组被追加，结果 `["cmdA","cmdA","cmdB"]`——cmdA 重复。
- **影响**：本 commit 修复了"顶层 .command 恒 null 误杀 template"的真 bug（方向正确，全有/全无场景已幂等，实测长度 1）。但边缘：用户手动只加了 omni template 某组内一条命令后重跑 /opinit，会得到重复 hook 项，导致同一命令被执行两次。实际概率低（template 各组通常整体注册），但破坏"重跑幂等"契约。
- **建议**：去重粒度下沉到单条 command 级——对 template 组内逐条 command 过滤已存在项后再合并，或以"组内**任一** command 已存在即视为该组已注册"（`any` 而非 `all`）近似，权衡见注释。若判定成本高可暂记为已知限制并加注释说明。
- **置信度**：高（实测复现）
- **优先级**：MEDIUM

### M2 — `is_struct_test` 的 `tests/*` 白名单过宽，可夹带非测试文件

- **位置**：`scripts/op_merge_gate.sh:84`（`*/tests/*|tests/*) return 0`）
- **现象**：任何 `tests/` 目录下文件（含 fixtures、helpers.bash、非测试脚本）都被判为结构层测试而放行，不要求命中 `*.test.*`/`*_test.*` 命名。
- **影响**：merge gate 白名单本意是"实现侧结构层测试"。`tests/*` 无差别放行给了 task 分支一条夹带任意 `tests/` 下改动的通道，绕过 workset 约束。攻击面有限（e2e 已被 case 前置排除），但与"白名单机械校验、最小授权"的设计意图有张力。
- **建议**：收紧为仅放行 `tests/` 下命中测试命名模式的文件（把 `tests/*` 与命名判定做 AND），或显式在注释中声明"tests/ 全目录放行"是有意决策及其理由。
- **置信度**：中（行为确定，是否"问题"取决于设计取舍）
- **优先级**：MEDIUM

### M3 — merge gate 空 workset 时逐文件全部落"越界"，缺少 workset 缺失的显式诊断

- **位置**：`scripts/op_merge_gate.sh:57`、`89-96`、`124-125`
- **现象**：`mapfile WORKSET` 若 jq 查不到该 TID 或 workset 字段缺失，`WORKSET` 为空数组。`in_workset` 对空数组恒 return 1。此时所有非 report/非结构测试改动全部 REJECT 为"工作集越界"，但根因可能是 tasks_list.json 里该 task 没配 workset，而非 task 真越界。
- **影响**：报错文案"不在 workset ∪ ... 白名单"会把"workset 未配置"误导为"task 越界"，增加排查成本。属可用性，非安全漏洞（fail-closed 方向正确）。
- **建议**：`WORKSET` 为空时先 WARN 提示"TID=$TID 在 tasks_list.json 无 workset 或字段为空，请确认 spec 拆分"，再继续裁决。
- **置信度**：中
- **优先级**：LOW

### L1 — 注释/commit 称"merge-base 三点"，代码用两点 `$MB..$BRANCH`（术语不精确）

- **位置**：`scripts/op_merge_gate.sh:43,47`；commit 93aa4c2 message；SKILL 236 行
- **现象**：代码 `git diff --name-only "$MB".."$BRANCH"`（两点，显式以 merge-base 为左端）。注释与 commit 反复称"merge-base 三点"。实测 `$MB..$BRANCH` 与 `$BASE...$BRANCH`（三点）结果等价——已正确排除 base 在切出后的移动（/tmp 验证：main 后续改 other.ts 不进 diff）。
- **影响**：功能正确，无 bug。仅术语：三点 `A...B` = `$(merge-base A B)..B`，作者用两点+手算 merge-base 达成同效，但文字统一叫"三点"易让读者误以为代码写的是 `...`。
- **建议**：注释改为"以 merge-base 为基的两点 diff（等价三点 `$BASE...$BRANCH`）"，消除代码与文字表述的错位。
- **置信度**：高
- **优先级**：LOW

### L2 — `op_close_post.sh` checkpoint 更新 awk 依赖 `### last_completed` 段紧邻结构，鲁棒性弱

- **位置**：`skills/oprun/scripts/op_close_post.sh:89-96`
- **现象**：awk 对 `### current_task`/`### last_completed`/`### next_step` 三段各 `print;print "";...;f="skip"` 后靠 `/^### /` 或 `/^## /` 复位。若 checkpoint 被人为改动导致段标题缺失或顺序错乱，last_completed 可能不被刷新或串段。失败仅 WARN 不阻塞（设计如此）。
- **影响**：checkpoint 是人机可读断点，非安全资产，容错策略（WARN 不阻塞）合理。但对模板结构强耦合，模板若演进需同步改 awk。测试已覆盖标准格式（op_close_post.bats 断言 last=T01）。
- **建议**：无需改动；建议在 awk 上方注释显式声明"依赖 docs_template/.../leader_checkpoint.md 的三段固定标题，模板变更需同步"。当前注释已部分提及，可补强段序依赖。
- **置信度**：中
- **优先级**：LOW

### L3 — 空提交模式脚本文件（op_closer_gate.sh/op_jq.sh）仅改 +x，diff stat 为 0 行

- **位置**：commit 341af55 对 `scripts/op_closer_gate.sh`、`scripts/op_jq.sh` 的 0 行变更（仅 mode 100644→100755）
- **现象**：commit message 述"op_closer_gate.sh / op_jq.sh 缺 +x"。属正确修复（脚本被 `bash script.sh` 调用时 +x 非必需，但被直接 `./script` 或某些 hook 调用路径需要）。
- **影响**：无负面。仅提示：若这两脚本全程只经 `bash "$OP_HOME/scripts/xxx.sh"` 调用，+x 非功能必需，属规范性对齐（与其他脚本一致可执行位）。
- **建议**：无。记录以示已核。
- **置信度**：高
- **优先级**：LOW

---

## 改进建议

1. **把"review.md 已 commit 到主分支"提为 merge gate 的显式前置契约**（H1）——这是本次安全机制最可能在真实运行中被自身绊倒的点。建议在 SKILL 3.4 判定通过后、3.6 之前插入明确的 `git add + commit review.md` 步骤，并在 merge gate 报错文案区分"未落盘/未 commit/verdict=FAIL"三态。
2. **统一 e2e 保护路径口径**（H2）——PROTECTED、skeleton 落点、design §3.4 三处对 e2e 目录前缀（`e2e/` vs `tests/e2e/`）表述不一。以 skeleton 实际落点为准补齐 gate 黑名单，避免 workset 误配击穿硬底线。
3. **补 merge gate 测试用例**：现有 5 场景未覆盖 (a) `tests/e2e/` 在 workset 时的裁决、(b) review.md 未 commit 到主分支时的行为、(c) 部分重叠 hooks 去重。这三条正是本报告 H1/H2/M1 的暴露点，加测试可固化预期并防回归。
4. **术语一致性**（L1）：merge-base 两点 vs 三点的措辞在 code/commit/SKILL/design 四处统一。
5. **fail-closed 诊断增强**（M3）：workset 缺失、review 缺失等 fail-closed 分支补充根因提示，降低运行期排查成本——安全机制的可运维性和其防护强度同等重要。

---

## 不确定项 / 可能误报

- **H1 的实际触发概率**取决于 leader 落盘 review.md 的具体实现（write 后是否立即 commit）。我通读 oprun/SKILL.md 未见 3.3→3.6 之间显式 commit review.md 的步骤，但 leader 主会话行为部分由 RULES.md 与 leader 自身编排决定，可能在别处有隐含 commit。若 RULES.md 或某脚本已强制 commit，则 H1 降为 LOW（文档显式化建议仍成立）。**需核 RULES.md 中 review.md 落盘时序**方能定级，本审阅范围未含 RULES.md 全文。
- **M2 的 `tests/*` 放行**是否为有意设计存疑——若 omni_powers 约定实现侧测试统一落 `tests/` 且不含其他文件，则非问题。判定为 MEDIUM 是基于"最小授权"原则的保守立场，可能与项目实际约定不符，属可能误报。
- **M1 部分重叠去重**在真实使用中概率低（template 各组通常整体注册），实证复现是构造场景。定级 MEDIUM 偏保守，若团队确认 template 组不会被用户拆分注册，可降为 LOW。
- 未运行完整 bats 套件（依赖环境 bats 可用性），本报告基于源码静态审 + 关键行为的 /tmp 隔离实证；commit message 声称"60/60 绿"未独立复验。
