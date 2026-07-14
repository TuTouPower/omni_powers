## 当前模型判断依据

settings.json 顶层 `model=haiku`；`env.ANTHROPIC_MODEL=default_model`；`ANTHROPIC_DEFAULT_SONNET_MODEL=default_sonnet`。主会话由 `default_model` 驱动。本次审阅以 sonnet 视角独立进行，不参考其他路审阅结果。

## 审阅范围

模块 12_scripts_hooks_install，排除 `vendors/` 与 `docs/archive/`。共审阅 22 个文件：

**hooks (8)**：README.md、git/commit-msg、git/pre-commit、post_tool_use.sh、pre_tool_use.sh、run-hook.cmd、settings.template.json、stop.sh
**顶层 (2)**：install.sh、uninstall.sh
**scripts (12)**：build_lite.sh、op_check_env.sh、op_closer_gate.sh、op_jq.sh、op_mutation_check.sh、op_new_task.sh、op_status.sh、op_trailer_unlock.sh、op_worktree_setup.sh、op_worktree_teardown.sh

已完整阅读设计文档 `docs/omni_powers_design.md` 作为上下文（不重复审阅）。

---

## 高优先级问题（CRITICAL / HIGH）

### H1. `op_check_env.sh` 强制要求 OP_HOME，与 lite 模式设计矛盾

- **位置**：`scripts/op_check_env.sh` 第 31-37 行
- **现象**：脚本硬性检查 `OP_HOME` 是否存在且为目录，不满足则 `die`。设计文档 §5.4 明确 lite 模式使用 `${OP_SCRIPT_ROOT:-$OP_HOME}` fallback，lite 不需要 OP_HOME；install.sh 第 72-74 行也明确「lite 走 fallback 不强依赖」。
- **影响**：如果 lite 模式的 skill 入口直接引用本脚本，会因 OP_HOME 未设而失败。虽然设计 §5.5 声明 lite 有独立改造版 `op_check_env.sh`（"只校验 jq/git，跳过 OP_HOME 段"），但 scripts/ 目录下的这份 heavy 版没有 `OP_PROFILE` 分支判断，注释也未标注"仅 heavy 用"。在共享脚本目录场景下，任何 lite 流程若误引本文件会直接 die。
- **建议**：在脚本顶部加 `OP_PROFILE` 分支：lite 模式下跳过 OP_HOME 检查，或至少加注释 `# heavy only: OP_HOME required` 并标注 lite 应使用 `skills/oplrun/scripts/op_check_env.sh` 替代版本。
- **置信度**：高
- **优先级**：HIGH

### H2. `op_closer_gate.sh` 使用 `mapfile` 不兼容 macOS 默认 bash 3.2

- **位置**：`scripts/op_closer_gate.sh` 第 20 行
- **现象**：`mapfile -t CHANGED < <(...)` 是 bash 4.0+ 内置命令。macOS 预装 bash 3.2，该行会报 `mapfile: command not found`，脚本直接失败。设计文档 §4.1 声明 hooks 需要跨平台（Windows/macOS/Linux），scripts 虽未明确要求 macOS，但 hooks/README.md 把 macOS 列为支持平台，install.sh 也无平台限制。
- **影响**：macOS 环境下 closer gate 校验失效，leader 无法检测 closer 越界写入。越界变更可能静默漏入主分支。
- **建议**：替换为 `while IFS= read -r line; do ... done < <(git status --porcelain | awk ...)` 兼容写法。或至少在脚本顶部检查 bash 版本并给出明确错误提示而非 `mapfile: command not found`。
- **置信度**：高
- **优先级**：HIGH

### H3. `post_tool_use.sh` 使用 `eval` 执行动态拼接的测试命令

- **位置**：`hooks/post_tool_use.sh` 第 57 行
- **现象**：`eval "$test_cmd" 2>&1 | head -200`。`test_cmd` 的值来自三个来源拼接：npm test 命令模板 + 文件路径（第 35 行）、pytest 固定命令（第 37 行）、用户环境变量 `OP_TEST_COMMAND`（第 39 行）。其中 `OP_TEST_COMMAND` 是用户可控的环境变量，`rel` 来自文件路径。
- **影响**：如果 `OP_TEST_COMMAND` 被设为恶意命令或文件路径包含 shell 元字符（如 `; rm -rf /`），`eval` 会执行注入代码。虽然 hook 在主会话上下文运行且信任度较高，但 `eval` 是已知的反模式——用 "$@" 传递参数即可避免。
- **建议**：`OP_TEST_COMMAND` 场景改用 `bash -c "$OP_TEST_COMMAND"` 或直接 `$OP_TEST_COMMAND`。npm/pytest 场景下，如果确实需要参数化，将命令拆分为数组 `cmd=(npm test -- ...)` 然后 `"${cmd[@]}"`。
- **置信度**：高
- **优先级**：HIGH

