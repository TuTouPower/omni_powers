# 测试分块审阅报告 — sonnet 视角

**审阅范围**: tests/ 目录 16 个测试文件（README.md + 14 个 .bats + 1 个 .bash）
**审阅基准**: docs/omni_powers_design.md（核心参考）

---

## 一、整体评价

测试套件覆盖了核心脚本的关键路径：P0 阻断（op_check_p0）、状态流转（op_status）、worktree 隔离（op_worktree_setup）、trailer 自锁（op_trailer_unlock）、verdict 判读（op_read_verdict）、checkpoint 幂等（op_checkpoint）、hook 拦截（pre_tool_use/run-hook）等。结构上采用 bats + helpers.bash 共享 fixture，每个 @test 独立隔离，设计合理。

**核心缺口**：lite profile（OP_PROFILE=lite）路径的测试覆盖严重不足。Design §5.5 明确列出多个脚本在 lite 下有行为分支（op_close_post、op_close_pre、op_check_env、close_check 等），但几乎所有测试都在 heavy 路径上运行。lite 退化矩阵（§5.7）的行为变更缺乏回归保护。

---

## 二、逐文件审阅

### 1. helpers.bash

#### 问题 1.1: tasks_list.json mock 使用中文状态值，与 design ASCII 枚举不一致
- **位置**: helpers.bash:23，status 字段值为 `"收口中"`
- **现象**: Design §1.1 明确 status 枚举为 ASCII 值：`pending|ready|in_progress|reviewing|closing|done|suspended|blocked|obsolete`。文档强调"脚本内 jq/grep 比较一律用左列 ASCII 值"。mock 数据使用中文值 `"收口中"` 意味着被测脚本（op_close_post.sh 等）内部也使用中文状态值做比较。
- **影响**: 若被测脚本确实用中文值做内部比较，则与 design 的"脚本内比较用 ASCII"约定冲突，locale 差异可能导致跨平台 jq/grep 匹配失败。若被测脚本实际用 ASCII 比较，则 mock 数据的中文值会导致测试验证不到真实的生产路径。
- **建议**: 统一为 ASCII 值。首选方案：mock 数据改用 ASCII status（如 `"closing"`），被测脚本同步改为 ASCII 内部比较（渲染层单独映射中文）。次选方案：在 design 中澄清此处未对齐的原因。
- **置信度**: 高
- **优先级**: HIGH

#### 问题 1.2: OP_HOME 硬编码为仓库根，未区分开发/生产安装路径
- **位置**: helpers.bash:6-7
- **现象**: `OP_HOME="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"` 将 OP_HOME 设为 omni_powers 仓库根。生产环境中 OP_HOME 指向 `~/.claude/`（或 install.sh 写入的位置），脚本寻址路径不同（如 `~/.claude/scripts/omni_powers/` vs 仓库 `skills/` 子目录）。
- **影响**: 无法验证 `${OP_SCRIPT_ROOT:-$OP_HOME}` fallback 链（design §5.4）的生产路径。
- **建议**: 在 helpers.bash 添加注释说明 OP_HOME 在此处仅作测试环境脚本寻址，非生产安装路径。未来可考虑创建独立测试 fixture 模拟 `~/.claude/` 安装结构。
- **置信度**: 中
- **优先级**: MEDIUM

#### 问题 1.3: mock tasks_list.json 缺少 D9 新增的 eval/eval_reason 字段
- **位置**: helpers.bash:22-24
- **现象**: Design §2.4 和 §0.2 能力矩阵中，task schema 新增了 `eval: "required"|"skip"` 和 `eval_reason` 字段（D9）。当前 mock 不包含这两个字段。
- **影响**: 未来依赖 eval/eval_reason 字段的测试（如 oprun dispatch 时非行为型 task 免派判据）无法验证。
- **建议**: 在 mock tasks_list.json 中补充 eval/eval_reason 字段，至少包含默认值 `"eval": "required"`。
- **置信度**: 中
- **优先级**: MEDIUM

