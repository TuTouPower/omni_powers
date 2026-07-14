# sonnet 审阅报告：hooks / install / uninstall / scripts

## 当前模型判断依据

可观测来源：settings 顶层 `model=default_model`；env `ANTHROPIC_MODEL=default_model`；主会话 powered by `default_sonnet`。本路 sonnet 继承主会话。未写入任何 secret。

## 审阅范围

21 个文件，分三组：

| 组 | 文件 |
|---|---|
| hooks（8） | README.md, git/commit-msg, git/pre-commit, post_tool_use.sh, pre_tool_use.sh, run-hook.cmd, settings.template.json, stop.sh |
| install/uninstall（2） | install.sh, uninstall.sh |
| scripts（11） | build_lite.sh, op_check_env.sh, op_closer_gate.sh, op_jq.sh, op_mutation_check.sh, op_new_task.sh, op_status.sh, op_trailer_unlock.sh, op_worktree_setup.sh, op_worktree_teardown.sh, test_lock.sh |

核心参照文档：`docs/omni_powers_design.md`。

---

## 高优先级问题

### H1. settings.template.json 缺少 Stop 与 SessionStart hook 配置

**位置**：`hooks/settings.template.json`（全局）+ `hooks/README.md`（hook 列表）

**现象**：

- design §4.1 hook 清单明确列出 Stop hook（"leader 收尾门禁：状态 + 新鲜证据"）和 SessionStart hook（"路由注入 + approved spec 漂移校验"）。
- 但 `settings.template.json` 仅配置了 PreToolUse、PostToolUse、SubagentStop 三类，没有 Stop 和 SessionStart 的 matcher/command 配置。
- 且 `hooks/` 目录下不存在 `session_start.sh` 与 `stop.sh` 的 Stop 事件版本（现有 `stop.sh` 是 SubagentStop 门禁，不含 leader 收尾逻辑）。
- `hooks/README.md` 的 hook 列表声称 SessionStart 存在（"路由注入 + approved spec 漂移校验"），与文件系统事实不符。

**影响**：opinit 注册 hook 时按 template 生成，Stop 和 SessionStart 两个 hook 完全不会生效——leader 收尾无门禁、session 启动无漂移校验注入。这两个 hook 仅在 heavy 主会话生效（设计 §3.3 已承认 subagent 场景 hook 失效），但即使主会话也完全缺失。

**建议**：

1. 立即决定：Stop/SessionStart hook 在当前阶段是否需要落地。若属于 P2 延后交付，需在 design §0.2 能力矩阵新增一行标注"未落地"，并修改 `hooks/README.md` 移除未实现的 hook 声明。
2. 若需要落地：补 `session_start.sh`（路由注入 + approved spec git diff 校验）和 leader 用 `stop.sh`（区分 SubagentStop 的 stop.sh——可用命名如 `leader_stop.sh` 或在现有 stop.sh 内根据 `stop_hook_active` 区分），并在 `settings.template.json` 追加配置。

**置信度**：高（文件系统验证：`session_start.sh` 不存在，template 无对应配置）。

**优先级**：高

---

### H2. shared scripts（scripts/）全部缺少 OP_PROFILE 入口校验

**位置**：`scripts/` 下全部脚本（op_check_env.sh / op_closer_gate.sh / op_jq.sh / op_mutation_check.sh / op_new_task.sh / op_status.sh / op_trailer_unlock.sh / op_worktree_setup.sh / op_worktree_teardown.sh / test_lock.sh）

**现象**：

- design §5.5 明确规定："heavy/lite 两版共用的脚本必须在入口校验 OP_PROFILE 存在且为已知值（heavy|lite），未知值 die 而非静默按 heavy 路径执行"。
- 所有 shared scripts 均无 `OP_PROFILE` 校验逻辑，无一例外。
- design §5.5 也承认此迁移未完成："lite 副本（skills/oplrun/scripts/）暂保留……完整归并（删 lite 副本 + oplrun SCRIPTS 寻址共享目录）待重构（D1）"。

**影响**：当前 `scripts/` 下脚本被 lite dispatch 通过 `OP_SCRIPT_ROOT` 引用时，可能静默按 heavy 路径执行——例如 `op_check_env.sh` 硬要求 `OP_HOME`（见 H3），lite 场景下会直接 die，导致 agent 启动即失败。

**建议**：

- 在 D1 归并时，为每个 shared script 入口追加统一的 profile guard：
  ```bash
  case "${OP_PROFILE:-}" in heavy|lite) ;; *) echo "[FATAL] OP_PROFILE 未设或未知" >&2; exit 1 ;; esac
  ```
