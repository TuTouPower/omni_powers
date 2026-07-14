# 当前模型判断依据

可观测来源：settings 顶层 model=default_model；env.ANTHROPIC_MODEL=default_model；默认档位 haiku=default_haiku[1m] / sonnet=default_sonnet[1m] / opus=default_opus[1m]；主会话 powered by default_model。current 路继承主会话。未写入 secret。

# 审阅范围

核心参考：`/home/karon/karson_ubuntu/omni_powers/docs/omni_powers_design.md`

本次只读审阅：

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
- `/home/karon/karson_ubuntu/omni_powers/scripts/test_lock.sh`

审阅重点：hook、install/uninstall、共享 scripts 是否与能力矩阵、heavy/lite 安装模型、merge gate/closer gate/trailer/worktree/status 设计一致。

# 高优先级问题

## 1. hook 模板缺失 design 要求的 SessionStart / Stop / PreToolUse[Task]，且 README 与模板不一致

- 位置：`/home/karon/karson_ubuntu/omni_powers/hooks/settings.template.json:3-28`；`/home/karon/karson_ubuntu/omni_powers/hooks/README.md:39-46`；design §4.1 hooks 清单。
- 现象：模板只注册 `PreToolUse(Edit|Write|MultiEdit|Bash)`、`PostToolUse(Edit|Write|MultiEdit)`、`SubagentStop(op-implementer)`。README 列出 `SessionStart`，design §4.1 还要求 `PreToolUse[Task]` dispatch 协议留痕、`Stop` leader 收尾门禁、`SessionStart` 或 `/oprun` 启动注入/漂移校验语义。当前模板均未包含。
- 影响：heavy 安装后的 hook 能力与文档承诺不一致。尤其 Stop/SessionStart 相关门禁缺席，会让恢复、漂移复查、leader 收尾门禁只能靠 skill 纪律；用户按 README/design 预期安装后实际防线不足。
- 建议：二选一统一：若这些 hook 已被设计改为 `/oprun` 内部脚本实现，则删除 README/template/design 中 hook 承诺；若仍属 heavy hook 能力，则补 `SessionStart`、`Stop`、`PreToolUse[Task]` 模板与对应脚本，并在 README 标明哪些是 advisory、哪些实际阻断。
- 置信度：高。
- 优先级：高。

## 2. install.sh 删除目标目录再复制/软链，违背“新增，不覆盖用户已有”安装边界

- 位置：`/home/karon/karson_ubuntu/omni_powers/install.sh:36-44`；design §5.3 零侵入边界；README 安装说明。
- 现象：`install_one()` 对每个目标执行 `rm -rf "$dst"`，再 `ln -s` 或 `cp -r`。design §5.3 表述全局安装允许写入 `~/.claude/skills/`、`~/.claude/agents/op-*.md` 是“新增，不覆盖用户已有”。当前实现会覆盖同名 skill/agent/script 目录或软链。
- 影响：若用户已有同名 skill/agent（尤其 `opstatus`、`opspec` 等通用名可能冲突）会被无确认删除。lite 宣称零侵入虽限定“不侵入用户项目”，但全局配置仍属用户资产；当前脚本行为比设计承诺更强。
- 建议：安装前检测目标是否存在且非本工具产物：默认 fail 并提示 `--force`；对已由本工具安装的目标可覆盖；`--link` 也不应无条件删除非本工具目录。脚本头说明需同步为“会覆盖 omni_powers 管理目标”。
- 置信度：高。
- 优先级：高。

## 3. uninstall.sh 未卸载共享 scripts 目录，install.sh 产物残留

- 位置：`/home/karon/karson_ubuntu/omni_powers/install.sh:56-58`；`/home/karon/karson_ubuntu/omni_powers/uninstall.sh:5-8`、`67-94`。
- 现象：install.sh 安装 `~/.claude/scripts/omni_powers`，uninstall.sh 只删除 skill、agent、`env.OP_HOME`，未删除该 scripts 目录；计划输出也未列出 scripts 清理。
- 影响：卸载不完整。后续 lite dispatch 若残留旧脚本，可能误用过期共享目录；重新安装/切换拷贝与软链模式也可能出现状态混杂。
- 建议：把 `~/.claude/scripts/omni_powers` 纳入全局卸载计划；同样采用“只删本工具产物”标识策略，避免误删用户目录。
- 置信度：高。
- 优先级：高。

## 4. op_check_env.sh 不支持 design 要求的 OP_SCRIPT_ROOT/profile 化共享入口，lite 会被 OP_HOME 卡死