#### 问题 1.4: mock project 未包含 op_blueprint/specs/ 目录场景
- **位置**: helpers.bash:16-18
- **现象**: setup_mock_project 创建了 `docs/omni_powers/op_execution/` 和 `op_record/` 的子目录，但未创建 `op_blueprint/specs/`。部分测试（如 pre_tool_use spec 写保护）在自己的 @test 中单独创建。
- **影响**: 共享 fixture 的一致性降低。
- **建议**: 非必须——部分测试明确需要干净环境。维持现状可接受。
- **置信度**: 低
- **优先级**: LOW

---

### 2. close_check.bats

#### 问题 2.1: 仅覆盖 heavy 路径
- **位置**: close_check.bats 全部
- **现象**: 测试调用 `$OP_HOME/skills/oprun/scripts/` 下的脚本，属于 heavy 路径。Design §5.5 中 `close_check.sh` 的 lite 分支差异为"完成态定义随状态机"——两版差异之一是 lite 无"收口中"态，完成态判定逻辑不同。
- **影响**: lite 下 close_check.sh 的完成态判定逻辑缺乏测试。
- **建议**: 增加 OP_PROFILE=lite 的 close_check 测试用例。
- **置信度**: 中
- **优先级**: MEDIUM

---

### 3. op_check_env.bats

#### 问题 3.1: 测试不够完整——缺少 jq/git 缺失场景
- **位置**: op_check_env.bats 全部
- **现象**: 测试覆盖了 OP_HOME 未设、OP_HOME 指向错、环境就绪三种场景，但未覆盖 jq 或 git 未安装的情况。Design §1.1 明确 jq 是必需依赖。
- **影响**: jq 缺失时 op_check_env.sh 的 fail-fast 行为未被测试验证。
- **建议**: 考虑在测试中通过 PATH 操纵模拟 jq/git 缺失场景（可用 mock 脚本替代），但需注意不破坏其他依赖 jq 的测试。
- **置信度**: 低（受限于 bats 环境隔离能力）
- **优先级**: LOW

#### 问题 3.2: 缺少 lite profile 路径测试
- **位置**: op_check_env.bats 全部
- **现象**: Design §5.5：op_check_env.sh 在 lite 下"只校验 jq/git（跳过 OP_HOME 段）"。测试未覆盖 OP_PROFILE=lite 时跳过 OP_HOME 校验的行为。
- **影响**: lite 下的环境检查行为缺乏测试。
- **建议**: 增加 OP_PROFILE=lite 的测试用例。
- **置信度**: 高
- **优先级**: MEDIUM

---

### 4. op_check_p0.bats

#### 问题 4.1: 测试覆盖良好，缺少"issues 目录存在但空"的场景
- **位置**: op_check_p0.bats
- **现象**: 测试覆盖了无 issues 目录、仅有 P2 issue、open P0、closed P0 四种场景，但未覆盖 issues 目录存在但无 .md 文件（即空目录或仅有非 .md 文件）的场景。脚本可能因 `find` 无结果而静默通过，也可能因 glob 扩展失败报错。
- **建议**: 增加"issues 目录存在但空"的测试用例，验证 exit 0 行为。
- **置信度**: 中
- **优先级**: MEDIUM

#### 问题 4.2: 测试环境未模拟 docs/omni_powers 完整结构
- **位置**: op_check_p0.bats:setup()
- **现象**: setup 直接创建 `mktemp -d` 临时目录，未创建 git 仓库或 docs/omni_powers 骨架。脚本 `op_check_p0.sh` 在工作目录而非固定路径下查找 issues 目录（`cd "$TEST_DIR"`），测试依赖此假设。若脚本改为固定路径查找（如 `$CLAUDE_PROJECT_DIR/docs/omni_powers/`），测试将失效。
- **影响**: 测试与脚本实现细节耦合。
- **建议**: 显式在 setup 中创建 docs/omni_powers/op_execution/issues/ 完整路径，降低耦合。
- **置信度**: 低
- **优先级**: LOW

