# haiku 审阅报告 · scripts / hooks / install 分块

## 当前模型判断依据

可观测来源：本 subagent 由 multi-model-review skill 显式 `model: haiku` 派发（授权调用 haiku）。当前会话顶层 model 配置未直接可见，但派发参数指定 haiku 即为本路模型契约。无 secret 写入。

## 审阅范围

hooks/（README、git/pre-commit、git/commit-msg、post_tool_use.sh、pre_tool_use.sh、run-hook.cmd、settings.template.json、stop.sh）、install.sh、uninstall.sh、scripts/（build_lite、op_check_env、op_closer_gate、op_jq、op_mutation_check、op_new_task、op_status、op_trailer_unlock、op_worktree_setup、op_worktree_teardown、test_lock）。

交叉验证读：skills/oprun/scripts/、skills/oplrun/scripts/、docs/omni_powers_design.md、docs/op_decisions.md、既有同批审阅报告。

## 高优先级问题

### H1 · op_close_pre 传中文 status，op_status 只收 ASCII —— heavy closer 流程必炸

- 位置：`skills/oprun/scripts/op_close_pre.sh:18` 调 `op_status.sh "$TID" 收口中`；`scripts/op_status.sh:37-40` 校验枚举 `pending|ready|in_progress|reviewing|closing|done|suspended|blocked|obsolete`。
- 现象：op_close_pre 传中文字符串"收口中"，op_status case 匹配失败 → die "无效 status: 收口中"。
- 影响：heavy per-task 收口第一步（§2.6 closer 一段式前 leader 标 status=closing）必然失败，整条 closer 链路断；与 design §1.1「status 机读 ASCII、渲染层映射中文」的铁律直接冲突。
- 建议：op_close_pre 改为 `op_status.sh "$TID" closing`。同步全仓 grep 中文 status 串调用点。
- 置信度：0.95（grep 已确认 op_status 枚举无中文，op_close_pre 是唯一调用者且参数确为中文）。
- 优先级：CRITICAL（流程断点，heavy 主路径阻塞）。

### H2 · op_merge_gate.sh 全仓缺失 —— design §3.4 写入硬底线核心机制未实现

- 位置：design §3.4 行 634/§0.2 行 47/§4.2 行 703 均称 `op_merge_gate.sh` 为 P1 写入硬底线；`find` 全仓无此文件；`skills/oprun/SKILL.md:229` 自认"P1 交付物，脚本就位前白名单靠 reviewer 双裁决 + 纪律兜底"。
- 现象：design 在 §0.2 能力矩阵标 merge gate 为 P1（未落地），同时 §0.1 信任根声明把 merge gate 作为「写入硬底线」唯一生效点；§3.3 防线映射表第 1 层「实现手段 op_merge_gate.sh」。但本分块审阅的 scripts/ 无此脚本，skills/oprun/scripts/ 也无。
- 影响：当前 heavy 实际无写入硬底线（design §0.1 自承"过渡期兜底靠 reviewer 双裁决 + evaluator 独立验收"，但 §0.2 标注 P1 未落地，诚实）。本条不是"实现漏了"而是"design 承诺 P1 交付，现状 P0，需确认仓库是否应已进入 P1"。
- 建议：(a) 若仓库定位 P0，design 各处改"将交付"为"未交付，P1 落地"统一表述（§4.2 已说清，§0.2 能力矩阵状态列已标 P1，但 §3.4 正文写法像已存在需淡化）；(b) 若 P1 启动，优先实现 op_merge_gate.sh 白名单校验（workset ∪ tasks/{TID}/report.md ∪ 结构层测试路径，其余 REJECT）。
- 置信度：0.9。
- 优先级：HIGH（design 与实现的对齐缺口，影响安全模型诚实性）。

### H3 · commit-msg 校验逻辑与 op_trailer_unlock 生成逻辑 hmac 输入不一致 —— trailer 永远校验失败

- 位置：`hooks/git/commit-msg:48-49` 构造 `hmac_data` 含一处冗余 `grep -c . >/dev/null`；`scripts/op_trailer_unlock.sh:49` 构造方式不同。
- 现象：
  - commit-msg：`e2e_paths` 在循环里累加，每个路径后附 `$'\n'`（line 25），故 `e2e_paths` 末尾有换行；`hmac_data` = `printf '%s' "$e2e_paths" | sort | tr '\n' ':'`。
  - unlock：`e2e_paths` = `git diff-index ... | grep '^e2e/'`（无尾换行保证）；`hmac_data` = `printf '%s\n' "$e2e_paths" | sort | tr '\n' ':'`（多了 `\n`）。
  - 两侧 sort 输入不同（一个末尾带换行一个不带），tr 后末尾是否多一个冒号也不同 → HMAC 必然不同 → 校验必失败。
  - 此外 commit-msg line 49 `printf '%s' "$e2e_paths" | grep -c . >/dev/null;` 是死代码（`grep -c` 输出被 `>/dev/null` 吞，且不影响后续管道），疑为调试残留。
