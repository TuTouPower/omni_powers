# 测试分块审阅报告 — Opus 视角

**审阅范围**: tests/ 目录下的 17 个文件（README.md + 1 个 bash helper + 15 个 bats 测试文件）
**审阅基准**: docs/omni_powers_design.md（核心设计参考，重构后版本）

---

## 一、 整体评价

测试套件整体涵盖了 omni_powers 目前已落地的核心脚本与机械防线，包括 worktree 隔离（op_worktree_setup）、trailer 自锁与 spec 写保护（op_trailer_unlock / pre_tool_use）、状态机与 checkpoint 管理（op_status / op_checkpoint）、verdict 判定（op_read_verdict）以及变异测试骨架（op_mutation_check）。使用 bats 结合共享 git 仓库 fixture（helpers.bash）进行隔离测试，方法设计得当。

然而，通过对照 `docs/omni_powers_design.md` 的最新设计（多模型审阅决策落地重构）与目前测试源码，发现了**严重的“测试与实现同步断裂”与“核心安全防线覆盖缺口”**：
1. **机读状态同步断裂（导致测试套件大面积红）**：测试 fixture 与用例仍在使用旧中文状态枚举（如 `"收口中"`、`"完成"`），而底层脚本已重构为 ASCII 机读值（如 `"closing"`、`"done"`）。
2. **测试与已废弃设计脱节**：测试仍在断言已被移除的 `SessionStart` hook，且在测试一个实际上已经被删除的脚本 `op_ci_local.sh`。
3. **关键安全防线无回归保护**：design 声明为“写入硬底线”的 `merge gate`，以及最近落地的 `op_closer_gate.sh`，在测试套件中均处于**零覆盖**状态。

---

## 二、 逐文件审阅

### 1. tests/README.md
- **问题 1.1: 覆盖范围表与实际测试文件严重不同步**
  - **位置**: `tests/README.md:30-41`
  - **现象**: 覆盖范围表仅列出了 10 个测试文件。而 `tests/scripts/` 目录下实际有 16 个测试文件（缺少了 `op_check_p0.bats`、`op_ci_local.bats`、`op_mutation_check.bats`、`op_trailer_unlock.bats`、`op_worktree_setup.bats`、`op_read_verdict.bats` 等）。
  - **影响**: 降低了测试文档的透明度，维护者无法通过 README 获取真实的测试覆盖矩阵。
  - **建议**: 补齐表格，对齐 design 对应章节，将新增的 bats 测试文件全部纳入索引。
  - **置信度**: 高 | **优先级**: P3

---

### 2. tests/scripts/helpers.bash
- **问题 2.1: mock data 状态使用旧中文值，引发大面积测试失败**
  - **位置**: `helpers.bash:23`
  - **现象**: fixture 中 `"status": "收口中"` 使用了中文。根据 design §1.1，`tasks_list.json.status` 的机读值必须是 ASCII 枚举（如 `closing`）。
  - **影响**: 导致凡是依赖 `helpers.bash` 建立初始 task 状态并调用 `op_status.sh` 或 `op_close_post.sh` 的测试全部报错（如 `op_status.sh` 拒绝非 ASCII 状态）。
  - **建议**: 将 mock 数据中的 `"status"` 改为 ASCII（例如 `"closing"`）。
  - **置信度**: 高 | **优先级**: P1

- **问题 2.2: mock data task schema 包含已废弃的冗余字段**
  - **位置**: `helpers.bash:23`
  - **现象**: 仍保留 `"type": "实现"`、`"covers_ac": ["AC-1"]`、`"touches_inv": []`、`"risk_probe": false` 等字段。根据 design §2.3，当前 schema 仅包含 `id/title/status/spec/depends_on/workset`。
  - **影响**: fixture 偏离了真实的 spec intake 拆分产物，无法验证新脚本对精简后 schema 的鲁棒性。
  - **建议**: 对齐 design §2.3 的 task schema，精简 mock JSON 结构，并补上 `eval` 和 `eval_reason`（D9 规划中字段）。
  - **置信度**: 高 | **优先级**: P2

