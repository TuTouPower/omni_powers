## 当前模型判断依据

`settings.json` 顶层 `model=haiku`, `ANTHROPIC_DEFAULT_SONNET_MODEL=default_sonnet`, `ANTHROPIC_DEFAULT_OPUS_MODEL=default_opus`。主会话环境由 `default_model` 驱动。本次以 sonnet 视角审阅，独立判断，不参考其他路审阅。

## 审阅范围

模块 14_tests：`tests/` 下全部文件（排除 `vendors/` 与 `docs/archive/`）。

审阅清单：
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

共 18 个文件，逐文件、逐测试用例全量审阅。

## 高优先级问题（CRITICAL / HIGH）

### H1: `oplrun_lite.bats` 中 `op_jq.sh pending` 命令名与查询语义不一致

- **位置**: `tests/scripts/oplrun_lite.bats` 第 8-14 行，`@test "lite op_jq: pending 查 ready（ASCII，lite 副本寻址）"`
- **现象**: 测试调用 `op_jq.sh pending`，期望返回 `status=="ready"` 的 task。`op_jq.sh` 脚本中 `pending` 分支查询的是 `select(.status=="ready")`（见 `skills/oplrun/scripts/op_jq.sh` 第 15 行）。命令名 `pending` 与查询的实际状态 `ready` 不一致。
- **影响**: 调用者看到 `pending` 命令会自然认为返回的是 `status=="pending"` 的任务，实际返回的却是 `ready` 状态。`pending_plan` 命令才是返回真正 `pending` 状态的。这个命名不一致容易导致维护者误用，造成任务调度逻辑错误。
- **建议**: 重命名 `pending` 为 `ready`，使其与查询语义一致；或将 `pending` 视为 `ready（待开始）` 的别名并在代码注释/帮助文本中明确标注。
- **置信度**: 高。源码和测试均可证实此不一致。
- **优先级**: HIGH。（虽不影响当前测试通过，但命名混乱是生产环境误用的潜在根因。）

### H2: 缺少 `op_assemble_eval_brief.sh` 的测试覆盖

- **位置**: `tests/README.md` 覆盖表 + `tests/scripts/` 目录
- **现象**: `tests/` 目录下无任何 `op_assemble_eval_brief.sh` 的 bats 测试。README.md 覆盖表中也未列出此脚本。该脚本在 design §2.5 中定义为 evaluator brief 机械组装的核心组件——brief 内容源全固定路径 cat（工作 spec / 生效规格 / baselines 索引 / 启动方式），leader 不参与内容生成。heavy 和 lite（简化版）均依赖此脚本。
- **影响**: eval_brief 组装是 evaluator 访问隔离的关键环节（design §2.5 报告回流层）。此脚本的输出决定了 evaluator 能看到什么、看不到什么。若无测试，brief 内容泄漏实现细节或遗漏验收标准时将无法被检测。
- **建议**: 新增 `op_assemble_eval_brief.bats`，至少覆盖：(a) brief 输出包含工作 spec 内容，(b) brief 输出不包含 implementer report 内容（隔离验证），(c) baselines 索引段在 heavy 模式存在，(d) lite 模式跳基线段。
- **置信度**: 高。确认 `tests/scripts/` 下无此文件。
- **优先级**: HIGH。（核心安全组件零测试，design §0.2 能力矩阵中 eval brief 组装属 P1 交付。）

### H3: `op_close_post.bats` 的 mock 项目设置 `eval: "skip"`，未覆盖 eval.md PASS 校验分支

- **位置**: `tests/scripts/helpers.bash` 第 23 行 fixture 中 `eval: "skip"` + `tests/scripts/op_close_post.bats` 全部 4 个测试
- **现象**: helpers.bash 中 tasks_list fixture 将 T01 设为 `"eval":"skip"`。`op_close_post.sh` 在 eval 非 skip 时会校验 `acceptance/{TID}/eval.md` 的存在性与 verdict PASS（D6 验收前置，design §2.5）。由于测试数据中永远 skip，eval.md 校验分支完全未被测试覆盖。
- **影响**: 若 `op_close_post.sh` 的 eval.md 校验逻辑存在 bug（如路径错误、verdict 解析正则失效），当前测试无法发现。对于非行为型 task（占比较小），skip 分支覆盖了；但行为型 task（占多数的 feat/fix 类 task）的 eval 校验路径完全没有测试。
- **建议**: 新增一个不使用 helpers fixture 的测试用例，直接构造 eval 非 skip 的 tasks_list + 创建 acceptance/T01/eval.md（分别含 verdict PASS 和 verdict FAIL），验证 op_close_post.sh 的 eval 校验分支。
- **置信度**: 高。
- **优先级**: HIGH。（D6 验收前置是 heavy 和 lite 共享的关键防线，校验分支零覆盖不可接受。）