- 影响：leader 跑 op_trailer_unlock 生成 trailer 后 commit，commit-msg 重算 HMAC 必不匹配，e2e 提交永远被阻。design §2.5「trailer 失效后恢复路径——失败提交可重跑解锁脚本」承诺可恢复，但当前是"必失败"非"失效"。
- 建议：(a) 统一两侧 hmac 输入构造，建议都用 `printf '%s\n' "$e2e_paths" | sort | tr '\n' ':'`（含尾换行，tr 后多一尾冒号，但两侧一致即可）；(b) 删 commit-msg:49 的 `grep -c . >/dev/null` 死代码；(c) 加自测：构造 staged e2e 文件 → 跑 unlock → mock commit-msg → 断言通过。
- 置信度：0.85（逐行读出差异，但未实跑 openssl 验证，保留 0.15 给"两侧 sort 对末尾空行处理可能巧合一致"的小概率）。
- 优先级：CRITICAL（e2e 合法写入通道完全失效）。

## 中低优先级问题

### M1 · build_lite.sh 自检当前红 —— 校验机制有效但仓库带病

- 位置：`scripts/build_lite.sh`；实跑输出：`[DRIFT] close_check.sh 与源不一致` + `[FAIL] op_status.sh 丢失 lite 标记「lite 无「收口中」态」`。
- 现象：close_check.sh lite 与 heavy 字节不一致（但被列为逐字节复制类）；op_status.sh lite 副本注释写的是「去 heavy 的 closing」，build_lite 期望标记字符串「lite 无「收口中」态」，措辞不匹配。
- 影响：build_lite 在 CI/开发流程会常红，噪音化，真实漂移会被淹没。
- 建议：(a) 二选一：close_check 若确为有意改造，移出 VERBATIM 列改入 MUTATED_MARK；(b) op_status lite 标记字符串与 build_lite 期望对齐（改 build_lite 的 mark 串或改 lite 注释）。
- 置信度：0.9。
- 优先级：MEDIUM。

### M2 · test_lock.sh 与 hooks 完全未集成 —— 锁定机制退化为登记簿

- 位置：`scripts/test_lock.sh` 全文；`hooks/pre_tool_use.sh:67-74` 按 `e2e/*|*BUG-*` 路径硬拦，未调 test_lock check。
- 现象：test_lock 提供 add/remove/list/check，但 pre_tool_use 拦截不消费它——任何 e2e/BUG-* 文件无论锁定与否都被同等阻断（advisory）。
- 影响：design §3.3 第 5 层「警告+留痕」未实现精细化；evaluator 固化 PASS 测试的"锁定后放行"通道缺失。当前靠 commit-msg trailer 管 e2e 写入，test_lock 实际无用武之地。
- 建议：明确 test_lock 定位——若保留，pre_tool_use 应在主会话场景 `test_lock check` 命中则放行 evaluator 固化路径；若废弃（被 trailer 机制取代），删脚本与 design §3.3 相关引用。
- 置信度：0.7（design §3.3 第 5 层未显式提 test_lock，可能已由 trailer 取代但脚本未清）。
- 优先级：MEDIUM。

### M3 · run-hook.cmd 的 CMD 段 `exit /b` 在 heredoc 消费后仍被 bash 读到？—— 需实测

- 位置：`hooks/run-hook.cmd:1-26`。
- 现象：polyglot 设计——CMD 段包在 `: << 'CMDBLOCK' ... CMDBLOCK` heredoc 里，bash 把 `:` 当 no-op、heredoc 消费 CMD 段。但 CMD 段末尾 `exit /b %errorlevel%` 在 `CMDBLOCK` 标记前——逻辑上 heredoc 内容不执行，OK。风险在 `.gitattributes` 若未强制 LF（README 声称强制），Windows clone CRLF 会令 `: << 'CMDBLOCK'` 失败（`: ` 后跟 CR）。
- 影响：Windows 用户 clone 仓库后 hook 全失效（polyglot 破坏），且静默失败难排查。
- 建议：(a) 确认仓库根 `.gitattributes` 存在且含 `*.cmd text eol=lf` 与 `*.sh text eol=lf`；(b) run-hook.cmd 开头加 CRLF 自检（`grep -q $'\r' "$0" && die "CRLF detected"`）。
- 置信度：0.6（未验证 .gitattributes 实际内容）。
- 优先级：MEDIUM。