### H4. `commit-msg` 第 64 行存在中文字符污染

- **位置**：`hooks/git/commit-msg` 第 64 行
- **现象**：`"  trailer 绑本次 e2e 文件清单，staged 文件变了中国需重跑 op_trailer_unlock.sh。"` 中的"中国"应为"之后"或"需"。经检查，"中"出现位置原文应为"变了之后需重跑"或"变了需重跑"，"中国"是笔误/编码异常产物。
- **影响**：用户看到错误提示时产生困惑。虽然是 stderr 信息不影响功能，但降低系统可信度。
- **建议**：将"中国"修复为"需"（即"文件变了需重跑"）或"之后需重跑"。
- **置信度**：高
- **优先级**：MEDIUM（功能无损，但影响专业度）

### H5. `pre_tool_use.sh` 引用不存在的设计章节

- **位置**：`hooks/pre_tool_use.sh` 第 69 行、第 71 行
- **现象**：注释写 `design §10`，但设计文档 `omni_powers_design.md` 最高章节号为 §5（lite 模式）。§10 不存在。第 57 行引用 `D18`（在 `op_decisions.md` 中），这个引用对象是正确的，但 §10 是无效引用。
- **影响**：维护者查设计文档找不到对应章节，降低代码可导航性。建议改为引用 `design §3.4（merge gate）` 或 `design §0.2（能力矩阵）`。
- **置信度**：高
- **优先级**：MEDIUM

---

## 中低优先级问题（MEDIUM / LOW）

### M1. `post_tool_use.sh` 文件扩展名假设仅支持 TypeScript

- **位置**：`hooks/post_tool_use.sh` 第 35 行
- **现象**：`npm test -- ${rel%.ts}.test.ts` 假设源文件扩展名为 `.ts` 且对应测试文件为 `.test.ts`。对于 `.js`/`.jsx`/`.tsx`/`.mjs` 文件，测试定位会失败。
- **影响**：非 `.ts` 源文件编辑后 PostToolUse 不可用对应测试，降级为 `npm test`（全量跑）。非致命但降低 hook 精准度。
- **建议**：扩展支持更多扩展名（`.ts`/`.tsx`/`.js`/`.jsx`/`.mjs`），或使用 `npm test -- --findRelatedTests "$rel"`（Jest 支持）。无此能力时直接跑 `npm test`（当前已有 fallback）。
- **置信度**：中
- **优先级**：LOW

### M2. `pre_tool_use.sh` 测试文件匹配模式过宽

- **位置**：`hooks/pre_tool_use.sh` 第 78 行
- **现象**：`*spec/*` 模式会匹配所有包含 `spec` 目录的路径，如 `docs/omni_powers/op_execution/specs/T0001_xxx.md`（工作 spec 文件）。这些文件不是测试文件，不应触发行级敏感度警告。
- **影响**：编辑 spec 文件时如果内容含 `expect`/`assert` 等关键字会触发 WARN（不阻断），产生噪音。
- **建议**：精确匹配改为 `*.test.*|*_test.*|*spec.*|tests/*`（排除 `docs/omni_powers/op_execution/specs/` 路径），或在守门逻辑中显式 skip `docs/omni_powers/` 路径。
- **置信度**：中
- **优先级**：LOW

### M3. `stop.sh` 无测试框架判断逻辑存在时间窗口缺陷

- **位置**：`hooks/stop.sh` 第 39 行
- **现象**：当 PostToolUse 从未在此 session 触发（如 implementer 不经过 Edit/Write/MultiEdit 工具完成工作，或 hook 根本没 fire），就不会产生 `test_evidence_NONE.log`。此时若 task 也没产生任何 `test_evidence_*.log`，stop.sh 会 BLOCKED（缺 5 分钟内新鲜证据）。
- **影响**：极少数场景（纯手写代码无 Edit 工具调用、SubagentStop 在新 session compact 后触发等）下 implementer 会被误拦。
- **建议**：在 current_task 非空但无任何 test_evidence 文件时，降级为 WARN 而非 BLOCKED。或由 oprun dispatch 时在 task 目录预置 `test_evidence_NONE.log`（表示"本 task 明确无测试框架"）。
- **置信度**：中
- **优先级**：LOW