- 或明确设计决策：shared scripts 不需要 profile guard，由 dispatch 侧确保只在正确环境下调用。若此决策成立，需更新 design §5.5 删除"必须在入口校验"的要求。

**置信度**：高（全量 grep 确认无一脚本含 `OP_PROFILE` 引用）。

**优先级**：高（与 D1 迁移绑定，当前处于已知半成品状态）

---

### H3. op_check_env.sh 硬依赖 OP_HOME，无 lite fallback

**位置**：`scripts/op_check_env.sh` 行 31-37

**现象**：

```bash
if [ -z "${OP_HOME:-}" ]; then
  echo "[FAIL] OP_HOME 未设" >&2
  missing=1
elif [ ! -d "$OP_HOME" ]; then
  echo "[FAIL] OP_HOME 目录不存在" >&2
  missing=1
fi
```

design §5.5 表格明确要求 lite 版 `op_check_env.sh` "只校验 jq/git（跳过 OP_HOME 段）"。§5.4 的 fallback 变量约定是 `${OP_SCRIPT_ROOT:-$OP_HOME}`——shared script 应优先用 `OP_SCRIPT_ROOT`，未设才 fallback 到 `OP_HOME`。但本脚本完全不走 fallback，直接 fail。

**影响**：lite 场景 dispatch 若调用 shared `scripts/op_check_env.sh`，agent 启动即 die——`OP_HOME` 在 lite 项目中不设（design §5.3 明确禁止 lite 写 `~/.claude/settings.json`）。

**建议**：按 design §5.5 实现 profile 分支：检测 `OP_PROFILE=lite` 时跳过 `OP_HOME` 检查，只校验 jq/git。

**置信度**：高

**优先级**：高

---

### H4. pre_tool_use.sh 注释引用已不存在的 design §10

**位置**：`hooks/pre_tool_use.sh` 行 67

**现象**：

```bash
# 本 hook 仅主会话拦（防 leader 误写 e2e）；evaluator/implementer 是 subagent，deny 不生效
# design §10 / op_decisions.md D18
```

design 文档在 heavy+lite 合并后（当前 `docs/omni_powers_design.md`）已无 §10 章节（共 5 大章 + §0 前置）。过期的章节引用会让后续维护者困惑，无法溯源设计意图。

**影响**：维护性——引用失效，读者无法追溯到设计依据。

**建议**：更新为当前 design 的正确引用：`design §3.3（防线层映射表）+ §3.4（merge gate）+ §0.2（能力矩阵）`。

**置信度**：高

**优先级**：中（不影响运行时行为）

---

### H5. uninstall.sh 遗漏 `~/.claude/scripts/omni_powers/` 清理

**位置**：`uninstall.sh` 全局卸载段（`remove_global` 函数，行 68-93）

**现象**：

- `install.sh` 在行 57-58 安装了 `~/.claude/scripts/omni_powers/`（shared scripts 目录）。
- `uninstall.sh` 的 `remove_global` 函数只删除 `skills/` 下 op* 目录和 `agents/op-*.md`，不处理 `scripts/omni_powers/`。
- `--purge-project` 也只清理项目侧（`docs/omni_powers/`、`.claude/settings.json` hooks、`.git/hooks/`），不涉及全局 scripts。

**影响**：完整卸载后残留 `~/.claude/scripts/omni_powers/` 目录，约 11 个脚本文件。不影响功能但违反"uninstall 反向 install"的契约。

**建议**：在 `remove_global` 中追加：

```bash
del "$CLAUDE_HOME/scripts/omni_powers"
```

**置信度**：高

**优先级**：中

---

## 中低优先级问题

### M1. hooks/README.md 声明 SessionStart hook 但文件不存在

**位置**：`hooks/README.md` 行 46

**现象**：hook 列表表格包含 `SessionStart | — | session_start.sh | 路由注入 + approved spec 漂移校验`，但 `hooks/` 目录下无 `session_start.sh` 文件。

**影响**：文档与代码不一致。新贡献者按 README 找文件会失败。

**建议**：若 P2 延后则 README 标注"规划中（P2 交付，当前未落地）"；若已决定不做则删除该行。

**置信度**：高

**优先级**：中

---

### M2. stop.sh 的 current_task 读取依赖 checkpoint 但无防御

**位置**：`hooks/stop.sh` 行 15-21

**现象**：

```bash
checkpoint="docs/omni_powers/op_execution/leader_checkpoint.md"
tid="$(awk -F': *' '/^current_task:/{print $2; exit}' "$checkpoint" 2>/dev/null | tr -d ' ')"
# 无活跃 task → WARN
if [ -z "$tid" ]; then
  echo "[Hook] WARN: current_task 为空..." >&2
  exit 0
fi
```