---

### 5. op_checkpoint.bats

#### 问题 5.1: TID 锚定测试仅覆盖 T01 vs T010 前缀场景
- **位置**: op_checkpoint.bats:23-31
- **现象**: 测试验证 T01 不误配 T010（TID 锚定），仅覆盖前缀匹配场景。Design TID 编码为固定四位数（T0001...），若 mock 使用 T0001/T0010 格式，用例会更贴近生产。当前 mock 使用 T01/T010（非固定宽度），与 design 编码规范不完全一致。
- **影响**: 测试覆盖到核心逻辑（精确匹配），但编码规范不一致可能导致未来 TID 宽度扩展时的 edge case。
- **建议**: 将 mock TID 改为 T0001/T0010 格式，对齐 design §1 编码约定。
- **置信度**: 低
- **优先级**: LOW

#### 问题 5.2: 未测试多 task 场景下 checkpoint 的顺序追加
- **位置**: op_checkpoint.bats 全部
- **现象**: 测试仅覆盖单 task 追加与幂等。未覆盖多个 task 依次 checkpoint 追加后 leader_checkpoint.md 的正确顺序。
- **建议**: 增加多 task 依次 checkpoint 的测试用例。
- **置信度**: 低
- **优先级**: LOW

---

### 6. op_ci_local.bats

#### 问题 6.1: 缺少 OP_E2E_CMD 和 OP_BUILD_CMD 单独设置的分支测试
- **位置**: op_ci_local.bats 全部
- **现象**: 测试覆盖了三接口全设、全 SKIP、只设 TEST 三种场景。缺少只设 E2E、只设 BUILD、TEST+E2E、TEST+BUILD 的组合场景覆盖。
- **建议**: 增加只设 OP_E2E_CMD 和只设 OP_BUILD_CMD 的测试用例。至少补充 E2E 单独场景。
- **置信度**: 中
- **优先级**: MEDIUM

---

### 7. op_close_post.bats

#### 问题 7.1: 缺少 review.md 文件完全缺失的测试
- **位置**: op_close_post.bats 全部
- **现象**: 测试覆盖了 review 缺 verdict 行（第 33-40 行），但未覆盖 review.md 文件不存在的情况。若 reviewer 崩溃 review.md 未落盘，op_close_post.sh 应明确 die 而非静默继续。
- **建议**: 增加 `@test "op_close_post: 无 review.md die"` 测试用例。
- **置信度**: 高
- **优先级**: MEDIUM

#### 问题 7.2: 完全缺少 lite profile 路径的测试（重大缺口）
- **位置**: op_close_post.bats 全部
- **现象**: Design §5.5 明确：`op_close_post.sh` 在 lite 下"跳过 `status=closing` 前置检查；完成态用 lite 状态机"。所有测试均在 heavy 路径（有 closing 态、有 `git mv` 归档）。lite 下收口是 leader 瞬时操作（review PASS 直接 op_close_post，无需 op_close_pre 先标 closing），行为差异未验证。
- **影响**: lite 路径收口逻辑缺乏回归保护——若 heavy 路径的 closing 前置检查变更，漏测 lite 分支可能导致 lite 收口失败（误报 closing 态不存在）。
- **建议**: 增加 OP_PROFILE=lite 的测试用例，至少覆盖：
  - lite 下不检查 `status=closing`
  - lite 下完成态标记为 `done`（非 `closing→done` 两段）
- **置信度**: 高
- **优先级**: HIGH

---

### 8. op_mutation_check.bats