- 位置：`/home/karon/karson_ubuntu/omni_powers/scripts/op_check_env.sh:30-44`；design §5.4、§5.5。
- 现象：脚本强制校验 `OP_HOME` 存在，未识别 `OP_SCRIPT_ROOT`，也未校验 `OP_PROFILE=heavy|lite`。design §5.4/§5.5 要求 heavy/lite 共用脚本经 `${OP_SCRIPT_ROOT:-$OP_HOME}` fallback，lite 不依赖 OP_HOME；共享脚本入口要校验 OP_PROFILE 未知值 die。
- 影响：install.sh 已安装共享 scripts 目录，但 lite 场景若只走 `OP_SCRIPT_ROOT`，该环境检查会失败；更严重的是新共享脚本没有 profile 明确分支时可能按 heavy 假设执行，违背 design 的防静默异常要求。
- 建议：改为 resolver：`script_root=${OP_SCRIPT_ROOT:-${OP_HOME:-}}`；`OP_PROFILE=lite` 时跳过 OP_HOME 必需校验，只校验 jq/git 与 script_root；`OP_PROFILE=heavy` 时要求 OP_HOME 或有效 script_root；未知/空 OP_PROFILE 按调用场景明确 fail 或从 `docs/omni_powers/profile` 读取。
- 置信度：高。
- 优先级：高。

## 5. 缺少目标清单中的 merge gate 实现，相关 hook/script 只能提供周边防线

- 位置：本分块审阅目标未包含 `/home/karon/karson_ubuntu/omni_powers/scripts/op_merge_gate.sh`；design §0.2、§3.4、§4.1。
- 现象：design 把 merge gate 定义为 P1 写入硬底线：白名单机械校验 + review verdict 主分支读取 + task 分支受保护路径 REJECT。本次目标脚本中没有对应文件；README/settings/hook 也不能替代该主防线。
- 影响：若仓库实际没有 `op_merge_gate.sh` 或 oprun 未调用，则能力矩阵“merge gate P1 硬防线”未闭环；e2e/spec/blueprint/decisions 的 task 分支越界改动无法在主分支回流时机械拦截。
- 建议：确认 `op_merge_gate.sh` 是否存在且由 `/oprun` 必跑；若未实现，应将能力矩阵状态降级，或补实现并纳入本分块审阅目标。此问题为设计一致性风险，需跨分块确认。
- 置信度：中（目标清单未列该文件，可能在其他分块）。
- 优先级：高。

## 6. closer gate 使用全工作区 git status，可能撤销 closer 前已有用户/leader 改动

- 位置：`/home/karon/karson_ubuntu/omni_powers/scripts/op_closer_gate.sh:20-36`；design §2.6。
- 现象：脚本用 `git status --porcelain` 扫整个工作区，再对越界文件执行 `git checkout -- "$f"`。它没有记录 closer 启动锚点，也没有区分“closer 本次触碰”与“closer 前已存在的未提交改动”。未跟踪新文件也不会被 `git checkout --` 删除。
- 影响：若 leader 在 closer 前已有合法未提交变更（例如 review.md、checkpoint、临时验证文件），closer gate 会误判越界并尝试撤销，造成数据丢失或流程状态损坏；未跟踪越界文件则可能残留，gate 输出 REVERT 也不一定真实清干净。
- 建议：closer 派发前记录 baseline（`git status --porcelain -z` 或临时 index/锚点），gate 只比较 baseline 之后新增/变化；撤销越界时区分 tracked/untracked，tracked 用 `git restore --worktree --staged -- path`，untracked 用明确的删除策略并先打印路径；更安全做法是 gate 只 fail，不自动撤销，交 leader 决策。
- 置信度：高。
- 优先级：高。

# 中低优先级问题

## 1. e2e trailer 实现与 design 文本的“绑定 commit-sha/最简存在性”描述不一致

- 位置：`/home/karon/karson_ubuntu/omni_powers/hooks/git/commit-msg:3-10`、`48-56`；`/home/karon/karson_ubuntu/omni_powers/scripts/op_trailer_unlock.sh:9-10`、`39-55`；design §2.5。
- 现象：实现使用 `HMAC(secret, 排序后的 staged e2e 文件清单)`，没有绑定 commit sha，也不是 design §2.5 所写“从最简版起步（trailer 存在性校验），HMAC 签名等强化等观察到真实绕过案例再加”。README 也写成 HMAC 文件清单。
- 影响：实现强于 design 旧段，但设计档案内部口径不一致。审阅者无法判断预期安全语义：绑定 commit-sha、防重放、还是只绑定文件清单。当前同一 e2e 文件清单的 trailer 可跨不同内容复用，若目标是“绑内容防重放”，实现并未达到；commit-msg 注释“绑内容防重放/复用”也不准确。
- 建议：统一 design 与实现。若保留 HMAC，应明确绑定对象是“e2e 路径清单”而非内容/commit；若要更强，改为绑定 staged e2e 路径 + blob sha 或 staged diff hash，commit-msg 与 unlock 同步。
- 置信度：高。
- 优先级：中。