### M4. `op_status.sh` flock 无锁写场景的潜在竞态

- **位置**：`scripts/op_status.sh` 第 60-62 行
- **现象**：当 `flock` 不可用时（macOS/Git Bash），脚本以 WARN 模式继续无锁写。虽然注释说"串行执行并发风险低"，但 lite 模式下 leader 与 subagent 同在单一 worktree，理论上存在并发写入 `tasks_list.json` 的可能（如 subagent 返回后 leader 和 PostToolUse hook 同时写）。
- **影响**：低概率的 tasks_list.json 数据损坏。当前 lite/havy 均严格串行 task，实际并发几乎不可能。
- **建议**：在无 flock 时改用 `mkdir` 作为目录锁（`mkdir .tasks_list.lock 2>/dev/null`），比空手写更安全且跨平台兼容。
- **置信度**：中
- **优先级**：LOW

### M5. `uninstall.sh` jq 正则 `test()` 函数中的转义可能因 jq 版本而异

- **位置**：`uninstall.sh` 第 116 行
- **现象**：`test("omni_powers|\\$OP_HOME/hooks/run-hook\\.cmd|OP_HOME/hooks/run-hook\\.cmd")` 中 `\\$` 在 jq 字符串里表示一个字面 `\$`。不同 jq 版本对字符串内反斜杠的解析可能存在细微差异。`jq` 1.6 vs 1.7 在正则转义上有已知变更。
- **影响**：极少数环境下 hook 清理正则匹配不到 `$OP_HOME/hooks/run-hook.cmd` 模式，导致该 hook 残留。
- **建议**：拆分为更简单的子串匹配或改用 `contains()` 函数（不依赖正则），或至少在两版 jq 上验证。
- **置信度**：低
- **优先级**：LOW

### M6. `op_status.sh` blocked 状态非 batch 分支设 `blocked_by=null` 的行为与注释矛盾

- **位置**：`scripts/op_status.sh` 第 81-83 行
- **现象**：非 blocked 状态更新时，`blocked_by` 被强制设为 `null`（第 82 行 `.blocked_by = null`）。注释第 8 行说 `blocked_by 仅在 status=阻塞 时填写`，但实现是对所有非 blocked 状态清零。如果之前是 blocked 且被重新设为 in_progress（重做），`blocked_by` 被清零是正确行为；但如果只是想更新 title 而保持 blocked_by 则被意外清零。不过当前脚本只改 status，不存在"只改 title"场景，所以实际无害。
- **影响**：无实际 bug，但代码意图与注释之间有微小落差。
- **建议**：在注释中说明 `blocked_by 在非 blocked 状态自动清零`，或改为仅当 blocked_by 当前有值且新状态非 blocked 时才清零（更防御性）。
- **置信度**：高
- **优先级**：LOW

### M7. `op_worktree_setup.sh` git version 检查使用 brittle 的 grep 正则

- **位置**：`scripts/op_worktree_setup.sh` 第 18 行
- **现象**：`git version | grep -qE 'git version (2\.(2[5-9]|[3-9])|[3-9])'` 用正则匹配版本号。如果 git 改变版本输出格式（如未来 `git version 10.0`，当前正则 `[3-9]` 不匹配两位数 10），会误报 WARN。同时 git 2.25 距今已 6 年，此检查实际几乎不会触发。
- **影响**：git 10.0+ 时 WARN 误报（不影响功能，sparse-checkout 本身可用）。
- **建议**：提取版本号后做数值比较更健壮：`git_version=$(git version | grep -oE '[0-9]+\.[0-9]+' | head -1)` + `if [ "$(printf '%s\n' 2.25 "$git_version" | sort -V | head -1)" != "2.25" ]`。
- **置信度**：中
- **优先级**：LOW

---

## 改进建议

### S1. 统一 `OP_PROFILE` 感知入口

当前 `scripts/` 目录下的脚本多数未做 `OP_PROFILE` 感知（design §5.5 要求脚本入口校验 `OP_PROFILE` 存在且为已知值，未知值 die）。目前仅 `op_check_env.sh` 被设计文档指定为需要 lite 改造版，但实际上 `op_status.sh`、`op_jq.sh` 等在 lite 下也有轻微行为差异（如 closing 态在 lite 不存在）。建议所有 scripts/ 下的共享脚本统一在顶部加入：