当 `leader_checkpoint.md` 文件不存在时（如首次初始化后未写入），awk 静默返回空字符串 → WARN → exit 0（放行）。但 design 意图是 SubagentStop 应阻止无证据的 implementer 交工。checkpoint 文件缺失本身是异常信号（oprun 派 implementer 前应写 current_task），当前静默放行削弱了门禁。

**影响**：oprun 忘记写 current_task 就派 implementer 时，SubagentStop 门禁形同虚设。

**建议**：区分"checkpoint 文件不存在"与"current_task 字段为空"两种情况——前者应 BLOCK（exit 2），后者 WARN + exit 0（可能正在进行 intake）。

**置信度**：中（当前行为是 defence-in-depth 的一层，merge gate + reviewer 兜底，单一门禁失效不致命）

**优先级**：中

---

### M3. test_lock.sh 为孤立脚本，与 hook 锁定机制脱节

**位置**：`scripts/test_lock.sh`（21 行脚本）

**现象**：

- `test_lock.sh` 管理 `.test_locks` 文件（`docs/omni_powers/op_execution/.test_locks`），提供 add/remove/list/check 操作。
- `opinit_skeleton.sh` 创建初始 `.test_locks` 文件（含注释头）。
- 但 `hooks/pre_tool_use.sh` 的 e2e/BUG-* 拦截逻辑是**硬编码路径匹配**（`case "$rel" in e2e/*|*BUG-*)`），完全不读取 `.test_locks` 文件。
- 也就是说，`test_lock.sh` 的锁定/解锁操作对实际 hook 行为无任何影响——锁定文件是纯档案。

**影响**：test_lock.sh 存在但未被集成到任何防护链路中。opred 协议引用它作为"锁定文件解锁"入口，但实际上锁不锁都不影响 pre_tool_use.sh 的拦截行为。

**建议**：

- 方案 A：删除 test_lock.sh，pre_tool_use.sh 的硬编码路径匹配已足够（行为层文件锁定不依赖外部状态）。
- 方案 B：让 pre_tool_use.sh 读取 `.test_locks` 文件作为放行白名单（leader 解锁后可编辑），但增加复杂度且引入状态依赖。
- 推荐方案 A——design §3.1 行为层归 evaluator 的规则是全局的，不需要 per-file 状态管理。

**置信度**：高

**优先级**：中

---

### M4. commit-msg hook 中的 grep 无操作语句

**位置**：`hooks/git/commit-msg` 行 49

**现象**：

```bash
hmac_data="$(printf '%s' "$e2e_paths" | grep -c . >/dev/null; printf '%s' "$e2e_paths" | sort | tr '\n' ':')"
```

第一个分句 `printf '%s' "$e2e_paths" | grep -c . >/dev/null` 将行数统计写入 /dev/null，是纯无操作。可能是遗留调试代码或原本意图为"空路径检测"但写错了。

**影响**：无运行时影响（输出被丢弃），但降低可读性。

**建议**：删除该无操作分句，简化为 `hmac_data="$(printf '%s' "$e2e_paths" | sort | tr '\n' ':')"`。

**置信度**：高

**优先级**：低

---

### M5. post_tool_use.sh NONE 证据标记与 design 不完全对齐

**位置**：`hooks/post_tool_use.sh` 行 41-45

**现象**：当项目无 package.json / pytest / OP_TEST_COMMAND 时，写 `test_evidence_NONE.log` 标记，SubagentStop 据此放行。这是合理的工程实践，但 design §3.3 第 3 层未提及 NONE 标记机制——design 只描述"自动跑受影响测试留证据"和"SubagentStop 验存在不验真伪"。

**影响**：无。NONE 标记是 PostToolUse/SubagentStop 配合的必要补充（否则无测试框架的项目 implementer 永远无法通过 SubagentStop）。

**建议**：在 design §3.3 第 3 层补充"NONE 标记：无测试框架项目写标记文件，SubagentStop 识别并放行"。

**置信度**：中

**优先级**：低

---

### M6. op_closer_gate.sh 末尾自 chmod 语句

**位置**：`scripts/op_closer_gate.sh` 行 44

**现象**：

```bash
chmod +x "$0" 2>/dev/null || true
```

脚本在退出前给自己加执行权限。这在正常流程中无意义（脚本已经以可执行状态运行），仅在通过 `bash op_closer_gate.sh` 调用且文件本身无执行权限时有效。

**影响**：无。但暗示"这个脚本可能以非可执行状态被调用"，这不是应该依赖的保障。

