# 14_tests 模块审阅（haiku 视角）

## 当前模型判断依据

可观测来源：`/home/karon/.claude/settings.json` 顶层 `model=haiku`；`env.ANTHROPIC_MODEL=default_model`；`ANTHROPIC_DEFAULT_HAIKU_MODEL=default_haiku[1m]`；主会话环境提示当前由 `default_model` 驱动（haiku 档）。不能读取运行时内部状态；current 路继承主会话。本报告以 haiku 视角独立完成，未参考其他路审阅。

## 审阅范围

`tests/` 下全部文件（排除 `vendors/` 与 `docs/archive/`，本模块无这两类）：

- `tests/README.md`
- `tests/scripts/helpers.bash`
- `tests/scripts/close_check.bats`
- `tests/scripts/op_check_env.bats`
- `tests/scripts/op_checkpoint.bats`
- `tests/scripts/op_close_post.bats`
- `tests/scripts/op_closer_gate.bats`
- `tests/scripts/op_mutation_check.bats`
- `tests/scripts/op_read_verdict.bats`
- `tests/scripts/op_status.bats`
- `tests/scripts/op_trailer_unlock.bats`
- `tests/scripts/op_worktree_setup.bats`
- `tests/scripts/opinit_register_hooks.bats`
- `tests/scripts/opinit_skeleton.bats`
- `tests/scripts/oplrun_lite.bats`
- `tests/scripts/pre_tool_use.bats`
- `tests/scripts/run-hook.bats`
- `tests/scripts/subagent_stop.bats`

对照被测脚本（`scripts/`、`skills/oprun/scripts/`、`skills/oplrun/scripts/`、`hooks/`）与 design（§0.2 能力矩阵、§1.1 状态枚举、§2.3 task schema、§2.5 evaluator 隔离、§2.6 closer gate、§3.1 可写性矩阵、§3.3 机械护栏、§3.4 merge gate、§5 lite 退化）。

## 高优先级问题（CRITICAL / HIGH）

### H1. fixture TID 宽度偏离 design 编码规则，TID 锚定测试存在盲区
- 位置：`tests/scripts/helpers.bash:23`、`tests/scripts/op_checkpoint.bats:23-31`、`close_check.bats` 全部、`op_close_post.bats` 全部、`op_read_verdict.bats` 全部
- 现象：design §1 规定 TID 全局单调递增 `T0001/T0002/…`，**固定四位数宽度**，永不复用。helpers.bash fixture 用 `T01`（两位），所有 bats 测试都基于 `T01`。op_checkpoint.bats:23 的"TID 锚定"测试只验了 `T01` vs `T010` 的前缀锚定（`grep -qE '^- T01 '`），未覆盖 design 真实编码 `T0001` vs `T00010`（五位）场景。close_check.sh:32 实际用 `grep -qE "^- ${TID} "` 做 TID 锚定，若真实 TID 为 `T0001` 而某行含 `T00010`，锚定逻辑同样有效——但测试从未用四位数宽度跑过。
- 影响：若未来被测脚本（op_checkpoint.sh / close_check.sh）引入 TID 格式校验（如 `^[T]\d{4}$`），所有测试 fixture 会集体失效；反之若脚本长期不校验，design 的"固定四位数宽度"约束无测试守护，漂移无警报。更隐蔽的是：TID 锚定测试（op_checkpoint.bats:23）声称防"T01 误配 T010"，但真实编码下误配场景是"T0001 误配 T00010"或"T0001 误配 T0001X"，测试构造的边界与真实边界错位。
- 建议：helpers.bash fixture 改用 `T0001`（四位宽度），TID 锚定测试构造 `T0001` vs `T00010`（或 `T0001X`）场景。同时补一条断言：被测脚本/fixture 的 TID 符合 `^T\d{4}$`（若 design 未来放松约束则同步改）。
- 置信度：高（design §1 编码规则明确，fixture 偏离可肉眼确认）
- 优先级：HIGH

