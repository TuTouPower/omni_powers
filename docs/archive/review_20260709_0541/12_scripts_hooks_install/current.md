## 当前模型判断依据

可观测来源：`/home/karon/.claude/settings.json` 顶层 `model=haiku`；`env.ANTHROPIC_MODEL=default_model`；`ANTHROPIC_DEFAULT_HAIKU_MODEL=default_haiku[1m]`；`ANTHROPIC_DEFAULT_SONNET_MODEL=default_sonnet[1m]`；`ANTHROPIC_DEFAULT_OPUS_MODEL=default_opus[1m]`；主会话环境提示当前由 `default_model` 驱动。不能读取运行时内部状态；current 路继承主会话。

## 审阅范围

已按要求先完整阅读上下文文件：

- `/home/karon/karson_ubuntu/omni_powers/docs/omni_powers_design.md`

本次只审阅以下文件，排除 `vendors/` 与 `docs/archive/`，未跑构建、未跑测试、未联网，源码只读，仅写本报告：

- `/home/karon/karson_ubuntu/omni_powers/hooks/README.md`
- `/home/karon/karson_ubuntu/omni_powers/hooks/git/commit-msg`
- `/home/karon/karson_ubuntu/omni_powers/hooks/git/pre-commit`
- `/home/karon/karson_ubuntu/omni_powers/hooks/post_tool_use.sh`
- `/home/karon/karson_ubuntu/omni_powers/hooks/pre_tool_use.sh`
- `/home/karon/karson_ubuntu/omni_powers/hooks/run-hook.cmd`
- `/home/karon/karson_ubuntu/omni_powers/hooks/settings.template.json`
- `/home/karon/karson_ubuntu/omni_powers/hooks/stop.sh`
- `/home/karon/karson_ubuntu/omni_powers/install.sh`
- `/home/karon/karson_ubuntu/omni_powers/uninstall.sh`
- `/home/karon/karson_ubuntu/omni_powers/scripts/build_lite.sh`
- `/home/karon/karson_ubuntu/omni_powers/scripts/op_check_env.sh`
- `/home/karon/karson_ubuntu/omni_powers/scripts/op_closer_gate.sh`
- `/home/karon/karson_ubuntu/omni_powers/scripts/op_jq.sh`
- `/home/karon/karson_ubuntu/omni_powers/scripts/op_mutation_check.sh`
- `/home/karon/karson_ubuntu/omni_powers/scripts/op_new_task.sh`
- `/home/karon/karson_ubuntu/omni_powers/scripts/op_status.sh`
- `/home/karon/karson_ubuntu/omni_powers/scripts/op_trailer_unlock.sh`
- `/home/karon/karson_ubuntu/omni_powers/scripts/op_worktree_setup.sh`
- `/home/karon/karson_ubuntu/omni_powers/scripts/op_worktree_teardown.sh`

## 高优先级问题（CRITICAL / HIGH）

### 1. `op_worktree_setup.sh dev` 只排除 `e2e/`，未隔离流程文件与规格/决策文件

- 位置：`/home/karon/karson_ubuntu/omni_powers/scripts/op_worktree_setup.sh:42-49`
- 现象：`dev` sparse-checkout 规则只有：
  - `/*`
  - `!/e2e/`
  因此 implementer worktree 仍会物化 `docs/omni_powers/op_execution/tasks_list.json`、`leader_checkpoint.md`、`op_execution/tasks/*/review.md`、`op_record/decisions.md`、`op_blueprint/**`、所有工作 spec 等流程/规格文件。
