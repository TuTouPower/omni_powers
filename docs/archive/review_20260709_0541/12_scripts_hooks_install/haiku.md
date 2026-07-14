# 12_scripts_hooks_install 审阅（haiku 视角）

## 当前模型判断依据

可观测来源：`/home/karon/.claude/settings.json` 顶层 `model=haiku`；`env.ANTHROPIC_MODEL=default_model`；`ANTHROPIC_DEFAULT_HAIKU_MODEL=default_haiku[1m]`；主会话环境提示当前由 `default_model` 驱动。不可读运行时内部状态；当前路径继承主会话，表现为 haiku 档。本报告以 haiku 能力做静态全量审阅，未跑构建/测试/联网。

## 审阅范围

`hooks/`（README/git commit-msg/git pre-commit/post_tool_use/pre_tool_use/run-hook.cmd/settings.template/stop.sh）、`install.sh`、`uninstall.sh`、`scripts/` 顶层（build_lite/op_check_env/op_closer_gate/op_jq/op_mutation_check/op_new_task/op_status/op_trailer_unlock/op_worktree_setup/op_worktree_teardown）。排除 `vendors/` 与 `docs/archive/`。源文件只读，仅写本报告。

## 高优先级问题（CRITICAL / HIGH）

### H1. `op_closer_gate.sh` 用 `mapfile`（bash 4+），macOS 默认 bash 3.2 致 closer 越界校验静默失效

- **位置**：`scripts/op_closer_gate.sh:20` — `mapfile -t CHANGED < <(git status --porcelain | awk '{print $2}')`
- **现象**：`mapfile`（及 `readarray`）是 bash 4.0+ builtin。macOS 系统自带 `/bin/bash` 为 3.2，`mapfile` 不存在 → 执行时 `mapfile: command not found`，`CHANGED` 数组为空。后续 `for f in "${CHANGED[@]:-}"` 遍历空集，`violation` 恒为 0，**closer gate 永远输出 `[OK]` 放行**。
- **影响**：design §2.6 / §0.2 把 closer gate 列为「已落地、硬级」防线（closer 权限最大约束最少，唯一的机械校验）。macOS 是项目主要平台之一（CLAUDE.md 全局约定支持 macOS Docker 等），closer gate 在 macOS 静默失效 = 安全防线凭空消失，且无报错（设计声称的"硬"退化为"无"）。属信任根声明（§0.1）所指机械证据失效。
- **建议**：改用 POSIX 兼容写法，如 `CHANGED=(); while IFS= read -r line; do CHANGED+=("$line"); done < <(git status --porcelain | awk '{print $2}')`；或入口加 `bash -ge 4` 检测并 die（当前脚本 `set -uo pipefail` 但 command not found 不属 pipefail 捕获范围，不会被 `set -e` 兜住——脚本恰好 `set -uo` 未设 `-e`，更隐蔽）。同时考虑与其他脚本对齐：`op_check_env.sh` 已 WARN 非 bash，但 `op_closer_gate.sh` 无版本守卫。
- **置信度**：高（本机 `type mapfile` = not found，bash 3.2 语义确定）
- **优先级**：CRITICAL

### H2. `build_lite.sh` 校验列表遗漏 `op_collect_open_issues.sh`，副本漂移检测有盲区

- **位置**：`scripts/build_lite.sh:18-38`（`VERBATIM` / `MUTATED_MARK` 列表）
- **现象**：lite 目录 `skills/oplrun/scripts/` 实际含 9 个 `.sh`（`close_check/op_assemble_eval_brief/op_check_env/op_close_post/op_coder_check/op_collect_open_issues/op_jq/op_read_verdict/op_status`），但 `VERBATIM` 只列 3 个逐字节复制类、`MUTATED_MARK` 列 5 个改造版，**`op_collect_open_issues.sh` 两处都未列**。
- **影响**：`build_lite.sh` 自称「防副本漂移」，但漏列文件既不校验一致性也不纳入 `--sync`。若该文件在 heavy 有对应源被改动，或 lite 版被误改，检测不到——正是 build_lite 要防的漂移静默发生。该脚本作为 D5「渐进归并」期的同步保障工具，盲区削弱其保障承诺。
- **建议**：确认 `op_collect_open_issues.sh` 归类（逐字节复制 or 改造版），补进对应列表并加标记校验；或脚本改为枚举 lite 目录全部 `.sh` 与校验列表做差集，缺失即告警（防新增文件漏登记）。
- **置信度**：高（实测 grep 无匹配 + ls 确认文件存在）
- **优先级**：HIGH