```bash
profile="${OP_PROFILE:-heavy}"
case "$profile" in heavy|lite) ;; *) die "OP_PROFILE 无效: $profile" ;; esac
```

并据此分支。这能防新增脚本只考虑 heavy 路径致 lite 静默异常。

### S2. `run-hook.cmd` polyglot 模式增加自检

`run-hook.cmd` 的 polyglot 依赖 `: << 'CMDBLOCK'` heredoc 机制正确运行。如果 `.gitattributes` CRLF 防护失效（如用户手动 clone 时未配置），CRLF 行尾会破坏 heredoc。建议在脚本顶部增加自检：

```bash
# 在 bash 段开始处
if [ "$(head -c 200 "$0" | tr -d '\r' | head -c 200)" != "$(head -c 200 "$0")" ]; then
    echo "[FATAL] $0 含 CRLF 行尾，polyglot heredoc 失效。请确保 .gitattributes 生效后重新 checkout。" >&2
    exit 1
fi
```

### S3. `post_tool_use.sh` 测试框架检测扩展

当前仅检测 npm/pytest。建议增加对常见测试运行器的检测：`Makefile` 中的 `test` target、`cargo test`（Rust）、`go test`（Go）、`./gradlew test`（JVM）。虽然可通过 `OP_TEST_COMMAND` 覆盖，但自动检测能减少配置摩擦。

### S4. `hooks/settings.template.json` 增加 OP_HOME 未设时的优雅降级

当前所有 hook command 使用 `"bash \"$OP_HOME/hooks/run-hook.cmd\" ..."`。如果 OP_HOME 未设（如 lite 用户误装了 heavy hook，或 settings.json env 段丢失），bash 会尝试执行 `/hooks/run-hook.cmd`（空字符串拼接），报错不友好。建议在 run-hook.cmd 内部或 hook command 中加一层防御：

```json
{ "type": "command", "command": "if [ -z \"$OP_HOME\" ]; then echo '[Hook] OP_HOME not set, skip' >&2; exit 0; fi; bash \"$OP_HOME/hooks/run-hook.cmd\" pre_tool_use" }
```

### S5. `op_worktree_teardown.sh` 增加安全检查

当前脚本对 `wt_path` 不做任何校验，`rm -rf "$wt_path"` 与 `git branch -D "$branch"` 理论上可能因变量为空或路径错误导致意外删除。建议增加最小安全校验：

```bash
case "$wt_path" in
    *".claude/worktrees/"*|*"/op/task/"*) ;;  # 预期的 worktree 路径模式
    *) echo "[WARN] $wt_path 不像 worktree 路径，跳过 rm -rf" >&2; exit 1 ;;
esac
```

---

## 不确定项 / 可能误报

### U1. `op_check_env.sh` 的 lite 改造版未被审阅到

设计文档 §5.5 声明 lite 有独立改造版 `op_check_env.sh`（"只校验 jq/git，跳过 OP_HOME 段"），该文件位于 `skills/oplrun/scripts/op_check_env.sh`。本次审阅范围只覆盖 `scripts/` 顶层目录，不含 `skills/oplrun/scripts/`。因此 H1 的判断基于"顶层 scripts/op_check_env.sh 被 lite 引用"这一假设——如果 lite skill 确实只引用自己的改造版而不引用 scripts/ 版本，则 H1 降级为注释建议。

### U2. `mapfile` 问题是否有意忽略 macOS 兼容

设计文档多处提到 macOS 支持（hooks/README.md 明确列出 macOS，install.sh 无平台限制），但也有可能 scripts/ 脚本被设计为"仅 leader 在 Linux/WSL 环境执行"，不承诺 macOS 兼容。如果这是有意设计决策，H2 从 HIGH 降为文档建议。

### U3. `eval` 在 hook 上下文中的实际风险

H3 标记为 HIGH 基于通用安全原则（eval = code injection surface）。但如果 Claude Code 的 hook 执行环境有沙箱限制、或 `OP_TEST_COMMAND` 在配置阶段由用户显式设定（用户信任自己的配置），实际攻击面极小。如果项目对 hook 脚本的安全等级定位为"trusted internal"，eval 可接受。