- 影响：与设计上下文 §3.4 明确冲突：流程文件只在主 worktree 一份物理副本，implementer/evaluator worktree 不挂 `op_execution/` + `op_record/`，例外只挂 report 与只读 spec；`tasks_list.json` 不挂给任何 subagent。当前实现会让 implementer 可无意或有意读写 tasks_list、review、decisions、blueprint/spec，破坏“单写者=leader”“spec 写保护”“流程文件单副本”模型。merge gate 未在本模块落地时，此处是直接污染通道。
- 建议：重写 `dev` sparse 规则为最小挂载：代码工作集所需路径 + 只读工作 spec + `op_execution/tasks/{TID}/report.md` 所在目录；明确排除 `docs/omni_powers/op_execution/tasks_list.json`、`leader_checkpoint.md`、`op_execution/tasks/*/review.md`、`op_record/**`、`op_blueprint/**`、`e2e/**`。脚本参数需接收 TID/spec/workset 或由调用方生成 sparse 文件。
- 置信度：高
- 优先级：HIGH

### 2. git `pre-commit` 可绕过 protected spec 删除

- 位置：`/home/karon/karson_ubuntu/omni_powers/hooks/git/pre-commit:13-27`
- 现象：hook 对 staged 路径读取工作区文件：`awk ... "$path"`。若 protected spec/baseline 文件被 `git rm` 后 staged，工作区文件已不存在，`awk` 读不到 `status: approved|in_progress`，因此删除可通过。
- 影响：approved/in_progress 生效规格或 baseline 可被直接删除并提交，spec 写保护失效。删除比修改风险更高，会破坏 blueprint 真相源与后续 task/evaluator 依据。
- 建议：从 staged blob 读取状态而非工作区文件，例如 `git show :"$path"`；同时根据 `git diff --cached --name-status` 显式拦截删除/重命名 protected 路径。对 baseline 等无 frontmatter 文件，建议路径级保护，不依赖 status 字段。
- 置信度：高
- 优先级：HIGH

### 3. git/Claude spec 写保护只覆盖 `op_blueprint`，未覆盖 approved 工作 spec

- 位置：
  - `/home/karon/karson_ubuntu/omni_powers/hooks/git/pre-commit:15-26`
  - `/home/karon/karson_ubuntu/omni_powers/hooks/pre_tool_use.sh:44-64`
- 现象：两个 hook 都只匹配 `docs/omni_powers/op_blueprint/**`，未匹配 `docs/omni_powers/op_execution/specs/*.md`。
- 影响：设计上下文 §2.2 与 §3.3 要求工作 spec `approved` 后冻结，改 spec 需走 spec 变更子流程。当前 leader 主会话或 git commit 层均不会阻止 approved 工作 spec 直接修改，可能造成实现、review、验收三方读取同源漂移后的规格，削弱“规格是唯一契约”。
- 建议：在 git `pre-commit` 与 `pre_tool_use.sh` 中加入 `docs/omni_powers/op_execution/specs/*.md` 的 frontmatter `status: approved` 保护；删除/重命名同样按 staged blob/name-status 拦截。若 lite 不使用 hook，应在文档中明确该保护仅 heavy，并在 lite 的 `oplrun` 收口锚点校验中补上。
- 置信度：高
- 优先级：HIGH

### 4. `op_worktree_teardown.sh` 可对任意传入路径执行 `rm -rf`

- 位置：`/home/karon/karson_ubuntu/omni_powers/scripts/op_worktree_teardown.sh:10-14`
- 现象：若 `git worktree list | grep -q "$wt_path"` 不匹配，脚本直接 `rm -rf "$wt_path"`，没有校验路径是否位于项目 worktree 管理目录、是否为 git worktree、是否属于 omni_powers 创建物、是否为空/根目录/上级目录。
- 影响：传错参数即可删除任意目录。该脚本用于清理，属于数据删除路径；当前缺少项目边界与安全确认，存在高风险数据损坏。
- 建议：移除 fallback `rm -rf`，或仅允许删除位于受控前缀（如 `$ROOT/.claude/worktrees/` 或明确配置目录）下且含 omni_powers 标记文件的目录；使用 `git worktree remove` 失败时只报错，不自动删除。对 `wt_path` 做 `realpath`、非空、非 `/`、非 `$HOME`、非项目根校验。
- 置信度：高
- 优先级：HIGH

### 5. `uninstall.sh --purge-project` 无法清理当前 settings 模板结构中的 hook