### H3. `install.sh` chmod glob 不覆盖 `scripts/omni_powers/`（共享脚本目录）及 `opintake`

- **位置**：`install.sh:60-62` — `find "$SKILLS_DST"/{opinit,oprun,oplinit,oplintake,oplrun} -name '*.sh' -exec chmod +x {} +`
- **现象**：
  1. glob 只含 5 个 skill，**不含 `opintake`**（`skills/opintake/scripts/` 本身不存在，影响小，但 glob 设计应与第 47 行 skill 列表对齐防遗漏）。
  2. 更关键：`install.sh:57-58` 把顶层 `scripts/` 拷到 `~/.claude/scripts/omni_powers/`（design §5.5 的共享脚本根，lite 的 `OP_SCRIPT_ROOT` 指向它），**chmod glob 完全不覆盖这个目录**。该目录下 `op_status.sh/op_jq.sh/op_check_env.sh/op_closer_gate.sh/op_mutation_check.sh/op_new_task.sh/op_trailer_unlock.sh/op_worktree_setup.sh/op_worktree_teardown.sh/build_lite.sh` 全部以仓库原始权限拷贝，若仓库 clone 时未保留 +x（如 zip 下载、某些 CI checkout），运行时 `permission denied`。
- **影响**：lite 模式依赖共享脚本目录，chmod 缺失致 lite 脚本不可执行；heavy 的 closer gate、worktree setup、trailer unlock 等同样受影响。属安装期遗漏，运行时才暴露。
- **建议**：chmod glob 扩展为 `find "$SKILLS_DST" "$SCRIPTS_DST" -name '*.sh' -exec chmod +x {} +`（覆盖全部已装 skill + 共享 scripts 目录），或更稳妥对所有安装目标统一 `find "$CLAUDE_HOME/skills" "$CLAUDE_HOME/scripts" "$CLAUDE_HOME/agents" -name '*.sh' -exec chmod +x {} +`。
- **置信度**：高（路径与 glob 字面比对确认）
- **优先级**：HIGH

### H4. `hooks/git/commit-msg` 与 `op_trailer_unlock.sh` 的 HMAC 输入对 `e2e_paths` 换行处理不一致，潜在 mismatch 致合法 trailer 被拒

- **位置**：`hooks/git/commit-msg.sh:23-27,49` vs `scripts/op_trailer_unlock.sh:41,49`
- **现象**：
  - commit-msg：`e2e_paths` 在 while 循环里逐行 `e2e_paths="${e2e_paths}${path}"$'\n'` 累积（每条后加换行），第 49 行 `printf '%s' "$e2e_paths" | grep . | sort | tr '\n' ':'`。
  - op_trailer_unlock：`e2e_paths="$(git diff-index ... | grep '^e2e/' || true)"`（命令替换默认去尾换行），第 49 行同样 `printf '%s' "$e2e_paths" | grep . | sort | tr '\n' ':'`。
  - 两处 `grep . | sort | tr '\n' ':'` 流水线对「中间换行 vs 无尾换行」的处理：commit-msg 的变量尾部多一个 `\n`，`grep .` 过滤空行后 `sort` 再 `tr`——理论上尾部多余换行经 grep 过滤后一致。**但** commit-msg 累积时若 `path` 含空格（git diff-index --name-only 默认对特殊字符加引号或转义），累积串与 unlock 的逐行 grep 结果在排序前可能因引号差异产生不同 token。
- **影响**：正常路径（纯 ASCII 无空格路径）大概率一致；但 Windows 路径含空格、含 Unicode 文件名时，两脚本对同一 staged 集算出不同 HMAC → 合法 trailer 被判非法 → leader 无法 commit e2e。属设计一致性缺陷，且难排查（报错信息只说"trailer 不合法"）。
- **建议**：统一 HMAC 输入构造——两处都用同一原语，如抽出公共函数 `compute_e2e_hmac_data()`。最低限度：两脚本都用 `git diff-index --cached --name-only -z "$against" | tr '\0' '\n' | grep '^e2e/' | sort | tr '\n' ':'`（`-z` 统一处理空格/特殊字符），消除累积方式差异。
- **置信度**：中（正常路径可能一致，特殊路径未实测；但两处构造方式明显不同，属代码异味 + 潜在正确性风险）
- **优先级**：HIGH