#### 问题 8.1: 测试覆盖良好，范围与 design 一致
- **位置**: op_mutation_check.bats 全部
- **现象**: 测试覆盖 KILLED/ESCAPE/SKIP 三条路径，与 design §3.3 中"骨架做 == ↔ != 变异自检"的定位一致。测试结构清晰：隔离临时目录创建被测脚本 + 测试脚本。
- **建议**: 无关键问题。可考虑增加复合条件（如 `[ "$1" == "$2" ] && [ "$3" == "$4" ]`）中 == 的变异测试。
- **置信度**: 低
- **优先级**: LOW

---

### 9. op_read_verdict.bats

#### 问题 9.1: 缺少"两轮均为 FAIL"的末行判定测试
- **位置**: op_read_verdict.bats 全部
- **现象**: 重审追加测试（第 31-39 行）覆盖了 FAIL→PASS（末行 PASS，exit 0）。缺少两轮都是 FAIL（末行 FAIL，exit 1）的场景。末行取最后一条 verdict 的逻辑应在多个 FAIL 追加的场景下验证。
- **建议**: 增加"两轮均 FAIL"的测试用例，验证 exit 1 且 result: FAIL。
- **置信度**: 中
- **优先级**: MEDIUM

#### 问题 9.2: 缺少"verdict 行后有空白行"的测试
- **位置**: op_read_verdict.bats 全部
- **现象**: 若 review.md 末行 verdict 后还有空行/注释行，`tail -1` 可能取到非 verdict 行。测试未覆盖此 edge case。
- **建议**: 增加 review.md 末尾有空白行的测试用例。
- **置信度**: 低
- **优先级**: LOW

---

### 10. op_status.bats

#### 问题 10.1: 状态值与中文渲染混淆
- **位置**: op_status.bats:7-45 全部
- **现象**: 测试使用中文状态值 `"阻塞"`、`"完成"` 调用 op_status.sh。与问题 1.1 一致——design §1.1 规定 ASCII 枚举为机读值，中文为渲染层映射。若被测脚本 `op_status.sh` 接受中文值做内部 jq 比较，则违反 design 约定；反之若脚本接受 ASCII 值做内部比较但接受中文命令行参数并内部转换——需确认被测脚本的实际行为。
- **建议**: 与问题 1.1 联合决策——统一为 ASCII 值。
- **置信度**: 高
- **优先级**: HIGH（与问题 1.1 绑在一起）

#### 问题 10.2: 缺少 lite 状态下"收口中"态不存在的验证
- **位置**: op_status.bats 全部
- **现象**: Design §5.6：lite 状态机去"收口中"态。测试未覆盖 lite profile 下 `op_status.sh` 拒绝 `closing` 状态的行为。
- **建议**: 增加 OP_PROFILE=lite 时设置 `closing` 状态应 die 的测试。
- **置信度**: 中
- **优先级**: MEDIUM

---

### 11. op_trailer_unlock.bats

#### 问题 11.1: 测试与 design 对齐良好，但 spec 写保护测试放在此处组织不当
- **位置**: op_trailer_unlock.bats:55-61
- **现象**: `pre-commit: approved spec 写保护` 测试验证的是 git pre-commit hook 拦截 approved spec 变更。这与 trailer 解锁无关——spec 写保护是独立的 concern（design §3.3 防线层 4）。
- **影响**: 测试文件组织不够清晰，spec 写保护测试混在 trailer 测试中。
- **建议**: 将 spec 写保护的 pre-commit 测试移至独立测试文件或与 pre_tool_use.bats 合并。
- **置信度**: 低（风格建议）
- **优先级**: LOW

#### 问题 11.2: trailer 重放检测测试仅覆盖 staged 变更场景
- **位置**: op_trailer_unlock.bats:63-73
- **现象**: `staged 变了中国旧 trailer 失效` 测试验证了 staged 文件变更后旧 trailer 失败。但 design §2.5 提到 "trailer 由解锁脚本一次性生成、绑定 commit-sha 防重放"。当前测试未覆盖"同一 staged 在不同 commit 上重放 trailer"的场景（即 staged 不变但 commit-sha 变）。
- **影响**: commit-sha 变更场景的重放检测可能缺少测试。
- **建议**: 考虑增加同一 staged 在不同 base commit 上使用同一 trailer 的测试。
- **置信度**: 低
- **优先级**: LOW