---

### 3. tests/scripts/close_check.bats
- **问题 3.1: 缺乏对 lite profile 路径的覆盖**
  - **位置**: 全文
  - **现象**: 仅在默认的 heavy 模式下测试 `close_check.sh`。Design §5.5 中，`close_check.sh` 在 lite 分支的差异是“完成态定义随状态机”（无 `closing` 状态，判定时序不同）。
  - **影响**: 无法验证 lite 模式下 `close_check.sh` 判定 done 的正确性。
  - **建议**: 引入 `OP_PROFILE=lite` 环境参数，增加对应的测试用例。
  - **置信度**: 中 | **优先级**: P2

---

### 4. tests/scripts/op_check_env.bats
- **问题 4.1: 未覆盖 lite 模式下的退化检查逻辑**
  - **位置**: 全文
  - **现象**: Design §5.5 规定，`op_check_env.sh` 在 lite 下“只校验 jq/git（跳过 OP_HOME 段）”。而测试用例均基于 heavy 假设（强制校验 OP_HOME 是否未设或指向错）。
  - **影响**: 在 lite 模式下运行此脚本时，跳过 OP_HOME 的行为没有经过测试验证，可能在 lite 下引入非预期的阻断。
  - **建议**: 增加 `OP_PROFILE=lite` 时不因 `OP_HOME` 缺失而 die 的断言。
  - **置信度**: 高 | **优先级**: P2

---

### 5. tests/scripts/op_check_p0.bats
- **问题 5.1: 固化了已被废弃的“事中阻断”语义**
  - **位置**: `op_check_p0.bats:30-38`
  - **现象**: 该用例断言“有 open P0 → exit 1”。但这与最新设计 design §5.8 / A18 明确声明的“P0 issue 不事中阻断归档，只进结束报告标注，事后处置”相违背。
  - **影响**: 该测试阻碍了向“事后知情 + 不事中阻断”这一自主性设计（autonomy-first）的迁移，修复时容易将阻断重新引入 `oplrun`。
  - **建议**: 重新设计 `op_check_p0` 的测试行为，断言其仅作为结束报告的数据汇总器，退出码应为 0（不阻断归档），同时确保输出包含 P0 清单。
  - **置信度**: 高 | **优先级**: P1

---

### 6. tests/scripts/op_checkpoint.bats
- **问题 6.1: 幂等性与 TID 锚定测试使用了中文状态逻辑**
  - **位置**: `op_checkpoint.bats:25`
  - **现象**: 用例在 mock tasks_list.json 中追加了 `"status": "完成"` 的 task，继续使用了旧的中文状态。
  - **影响**: 与 `op_status` 转移到 ASCII 的规范冲突，无法保障在纯 ASCII 环境下的 checkpoint 读写幂等性。
  - **建议**: 将追加的测试任务状态改为 `"done"`。
  - **置信度**: 高 | **优先级**: P1

---

### 7. tests/scripts/op_ci_local.bats
- **问题 7.1: 测试了一个在仓库中已经被废弃和删除的脚本**
  - **位置**: `op_ci_local.bats:6`
  - **现象**: 脚本指向 `$REPO/scripts/op_ci_local.sh`。然而在 commit `709afb3` 中，该脚本已经被彻底删除。实跑测试时，bats 产生警告 `exited with code 127`，测试用例全部失败。
  - **影响**: 死测试污染套件，破坏了测试绿线的可信度。
  - **建议**: 鉴于 design 声明该回归 CI 属于 P2+/P3 阶段规划，应将该测试文件删除，或者将测试用例置为 `skip` 并加上说明。
  - **置信度**: 极高 | **优先级**: P1

---

