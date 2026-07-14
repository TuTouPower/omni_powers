## 当前模型判断依据

可观测来源：`/home/karon/.claude/settings.json` 顶层 `model=haiku`；`env.ANTHROPIC_MODEL=default_model`；`ANTHROPIC_DEFAULT_HAIKU_MODEL=default_haiku[1m]`；`ANTHROPIC_DEFAULT_SONNET_MODEL=default_sonnet[1m]`；`ANTHROPIC_DEFAULT_OPUS_MODEL=default_opus[1m]`；主会话环境提示当前由 `default_model` 驱动。不能读取运行时内部状态；current 路继承主会话。

## 审阅范围

已按要求完整阅读设计上下文 `/home/karon/karson_ubuntu/omni_powers/docs/omni_powers_design.md`，该文件仅作上下文，不重复审阅。

本轮只读审阅以下 tests 范围，排除 `vendors/` 与 `docs/archive/`，未运行构建、未运行测试、未联网：

- `/home/karon/karson_ubuntu/omni_powers/tests/README.md`
- `/home/karon/karson_ubuntu/omni_powers/tests/scripts/close_check.bats`
- `/home/karon/karson_ubuntu/omni_powers/tests/scripts/helpers.bash`
- `/home/karon/karson_ubuntu/omni_powers/tests/scripts/op_check_env.bats`
- `/home/karon/karson_ubuntu/omni_powers/tests/scripts/op_checkpoint.bats`
- `/home/karon/karson_ubuntu/omni_powers/tests/scripts/op_close_post.bats`
- `/home/karon/karson_ubuntu/omni_powers/tests/scripts/op_closer_gate.bats`
- `/home/karon/karson_ubuntu/omni_powers/tests/scripts/op_mutation_check.bats`
- `/home/karon/karson_ubuntu/omni_powers/tests/scripts/op_read_verdict.bats`
- `/home/karon/karson_ubuntu/omni_powers/tests/scripts/op_status.bats`
- `/home/karon/karson_ubuntu/omni_powers/tests/scripts/op_trailer_unlock.bats`
- `/home/karon/karson_ubuntu/omni_powers/tests/scripts/op_worktree_setup.bats`
- `/home/karon/karson_ubuntu/omni_powers/tests/scripts/opinit_register_hooks.bats`
- `/home/karon/karson_ubuntu/omni_powers/tests/scripts/opinit_skeleton.bats`
- `/home/karon/karson_ubuntu/omni_powers/tests/scripts/oplrun_lite.bats`
- `/home/karon/karson_ubuntu/omni_powers/tests/scripts/pre_tool_use.bats`
- `/home/karon/karson_ubuntu/omni_powers/tests/scripts/run-hook.bats`
- `/home/karon/karson_ubuntu/omni_powers/tests/scripts/subagent_stop.bats`

## 高优先级问题（CRITICAL / HIGH）

### HIGH-1：`op_check_env.bats` 两个负例用空 `OP_HOME` 拼脚本路径，实际测不到目标脚本环境分支

- 位置：`/home/karon/karson_ubuntu/omni_powers/tests/scripts/op_check_env.bats:11-20`
- 现象：
  - `OP_HOME="" run bash "$OP_HOME/scripts/op_check_env.sh"` 展开后脚本路径变成 `/scripts/op_check_env.sh`。
  - `OP_HOME="/nonexistent" run bash "$OP_HOME/scripts/op_check_env.sh"` 展开后脚本路径变成 `/nonexistent/scripts/op_check_env.sh`。
  - 这两条失败可能来自 Bash 找不到脚本，而不是 `scripts/op_check_env.sh` 内部的 `OP_HOME 未设`、`目录不存在` 分支。
- 影响：
  - 环境检查的关键失败路径存在假绿风险。
  - 若 `op_check_env.sh` 内部删掉 OP_HOME 校验或错误文案，测试仍可能因脚本路径不存在而失败；当前输出断言虽尝试匹配文案，但路径展开错误使测试意图脆弱，容易受系统 `/scripts/...` 或 shell 错误文本影响。
- 建议：
  - 保留真实脚本路径变量，例如 `SCRIPT="$OP_HOME/scripts/op_check_env.sh"` 后再在 `run` 前覆盖子进程环境：`OP_HOME="" run bash "$SCRIPT"`、`OP_HOME="/nonexistent" run bash "$SCRIPT"`。
  - 同时断言输出来自脚本自有 `[FAIL] OP_HOME ...` 前缀，避免误吃 shell 的 `No such file`。