- 位置：`/home/karon/karson_ubuntu/omni_powers/uninstall.sh:105-123`
- 现象：清理 jq 逻辑检查每个 hook 条目的顶层 `.command`：
  - `def is_op: (.command // "") | test(...)`
  但 `hooks/settings.template.json` 的结构是事件数组项里有 `hooks: [{type, command}]`，`command` 在嵌套数组内，不在 matcher 条目顶层。
- 影响：`--purge-project` 声称会清 `.claude/settings.json` 中 omni_powers 注册的 hook，实际对当前结构大概率不会删除任何 hook。用户以为已卸载/清理项目，Claude Code 仍继续执行旧 hook，造成误拦截、旧 OP_HOME 路径报错或安全策略误判。
- 建议：jq 递归检查嵌套 `.hooks[].command`，删除命中的 hook command；若一个 matcher 条目内部 hooks 全删空，则删除该 matcher 条目。补充 dry-run 输出命中项数量。
- 置信度：高
- 优先级：HIGH

### 6. `op_closer_gate.sh` 使用 `mapfile`，macOS 系统 bash 3.2 直接不可用

- 位置：`/home/karon/karson_ubuntu/omni_powers/scripts/op_closer_gate.sh:20`
- 现象：脚本使用 `mapfile -t CHANGED ...`。macOS 默认 `/bin/bash` 是 3.2，不支持 `mapfile`。
- 影响：项目文档与 hook README 宣称支持 macOS；closer gate 是已落地机械校验。macOS 上运行会在关键校验点失败，使 closer 越界检查不可用。
- 建议：改为 bash 3.2 兼容写法：`CHANGED=(); while IFS= read -r line; do CHANGED+=("$line"); done < <(...)`，或显式要求 bash 4+ 并在 `op_check_env.sh` 硬检查版本。
- 置信度：高
- 优先级：HIGH

## 中低优先级问题（MEDIUM / LOW）

### 7. `op_mutation_check.sh` 的 `sed -i -E` 不兼容 macOS/BSD sed

- 位置：`/home/karon/karson_ubuntu/omni_powers/scripts/op_mutation_check.sh:42`
- 现象：脚本使用 GNU sed 风格 `sed -i -E ... "$src"`。macOS/BSD sed 的 `-i` 需要备份扩展参数（如 `-i ''`），否则失败。
- 影响：跨平台声明下，macOS 定期体检骨架不可用。虽然这是 P3/骨架能力，但失败会造成“变异体未运行”被误解为测试有效性已检查。
- 建议：用临时文件替换原地 `sed -i`，或封装 `sed_in_place` 兼容 GNU/BSD。
- 置信度：高
- 优先级：MEDIUM

### 8. `op_mutation_check.sh` 会错误变异 JS/TS 的 `===` / `!==`

- 位置：`/home/karon/karson_ubuntu/omni_powers/scripts/op_mutation_check.sh:36-42`
- 现象：匹配与替换只按 `==|!=`，会命中 `===`、`!==` 的前两个字符。例如 `===` 可能被替成 `!==` 后残留额外 `=`，生成非法或非预期代码。
- 影响：对 JS/TS 项目可能产生语法错误，把“变异后测试红”误判为 `KILLED`，实际只是代码被破坏，测试覆盖信号失真。
- 建议：按语言区分运算符；JS/TS 使用更精确 token 规则处理 `===`/`!==`，不要用简单 sed；至少检测文件扩展并跳过无法安全变异的语言。
- 置信度：中
- 优先级：MEDIUM

### 9. `op_status.sh --batch ... blocked` 可生成无 `blocked_by` 的 blocked task

- 位置：`/home/karon/karson_ubuntu/omni_powers/scripts/op_status.sh:66-72`
- 现象：单 task 分支要求 `status=blocked` 必须提供 `blocked_by`，但 batch 分支无该校验，且统一 `.blocked_by = null`。
- 影响：违反脚本自身约束与状态语义，后续 `opstatus`/调度/triage 无法区分 resource/quality/spawn 阻塞来源。批量阻塞下游时会产生不完整状态。
- 建议：batch 分支若 status=blocked，要求第 4 参数为 blocked_by 并写入；或明确禁止 batch 设置 blocked。
- 置信度：高
- 优先级：MEDIUM