### M4 · op_worktree_setup eval 排除 pattern 漏 `packages/*/src` 以外的 monorepo 形态

- 位置：`scripts/op_worktree_setup.sh:53-60`，eval pattern：`!/src/`、`!/packages/*/src/`。
- 现象：design §0.2 说 evaluator 无 `src/**`，但 pattern 只覆盖顶层 src 与 packages/*/src 两形。pnpm/yarn workspace 其他形（apps/*/src、libs/*/src）漏排。
- 影响：monorepo 项目 evaluator 可读到非标准路径的 src，advisory 隔离失效（design §0.1 已承认识别 advisory 不防有意，故影响有限）。
- 建议：pattern 改 `!/src/`、`!/*/src/`（通配任意一级目录下的 src）；或文档注明"monorepo 需项目侧补 pattern"。
- 置信度：0.75。
- 优先级：LOW（advisory 层，design 已声明不防有意）。

### M5 · pre_tool_use.sh blueprint 写保护对 op_blueprint/baselines/ 的 status 读取逻辑不严谨

- 位置：`hooks/pre_tool_use.sh:46-53`，对 `op_blueprint/baselines/*` 路径也跑 `awk /^status:/`。
- 现象：baselines 下是 png/txt/dom 快照（design §1），无 frontmatter status。awk 读不到 status 返回空，不匹配 approved/in_progress，放行——行为正确但逻辑冗余（对无 frontmatter 文件跑 status 检查）。
- 影响：无功能 bug，仅代码清晰度。
- 建议：case 分支细化——specs/*.md + *.md 跑 status 检查；baselines/* 直接走 agent_type 拦截（subagent 不可写）。
- 置信度：0.8。
- 优先级：LOW。

### M6 · install.sh 装共享 scripts 用整目录 cp，lite 共享目录名与 design 不一致

- 位置：`install.sh:57-58` `install_one "$REPO_ROOT/scripts" "$SCRIPTS_DST"`（SCRIPTS_DST=`~/.claude/scripts/omni_powers`）。
- 现象：design §5.5 行 805 说「装 `~/.claude/scripts/omni_powers/`」——一致。但 install_one 用 `rm -rf "$dst"; cp -r "$src" "$dst"`，src 是 `$REPO_ROOT/scripts`（仓库根 scripts 目录，仅含本分块 11 个脚本），而 design §4.1 scripts 清单含 op_assemble_eval_brief/op_close_pre 等位于 `skills/oprun/scripts/` 的脚本——这些不会被装到共享目录。
- 影响：lite 通过 `${OP_SCRIPT_ROOT:-$OP_HOME}` fallback 定位共享目录时，找不到 op_assemble_eval_brief.sh（在 skills/oplrun/scripts/ 有 lite 副本，但共享目录没有 heavy 版）。design §5.5 承认「完整归并待重构」，现状 lite 靠自带副本兜底，但 install.sh 装的共享目录内容不完整，名不副实。
- 建议：(a) install.sh 补装 `skills/oprun/scripts/` 到共享目录（合并而非覆盖），或；(b) design §5.5 明示「共享目录当前仅含根 scripts/，oplrun 专属脚本走 skill 内 scripts/」，对齐现状。
- 置信度：0.8。
- 优先级：MEDIUM。

### M7 · op_check_env.sh 仅校验 OP_HOME，与 design §5.5 lite 跳过 OP_HOME 段不一致

- 位置：`scripts/op_check_env.sh:30-37` 无条件校验 OP_HOME；design §5.5 表格「op_check_env.sh | lite 跳过 OP_HOME 段」。
- 现象：本分块根 scripts/op_check_env.sh 是 heavy 版（校验 OP_HOME）；lite 副本（skills/oplrun/scripts/op_check_env.sh）是改造版（跳过）。但 install.sh 装到 `~/.claude/scripts/omni_powers/op_check_env.sh` 的是 heavy 版——lite 若走共享目录会命中 heavy 校验失败。
- 影响：lite 当前靠 skill 内副本绕开此问题，但共享目录定位（design §5.5 终态）一旦启用，lite 会误判 OP_HOME 缺失而 die。
- 建议：op_check_env.sh 入口加 `OP_PROFILE` 分支（design §5.5 已约定脚本入口校验 profile），lite 分支跳 OP_HOME 段。
- 置信度：0.85。
- 优先级：MEDIUM。

### L1 · op_status.sh 文件名与 design 用词混淆

- 位置：本分块 `scripts/op_status.sh` 实为「更新 task 状态」脚本（注释 line 1-2）；design §4.1「opstatus skill」是「渲染人类可读状态报告」。
- 现象：两处都叫 status 但语义不同——脚本是写者、skill 是读者。文件名易误判。
- 建议：脚本改名 `op_set_status.sh` 或 `op_task_status.sh`，留 opstatus 给渲染 skill。
- 置信度：0.7（命名优化，非 bug）。
- 优先级：LOW。

### L2 · uninstall.sh 清理 .claude/settings.json hook 的 jq 表达式对嵌套 hooks 结构假设过强

- 位置：`uninstall.sh:112-118` jq 表达式 `.hooks |= with_entries(.value |= map(select(. | is_op | not)))`。
- 现象：假设 hooks 结构为 `{事件名: [{matcher, hooks:[{command}]}]}`（数组层数组），Claude Code settings.json hooks 格式确如此。但 `.value |= map(...)` 只过滤外层数组的 matcher 块，若整个 matcher 块的所有 hooks 都被删，留空 hooks 数组的 matcher 块残留（后续 `with_entries(select(.value | length > 0))` 清理的是 value 为空数组，但 value 是 matcher 对象数组——length>0 判 matcher 数量非 hooks 数量）。
- 影响：若某 matcher 块下原本仅 omni_powers 一个 hook，清理后该 matcher 块 hooks 字段为空数组但 matcher 块本身残留（`{matcher:"Edit",hooks:[]}`）。非致命，不干净。
- 建议：jq 表达式补一层：先 map 每个 matcher 块的 .hooks 过滤，再过滤掉 .hooks 为空的 matcher 块。
- 置信度：0.7。
- 优先级：LOW。

### L3 · op_jq.sh `pending` 命名误导

- 位置：`scripts/op_jq.sh:22` `pending)` 查 `status=="ready"`。
- 现象：命令名 pending 映射到 status=ready（待开始），但 tasks_list 另有 `pending` 状态（待规划，§1.1）。命令名与 status 值同名异义。
- 影响：调用者易混淆 `op_jq pending`（返回 ready）与 status=pending。
- 建议：命令改名 `ready` 或 `next`，留 `pending` 给 status=pending 查询。
- 置信度：0.8。
- 优先级：LOW。

## 改进建议

1. **脚本间契约测试**：op_close_pre→op_status、op_trailer_unlock→commit-msg 这类"生成-校验"对需加端到端自测（bats），防 H1/H3 这类跨脚本字符串/编码不一致。
2. **design 状态对齐**：§0.2 能力矩阵已诚实标注各防线交付阶段，但 §3.4/§4.1 正文对 op_merge_gate.sh 的描述语气像已存在（"PASS 才许合"），建议正文统一加"（P1 交付）"后缀，与 §0.2 一致。
3. **共享 scripts 目录完整性**：install.sh 装 `scripts/` 到 `~/.claude/scripts/omni_powers/`，但 design §4.1 scripts 清单跨根 scripts/ 与 skills/oprun/scripts/ 两处——要么 install.sh 合并装，要么 design 明示终态目录布局。
4. **build_lite 标记机制**：当前用固定字符串 grep 断言，注释措辞微调即误报（M1）。改用结构化标记（如 `# PROFILE: lite` 注释键）+ json schema 校验更稳。

## 不确定项

- H3 的 hmac 不一致未实跑 openssl 验证两侧输出是否巧合相同（置信度留 0.15 给此可能）。
- M3 的 CRLF 风险未验证仓库根 `.gitattributes` 实际内容，仅基于 README 声称。建议读 `.gitattributes` 确认。
- 本分块不含 skills/oprun/scripts/ 与 skills/oplrun/scripts/，design §4.1 的 scripts 完整性判断需结合 03 分块（skills 审阅）结论交叉。
- op_worktree_setup 的 sparse-checkout pattern 在 git 2.25-2.27（非 cone 模式早期实现）的兼容性未实测，design §0.2 仅说"git 2.25+"。