- 置信度：HIGH
- 优先级：HIGH

### HIGH-2：`opinit_register_hooks.bats` 两个 OP_HOME 负例同样用被覆盖的 `OP_HOME` 拼目标脚本路径，环境校验未被真实覆盖

- 位置：`/home/karon/karson_ubuntu/omni_powers/tests/scripts/opinit_register_hooks.bats:16-26`
- 现象：
  - `OP_HOME="" run bash "$OP_HOME/skills/opinit/scripts/opinit_register_hooks.sh"` 会把目标脚本路径展开为 `/skills/opinit/scripts/opinit_register_hooks.sh`。
  - `OP_HOME="/nonexistent" run bash "$OP_HOME/skills/opinit/scripts/opinit_register_hooks.sh"` 会把目标脚本路径展开为 `/nonexistent/skills/opinit/scripts/opinit_register_hooks.sh`。
  - 测试标题声称覆盖脚本内部 `OP_HOME 未设` 与 `OP_HOME 指向错`，但命令未稳定调用仓库中的真实脚本。
- 影响：
  - `opinit_register_hooks.sh` 的 OP_HOME 校验可回归而测试不一定捕获。
  - hooks 注册入口属于 heavy 初始化关键路径；此处假绿会削弱安装/初始化失败可诊断性。
- 建议：
  - 在覆盖环境变量前保存脚本绝对路径：`SCRIPT="$OP_HOME/skills/opinit/scripts/opinit_register_hooks.sh"`。
  - 使用 `OP_HOME="" run bash "$SCRIPT"` 与 `OP_HOME="/nonexistent" run bash "$SCRIPT"`。
  - 断言脚本自有错误前缀和关键文案。
- 置信度：HIGH
- 优先级：HIGH

### HIGH-3：`op_close_post.bats` 未覆盖行为型 task 必须有 `eval.md verdict: PASS`，D6 验收前置硬门可能回归

- 位置：`/home/karon/karson_ubuntu/omni_powers/tests/scripts/op_close_post.bats:13-40`；fixture 在 `/home/karon/karson_ubuntu/omni_powers/tests/scripts/helpers.bash:21-24`
- 现象：
  - README 声明 `op_close_post.bats` 覆盖“校验 review+eval verdict PASS（D6）”。
  - 但共享 fixture 的 `tasks_list.json` 默认 `eval:"skip"`，现有 `op_close_post` 用例全部走非行为型豁免路径。
  - 测试只覆盖 `review.md verdict`，没有构造 `eval:"required"` 且缺 `acceptance/T01/eval.md`、`eval.md FAIL`、`eval.md PASS` 的分支。
- 影响：
  - 设计 §2.4/§2.5/§5.6 的“验收 PASS 才收口”是核心防线；当前测试不能防止脚本未来误删 eval gate。
  - 行为型 task 可能在无 evaluator PASS 证据时被归档并标 done，属于流程正确性高风险。
- 建议：
  - 新增三类用例：
    1. `eval="required"` 且 `eval.md` 缺失 → 非 0，输出包含 `eval.md 缺或空`。
    2. `eval="required"` 且 `verdict: FAIL` → 非 0，输出包含 `eval 未 PASS`。
    3. `eval="required"` 且 `verdict: PASS` → 正常归档。
  - 保留现有 `eval:"skip"` 用例作为非行为型豁免覆盖。
- 置信度：HIGH
- 优先级：HIGH

### HIGH-4：`op_trailer_unlock.bats` 只校验 e2e 路径清单 HMAC，未覆盖内容变更后旧 trailer 失效，和注释“绑内容防重放/复用”不一致

- 位置：`/home/karon/karson_ubuntu/omni_powers/tests/scripts/op_trailer_unlock.bats:34-73`
- 现象：
  - 测试覆盖“有 staged e2e → trailer 可提交”“无 trailer 被拦”“staged 清单新增文件后旧 trailer 失效”。
  - 但未覆盖“同一路径文件内容改变后旧 trailer 失效”。
  - 被测 hook 注释写的是 `trailer = HMAC-SHA256(secret, 本次 staged 的 e2e 文件清单)`，并注明“绑内容防重放/复用”；实现与测试都只绑定路径清单，不绑定 blob/content。
- 影响：
  - 若安全预期是“绑定内容”，当前机制允许同一 e2e 路径下改内容后复用旧 trailer，测试不会发现。
  - e2e 主分支自锁是防 leader 误提交行为层测试的特例防线；绑定粒度误解会高估安全性。