### H5. `hooks/git/commit-msg` 的 `e2e_paths` 累积在 `set -uo pipefail` + 进程替换下，空时 `has_e2e` 判断与 staged 扫描耦合，首提交（无 HEAD）fallback 正确但空树 hash 依赖 git 版本

- **位置**：`hooks/git/commit-msg:18` — `against="$(git rev-parse --verify HEAD >/dev/null 2>&1 && echo HEAD || echo "$(git hash-object -t tree /dev/null)")"`
- **现象**：初始仓库无 HEAD 时用 `git hash-object -t tree /dev/null` 生成空树对象 hash 作为 diff-index 的 against。该命令在不同 git 版本行为：旧版 git 对 `/dev/null` 作 tree hash 可能报错或产出非标准 hash；`git hash-object -t tree` 期望 tree 对象内容（非文件），传 `/dev/null` 依赖 git 容错。pre-commit 第 10 行同样模式。
- **影响**：极端场景（全新仓库首次 commit 即含 e2e）against 计算异常 → diff-index 失败 → has_e2e 恒为 0 → e2e 校验被跳过 → 首提交 e2e 无 trailer 也能过。概率低但属安全门禁的边界绕过。
- **建议**：用 git 官方空树常量 `4b825dc642cb6eb9a060e54bf8d69288fbee4904` 或 `git rev-parse --verify HEAD^{} 2>/dev/null || echo "<EMPTY-TREE>"` 配合显式判断；或首提交场景显式 `git diff --cached --name-only`（无 against 需求）。
- **置信度**：中（git 版本行为差异未实测，但模式非常规）
- **优先级**：HIGH

## 中低优先级问题（MEDIUM / LOW）

### M1. `hooks/post_tool_use.sh` 测试命令拼接用 `eval`，路径含空格/特殊字符时破坏命令

- **位置**：`hooks/post_tool_use.sh:35` — `test_cmd="npm test -- ${rel%.ts}.test.ts 2>/dev/null || npm test 2>/dev/null"`；第 57 行 `eval "$test_cmd"`
- **现象**：`rel` 来自编辑文件路径相对化，若含空格（`src/my dir/foo.ts`），`test_cmd` 拼接后 `npm test -- src/my dir/foo.test.ts` 被 eval 拆词出错。
- **影响**：测试证据文件记录错误的命令/失败结果，Stop hook 据此可能误判（虽有 5 分钟新鲜证据即放行，但证据质量受损）。
- **建议**：对 `rel` 加引号 `"${rel%.ts}.test.ts"`，或改 `eval` 为数组 + `"$@"`。
- **置信度**：中（路径含空格在 Windows 较常见）
- **优先级**：MEDIUM

### M2. `hooks/post_tool_use.sh` 测试命令探测逻辑粗糙，`pytest -q` 全量跑可能很慢

- **位置**：`hooks/post_tool_use.sh:34-40`
- **现象**：只要有 `pytest.ini` 或 `tests/` 目录就 `pytest -q`（全量），每次 src/test 编辑触发全量测试。大型项目 PostToolUse 阻塞编辑流，体验差且证据文件膨胀（虽 `head -200` 截断）。npm 分支尝试 `${rel%.ts}.test.ts` 单文件，pytest 分支无对应单测定位。
- **影响**：编辑延迟、token 浪费（证据灌进 task 目录后续可能被读）。设计意图是「留机器证据」，但全量 pytest 的证据意义有限。
- **建议**：pytest 分支也尝试定位单测（`${rel%.py}_test.py` / `test_${rel}`），失败再 fallback 全量并标注；或加超时。
- **置信度**：中
- **优先级**：MEDIUM

### M3. `op_worktree_setup.sh` eval 模式 sparse pattern `/*` 在非 cone 模式只匹配顶层，深层排除依赖默认行为