### H2. op_close_post.bats 全部依赖 fixture `eval:"skip"` 豁免 eval.md 校验，eval.md PASS 路径零覆盖
- 位置：`tests/scripts/op_close_post.bats` 全部 4 个 @test；`tests/scripts/helpers.bash:23`
- 现象：op_close_post.sh:41-47 实现了 D6 验收前置——非 `eval:skip` task 必须有 `acceptance/{TID}/eval.md` 且末行 `verdict: PASS`，否则 die。helpers.bash fixture 写死 `"eval":"skip"`，故所有 op_close_post.bats 测试都走豁免分支，从未覆盖 eval.md 存在/缺失/PASS/FAIL 四种真实路径。README:31 声称 op_close_post.bats 覆盖"校验 review+eval verdict PASS（D6）"，但实际 eval verdict 校验完全未被测试触发。
- 影响：D6 验收前置是 design §5.6 lite 流程的核心防线（验收 PASS 才 commit），eval.md 校验逻辑若被回归破坏（如 `grep -oE '^verdict:'` 正则写错、`EVAL_SKIP` 判断反了），测试全绿但生产 die。这是测试覆盖空洞，不是脚本 bug。
- 建议：helpers.bash fixture 拆两套——`eval:skip` 版（当前）+ `eval:required` 版（带 acceptance/T01/eval.md，verdict PASS/FAIL 两条）。op_close_post.bats 补三条：`eval:required + eval.md PASS → 归档`、`eval:required + eval.md FAIL → die`、`eval:required + 无 eval.md → die`。
- 置信度：高（op_close_post.sh:41-47 逻辑与 fixture eval:skip 叠加，覆盖空洞可确认）
- 优先级：HIGH

### H3. op_closer_gate.bats 未验证"越界后提案不进闸门 C"的下游效应，仅验文件保留
- 位置：`tests/scripts/op_closer_gate.bats:19-31`
- 现象：测试断言越界时 `[ -f src/leak.ts ]`（文件保留）+ exit 1 + 输出含"越界"。但 design §2.6 closer gate 的完整语义是"越界即 `git checkout` 撤销 + 告警，**提案不进闸门 C**"——Q5 改为"只报不撤销"后，测试验了"不撤销"，但未验"提案不进闸门 C"（即 leader 后续是否真的跳过了闸门 C 写入）。测试只覆盖 closer gate 脚本本身的 exit code，未覆盖 leader 侧对 exit 1 的处置。
- 影响：leader 侧若忽略 closer gate 的 exit 1 继续走闸门 C，closer gate 形同虚设。但这是 leader 提示词/流程问题，非脚本测试能覆盖——测试边界到此为止。真正可测的是"closer gate exit 1 时 leader 不 commit"，这属于 oplrun/oprun 集成测试范畴，当前 bats 未覆盖。
- 建议：要么在 README 明确标注"closer gate 下游效应由 oprun 集成测试覆盖（待补）"，要么补一条 mock leader 行为的测试（如 closer gate exit 1 时 op_close_post 不被执行）。当前测试本身无错，只是覆盖边界声明不足。
- 置信度：中（design §2.6 的"提案不进闸门 C"语义是否算 closer gate 脚本职责，存在解释空间）
- 优先级：HIGH（按 design §2.6 字面"提案不进闸门 C"是 closer gate 的设计目的，测试未验）

## 中低优先级问题（MEDIUM / LOW）

### M1. helpers.bash fixture 缺 `acceptance/` 目录，eval:required 路径测不了（与 H2 同源，独立列因影响面不同）
- 位置：`tests/scripts/helpers.bash:16-19`
- 现象：setup_mock_project 建 `tasks/T01`、`issues`、`op_record/tasks`、`e2e`，但不建 `op_execution/acceptance/T01/`。除 H2 说的 eval.md 外，closer 提案 `blueprint_update.md`（design §2.6）、baseline 快照（§2.5）都在 acceptance 下，这些路径的存在性/可写性未被任何测试 fixture 覆盖。
- 影响：op_close_post.sh 若未来加"校验 acceptance/{TID}/blueprint_update.md 存在"逻辑，fixture 不支持。
- 建议：helpers.bash 补 `mkdir -p docs/omni_powers/op_execution/acceptance/T01`，op_closer_gate.bats 已手动建（第 9 行），但 helpers 统一更干净。
- 置信度：高
- 优先级：MEDIUM

### M2. op_status.bats test 1 的 `invalid_status` 传参依赖脚本枚举文本，枚举漂移无警报
- 位置：`tests/scripts/op_status.bats:30-35`
- 现象：测试传 `invalid_status` 验证 die，断言 `*"无效 status"*`。op_status.sh:39 的 die 文本是 `"无效 status: $status（有效值: ...）"`。若脚本未来把 `closing` 从 heavy 枚举移除（如 heavy 也去 closing 态），或新增枚举值，测试不会感知——`invalid_status` 始终 die，但"哪些值合法"的契约无守护。
- 影响：design §1.1 状态枚举（pending/ready/in_progress/reviewing/closing/done/suspended/blocked/obsolete）是机读契约，脚本与测试都不该自创。当前测试只验"非法值 die"，未验"合法值全集通过"。
- 建议：补一条参数化测试，遍历 design §1.1 的 9 个合法状态（heavy）/ 8 个（lite 去 closing），每个都 exit 0。lite 版（oplrun/scripts/op_status.sh）已有 `closing die` 测试（oplrun_lite.bats:25），heavy 版缺正向枚举覆盖。
- 置信度：高
- 优先级：MEDIUM