---

### 12. op_worktree_setup.bats

#### 问题 12.1: dev worktree 未验证 spec 文件可访问性
- **位置**: op_worktree_setup.bats:29-34
- **现象**: dev worktree 测试验证了 src 存在、e2e 排除，但未验证 implementer 所需的 spec 文件（`docs/omni_powers/op_execution/specs/`）是否在 worktree 中可读。Design §3.4：implementer 需要只读访问 spec。
- **建议**: 在 dev worktree 测试中增加 spec 文件可访问性断言。
- **置信度**: 中
- **优先级**: MEDIUM

#### 问题 12.2: eval worktree 未验证 spec 文件可访问性
- **位置**: op_worktree_setup.bats:36-43
- **现象**: eval worktree 测试验证了 src/tasks/decisions 排除、e2e 保留，但未验证 evaluator 所需的 spec 文件是否在 worktree 中可读。Design §2.5：evaluator 需要读工作 spec + 生效规格。
- **建议**: 在 eval worktree 测试中增加 spec 文件可访问性断言。
- **置信度**: 中
- **优先级**: MEDIUM

#### 问题 12.3: 缺少 lite profile 下的行为测试
- **位置**: op_worktree_setup.bats 全部
- **现象**: Design §5.1：lite 无分支拓扑/worktree。若 lite 下误调 op_worktree_setup.sh（无论是 dev 还是 eval），应当报错或 die。当前无此场景的测试。
- **建议**: 增加 OP_PROFILE=lite 时 op_worktree_setup.sh 应 die 的测试。
- **置信度**: 中
- **优先级**: MEDIUM

#### 问题 12.4: git 版本检查在 setup 中，跳过时其他测试也跳过
- **位置**: op_worktree_setup.bats:11
- **现象**: setup 中使用 `skip` 在 git < 2.25 时跳过整个文件。这是正确的行为（sparse-checkout 不可用），但未输出明确信息说明为什么跳过。
- **建议**: 在 skip 后加一条提示信息（bats skip 支持 reason 参数）。
- **置信度**: 低
- **优先级**: LOW

---

### 13. opinit_register_hooks.bats

#### 问题 13.1: concat 不覆盖用户 hooks 的测试仅验证 PreToolUse 数量
- **位置**: opinit_register_hooks.bats:36-48
- **现象**: 测试验证了 concat 后 PreToolUse 条数 >=2 且用户 hook 保留。未验证用户 hook 的顺序位置是否正确（用户 hook 在 omni_powers hook 前面？后面？）。错误的顺序可能导致 hook 执行优先级问题。
- **建议**: 增加对 hook 顺序的断言。
- **置信度**: 低
- **优先级**: LOW

#### 问题 13.2: 缺少 Windows wrapper 改写测试
- **位置**: opinit_register_hooks.bats 全部
- **现象**: tests/README.md 提到 opinit_register_hooks.bats 覆盖"Windows wrapper 改写"。当前测试文件中没有 Windows wrapper 相关测试。README 与实际测试不一致。
- **影响**: Windows 路径下的 polyglot wrapper 行为缺乏测试，README 的描述可能过时。
- **建议**: 更新 tests/README.md 的描述以反映实际覆盖范围，或补充 Windows wrapper 测试。
- **置信度**: 中
- **优先级**: MEDIUM

---

### 14. opinit_skeleton.bats

#### 问题 14.1: 幂等测试仅验证 tasks_list.json 和 checkpoint 保留
- **位置**: opinit_skeleton.bats:34-45
- **现象**: 幂等测试验证了 tasks_list.json 和 leader_checkpoint.md 内容保留不被覆盖。未验证已存在的目录（如 tasks/、specs/ 等）在重跑时不被删除。未验证新目录（如果 skeleton 后期新增）在幂等重跑时能补齐。
- **影响**: 新增目录的幂等补齐行为未知。
- **建议**: 增加重跑时新增目录能补齐的测试。
- **置信度**: 低
- **优先级**: LOW