### 8. tests/scripts/op_close_post.bats
- **问题 8.1: 调用底层脚本传入中文状态导致测试失败**
  - **位置**: `op_close_post.bats:15-16`
  - **现象**: 实跑该测试时，由于 `op_close_post.sh` 内部直接调用了 `bash "$OP_HOME_DIR/scripts/op_status.sh" "$TID" 完成`（中文“完成”），导致其因无效状态而报错中断，测试用例 `verdict PASS 归档` 失败。
  - **影响**: 暴露出不仅测试用例有遗留中文，`op_close_post.sh` 脚本本身也有未清理的中文状态调用。
  - **建议**: 修复 `op_close_post.sh` 中的调用，将 `"完成"` 改为 `"done"`；测试用例中对应断言也应进行 ASCII 对齐。
  - **置信度**: 高 | **优先级**: P1

---

### 9. tests/scripts/op_mutation_check.bats
- **问题 9.1: 变异测试用例断言较弱，未涵盖多运算符场景**
  - **位置**: 全文
  - **现象**: 用例仅验证了包含单个 `==` 运算符的简单场景。如果源文件包含多个 `==` 或混杂 `!=`，此简易 sed 替换（`s/==/__MUT_EQ_PLACEHOLDER__/g; ...`）是否会破坏语法导致编译失败，没有进行边界验证。
  - **影响**: 作为定期体检的变异自检骨架，若在稍复杂的 shell 代码上运行可能直接因语法错误 die，而非正常产出 ESCAPE。
  - **建议**: 增加包含多个运算符混合的源文件 mock 场景，确保测试能正确识别并回滚。
  - **置信度**: 中 | **优先级**: P3

---

### 10. tests/scripts/op_read_verdict.bats
- **问题 10.1: 未校验 verdict 格式的容错性**
  - **位置**: 全文
  - **现象**: 测试仅覆盖了严格的 `verdict: PASS` / `verdict: FAIL` 场景。但由于 verdict 是写在 `review.md` 中的，如果有前导空格、空行或大小写偏差（如 `Verdict: Pass`），脚本的判定逻辑未在测试中体现。
  - **影响**: 实际 review 产物是由 leader 或 reviewer 手写/追加的，格式微调可能导致 `op_read_verdict.sh` 误判为 `NONE`。
  - **建议**: 增加带前导空格、大小写混合、多余后缀等容错格式的 verdict 判定测试。
  - **置信度**: 中 | **优先级**: P2

---

### 11. tests/scripts/op_status.bats
- **问题 11.1: 阻塞状态校验测试依旧基于旧中文状态，导致全面失败**
  - **位置**: 全文
  - **现象**: 用例依旧使用 `阻塞`、`完成`、`无效状态` 作为参数传递给 `op_status.sh`，并且断言 jq 写入的 status 是 `"阻塞"` 这一中文。由于 `op_status.sh` 已移至 ASCII，这些用例在执行时全部被 `die` 拦截。
  - **影响**: 该测试处于完全损坏状态，无法锁住 design §1.1 规定的 ASCII 状态强校验契约。
  - **建议**: 将用例全部重构为 ASCII：`阻塞` → `blocked`，`完成` → `done`。
  - **置信度**: 高 | **优先级**: P1

- **问题 11.2: 缺少对 --batch 批量处理能力的覆盖**
  - **位置**: 全文
  - **现象**: `op_status.sh` 支持 `--batch` 批量更新状态（见其代码 :23-26, 62-68），但 `op_status.bats` 中没有任何关于批量更新的测试用例。
  - **影响**: 批量更新作为关键调度功能，存在重大的回归隐患。
  - **建议**: 增加批量测试用例，例如 `op_status.sh --batch T01,T02 done`，并断言两个任务的状态均被正确写入。
  - **置信度**: 高 | **优先级**: P2

---