- 建议：
  - 二选一：
    1. 若设计只要求绑定路径清单：修正文档/注释，明确“不绑定内容，仅绑定 staged e2e 路径集合”；测试名也改为“路径清单变更旧 trailer 失效”。
    2. 若设计要求绑定内容：`op_trailer_unlock.sh` 与 `commit-msg` HMAC 输入应包含 staged blob hash（如 `git diff --cached --name-only -z e2e/` + `git rev-parse :path`），并补“同路径内容变更旧 trailer 失效”测试。
- 置信度：HIGH
- 优先级：HIGH

### HIGH-5：`op_closer_gate.bats` 现有期望“越界只报不撤销”与设计上下文 §2.6“越界即 git checkout 撤销”冲突

- 位置：`/home/karon/karson_ubuntu/omni_powers/tests/scripts/op_closer_gate.bats:19-30`；设计上下文 `/home/karon/karson_ubuntu/omni_powers/docs/omni_powers_design.md:490-492`
- 现象：
  - 测试明确断言 `src/leak.ts` 越界后文件仍保留，并注释“Q5：只报不撤销”。
  - 设计 §2.6 写明 closer gate：触碰路径不在白名单时“越界即 `git checkout` 撤销 + 告警，提案不进闸门 C”。
  - 这不是测试内部问题，而是测试目标与当前设计档案矛盾。
- 影响：
  - 若设计是权威，当前测试把错误行为锁死，阻止 closer gate 自动清理越界写入。
  - closer 是“权限最大约束最少”的角色，越界处理语义错误会影响收口安全模型。
- 建议：
  - 先统一设计与实现语义。
  - 若采纳 Q5“只报不撤销”，必须更新设计 §2.6 与能力矩阵描述，说明 leader 决策前保留越界文件的理由和后续清理流程。
  - 若设计保持“越界即撤销”，测试应改为断言越界文件消失或 staged/working tree 越界改动被恢复，并验证白名单文件保留。
- 置信度：HIGH
- 优先级：HIGH

## 中低优先级问题（MEDIUM / LOW）

### MEDIUM-1：`op_worktree_setup.bats` 未断言敏感路径泄漏时应失败或至少测试 WARN，隔离退化会被 exit 0 掩盖

- 位置：`/home/karon/karson_ubuntu/omni_powers/tests/scripts/op_worktree_setup.bats:37-55`
- 现象：
  - 测试只在正常 sparse-checkout 成功时断言目录存在/不存在。
  - 被测脚本在 sparse pattern 应用后发现泄漏时只输出 `[WARN]`，仍 exit 0。
  - 测试没有断言“泄漏 WARN 出现时如何处理”，也没有负例模拟 pattern 失败或 Git 退化。
- 影响：
  - implementer/evaluator 隔离是设计 §0.2 已落地能力，但当前脚本的失败语义偏 advisory；测试又只锁成功路径，无法防止隔离实际失效时流程继续。
  - 未来如果 sparse pattern 被改坏，可能只产生 WARN，调度层仍把 worktree 当隔离成功。
- 建议：
  - 至少新增对输出中不得包含 `sparse-checkout 未生效`、`仍有敏感目录` 的断言。
  - 更稳妥：脚本在 git 版本支持 sparse-checkout 且验证泄漏时 exit 非 0；测试覆盖该非 0 语义。若设计坚持 advisory，则 README 和测试名应标明“仅 WARN，不是硬门”。
- 置信度：MEDIUM
- 优先级：MEDIUM

### MEDIUM-2：`op_worktree_setup.bats` 未覆盖 tasks_list.json 不挂给 subagent，与设计 §3.4 的关键约束不匹配

- 位置：`/home/karon/karson_ubuntu/omni_powers/tests/scripts/op_worktree_setup.bats:37-55`；README 声明在 `/home/karon/karson_ubuntu/omni_powers/tests/README.md:42`
- 现象：
  - README 声称 worktree 测试包含 `tasks_list` 挂载断言。
  - 实际 fixture 没创建 `docs/omni_powers/op_execution/tasks_list.json`，测试也没有断言 dev/eval worktree 中该文件不存在。
  - 设计 §3.4 明确：`tasks_list.json` 不挂给任何 subagent，workset/depends_on 由 dispatch 脚本注入。