#### 问题 14.2: profile 互斥 die 测试正确
- **位置**: opinit_skeleton.bats:53-59
- **现象**: 测试验证了已有 profile=lite 时重跑 opinit_skeleton 应 die——对齐 design §5.2 互斥保护。
- **建议**: 无问题。
- **置信度**: —
- **优先级**: —

---

### 15. pre_tool_use.bats

#### 问题 15.1: baselines subagent 写拦测试的有效范围缺乏说明
- **位置**: pre_tool_use.bats:40-47
- **现象**: 测试验证当 stdin JSON 包含 `agent_type` 字段时，baselines 写入被拦截（exit 2）。但 design §0.1/§3.3 明确：**hook deny 对 subagent 整体失效**——Claude Code subagent 不触发 PreToolUse hook。因此 production 中 subagent 写入 baselines 不会经过这个 hook。此测试验证的是"hook 脚本内部实现了 agent_type 检查逻辑"，但此逻辑在 production 中不会被触发。
- **影响**: 测试给人"subagent 被保护"的假象，但实际防线在 merge gate（§3.4）和 closer gate（§2.6）。
- **建议**: 在测试中添加注释说明：此测试验证 hook 脚本实现完备性（agent_type 字段能正确触发拦截），但 production 中 subagent 不会触发此 hook——真正的防线在 merge gate 和 closer gate（design §0.2 能力矩阵、§2.6 closer gate 机械校验）。
- **置信度**: 高
- **优先级**: MEDIUM

---

### 16. run-hook.bats

#### 问题 16.1: polyglot wrapper 测试正确但范围有限
- **位置**: run-hook.bats 全部
- **现象**: 测试验证了 polyglot wrapper 路径路由、缺 hook 名 die、自动补 .sh 扩展名。Windows CMD 路径在 Linux 无法测（tests/README.md 声明了此限制）。测试范围适当。
- **建议**: 无关键问题。
- **置信度**: —
- **优先级**: —

---

## 三、全局问题

### 问题 G1: lite profile 路径的测试覆盖严重不足（最高优先级）

**涉及文件**: op_close_post.bats、op_status.bats、op_check_env.bats、close_check.bats、op_worktree_setup.bats

Design §5.5 明确列出 10 个脚本在 lite 下有行为分支差异。当前测试套件几乎所有测试都在 heavy 路径上运行。以下 lite 特有行为完全没有测试：

| 脚本 | lite 差异（design §5.5） | 测试状态 |
|---|---|---|
| op_close_post.sh | 跳过 status=closing 前置检查；完成态用 lite 状态机 | 无 lite 测试 |
| op_close_pre.sh | lite 不调用 | 无需测试（但应验证 lite 下调此脚本 die） |
| op_check_env.sh | 只校验 jq/git（跳过 OP_HOME 段） | 无 lite 测试 |
| close_check.sh | 完成态定义随状态机 | 无 lite 测试 |
| op_assemble_eval_brief.sh | 裸评简化：跳基线/baselines 段 + 剥探索结论 | 无测试（不在本分块） |

**影响**: lite 退化矩阵（design §5.7）的行为变更无法被回归验证。heavy 路径修改可能意外破坏 lite 分支。

**建议**:
1. 新增 `op_lite_profile.bats` 或在各测试文件中增加 `OP_PROFILE=lite` 的参数化测试
2. 至少覆盖 op_close_post.sh lite 分支（跳过 closing 检查）+ op_check_env.sh lite 分支（跳过 OP_HOME 检查）

**置信度**: 高
**优先级**: HIGH

### 问题 G2: ASCII 状态枚举与中文渲染未在测试中分离

**涉及文件**: helpers.bash、op_status.bats、op_close_post.bats