### 12. tests/scripts/op_trailer_unlock.bats
- **问题 12.1: 缺少对 trailer 重放（Replay Attack）的防范测试**
  - **位置**: 全文
  - **现象**: 脚本只测试了“修改 staged 文件会导致 trailer 失效”，未测试“重放攻击”。根据 design §2.5，trailer 必须一次性生成并绑定 commit-sha。
  - **影响**: 如果底层代码仅绑定了 staged 清单而未结合 commit-sha（或 HEAD sha），攻击者可以通过复用旧 trailer 绕过对相同文件清单的多次篡改。
  - **建议**: 显式构造两个不同的 HEAD sha（通过提交其他无关文件），验证在 staged e2e 文件清单完全一致时，旧的 trailer 是否会在新 sha 上被拒绝。
  - **置信度**: 中 | **优先级**: P2

---

### 13. tests/scripts/op_worktree_setup.bats
- **问题 13.1: eval 排除校验中未测试 decisions.md 排除的真实性**
  - **位置**: `op_worktree_setup.bats:36-43`
  - **现象**: 虽有 `[ ! -f ".claude/wt/docs/omni_powers/op_record/decisions.md" ]` 断言，但 `setup` 中只在主仓创建了 decisions.md，没有在 mock 项目中真正创建 `op_record/tasks/` 归档目录。
  - **影响**: 漏测了 eval 隔离对归档 task 目录（`op_record/tasks/`）的排除保护，而这是 design §2.5 防止 evaluator 抄历史实现的重要规则。
  - **建议**: 在 `setup` 中显式创建 `docs/omni_powers/op_record/tasks/T00_old/report.md`，并在 eval 用例中增加对归档任务目录已被排除的断言。
  - **置信度**: 中 | **优先级**: P2

---

### 14. tests/scripts/opinit_register_hooks.bats
- **问题 14.1: 断言了已经被移除的 SessionStart hook**
  - **位置**: `opinit_register_hooks.bats:33`
  - **现象**: 测试断言中包含 `jq -e '.hooks.SessionStart' .claude/settings.json`。但根据 design A17/D8，由于 SessionStart 对 subagent 无效且易产生死循环，已经移除了该 hook 事件（settings.template.json 中已无此项）。
  - **影响**: 导致本测试在最新版本上必然报错，阻断测试通过。
  - **建议**: 移除此 SessionStart 的断言行。
  - **置信度**: 高 | **优先级**: P1

---

### 15. tests/scripts/opinit_skeleton.bats
- **问题 15.1: 缺乏对 profile 异常改写保护的校验**
  - **位置**: 全文
  - **现象**: 测试了 `profile=lite 时 die`，但未测试如果 `docs/omni_powers/profile` 缺失且目录非空时，脚本是否能安全拦截或提示混跑。
  - **影响**: 无法验证 design §5.2 的判定表边缘行为（如无 profile 且无 hook 痕迹时是否默认 die）。
  - **建议**: 增加“存在 specs 目录但无 profile 文件，重跑 skeleton 必须 die 拒绝”的边界测试。
  - **置信度**: 中 | **优先级**: P3

---

### 16. tests/scripts/pre_tool_use.bats
- **问题 16.1: spec 写保护拦截测试未隔离主会话/子代理身份**
  - **位置**: `pre_tool_use.bats:13-22`
  - **现象**: 测试中仅模拟了 Edit 输入，没有传递 `agent_type` 字段。在 design A18 引入后，PreToolUse 区分了“主会话（无 agent_type，放行）”与“子代理（有 agent_type，阻断）”。
  - **影响**: 目前测试通过是因为直接拦截了，但如果 leader 需要基于 closer 提案在主会话写入 approved spec 时，由于测试没能锁住“主会话不拦/子代理拦截”的区别，可能会在未来误改导致 leader 也被卡死。
  - **建议**: 增加两组对照测试：① 无 `agent_type`，编辑 approved spec 必须 PASS (exit 0)；② 携带 `"agent_type": "op-closer"`，编辑 approved spec 必须 BLOCKED (exit 2)。
  - **置信度**: 高 | **优先级**: P2