- 影响：
  - 若 worktree sparse 规则未来把 `tasks_list.json` 暴露给 implementer/evaluator，现有测试不会失败。
  - 这会破坏流程文件单副本与 dispatch 注入边界，增加 subagent 读/改共享状态的风险。
- 建议：
  - fixture 中创建 `docs/omni_powers/op_execution/tasks_list.json`。
  - 对 `dev` 和 `eval` 均断言 `.claude/wt/docs/omni_powers/op_execution/tasks_list.json` 不存在。
  - README 覆盖说明同步到真实断言。
- 置信度：HIGH
- 优先级：MEDIUM

### MEDIUM-3：`op_worktree_setup.bats` 断言 dev worktree 挂载完整 task 目录，未区分 report.md 可写与 review.md 禁写

- 位置：`/home/karon/karson_ubuntu/omni_powers/tests/scripts/op_worktree_setup.bats:37-44`；fixture 在同文件 `18-30`
- 现象：
  - 测试只断言 `tasks/T01/report.md` 存在。
  - fixture 没创建 `tasks/T01/review.md`，所以无法证明 dev worktree 未暴露 `review.md`。
  - 设计 §1.1/§3.4 要求 `review.md` 单写者 = leader，task 分支不许碰；implementer 只写 report.md。
  - 但当前 sparse 规则 dev 模式是 `/*` 排除 `e2e/`，会挂载整个 task 目录；若真实 task 目录含 `review.md`，dev worktree 可见。
- 影响：
  - 测试未锁住“review.md 不给 implementer 写”的设计不变量。
  - 如果流程依赖 worktree 物理隔离而非 merge gate 拦截，review 单写者语义会被削弱。
- 建议：
  - fixture 增加 `docs/omni_powers/op_execution/tasks/T01/review.md`。
  - 明确设计取舍：若 dev worktree 允许看到 review.md 但靠 merge gate 拦，测试名/README 不应暗示“report 可写”即隔离完备；若设计要求物理不挂 review.md，应调整 sparse 规则并加断言 `review.md` 不存在。
- 置信度：MEDIUM
- 优先级：MEDIUM

### MEDIUM-4：`oplrun_lite.bats` 仅冒烟三个脚本分支，未覆盖 lite 收口前关键机械补强

- 位置：`/home/karon/karson_ubuntu/omni_powers/tests/scripts/oplrun_lite.bats:1-31`
- 现象：
  - 文件注释说明“只冒烟 lite 副本寻址 + ASCII”。
  - 设计 §5.9 明确 lite 需要机械补强：spec 写保护用 dispatch 锚点 sha、按实际 diff add、dirty-tree 检查、review diff 锚定 dispatch sha。
  - 当前测试只覆盖 `op_jq pending`、`op_status done`、`closing die`，未覆盖上述 lite 高风险路径。
- 影响：
  - lite 无 hook、无 worktree、无 merge gate，收口机械补强是主要替代防线；当前测试不足以防主分支直改 spec、implementer 自行 commit 导致 diff 空、evaluator 残留污染下个 task 等回归。
- 建议：
  - 补 lite 收口脚本/流程测试：
    - dispatch 后改 `op_execution/specs/**` 应停。
    - implementer 自行 commit 后 review diff 仍基于 dispatch sha 非空。
    - evaluator 后 dirty tree 非空应停。
    - 收口 `git add` 覆盖实际 diff 文件集。
  - 若这些逻辑尚无可测脚本入口，README 应把它列为未覆盖，而不是只说 heavy 测试覆盖逻辑。
- 置信度：HIGH
- 优先级：MEDIUM

### MEDIUM-5：`op_checkpoint.bats` 使用固定 `/tmp/tasks.json`，并行测试可能互相覆盖

- 位置：`/home/karon/karson_ubuntu/omni_powers/tests/scripts/op_checkpoint.bats:25`
- 现象：
  - 测试中间文件写死为 `/tmp/tasks.json`。
  - 其他测试或并行 bats 进程可能同时写同一路径。
- 影响：
  - 测试隔离性不足，未来并行运行或 CI shard 下可能出现偶发失败/误读。
- 建议：
  - 使用 `mktemp`，或写到 `$TEST_ROOT/tasks_list.tmp`。
- 置信度：HIGH
- 优先级：MEDIUM

### MEDIUM-6：`oplrun_lite.bats` 同样使用固定 `/tmp/t`，并行运行存在串扰