- **位置**：`scripts/op_worktree_setup.sh:37-60`
- **现象**：非 cone 模式 sparse-checkout 的 pattern 是 gitignore 风格。`/*` 匹配顶层所有，`!/src/` 重新包含 src——但意图是**排除** src。代码注释说「排除 src/」，可 pattern `!/src/` 语义是「不排除」（即包含）。对照 dev 模式 `/*` + `!/e2e/` 同样意图排除 e2e。**这里 pattern 语义与注释相反**：`!/e2e/` 在 `/*`（包含全部）之后是「重新包含 e2e」，即 e2e 被**包含**，与「排除 e2e」意图相反。
- **影响**：若分析正确，dev worktree 实际**包含** e2e（隔离失效），eval worktree **包含** src/tasks/decisions（防抄实现失效）。但第 72-92 行有验证段（检查目录是否存在并 WARN），实测若隔离未生效会 WARN。需实机验证 pattern 语义——git 非 cone 模式下 `/*` 是否真的「包含全部」还是「匹配顶层」。若 git sparse-checkout 非 cone 默认「不物化任何，pattern 决定物化」，则 `/*` 物化全部、`!/x/` 排除 x，语义正确。
- **建议**：pattern 语义存疑，强烈建议补一行注释明确「非 cone 模式 = 默认全物化，! 用于排除」并在 PR 说明里附 git 文档链接；或改用 cone 模式（更可预测，但不支持 `!` 否定，需重写 pattern）。当前依赖验证段兜底，但验证段只 WARN 不 fail，advisory 级。
- **置信度**：中（git sparse-checkout 非 cone pattern 语义需核对官方文档，本审阅未联网；代码异味在注释与 pattern 字面张力）
- **优先级**：MEDIUM

### M4. `op_worktree_setup.sh` git 版本检测正则 `2\.(2[5-9]|[3-9])` 不匹配 2.10-2.24 但 sparse-checkout 需 2.25+

- **位置**：`scripts/op_worktree_setup.sh:18`
- **现象**：注释说「需 git 2.25+」，正则 `2\.(2[5-9]|[3-9])` 匹配 2.25-2.29、2.3-2.9，**不匹配 2.30-2.99**（`[3-9]` 只到 2.9）。git 2.30+ 反而不被识别为满足，触发 WARN。实际 2.25+ 都满足 sparse-checkout。
- **影响**：git 2.30+ 用户（当前主流 git 已 2.40+）每次 setup 都打 WARN「sparse-checkout 可能不可用」，误报警告疲劳。
- **建议**：正则改为 `2\.(2[5-9]|[3-9][0-9])` 或用 `git version` 数值比较（`awk '{split($3,v,"."); if (v[1]>2 || (v[1]==2&&v[2]>=25)) exit 0; else exit 1}'`）。
- **置信度**：高（正则字面分析确定）
- **优先级**：MEDIUM

### M5. `scripts/op_status.sh` 与 `scripts/op_jq.sh` 在顶层与 lite 副本内容不同，install 同时安装致解析歧义

- **位置**：`install.sh:48,57-58`（顶层 scripts 与 skills/oplrun/scripts 都被装）
- **现象**：`diff` 确认 `scripts/op_status.sh`（含 closing 态）≠ `skills/oplrun/scripts/op_status.sh`（lite 去 closing）；`op_jq.sh` 同理。install 把顶层 `scripts/` 装 `~/.claude/scripts/omni_powers/`，把 `skills/oplrun/` 装 `~/.claude/skills/oplrun/scripts/`。lite skill 用 `${OP_SCRIPT_ROOT:-$OP_HOME}` 解析——`OP_SCRIPT_ROOT` 指向共享目录（顶层版，含 closing），与 lite 副本（去 closing）语义冲突。design §5.5 称「副本暂留并与 heavy 同步内容（ASCII/obsolete/删 skipped）」，但 op_status 两版本就该不同（lite 去 closing）。
- **影响**：lite 解析到顶层版 `op_status.sh`（含 closing）时，status 校验接受 closing——但 lite 状态机无 closing 态（design §5.6），语义不一致；反之 lite 副本若被解析则正确。实际哪个被加载取决于 `OP_SCRIPT_ROOT` 注入值与 resolver 双路径（agent 内 `op_script()` 先查 `scripts/` 再 `skills/oprun/scripts/`），lite 副本在 `skills/oplrun/scripts/` 不在 resolver 搜索路径——**lite 副本可能根本不被加载**，resolver 找到顶层共享版。design §5.5 的「渐进归并待重构」承认此点，但当前状态下 lite 状态机一致性受损。
- **建议**：短期在顶层 `op_status.sh` 加 `OP_PROFILE` 分支（lite 时 reject closing），与 design §5.5「脚本内 profile 分支」对齐；长期按 D5 完成归并删 lite 副本。
- **置信度**：中高（resolver 路径与副本存在性确认，但具体 oplrun SKILL 是否显式指 lite 副本路径未在本模块审阅）
- **优先级**：MEDIUM