### M3. op_trailer_unlock.bats 第三个 test（commit-msg 无 trailer 被拦）未断言"被拦原因含 e2e"
- 位置：`tests/scripts/op_trailer_unlock.bats:47-53`
- 现象：测试验 `[ "$status" -ne 0 ]`，但未断言输出内容（应含"e2e"/"trailer"等关键词）。若 commit-msg hook 误拦（如因其他原因 die），测试假绿。
- 影响：拦截的"正确性"未被验证——只验"拦了"，不验"为何拦"。
- 建议：补 `[[ "$output" == *"trailer"* ]]` 或 `*"e2e"*` 断言（取决于 commit-msg 实际输出文本）。
- 置信度：中（需读 commit-msg 脚本确认输出文本，未读）
- 优先级：MEDIUM

### M4. pre_tool_use.bats 未覆盖 design §3.1 的"行级敏感度"警告层
- 位置：`tests/scripts/pre_tool_use.bats` 全部 5 个 @test
- 现象：design §3.3 第 5 层"警告+留痕"要求结构层测试编辑按行敏感度——import/setup/调用行静默，expect/assert 行强制说明。pre_tool_use.bats 测了 --no-verify、spec 写保护、e2e 拦截、baselines 主会话/subagent 区分，但未测 `*.test.*` 文件编辑 expect/assert 行的警告逻辑。
- 影响：design §3.1 的可写性矩阵中"refactor 断言期望值不许变"这条核心防偷改机制，测试零覆盖。
- 建议：补 test：编辑 `src/x.test.ts` 的 `expect(a).toBe(b)` 行 → 警告/拦截；编辑 import 行 → 静默放行。需先确认 pre_tool_use.sh 是否实现了行级敏感度（若未实现，这是脚本缺失，非测试问题）。
- 置信度：中（未读 pre_tool_use.sh 全文，可能脚本未实现该层）
- 优先级：MEDIUM

### M5. subagent_stop.bats "有新鲜证据" test 用 `date +%s` 命名证据文件，时间窗口边界未测
- 位置：`tests/scripts/subagent_stop.bats:28-32`
- 现象：测试用 `test_evidence_$(date +%s).log` 命名证据文件，假设 stop.sh 的"新鲜"判定基于文件 mtime 与当前时间差。若 stop.sh 判定窗口是"最近 N 秒"，test 在极端负载下 `date +%s` 与文件实际 mtime 可能差 1-2 秒，flaky 风险低但存在。更重要的是：**未测"过期证据被拒"**——只测了新鲜通过，没测过期 die。
- 影响：stop.sh 的"新鲜"阈值逻辑无负向覆盖。
- 建议：补 test：构造 mtime 超 N 秒（如 `touch -d '5 minutes ago'`）的证据文件 → 验 exit 2。需读 stop.sh 确认阈值。
- 置信度：中（未读 stop.sh 全文）
- 优先级：MEDIUM

### M6. opinit_register_hooks.bats 未测 Stop hook 注册（design §4.1 列了 Stop）
- 位置：`tests/scripts/opinit_register_hooks.bats:28-34`
- 现象：test 3 断言 `.hooks.PreToolUse` 和 `.hooks.SubagentStop` 存在，但 design §4.1 还列了 `Stop`（leader 收尾门禁）和 `PostToolUse[src/**]`。README:38 声称覆盖"hooks 注册（PreToolUse/PostToolUse/SubagentStop/Stop）"，但测试只验了 PreToolUse + SubagentStop。
- 影响：README 声明与测试实际不一致；Stop/PostToolUse hook 若注册逻辑回归，测试无感知。
- 建议：test 3 补 `jq -e '.hooks.Stop'`、`jq -e '.hooks.PostToolUse'` 断言。
- 置信度：高（README 与测试断言可直接对比）
- 优先级：MEDIUM