- 位置：`/home/karon/karson_ubuntu/omni_powers/tests/scripts/oplrun_lite.bats:10`
- 现象：
  - jq 输出临时文件固定为 `/tmp/t`。
- 影响：
  - 与 MEDIUM-5 同类，并行/重入时可能覆盖其他测试输出。
- 建议：
  - 改用 `mktemp` 或 `$TEST_ROOT/tasks_list.tmp`。
- 置信度：HIGH
- 优先级：MEDIUM

### MEDIUM-7：`subagent_stop.bats` 不区分 agent_type，可能把非 implementer subagent 也纳入“新鲜测试证据”门禁

- 位置：`/home/karon/karson_ubuntu/omni_powers/tests/scripts/subagent_stop.bats:22-38`
- 现象：
  - 测试只覆盖 `agent_type:"op-implementer"`。
  - 设计与注释强调 SubagentStop matcher 按 agent_type 过滤，主要拦 implementer 交工证据。
  - 但测试没有覆盖 `op-reviewer`、`op-evaluator`、`op-closer` 的行为。
- 影响：
  - 若注册配置或 stop 脚本逻辑导致所有 subagent 都要求 implementer 测试证据，reviewer/evaluator/closer 可能被误拦；反向若 implementer 过滤失效，也难被发现。
- 建议：
  - 新增非 implementer agent_type 用例，明确期望：跳过证据门禁或按各角色专属门禁处理。
  - 同步检查 hook 注册 matcher 是否只匹配目标角色。
- 置信度：MEDIUM
- 优先级：MEDIUM

### MEDIUM-8：`subagent_stop.bats` 新鲜证据用当前时间命名，未覆盖过期证据拒绝

- 位置：`/home/karon/karson_ubuntu/omni_powers/tests/scripts/subagent_stop.bats:28-32`
- 现象：
  - 有证据用例只创建当前时间文件。
  - 无证据用例没有创建过期 `test_evidence_*.log`。
  - 被测逻辑依赖 `find ... -mmin -5`，时间窗口是关键语义。
- 影响：
  - 如果未来 `-mmin -5` 被误改成任意证据都放行，测试可能仍通过。
- 建议：
  - 新增 `touch -d '10 minutes ago' test_evidence_old.log` 后应 exit 2 的用例。
- 置信度：HIGH
- 优先级：MEDIUM

### MEDIUM-9：`pre_tool_use.bats` 与 `op_trailer_unlock.bats` 对 e2e 锁的路径覆盖只测顶层 `e2e/`，未覆盖 `BUG-*` 非 e2e 路径

- 位置：`/home/karon/karson_ubuntu/omni_powers/tests/scripts/pre_tool_use.bats:24-29`；`/home/karon/karson_ubuntu/omni_powers/tests/scripts/op_trailer_unlock.bats:34-73`
- 现象：
  - 设计 §3.1 写明行为层 = `e2e/` 全部 + `BUG-*` 回归测试，且 BUG-* 一律放 `e2e/` 下。
  - pre_tool_use hook 匹配 `e2e/*|*BUG-*`，但测试只覆盖 `e2e/test.spec.ts`。
  - git commit-msg hook 只检查 `e2e/*`，测试没有说明 BUG-* 在非 e2e 路径是否应被拦。
- 影响：
  - 若 BUG-* 回归测试被误放到非 e2e 路径，Claude hook 会拦主会话写入，但 git trailer hook 不一定拦提交；测试没有固定该边界。
- 建议：
  - 增加 `src/BUG-123_test.spec.ts` 或 `tests/BUG-123.bats` 的策略测试：要么明确禁止并拦截，要么文档写清只有 `e2e/BUG-*` 是合法路径。
  - README 中补充“BUG-* 非 e2e 路径不在 commit-msg e2e trailer 保护内”。
- 置信度：MEDIUM
- 优先级：MEDIUM

### LOW-1：`op_read_verdict.bats` 未覆盖大小写、前置空格、末行非 verdict 等解析边界

- 位置：`/home/karon/karson_ubuntu/omni_powers/tests/scripts/op_read_verdict.bats:5-39`
- 现象：
  - 覆盖了无 review、PASS、FAIL、多轮末个 verdict。
  - 未覆盖 ` verdict: PASS`、`verdict: pass`、末尾有范围外暂存段、最后一行非 verdict 等格式边界。
- 影响：
  - reviewer 返回格式是流程机读入口；解析宽严不明时，未来提示词或脚本调整可能造成误判。