---

### 17. tests/scripts/run-hook.bats
- **问题 17.1: 仅覆盖了 .sh 自动补齐，未验证 hook 执行的错误透传**
  - **位置**: 全文
  - **现象**: 测试通过路由到 pre_tool_use 返回 exit 2 验证了 .sh 自动补齐。但没有验证当底层 hook 脚本异常退出（如语法错误返回 1）或权限不足时，wrapper 是否能如实透传非 2 退出码。
  - **影响**: 作为 hook 执行的 polyglot 核心入口，如果其错误退出码透传逻辑损坏，可能导致严重的拦截漏过。
  - **建议**: 新增测试：调用一个会返回 exit 1/127 的 mock 脚本，验证 `run-hook.cmd` 的退出码也是该值。
  - **置信度**: 中 | **优先级**: P3

---

## 三、 核心防线覆盖缺失审计（Design vs Tests）

依据 `docs/omni_powers_design.md` 的“§0.2 能力矩阵”，对测试覆盖的盲区进行统计：

| 能力/防线 (Design §0.2) | 对应脚本 | 目前测试覆盖 | 严重程度与影响 |
|---|---|---|---|
| **merge gate (写入硬底线)** | `scripts/op_merge_gate.sh` | **0%（无此测试文件）** | **P0 级**。这是整个 omni_powers 写入隔离最核心的物理防线（因为 hook 对子代理失效，sparse-checkout 仅是 advisory）。缺少该测试将无法保护白名单/黑名单校验逻辑，面临受保护路径被 subagent 静默篡改的回归风险。 |
| **closer gate (机械校验)** | `scripts/op_closer_gate.sh` | **0%（无此测试文件）** | **P1 级**。closer 权限最大，在主仓库上直接修改，没有 merge gate 约束。D3 已落地 `op_closer_gate.sh`，未进行任何 bats 覆盖，存在越界写入不退回的风险。 |
| **SubagentStop 完成门禁** | `hooks/stop.sh`（或 wrapper 调用的 stop 逻辑） | **0%** | **P1 级**。这是强迫 subagent 提交测试证据和任务状态的唯一门禁，缺乏测试导致 subagent 可以空手交工。 |

---

## 四、 总结与修复路径

当前测试套件处于**部分功能不可用**的状态，55 个用例中有 10 个实跑失败。主要原因在于状态机的 ASCII 化重构、SessionStart 的去除等架构决策在测试层未同步修改，属于典型的文档/测试漂移。

### 修复优先级建议：

1. **第一阶段 (P1 - 恢复绿线)**:
   - 彻底将 `helpers.bash`、`op_status.bats`、`op_checkpoint.bats`、`op_close_post.bats` 中的状态字段改为 ASCII。
   - 删除 `opinit_register_hooks.bats` 中对已废弃 `SessionStart` hook 的断言。
   - 删除或禁用 `op_ci_local.bats`（测试不存在的脚本）。
   - 重构 `op_check_p0.bats` 对齐 A18 不阻断的设计。
2. **第二阶段 (P1 - 补齐核心防线测试)**:
   - 新增 `tests/scripts/op_merge_gate.bats`，严格覆盖白名单机制（e2e/specs/blueprint 禁止 commit，workset/report.md 允许 commit，主仓 verdict 读取）。
   - 新增 `tests/scripts/op_closer_gate.bats`，覆盖越界 checkout 机制。
   - 新增 `tests/scripts/subagent_stop.bats`，验证 SubagentStop 机器证据拦截。
3. **第三阶段 (P2 - 完善边界)**:
   - 补充 `op_status.bats` 对 `--batch` 的覆盖。
   - 完善 `pre_tool_use.bats` 对主会话/子代理不同写权拦截的用例。
   - 在 `op_worktree_setup.bats` 中补上 `op_record/tasks/` 的排除断言。