### M7. oplrun_lite.bats 只测 3 条，lite 副本的关键差异覆盖不足
- 位置：`tests/scripts/oplrun_lite.bats` 全部 3 个 @test
- 现象：design §5.5 列了 lite 副本的 8 处脚本差异（op_status 去 closing、op_check_env 跳 OP_HOME、op_close_post 跳 closing 前置、op_assemble_eval_brief 裸评简化等）。oplrun_lite.bats 只测了 op_jq pending 查询、op_status done、op_status closing die 三条。op_close_post 的"跳 closing 前置检查"、op_check_env 的"跳 OP_HOME 段"、op_assemble_eval_brief 的"跳基线/baselines 段"均未覆盖。
- 影响：lite 副本与 heavy 的 profile 分支若漂移（如 op_close_post 忘了加 lite 分支），测试不报警。design §5.5 明确这些差异"改任一处须同步另两处"，但测试未守护同步性。
- 建议：补 op_close_post lite 副本测试（无 closing 前置，直接从 reviewing → done）；op_check_env lite 副本（OP_HOME 未设也通过）；op_assemble_eval_brief lite 副本（输出无 baselines 段）。
- 置信度：高
- 优先级：MEDIUM

### M8. op_mutation_check.bats 的 ESCAPE 测试用 `unused` 函数，变异器未覆盖"测试存在但不断言"
- 位置：`tests/scripts/op_mutation_check.bats:34-51`
- 现象：ESCAPE test 构造的场景是"测试只调 unused，从不调 eq"——即 `==` 运算符所在函数完全未被调用。这是"函数级无覆盖"，不是 design §3.3 第 6 层关心的"断言不杀人"（测试调了函数但断言恒真）。真正的变异测试价值在后者：`eq a a` 被调，但断言是 `echo pass` 无 assert，变异 `== → !=` 后测试仍绿。
- 影响：op_mutation_check.sh 的核心能力（杀死恒真断言）未被测试验证。当前 ESCAPE test 只验了"函数不被调"，过弱。
- 建议：补 test：`eq a a` 被调 + 测试无 assert（只 echo pass）→ 变异 `==` → 测试仍绿 → ESCAPE。这才是 design §3.3"杀不死变异体的测试判假重写"的真实场景。
- 置信度：中（取决于 op_mutation_check.sh 的实际变异策略，未读全文）
- 优先级：MEDIUM

### L1. helpers.bash teardown 用 `rm -rf "$TEST_ROOT"` 无 guard 防 TEST_ROOT 为空或 `/`
- 位置：`tests/scripts/helpers.bash:51-53`
- 现象：`[ -n "${TEST_ROOT:-}" ] && [ -d "$TEST_ROOT" ] && rm -rf "$TEST_ROOT"`。虽有非空 + 目录检查，但未防 TEST_ROOT 被恶意/误设为 `/` 或 `/home`。mktemp -d 不会产生这种值，但若 setup_mock_project 失败后 TEST_ROOT 未赋值，teardown 的 `-d` 检查会因空值跳过——安全。风险极低。
- 影响：理论上的安全网缺失，实际 mktemp 保证安全。
- 建议：可选加 `[ "$TEST_ROOT" != "/" ] && [[ "$TEST_ROOT" == /tmp/* ]]` 双保险。
- 置信度：高
- 优先级：LOW

### L2. README "未覆盖"段遗漏 op_merge_gate.sh 之外的其他未落地脚本
- 位置：`tests/README.md:48-50`
- 现象：只列了 merge gate 和系统层夜跑未覆盖。但 design §0.2 还列了"P2 evaluator baseline 对照评"、"P3 定期体检"未落地，这些也无测试。README 的"未覆盖"声明不完整。
- 影响：文档完整性问题，不影响测试正确性。
- 建议：README "未覆盖"段补 baseline 对照评、定期体检、变异测试体检（专业版，当前 op_mutation_check 是骨架）。
- 置信度：高
- 优先级：LOW

### L3. run-hook.bats test 3 与 test 1 逻辑重复
- 位置：`tests/scripts/run-hook.bats:8-12` 与 `:20-24`
- 现象：两个 test 都跑 `pre_tool_use` + `--no-verify` JSON + 断言 exit 2。test 3 注释说"证明 .sh 自动补"，但 test 1 已经路由成功（若不自动补 .sh 会 die）。test 3 无增量价值。
- 影响：测试冗余，维护成本。
- 建议：删 test 3，或改 test 3 传 `pre_tool_use.sh`（带扩展名）验"带扩展名也工作"——这才是 polyglot wrapper 的双向兼容。
- 置信度：高
- 优先级：LOW