- 建议：
  - 根据规范明确 verdict 必须行首大写，新增负例锁住格式；或支持宽松解析并补测试。
- 置信度：MEDIUM
- 优先级：LOW

### LOW-2：`op_status.bats` 未覆盖 batch 更新与不存在 TID 行为

- 位置：`/home/karon/karson_ubuntu/omni_powers/tests/scripts/op_status.bats:5-45`
- 现象：
  - 覆盖 blocked_by、无效 status、done 清 blocked_by。
  - 未覆盖 `--batch` 分支、目标 TID 不存在时是否应 die。
- 影响：
  - 批量状态更新若回归无测试保护；不存在 TID 静默 no-op 可能掩盖调用错误。
- 建议：
  - 增加 `--batch T01,T02 done` 用例。
  - 明确不存在 TID 的期望；建议 die，避免状态机静默漂移。
- 置信度：MEDIUM
- 优先级：LOW

### LOW-3：`close_check.bats` 未覆盖“git status 仅 WARN 不阻断”语义

- 位置：`/home/karon/karson_ubuntu/omni_powers/tests/scripts/close_check.bats:5-19`
- 现象：
  - 只覆盖归档+checkpoint 后通过、未归档不通过。
  - 被测脚本有“非本 task git status 改动只 WARN、不拦”的分支，但测试未覆盖。
- 影响：
  - WARN/FAIL 边界未来可能被误改，影响 leader 收口节奏。
- 建议：
  - 构造额外未归档文件，断言 exit 0 且输出含 `[WARN]`。
- 置信度：HIGH
- 优先级：LOW

### LOW-4：`helpers.bash` teardown 依赖测试显式调用，失败断言中途退出时临时目录可能残留

- 位置：`/home/karon/karson_ubuntu/omni_powers/tests/scripts/helpers.bash:51-53`；多处测试手动调用 `teardown_mock_project`
- 现象：
  - helpers 提供 `setup_mock_project`/`teardown_mock_project`，但很多测试在用例末尾手动调用 teardown。
  - 若中间断言失败，后续 `teardown_mock_project` 不执行。
- 影响：
  - 失败时 `/tmp` 下临时仓库残留，长期 CI 可能堆积。
- 建议：
  - 在各 bats 文件使用标准 `setup()`/`teardown()` 包装，或用 Bats `teardown_file`/trap 保证清理。
- 置信度：HIGH
- 优先级：LOW

## 改进建议

1. 优先修复两个“覆盖环境变量同时拼脚本路径”的假绿模式：`op_check_env.bats` 与 `opinit_register_hooks.bats`。这是测试自身可靠性问题，修复成本低。
2. 将 README 覆盖矩阵改为“已覆盖 / 未覆盖 / 仅冒烟”三栏，避免把 `op_close_post` 的 eval gate、worktree 的 tasks_list 隔离、lite 收口机械补强误标为已覆盖。
3. 对关键防线测试增加负例：
   - 行为型 task 无 eval PASS 不得收口。
   - worktree 泄漏敏感路径时不得静默成功，或至少测试 WARN。
   - stale evidence 不得通过 SubagentStop。
   - e2e trailer 内容/路径绑定语义必须与文档一致。
4. 统一设计文档与测试对 `op_closer_gate` 越界处理语义：撤销还是只报，必须单一真相。
5. 所有临时文件从固定 `/tmp/...` 改为 `mktemp` 或 `$TEST_ROOT` 内路径，提升并行安全。

## 不确定项 / 可能误报

1. `op_closer_gate` 的“只报不撤销”可能来自 Q5 后的新决策，而当前 `omni_powers_design.md` 未同步。如果 Q5 是最新权威，则 HIGH-5 应转为“设计文档未更新”，不是测试错误。
2. e2e trailer 是否必须绑定内容存在语义不确定：设计 §2.5 强调最简版“trailer 存在性校验”，而 hook 注释写 HMAC 绑定文件清单且“绑内容防重放”。若项目刻意只绑定路径清单，HIGH-4 应降级为注释/测试名误导。
3. `review.md` 是否应在 dev worktree 物理排除不完全确定。设计说单写者与 merge gate REJECT，但也承认 sparse-checkout 是 advisory；若团队接受 dev 可见 review.md、仅靠 merge gate 拦写，则 MEDIUM-3 属测试说明不足而非实现缺陷。
4. 未运行 bats，所有结论基于静态逐文件阅读与关键被测脚本抽查；个别输出文案断言是否实际通过未验证。