## 中低优先级问题（MEDIUM / LOW）

### M1: `tests/README.md` 覆盖表描述与实际测试内容偏差

- **位置**: `tests/README.md` 第 37 行，op_check_env.bats 描述
- **现象**: 描述为"环境检查（jq/git/OP_HOME）"，但实际测试（`op_check_env.bats`）仅覆盖 OP_HOME 三个场景（未设、目录不存在、正常），未测试 jq 或 git 缺失场景。
- **影响**: 读者看到此表会以为 jq/git 缺失场景已有覆盖，实际没有。
- **建议**: 要么补充 jq/git 缺失场景的测试用例，要么将表描述改为"环境检查（OP_HOME）"。
- **优先级**: MEDIUM。

### M2: `op_worktree_setup.bats` 不覆盖 git < 2.25 降级路径

- **位置**: `tests/scripts/op_worktree_setup.bats` 第 12 行 `skip` 逻辑
- **现象**: setup 中 `git version ... | grep -qE 'git version (2\.(2[5-9]|[3-9])|[3-9])' || skip "git < 2.25，sparse-checkout 不可用"`。当 git < 2.25 时，全部测试被跳过。design §4.1 提到 git < 2.25 时 sparse-checkout 退化为纯纪律 WARN，merge gate 不受影响——但此降级路径零测试覆盖。
- **影响**: 无法验证低版本 git 下 worktree setup 脚本是否正确输出 WARN 并降级，而非 crash。
- **建议**: 新增测试用例在 git < 2.25 环境下运行（或模拟），验证脚本输出 WARN 而非错误退出。
- **优先级**: MEDIUM。

### M3: `op_trailer_unlock.bats` 未测试 commit-msg hook 的 trailer 格式校验

- **位置**: `tests/scripts/op_trailer_unlock.bats` 第 34-45 行
- **现象**: 测试 `有 staged e2e → 输出 trailer + commit 成功` 使用了正确格式的 trailer（由 unlock 脚本生成）并验证 commit 成功。但未测试 commit-msg hook 对**格式错误** trailer 的行为——例如 trailer 行格式为 `Op-E2e-Unlock:badhash`、或 trailer 行完全缺 hash。
- **影响**: commit-msg hook 如果只做存在性检查不做格式校验（或正则过于宽松），可能被伪造 trailer 绕过。
- **建议**: 新增测试：用手工构造的无效 trailer 提交，验证 commit-msg hook 拦截。
- **优先级**: MEDIUM。

### M4: `helpers.bash` mock 项目 TID 格式不符合 design 规范

- **位置**: `tests/scripts/helpers.bash` 第 22 行 `"id":"T01"` 及 fixture 中全部 `T01` 引用
- **现象**: design §1 规定 TID 为固定四位数宽度 `T0001/T0002/...`。测试 fixture 使用简写 `T01`，与实际生产数据格式不一致。
- **影响**: 当前不影响测试逻辑（因为脚本通过 jq 精确匹配 `id == $tid`，不依赖宽度）。但未来若新增依赖正则 `T[0-9]{4}` 的校验，这些测试将假 FAIL。测试数据应尽可能贴近生产格式。
- **建议**: 将 fixture 中 TID 统一为 `T0001`，或在 README.md 中说明测试使用简化 TID 格式的原因。
- **优先级**: LOW。

### M5: `op_closer_gate.bats` 越界测试仅覆盖新增文件，未覆盖修改已有文件

- **位置**: `tests/scripts/op_closer_gate.bats` 第 19-31 行
- **现象**: 越界测试通过 `echo "leak" > src/leak.ts` 新建文件并 `git add -A` 模拟 closer 越界写入。未覆盖 closer 修改已有跟踪文件（如修改 `docs/omni_powers/op_execution/tasks/T01/report.md`——该文件在白名单外）的场景。
- **影响**: `op_closer_gate.sh` 使用 `git status --porcelain | awk '{print $2}'` 扫描所有改动（含修改和新增）。理论上修改场景也被覆盖，但缺少显式测试用例作为回归哨兵。
- **建议**: 新增测试用例：在 mock 项目中修改一个已有但不在白名单内的文件（如 report.md），验证 gate 检测到越界。
- **优先级**: LOW。