## 2. commit-msg HMAC 数据构造有多余命令与错误文案

- 位置：`/home/karon/karson_ubuntu/omni_powers/hooks/git/commit-msg:49`、`63-65`。
- 现象：`hmac_data="$(printf '%s' "$e2e_paths" | grep -c . >/dev/null; printf '%s' "$e2e_paths" | sort | tr '\n' ':')"` 前半段只执行无输出检查，语义噪音大；错误提示含“staged 文件变了中国需重跑”。
- 影响：可读性下降；中文 typo 影响用户按提示处理失败。
- 建议：改为与 `op_trailer_unlock.sh` 一致的 `printf '%s\n' "$e2e_paths" | sort | tr '\n' ':'`，修正文案为“staged 文件变了需重跑”。
- 置信度：高。
- 优先级：低。

## 3. post_tool_use.sh 测试命令推断偏 npm/ts，且 OP_TEST_COMMAND 优先级过低

- 位置：`/home/karon/karson_ubuntu/omni_powers/hooks/post_tool_use.sh:32-40`。
- 现象：存在 `package.json` 且有 `scripts.test` 时固定用 `npm test -- ${rel%.ts}.test.ts || npm test`；OP_TEST_COMMAND 只有在无 package/pytest 时才生效。对 pnpm/yarn、js/tsx/vue、monorepo、非 `.ts` 文件都可能误判。
- 影响：PostToolUse 证据可能不是项目真实测试入口；SubagentStop 只检查新鲜证据存在，错误命令可能写出失败日志仍被当作证据文件存在，削弱“机器证据”门禁可信度。
- 建议：OP_TEST_COMMAND 应最高优先级；package 管理器按 lockfile 选择 pnpm/yarn/npm；证据文件中记录 exit code 后，Stop 至少检查最近证据 `--- exit: 0 ---`，否则“有失败证据也放行”。若设计仍坚持只验存在，应在 README 明确。
- 置信度：中。
- 优先级：中。

## 4. stop.sh 对 test_evidence_NONE.log 永久放行，不检查新鲜度或任务匹配

- 位置：`/home/karon/karson_ubuntu/omni_powers/hooks/stop.sh:24-29`。
- 现象：只要 `tasks/{TID}/test_evidence_NONE.log` 存在即放行，不检查 mtime，也不验证该文件是否由本轮 PostToolUse 生成。
- 影响：无测试项目一旦生成过 NONE 标记，后续同 task 多轮修改无需任何新证据即可交工。虽 design 承认证据为 advisory，但这会进一步降低门禁信号。
- 建议：NONE 标记也按 5 分钟新鲜度校验，或记录本轮 edit 时间/dispatch 锚点；至少在 Stop 输出 WARN 提醒“无测试入口，仅纪律放行”。
- 置信度：高。
- 优先级：中。

## 5. op_worktree_setup.sh dev 注释包含 reviewer/closer，和 design 角色工作位置不一致

- 位置：`/home/karon/karson_ubuntu/omni_powers/scripts/op_worktree_setup.sh:5-6`、`43-49`；design §3.4 角色 × 文件系统视图。
- 现象：用法注释写 `dev # implementer/reviewer/closer，排除 e2e/`，但 design 规定 reviewer 只读不需要 checkout，closer 在主 worktree 完整 checkout，且 closer 由 `op_closer_gate.sh` 控制。
- 影响：误导调用方给 reviewer/closer 创建 dev sparse worktree，破坏“review.md 单写者=leader”和“closer 主 worktree 一段式收口后 gate”的流程假设。
- 建议：注释改为 `dev # implementer`；若确有 reviewer/closer 历史路径，删除或标废弃。
- 置信度：高。
- 优先级：中。

## 6. op_worktree_teardown.sh 用 grep 匹配 worktree 路径，可能误匹配

- 位置：`/home/karon/karson_ubuntu/omni_powers/scripts/op_worktree_teardown.sh:10-14`。
- 现象：`git worktree list | grep -q "$wt_path"` 未做固定字符串整行路径匹配；路径包含正则字符或是另一 worktree 路径子串时可能误判。
- 影响：可能对非目标目录执行 `git worktree remove` 或 fallback `rm -rf`，尤其路径来自变量时风险较高。
- 建议：使用 `git worktree list --porcelain` 解析 `worktree <path>` 行，固定字符串比较；`rm -rf` fallback 前确认路径在项目受控 worktree 根下。
- 置信度：中。
- 优先级：中。

## 7. op_new_task.sh 仍硬依赖 OP_HOME/docs_template，不符合共享脚本 fallback 方向