### M6. `hooks/pre_tool_use.sh` 行级敏感度只对 `Edit` 生效，`Write`/`MultiEdit` 改 expect/assert 无警告

- **位置**：`hooks/pre_tool_use.sh:77-88`
- **现象**：matcher 含 `Edit|Write|MultiEdit`，但行级敏感度判断 `if [ "$tool_name" = "Edit" ]`——Write 整文件覆盖、MultiEdit 多段编辑改断言均不触发 WARN。Write 整文件重写测试文件是「改 expect/assert」的高危场景（整体重写比 Edit 更易掩盖意图）。
- **影响**：Write/MultiEdit 改测试断言无留痕，advisory 防线有缺口（subagent 失效已知，但主会话 leader 场景 Write 改测试也漏 WARN）。
- **建议**：Write 分支读 `.tool_input.content` grep 危险模式；MultiEdit 读 `.tool_input.edits[].new_string`。或至少对 `.test.*`/`tests/*` 路径的 Write 加存在性 WARN。
- **置信度**：中
- **优先级**：MEDIUM

### L1. `hooks/stop.sh` 主会话 Stop 分支 `current_task` 非空只 WARN，但无 `exit 2`——与 README 表述「Q2 不 BLOCK 允许中断」一致，然 WARN 文本可能被 Claude Code Stop 事件忽略

- **位置**：`hooks/stop.sh:17-25`
- **现象**：主会话 Stop（agent_type 空）时 current_task 非空只 echo WARN 到 stderr + `exit 0`。Claude Code 的 Stop hook 对 exit 0 放行，stderr 文本是否回显给模型取决于实现。设计是「不 BLOCK 允许中断」，语义正确，但 WARN 若不可见则等于静默放行。
- **影响**：低（设计本就 advisory，非阻断）。
- **建议**：确认 Claude Code Stop hook 的 stderr 回显行为；若不回显，考虑 exit 2 但提示「允许 override 继续」的交互（与「允许中断」张力，需权衡）。
- **置信度**：中
- **优先级**：LOW

### L2. `uninstall.sh` purge_project 的 jq filter `is_op` 正则对 `\$OP_HOME/hooks/run-hook.cmd` 转义繁复，边界情况可能漏匹配

- **位置**：`uninstall.sh:116` — `test("omni_powers|\\$OP_HOME/hooks/run-hook\\.cmd|OP_HOME/hooks/run-hook\\.cmd")`
- **现象**：jq `test` 用 PCRE，`\\$` 在 bash 单引号 + jq 字符串里转义层次多。实际 command 字段是字面 `$OP_HOME/hooks/run-hook.cmd`（未展开，因 settings.json 存原样）。正则 `omni_powers` 已足够兜底匹配（所有 op hook command 都含 omni_powers 路径或 run-hook.cmd 在 OP_HOME 下，OP_HOME 指向 omni_powers 仓库）。
- **影响**：低（`omni_powers` 关键词已覆盖，复杂正则属冗余防御）。
- **建议**：简化为 `test("omni_powers|run-hook\\.cmd")`，减少转义层次。
- **置信度**：中高
- **优先级**：LOW

### L3. `op_trailer_unlock.sh` secret 生成 fallback `/dev/urandom | od` 在某些精简环境（容器）od 可能缺失

- **位置**：`scripts/op_trailer_unlock.sh:31`
- **现象**：openssl 缺失时 fallback `head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n'`。`od`（octal dump）在极精简容器可能不存在。openssl 是主路径，fallback 冷僻。
- **影响**：低（openssl 广泛存在）。
- **建议**：fallback 改 `xxd -p -c 32` 或 `hexdump -v -e '32/1 "%02x"'`，或直接提示需 openssl。
- **置信度**：中
- **优先级**：LOW

### L4. `hooks/README.md` 称 SubagentStop matcher=`op-implementer`，但 settings.template.json 同配置——matcher 语法是否匹配 agent_type 需核对 Claude Code 版本