### L4. op_worktree_setup.bats git 版本 skip 用正则可能误放行 2.2x-2.24
- 位置：`tests/scripts/op_worktree_setup.bats:12`
- 现象：`git version 2>/dev/null | grep -qE 'git version (2\.(2[5-9]|[3-9])|[3-9])'`。正则 `2.(2[5-9]|[3-9])` 匹配 2.25-2.29、2.3-2.9，但不匹配 2.30-2.99（`[3-9]` 只匹配一位数）。git 2.30+ 会被 skip 误判为"版本不足"——实际 sparse-checkout 在 2.30+ 完全可用。反过来说，若机器是 git 2.30，测试被 skip，覆盖丢失。
- 影响：高版本 git 环境下测试被错误 skip，静默失去覆盖。
- 建议：正则改为 `git version (2\.(2[5-9]|[3-9][0-9]*)|[3-9])` 或用 `sort -V` 比较：`[ "$(git version | awk '{print $3}')" \< "2.25" ] && skip`。
- 置信度：高（正则语义可确认）
- 优先级：LOW（但若 CI 是 git 2.30+，实际影响升为 MEDIUM）

## 改进建议

### 结构性改进

1. **fixture 分层**：helpers.bash 当前单一 fixture（T01 + eval:skip + closing 状态）。建议拆 `setup_mock_project_minimal`（当前）+ `setup_mock_project_full`（T0001 + eval:required + acceptance/eval.md PASS + ready 状态），各 test 按需选。解决 H1/H2/M1 三个问题。

2. **状态枚举参数化**：design §1.1 的 9 个状态用 bats `for status in pending ready ...; do` 遍历，单测覆盖 heavy 全集；lite 版遍历 8 个（去 closing）。解决 M2。

3. **lite 副本差异守护**：oplrun_lite.bats 扩展为"design §5.5 的 8 处差异逐条覆盖"，每处差异至少一条 test。解决 M7。

4. **README 与测试一致性校验**：README 的"测试范围"表与"未覆盖"段，建议加一个 `tests/scripts/check_readme_consistency.sh`（或 bats test），自动校验 README 声明的覆盖项与实际 @test 数量/名称匹配。解决 M6/L2 类文档漂移。

### 可测性改进

5. **脚本输出契约稳定化**：当前测试大量 grep 中文字符串（"未 PASS"/"越界"/"必须提供 blocked_by"）。建议被测脚本对关键 die/exit 点输出机器可读前缀（如 `[FAIL:TID-Anchored]`、`[FAIL:Eval-Not-Pass]`），测试 grep 前缀而非自然语言。降低脚本文本本地化/措辞调整导致的测试假绿。影响面大，建议逐步迁移。

## 不确定项 / 可能误报

1. **M4（行级敏感度未覆盖）**：若 pre_tool_use.sh 根本未实现行级敏感度（design §3.3 第 5 层标记为 advisory，P1 阶段可能未落地），则测试缺失是合理的——脚本没的东西测不了。需读 pre_tool_use.sh 全文确认。若脚本未实现，本项应改为"脚本缺失"而非"测试缺失"。

2. **M5（新鲜证据时间窗口）**：stop.sh 的"新鲜"判定逻辑未读，可能用的是"文件存在"而非"mtime 在 N 秒内"（design §3.3 第 3 层原文"只验存在不验真伪"）。若如此，则"过期证据"概念不成立，M5 的负向测试建议无效。需读 stop.sh 确认。

3. **M8（变异测试 ESCAPE 场景）**：op_mutation_check.sh 的变异策略未读全文，可能它只做"函数级覆盖检测"（调没调），不做"断言级杀伤力检测"（assert 真伪）。若如此，当前 ESCAPE test 是正确的，M8 建议无效。需读脚本确认。

4. **H3（closer gate 下游效应）**：closer gate 脚本 exit 1 后 leader 是否跳过闸门 C，属于流程/提示词层，可能根本不该由 bats 测（属于 oplrun/oprun 集成测试范畴）。若 design §2.6 的"提案不进闸门 C"由 leader 提示词保证而非脚本，则 H3 是过度要求。判定为 MEDIUM 更合适，标 HIGH 偏严。

5. **L4（git 版本正则）**：bats 环境实际 git 版本未知，若 CI 固定用 git 2.25-2.29，正则不会误判，L4 无实际影响。但仓库本地跑（用户 git 2.40+）会触发误 skip。置信度随环境变。