- 位置：`/home/karon/karson_ubuntu/omni_powers/scripts/op_new_task.sh:9-16`；design §5.4、§5.5。
- 现象：`PLUGIN_ROOT="${OP_HOME:-...}"`，模板取 `$PLUGIN_ROOT/docs_template/...`。install.sh 只把 `scripts` 复制到 `~/.claude/scripts/omni_powers`，未复制 `docs_template` 到共享脚本目录；lite 无 OP_HOME 时该脚本从共享 scripts 运行会推导到 `~/.claude/scripts/omni_powers/..`，找不到模板。
- 影响：如果 lite 或全局共享脚本路径调用 `op_new_task.sh`，会失败；与“install.sh 装共享 scripts，lite 固定路径引用”不完全一致。
- 建议：要么把 `docs_template` 同步安装到共享根并让 resolver 知道模板根；要么该脚本明确 heavy-only；要么改用项目内已初始化模板/内联生成。
- 置信度：高。
- 优先级：中。

## 8. build_lite.sh 与 design §5.5 新旧状态并存，容易让维护者误判共享脚本已彻底归并

- 位置：`/home/karon/karson_ubuntu/omni_powers/scripts/build_lite.sh:1-8`；design §5.5 特别是 803-825。
- 现象：design 前半段说“消灭 per-skill 副本同步机制”，后半段又写“lite 副本暂保留，build_lite.sh 暂留维护副本同步”。脚本自身仍按副本漂移校验运行。
- 影响：这是文档状态冲突，不一定是代码 bug，但会影响审阅与后续改造：维护者不清楚 build_lite 是遗留必跑，还是应删除。
- 建议：design §5.5 改成单一当前态：当前仍保留副本 + build_lite 维护；目标态是共享脚本删除副本。install.sh 说明也标“D5 基础，不代表 lite 已完全切共享”。
- 置信度：高。
- 优先级：中。

## 9. hooks/pre_tool_use.sh 中 spec 写保护覆盖 baselines/* 但未递归覆盖 baselines 子目录

- 位置：`/home/karon/karson_ubuntu/omni_powers/hooks/pre_tool_use.sh:45-46`；`/home/karon/karson_ubuntu/omni_powers/hooks/git/pre-commit:15-17`。
- 现象：pattern 为 `docs/omni_powers/op_blueprint/baselines/*`，只能覆盖 baselines 下一级路径；design baseline 示例有 `baselines/session-management/AC-2_login_error.png` 二级文件。
- 影响：主会话 PreToolUse 和 git pre-commit 对深层 baseline 文件的 status 检查不会命中。不过 baseline 快照本身未必有 frontmatter status，且主保护应靠 merge gate/closer gate；此处主要是路径保护口径不完整。
- 建议：若要保护整个 baselines 树，改为 `docs/omni_powers/op_blueprint/baselines/**` 等 shell case 可表达的递归模式（或前缀判断）；若仅保护带 frontmatter 的索引文件，注释说明。
- 置信度：中。
- 优先级：低。

# 改进建议

1. 建立 hook 能力表自动测试：给 `settings.template.json`、README hook 列表、design §4.1 生成对照检查，避免模板漏注册。
2. 给所有共享脚本加统一入口库：`op_resolve_env.sh` 负责 `OP_PROFILE`、`OP_SCRIPT_ROOT`、`OP_HOME`、项目根、profile 文件读取；减少每个脚本自行判断导致 heavy/lite 漂移。
3. 安装产物加 manifest：install.sh 写 `~/.claude/omni_powers/install_manifest.json`，记录 skill/agent/scripts 路径、模式 cp/link、源仓库；uninstall 根据 manifest 删除，避免漏删与误删。
4. gate 类脚本默认只报告不自动破坏工作区；确需自动撤销时必须基于派发前快照，只处理本轮新增变化。
5. trailer 绑定对象升级为 staged e2e blob/diff hash，比“路径清单”更贴近“防重放/复用”目标。

# 不确定项

1. `op_merge_gate.sh` 未在本分块目标内。若它存在且由 `/oprun` 强制调用，高优先级问题 5 应转为“审阅目标遗漏/需另分块确认”；若不存在，则能力矩阵需要降级或补实现。
2. `opinit_register_hooks.sh` 未在本分块目标内。Windows hook command 改写、git hooks 注册“不覆盖用户已有非 omni_powers hook”的实际行为无法从当前文件确认。
3. `session_start.sh` 在 README 中出现，但不在本分块目标内，仓库是否存在及是否由其他路径注册未确认。
4. lite skills 是否仍调用 `skills/oplrun/scripts` 副本，还是已切到 `~/.claude/scripts/omni_powers`，需结合 skill 文件确认；本报告仅指出共享脚本本身与 design fallback 的不一致。