### 10. `op_status.sh` 与 `op_jq.sh status` 对不存在 TID 静默成功

- 位置：
  - `/home/karon/karson_ubuntu/omni_powers/scripts/op_status.sh:77-85`
  - `/home/karon/karson_ubuntu/omni_powers/scripts/op_jq.sh:61-64`
- 现象：`op_status.sh` 更新不存在 TID 时 jq `map` 不改任何记录，但脚本仍输出 `[OK] <tid> → <status>`；`op_jq.sh status <TID>` 对不存在 TID 输出空且退出 0。
- 影响：leader/脚本可能误以为状态已推进或已读取到有效状态，造成 checkpoint 与 tasks_list 不一致，尤其在 blocked/done/obsolete 这类关键状态推进时不易察觉。
- 建议：更新前后用 jq 校验 TID 存在且恰好 1 条；不存在或重复时 `die`。`op_jq status` 对不存在 TID 返回非零并输出明确错误。
- 置信度：高
- 优先级：MEDIUM

### 11. `op_closer_gate.sh` 路径白名单用前缀匹配，文件型白名单可被相邻文件名绕过

- 位置：`/home/karon/karson_ubuntu/omni_powers/scripts/op_closer_gate.sh:26-29`
- 现象：所有 allowed 项都用 `"$a"*` 匹配。对文件型白名单 `docs/omni_powers/op_record/decisions.md`，`docs/omni_powers/op_record/decisions.md.bak`、`decisions.md.tmp` 等也会被视为合法。
- 影响：closer 可在 `op_record/` 下写入非协议文件并通过 gate，污染 record 区。虽然影响面小于源码/spec 越界，但违背“仅写 decisions.md + issues/ + acceptance/{TID}/”权限清单。
- 建议：区分文件与目录白名单：文件用精确相等，目录用带 `/` 的前缀匹配。
- 置信度：高
- 优先级：MEDIUM

### 12. `op_closer_gate.sh` 解析 `git status --porcelain` 不支持 rename 与含空格文件名

- 位置：`/home/karon/karson_ubuntu/omni_powers/scripts/op_closer_gate.sh:20`
- 现象：`git status --porcelain | awk '{print $2}'` 对 `R  old -> new` 只取旧路径；对带空格路径会截断。
- 影响：白名单判断可能误报或漏报。项目路径多数无空格，故现实概率较低。
- 建议：使用 `git status --porcelain -z` 并按 NUL 解析，或使用 `git diff --name-only -z` / `git ls-files -m -o --exclude-standard -z`。
- 置信度：中
- 优先级：LOW

### 13. `settings.template.json` 未注册设计中提到的 `PreToolUse[Task]` advisory hook

- 位置：
  - `/home/karon/karson_ubuntu/omni_powers/hooks/settings.template.json:4-35`
  - `/home/karon/karson_ubuntu/omni_powers/docs/omni_powers_design.md:680-683`（上下文依据）
- 现象：设计与 hook README 描述有 `PreToolUse[Task]` 用于 dispatch 协议 advisory 留痕；模板只注册 `Edit|Write|MultiEdit|Bash`、`PostToolUse`、`SubagentStop`、`Stop`。
- 影响：dispatch prompt 留痕能力缺失或文档过期。该能力定位 advisory，不影响主防线，但会降低事后审计可观测性。
- 建议：若仍需要 dispatch 留痕，补注册 `PreToolUse` matcher `Task` 并在 `pre_tool_use.sh` 实现只记录不阻断；若已放弃，更新设计/README 删除该承诺。
- 置信度：中
- 优先级：LOW

### 14. `pre_tool_use.sh` 无合法 e2e leader 写入例外，主会话 Edit/Write 会被一律拦截