**建议**：删除此行，确保安装流程（install.sh / opinit）设好权限。

**置信度**：高

**优先级**：低

---

### M7. op_worktree_setup.sh evaluator 排除列表缺少 op_execution/tasks 的 decisions.md

**位置**：`scripts/op_worktree_setup.sh` 行 53-60

**现象**：eval worktree sparse-checkout 排除列表中：
- 排除了 `!/docs/omni_powers/op_execution/tasks/` ✓
- 排除了 `!/docs/omni_powers/op_record/tasks/` ✓
- 排除了 `!/docs/omni_powers/op_record/decisions.md` ✓
- 但 `op_execution/` 下的 `issues/` 目录未被排除——evaluator 物理可读 issue 文件

evaluator 访问隔离（design §2.5）要求"源码 src/**、task 目录（op_execution/tasks/** + op_record/tasks/**）、op_record/decisions.md 不物化"。issues/ 未被列出，但 issues 包含 reviewer 范围外发现（可能含实现细节描述），evaluator 读到会削弱"独立验收"。

**影响**：低——issues/ 通常是高层描述而非实现细节，但严格按 design 隔离精神应排除。

**建议**：追加 `!/docs/omni_powers/op_execution/issues/` 和 `!/docs/omni_powers/op_record/` 到 eval 排除列表。

**置信度**：中

**优先级**：低

---

## 改进建议

### S1. hooks/ 文件命名歧义：stop.sh 代表 SubagentStop 而非 Stop

design §4.1 同时列出 SubagentStop 和 Stop 两个 hook。当前 `stop.sh` 仅处理 SubagentStop（通过 `stop_hook_active` 判断，是 SubagentStop 特有字段）。建议重命名为 `subagent_stop.sh`，为未来的 leader Stop hook 预留 `leader_stop.sh`。或至少在文件头部注释中明确标注"此脚本仅用于 SubagentStop，非 Stop 事件"。

### S2. install.sh 可增加 hooks/ 目录安装

当前 install.sh 安装 skill、agent、scripts 但不安装 hooks/ 下的脚本到 `~/.claude/`。虽然 hooks 是 per-project 注册（由 /opinit 按 template 生成 command 路径指向 `$OP_HOME/hooks/`），但 `run-hook.cmd` polyglot wrapper 的路径解析依赖 hooks 脚本物理存在于仓库目录。建议 install.sh 至少做存在性校验，确保 hook 脚本可访问。

### S3. build_lite.sh 适应共享脚本归并后的新布局

当前 `build_lite.sh` 校验 lite 副本（`skills/oplrun/scripts/`）与 heavy 源（`skills/oprun/scripts/`）的一致性。D1 完成归并后（lite 改用 `~/.claude/scripts/omni_powers/`），`build_lite.sh` 的校验目标应从"lite 副本 vs heavy 源"改为"shared scripts 的 profile 分支完整性"——验证每个共享脚本是否正确处理 `OP_PROFILE=lite` 路径。

### S4. op_trailer_unlock.sh 和 commit-msg 的 HMAC 输入格式应提取为共享函数

当前两处各自构造 HMAC 输入字符串（路径收集 → 排序 → tr '\n' ':'），逻辑重复。建议提取为共享函数（`op_e2e_hmac_input()`），放在 shared scripts 中，两个调用方引用同一函数，消除未来"改一处忘另一处"的漂移风险。

---

## 不确定项

### U1. SessionStart hook 的设计意图是仅 heavy 还是两版共享

design §4.1 在 hook 清单中列出 SessionStart，§5.3 说 lite "无 SessionStart 注入（A17 已去）"，但 design 目录结构 §1 又写 "index.md 给 agent 看的目录页（heavy: SessionStart 注入其摘要 → /oprun 启动读其摘要）"。SessionStart hook 是否仅 heavy？当前缺失的 `session_start.sh` 应该做什么？设计层面的优先序待澄清。

### U2. Stop hook（leader 收尾门禁）的具体内容未定义

design §4.1 说 "Stop：leader 收尾门禁：状态 + 新鲜证据"，但未展开具体检查项。需与当前已实现的 SubagentStop 区分——是只检查 tasks_list 状态与新鲜证据存在，还是有额外检查（如 uncommitted changes 检测、spec diff 校验）。

### U3. test_lock.sh 的存废

opinit_skeleton.sh 创建 `.test_locks` 文件，opred skill 引用 test_lock.sh，pre_tool_use.sh 不读它——三方行为不一致。需明确：`.test_locks` 机制是否要保留？如果要，pre_tool_use.sh 是否应该读它？如果不要，opinit_skeleton.sh 和 opred 的引用应同步清理。