- **位置**：`hooks/settings.template.json:21-27`、`hooks/README.md:45`
- **现象**：SubagentStop matcher 写 `op-implementer`，假定 Claude Code 按 agent_type 过滤。Claude Code hook matcher 语义随版本演进，SubagentStop 的 matcher 字段是否支持 agent_type 值过滤未在本审阅核对（不联网）。
- **影响**：若 matcher 不按 agent_type 过滤，所有 subagent 停止都触发 stop.sh，但脚本内第 16 行读 `.agent_type` 判断，op-reviewer/op-evaluator 也会被 `current_task` 校验——可能误拦非 implementer subagent。
- **建议**：核对接入的 Claude Code 版本的 SubagentStop matcher 规范；脚本内 agent_type 判断已有一定防御。
- **置信度**：中（不联网无法确认）
- **优先级**：LOW

## 改进建议

1. **统一 bash 版本守卫**：`op_check_env.sh` 已 WARN 非 bash，但关键安全脚本（`op_closer_gate.sh` 用 mapfile、`op_status.sh` 用 flock）无 bash 版本检查。建议入口统一 `if [ "${BASH_VERSINFO[0]:-0}" -lt 4 ]; then die "需 bash 4+（mapfile/flock）"; fi`，或在 `op_check_env.sh` 强化（当前只 WARN 不 die）。macOS 用户默认 bash 3.2 是真实部署风险。

2. **HMAC 构造公共化**：commit-msg 与 op_trailer_unlock 的 e2e 清单 → HMAC 流水线抽公共函数（或公共脚本 `op_e2e_hmac.sh`），两处 source/call，消除 H4 的构造差异风险。

3. **chmod 覆盖全安装目标**：install.sh 的 chmod 改为覆盖所有 `$CLAUDE_HOME` 下 op 产物（skills/scripts/agents），而非手动列 glob，防新增 skill/脚本漏 chmod。

4. **build_lite 改为目录枚举**：校验列表从硬编码改为「枚举 lite 目录全部 .sh，与校验列表做差集，未登记即告警」，防新增文件漏登记（H2 根因）。

5. **sparse-checkout pattern 补注释 + 单测**：op_worktree_setup 的 pattern 语义补官方文档引用，并考虑加一个最小 worktree 创建测试（bats）验证 e2e/src 确实未物化，防 M3 的语义误解静默失效。

6. **行级敏感度覆盖 Write/MultiEdit**：pre_tool_use 的 expect/assert WARN 扩展到 Write（读 content）与 MultiEdit（读 edits[].new_string），堵 M6 缺口。

## 不确定项 / 可能误报

- **M3（sparse pattern 语义）**：非 cone 模式 `/*` + `!/x/` 的实际语义未联网核对 git 官方文档。若非 cone 模式默认「全物化、pattern 排除」，则当前 pattern 正确、注释只是冗余；若默认「全不物化、pattern 包含」，则 pattern 反向、隔离失效。验证段（检查目录存在）是 advisory 兜底，但只 WARN。**建议实机测一个 dev worktree 确认 e2e/ 是否物化**。可能误报为 MEDIUM，实情或为 CRITICAL（隔离失效）或为无问题。

- **H4（HMAC mismatch）**：正常 ASCII 路径下两处构造经 `grep . | sort | tr` 后大概率一致，特殊字符路径未实测。若 git diff-index 在两脚本中以相同参数调用（都 `--cached --name-only`），输出应一致，mismatch 风险降低。commit-msg 的 while 累积方式与 unlock 的命令替换方式在 `grep .` 过滤后应趋同。可能高估为 HIGH，实情或为 MEDIUM。

- **H5（空树 hash）**：`git hash-object -t tree /dev/null` 在现代 git（2.20+）产出稳定空树 hash，旧 git 行为未实测。若所有目标 git 版本都支持，则非问题。可能误报。

- **M5（lite 副本是否被加载）**：取决于 oplrun SKILL.md 是否显式指向 `skills/oplrun/scripts/` 还是走 resolver 到共享目录。本模块未审阅 oplrun SKILL.md（不在范围），若 oplrun 显式用 lite 副本路径则 M5 不成立。

- **L4（SubagentStop matcher 语义）**：不联网未确认 Claude Code 当前版本 SubagentStop matcher 规范，可能误报。