- 位置：`/home/karon/karson_ubuntu/omni_powers/hooks/pre_tool_use.sh:66-74`
- 现象：任何 `e2e/*|*BUG-*` 的 Edit/Write/MultiEdit 都直接 `exit 2`，没有 trailer unlock 或 leader 合法入口例外。
- 影响：设计允许 leader 主会话通过专属通道落盘 evaluator 固化 PASS 测试或 BUG-* patch。当前工具层会阻止使用 Edit/Write 写 e2e，只能绕到 Bash/cp/patch 等路径，流程体验不一致，也可能诱导使用更难审计的 shell 写入。
- 建议：保留默认阻断，但支持显式 unlock 环境/一次性 token/调用 `op_trailer_unlock.sh` 后的受控写入；或文档明确 e2e 合法写入只能通过 Bash/patch 文件落盘，不能用 Edit/Write。
- 置信度：中
- 优先级：MEDIUM

### 15. `commit-msg` 错误文案含明显错字

- 位置：`/home/karon/karson_ubuntu/omni_powers/hooks/git/commit-msg:63-65`
- 现象：错误提示为“staged 文件变了中国需重跑 op_trailer_unlock.sh”。
- 影响：不影响功能，但会降低可理解性。
- 建议：改为“staged 文件变更后需重跑 op_trailer_unlock.sh”。
- 置信度：高
- 优先级：LOW

### 16. `README.md` 中 design 章节引用疑似过期

- 位置：`/home/karon/karson_ubuntu/omni_powers/hooks/README.md:43,59`
- 现象：README 提到 `design §8.1`、`design §10`，但当前设计文件主要章节为 §0-§5，相关内容在 §0.1/§3.3/§4.1。
- 影响：读者按章节查找会失败，增加维护成本。
- 建议：更新引用到当前章节：subagent hook 失效与安全声明见 §0.1/§3.3，hook 清单见 §4.1，e2e 写入通道见 §2.5。
- 置信度：高
- 优先级：LOW

## 改进建议

1. 为所有 destructive 脚本建立统一安全前置：`realpath`、项目根边界、受控目录前缀、非空路径、非根目录、dry-run。优先覆盖 `op_worktree_teardown.sh`、`uninstall.sh --purge-project`。
2. 将“路径白名单判断”抽成共享函数：区分精确文件、目录前缀、glob；支持 NUL 分隔，避免每个脚本重复实现出错。
3. 明确 heavy/lite 脚本状态：设计 §5.5 同时写“共享 scripts 目录已装”和“lite 副本暂保留”。建议在 `build_lite.sh` 文件头注明当前仍处于 D5 过渡态，避免维护者误删。
4. `op_check_env.sh` 若继续声称 bash 4+，应真正校验 `${BASH_VERSINFO[0]}`；否则所有脚本保持 bash 3.2 兼容，避免 macOS 默认环境失败。
5. `install.sh`/`uninstall.sh` 建议输出安装/卸载的 hooks/scripts 版本或源路径，方便诊断旧全局安装与仓库版本不一致。
6. 对 git hook 增加最小自测脚本：删除 protected spec、改 approved work spec、含 e2e commit 无 trailer、合法 trailer、purge hooks 嵌套结构清理。无需跑构建即可覆盖本模块关键风险。

## 不确定项 / 可能误报

1. `op_worktree_setup.sh dev` 可能被上层调用方另行生成 workset 限制或后续 merge gate 兜底；但本文件自身注释与设计 §3.4 对“worktree 不挂流程文件”的要求不一致，且本模块未包含 `op_merge_gate.sh`，因此按当前文件判断为 HIGH。
2. `pre_tool_use.sh` 对 e2e 的一律阻断可能是有意迫使 leader 只走 shell/trailer 提交通道；但 README/设计没有把“禁止 Edit/Write 写 e2e”作为明确契约，故列为 MEDIUM。
3. `op_closer_gate.sh` 当前“只报不撤销”是 Q5 明确调整；本审阅未将“不自动撤销”本身列为问题，只指出 macOS 兼容与白名单精度问题。
4. `op_mutation_check.sh` 属 P3 骨架能力，不是当前核心流程必经路径；因此即使存在跨平台与 JS/TS token 问题，优先级降为 MEDIUM。