### M6: `tests/README.md` 未标注 `oplrun_lite.bats` 和 `op_trailer_unlock.bats` 的覆盖范围

- **位置**: `tests/README.md` 覆盖表（第 29-44 行）
- **现象**: 覆盖表列出了 13 个测试文件及其覆盖目标，但遗漏了 `oplrun_lite.bats`（lite 副本冒烟）和 `op_trailer_unlock.bats`（e2e trailer）。README 合计列出 14 个文件，实际 tests/scripts/ 下有 17 个 .bats 文件。
- **影响**: 维护者通过 README 了解测试范围时会遗漏这两个文件的覆盖信息。
- **建议**: 在表中补充 `oplrun_lite.bats` 和 `op_trailer_unlock.bats`（以及 `run-hook.bats`，当前也缺失）的覆盖说明。
- **优先级**: LOW。

## 改进建议

### 1. 测试数据贴近生产格式

helpers.bash fixture 中 TID 格式（`T01`）、文件命名、目录结构建议与 design 规范保持一致（四位数 TID、spec 文件实际存在等）。可在 helpers.bash 注释中统一声明测试简化约定，避免"测试绿但格式不兼容"。

### 2. 补充混合场景测试

当前除 `op_trailer_unlock.bats`（测试 staged 变化使 trailer 失效）外，大多数测试为单场景正向/负向。建议增加以下混合场景：
- closer gate：一个更正中同时存在白名单通过文件和越界文件
- op_status：批量模式 `--batch` 的 blocked_by 行为
- pre_tool_use：同一个 tool_input 同时命中多个拦截规则（如既改 spec 又改 e2e）

### 3. 补充 `op_check_env.bats` 中 jq/git 缺失场景

当前 `op_check_env.bats` 三个用例全围绕 OP_HOME。建议补充 jq 未安装、git 未安装两个场景，至少验证脚本输出明确的 die 信息而非未定义行为。

### 4. 建议对 `stop.sh` 的 `stop_hook_active` 字段做显式测试

`subagent_stop.bats` 所有测试的输入 JSON 均含 `"stop_hook_active":false`。design §3.3 规定"脚本开头必检查 stdin 的 `stop_hook_active` 字段防递归"，但当前测试未覆盖 `stop_hook_active: true` 时脚本应跳过/静默退出的路径。

### 5. 考虑对 `op_read_verdict.sh` 增加畸形 review.md 测试

`op_read_verdict.bats` 测试了 NONE / PASS / FAIL / 多轮追加。建议增加：review.md 存在但内容为空、verdict 行拼写错误（如 `verdict: PAS`）、verdict 行不在末行等畸形场景。

## 不确定项 / 可能误报

### U1: `op_worktree_setup.bats` 在 git < 2.25 时全部 skip 是否合理

当前设计为 git 版本不足时直接 `skip`，不跑任何测试。这是 bats 的惯用做法（能力不可用则跳过），但设计文档 §0.1 提到 git < 2.25 时 sparse-checkout 退化为 WARN（不是 skip）。如果脚本确实在低版本 git 下有降级逻辑，测试应覆盖降级路径而非完全跳过。如果脚本在低版本 git 下直接 die，则当前 skip 合理。需要确认实际脚本行为后判定。暂时标记为 MEDIUM。

### U2: `close_check.bats` 测试依赖 `op_close_post.sh` 和 `op_checkpoint.sh` 的外部行为

`close_check.bats` 第一个测试用例先调用 `op_close_post.sh` 再调用 `op_checkpoint.sh` 后才测 `close_check.sh`。这种链式依赖使得该测试实际上是 op_close_post + op_checkpoint + close_check 的集成测试，而非 close_check 的单元测试。如果前两个脚本的行为变化导致测试失败，会误报为 close_check 问题。但考虑到这些脚本本身就是紧密配合的流程组件，集成测试有其合理性。不设优先级，仅提请关注。

### U3: `opinit_register_hooks.bats` 对 Windows wrapper 的测试声明

`run-hook.bats` 注释提到 "CMD 路径在 Linux 无法测，基于 superpowers 验证写法信任"。实际上 `run-hook.bats` 的三个测试在 Linux 下通过 `bash "$OP_HOME/hooks/run-hook.cmd"` 测试 polyglot wrapper 的 bash 路径路由，并非无法测试。注释与实际测试内容存在偏差，建议更新注释。