Design §1.1 定义了 ASCII 机读值 + 中文渲染映射的双层模型，但 helpers.bash mock 数据和 op_status.bats 测试断言均使用中文值。这不一定是 bug（被测脚本可能确实接受中文参数），但若被测脚本内部使用中文做 jq 比较，则违背 design 约定——跨平台 locale 差异可能导致匹配失败。

**建议**: 在 design 与测试之间做出选择：要么统一为 ASCII 机读值（推荐），要么在 design 中声明当前阶段中文值是临时方案。

**置信度**: 高
**优先级**: HIGH

### 问题 G3: tests/README.md 覆盖表与测试实际内容存在偏差

**位置**: tests/README.md:30-41

| README 声称覆盖 | 实际测试内容 | 偏差 |
|---|---|---|
| opinit_register_hooks.bats: Windows wrapper 改写 | 无 Windows wrapper 测试 | README 描述与实际不符 |
| op_status.bats: P1-5 阻塞强校验 blocked_by、状态流转 | 状态流转覆盖 parcial（缺 lite 路径） | 覆盖范围描述过于宽泛 |
| close_check.bats: P2-6 TID 精确匹配（不误配 T010）| TID 精确匹配测试实际在 op_checkpoint.bats 中（P1-7），不在 close_check.bats 中 | 覆盖归属不一致 |

**建议**: 更新 tests/README.md 覆盖表以反映实际测试内容。将 TID 锚定测试的正确归属标注清楚（属于 op_checkpoint.bats）。

**置信度**: 中
**优先级**: MEDIUM

---

## 四、按能力矩阵对照（design §0.2）

| 防线/能力 | 对应测试文件 | 覆盖程度 | 缺口 |
|---|---|---|---|
| implementer e2e 排除 | op_worktree_setup.bats (dev) | 基本覆盖 | 缺少 spec 可访问性验证（§12.1） |
| evaluator src 排除 | op_worktree_setup.bats (eval) | 基本覆盖 | 缺少 spec 可访问性验证（§12.2）；缺少 lite 下 die 测试（§12.3） |
| merge gate | 无直接测试 | 未覆盖 | `op_merge_gate.sh` 无对应的 bats 测试文件 |
| e2e/BUG-* trailer 自锁 | op_trailer_unlock.bats | 良好 | 缺少不同 commit-sha 重放测试（§11.2） |
| spec 写保护 | pre_tool_use.bats + op_trailer_unlock.bats | 基本覆盖 | subagent 场景的有效性缺乏说明（§15.1） |
| reviewer 双裁决 | op_read_verdict.bats | 良好 | 缺少两轮 FAIL 场景（§9.1） |
| closer gate | 无直接测试 | 未覆盖 | `op_closer_gate.sh` 无对应的 bats 测试文件 |
| lite P0 处置 | op_check_p0.bats | 良好 | 缺少空目录场景（§4.1） |
| scripts/ 基础套件 | op_close_post/op_status/op_checkpoint/close_check | 中等 | lite 路径全面缺失（G1） |

**最显著的测试盲区**：
1. `op_merge_gate.sh` — 这是 design 中"写入硬底线所在"（§3.4），能力矩阵中级别为"硬"，但没有任何 bats 测试
2. `op_closer_gate.sh` — 同样标记为"硬"级别，无测试
3. lite 全路径 — 如上 G1

---

## 五、总结

测试套件整体结构合理，bats + helpers.bash 模式运行良好。核心问题三条：

1. **lite profile 路径测试全面缺失**（HIGH）——多个脚本的 lite 行为分支无回归保护，是当前最紧迫的缺口
2. **ASCII 状态枚举 vs 中文渲染混淆**（HIGH）——mock 数据与测试断言使用中文值，与 design 约定冲突
3. **merge gate 和 closer gate 两个"硬"防线无 bats 测试**（MEDIUM）——虽然当前阶段 merge gate 可能尚在施工，但测试先行可防回归
