## 当前模型判断依据

- 用户提供依据：`~/.claude/settings.json` 顶层 `model=haiku`，`env.ANTHROPIC_MODEL=default_model`，默认模型环境变量含 `default_haiku[1m]` / `default_sonnet[1m]` / `default_opus[1m]`；主会话提示由 `default_model` 驱动。
- 当前会话无法读取运行时内部模型状态；本报告按用户授权的 opus 视角进行只读审阅。

## 审阅范围

已按要求先读上下文：`/home/karon/karson_ubuntu/omni_powers/docs/omni_powers_design.md`。

本次只读审阅以下文件：

- `hooks/README.md`
- `hooks/git/commit-msg`
- `hooks/git/pre-commit`
- `hooks/post_tool_use.sh`
- `hooks/pre_tool_use.sh`
- `hooks/run-hook.cmd`
- `hooks/settings.template.json`
- `hooks/stop.sh`
- `install.sh`
- `uninstall.sh`
- `scripts/build_lite.sh`
- `scripts/op_check_env.sh`
- `scripts/op_closer_gate.sh`
- `scripts/op_jq.sh`
- `scripts/op_mutation_check.sh`
- `scripts/op_new_task.sh`
- `scripts/op_status.sh`
- `scripts/op_trailer_unlock.sh`
- `scripts/op_worktree_setup.sh`
- `scripts/op_worktree_teardown.sh`

未运行应用、未跑构建/测试/联网。仅写入本报告。

## 高优先级问题（CRITICAL / HIGH）

### HIGH-1：`op_worktree_setup.sh` 的 dev sparse 模式与设计不符，可能把实现侧流程文件全部暴露给 implementer

- 位置：`scripts/op_worktree_setup.sh:42-49`
- 现象：dev worktree sparse 规则为：
  - `/*`
  - `!/e2e/`
  这等价于除 `e2e/` 外几乎全仓挂载。
- 影响：设计文档 §3.4 明确要求 implementer/evaluator worktree 不挂完整流程文件，流程文件只在主 worktree 一份物理副本；implementer 例外仅应能写 `tasks/{TID}/report.md`，只读工作 spec。当前 dev worktree 会暴露 `docs/omni_powers/op_execution/tasks_list.json`、`leader_checkpoint.md`、`issues/`、`op_record/decisions.md`、`op_blueprint/` 等。虽然 merge gate 未来可拦回流，但当前模块中未审到 `op_merge_gate.sh`，此处会放大“误改流程文件”和“读实现/流程污染”的风险。
- 建议：按设计收紧 dev sparse：只挂载源码/结构层测试/工作 spec/对应 task report 及必要项目文件；不挂 `op_execution/tasks_list.json`、`op_execution/tasks/*/review.md`、`op_record/**`、`op_blueprint/**`（除明确只读蓝图定向包外）。若暂无法细分，应至少显式排除 `docs/omni_powers/op_execution/tasks_list.json`、`leader_checkpoint.md`、`issues/`、`op_record/`。
- 置信度：高
- 优先级：HIGH

### HIGH-2：git hook 中 `against` 获取逻辑错误，已有仓库中 staged diff 会对空树比较

- 位置：
  - `hooks/git/commit-msg:18`
  - `hooks/git/pre-commit:10`
  - `scripts/op_trailer_unlock.sh:40`
- 现象：写法为：
  - `against="$(git rev-parse --verify HEAD >/dev/null 2>&1 && echo HEAD || echo "$(git hash-object -t tree /dev/null)")"`
  在命令替换内，`git rev-parse --verify HEAD` 的 stdout 被重定向，成功时输出 `HEAD`；失败时使用空树。语义看似可用，但三处依赖 `git diff-index --cached --name-only "$against"`。若用户处于 unborn branch 或特殊状态，逻辑可退化；更关键的是 `git diff-index --cached` 对工作树删除/重命名状态输出与后续脚本读取文件内容存在不一致风险。
- 影响：e2e trailer、spec 写保护、解锁生成都依赖 staged 文件清单。任何 staged 文件集计算偏差都会导致：该拦的 e2e/spec 漏拦，或合法提交被误拦。当前代码未做 `--diff-filter` 与 NUL 分隔处理，后续 HIGH-3 会进一步放大。
- 建议：统一抽公共函数，使用更明确写法：先 `if git rev-parse --verify HEAD >/dev/null 2>&1; then against=HEAD; else against=$(git hash-object -t tree /dev/null); fi`。同时改用 `git diff --cached --name-only -z "$against" --` 并按 NUL 读取。
- 置信度：中
- 优先级：HIGH

### HIGH-3：多处以换行/空格解析 git 路径，含空格、换行、重命名时白名单和 HMAC 均不可靠

- 位置：
  - `hooks/git/commit-msg:23-27,49`
  - `hooks/git/pre-commit:13-27`
  - `scripts/op_trailer_unlock.sh:41,49`
  - `scripts/op_closer_gate.sh:20`
  - `scripts/op_worktree_teardown.sh:10`
- 现象：脚本使用 `git diff-index --cached --name-only`、`git status --porcelain | awk '{print $2}'`、`grep -q "$wt_path"` 等基于空格/换行的解析。
- 影响：路径包含空格会被截断；重命名状态的 porcelain 格式会被 `awk '{print $2}'` 错读；路径包含换行会破坏 e2e HMAC 输入。安全类脚本（trailer、closer gate、spec/e2e 锁）不应依赖非 NUL 安全解析。攻击或误操作均可能绕过/误杀白名单。
- 建议：所有 git 路径清单改用 `-z` 输出与 `while IFS= read -r -d '' path`。`op_closer_gate.sh` 用 `git status --porcelain=v1 -z` 或 `git diff --name-only -z` 分别读取 index/worktree；worktree teardown 用 `git worktree list --porcelain` 精确匹配 `worktree <path>`。
- 置信度：高
- 优先级：HIGH

### HIGH-4：`commit-msg` 与 `op_trailer_unlock.sh` 只绑定 e2e 路径清单，不绑定内容，设计/注释声称“绑内容”但实现不成立

- 位置：
  - `hooks/git/commit-msg:4,8,40,49-52`
  - `scripts/op_trailer_unlock.sh:9,39-52`
  - `hooks/README.md:55`
- 现象：HMAC 输入是排序后的 e2e 文件路径清单：`printf '%s' "$e2e_paths" | grep . | sort | tr '\n' ':'`，没有包含 blob hash、mode、状态、diff 内容。
- 影响：同一组 e2e 路径下，生成 trailer 后继续修改 staged 内容，只要路径集合不变，旧 trailer 仍有效。README 与注释写“绑内容防重放/复用”会误导用户高估防线强度。此项直接影响行为层测试主分支自锁可信度。
- 建议：HMAC 输入改为 staged e2e 变更的确定性内容摘要，例如 `git diff --cached --raw -z -- e2e/` 加每个目标 blob hash，或 `git ls-files -s -z -- e2e/` 限定 staged 条目，并包含删除/重命名状态。README 同步修正为“绑定 staged e2e 内容摘要”。
- 置信度：高
- 优先级：HIGH

### HIGH-5：`op_mutation_check.sh` 使用 GNU `sed -i`，macOS 默认 BSD sed 会失败且可能留下半变异文件

- 位置：`scripts/op_mutation_check.sh:42`
- 现象：`sed -i -E` 是 GNU sed 习惯；macOS BSD sed 需要 `sed -i '' -E`。
- 影响：设计强调 Windows/macOS/Linux 跨平台；该脚本在 macOS 可能直接失败。虽然 trap 会尝试恢复，但 sed 失败点与 shell 选项未启用 `set -e`，后续仍可能跑测试，导致误判 ESCAPE/KILLED 或恢复逻辑不符合预期。
- 建议：避免原地 sed，使用临时文件生成后 `mv`：`sed -E ... "$src" > "$tmp" && mv "$tmp" "$src"`；或者按平台选择 `sed -i` 参数，并启用明确错误处理。
- 置信度：高
- 优先级：HIGH

### HIGH-6：`post_tool_use.sh` 用 `eval "$test_cmd"` 执行拼接命令，存在命令注入与误执行风险

- 位置：`hooks/post_tool_use.sh:32-58`
- 现象：测试命令以字符串拼接存入 `test_cmd`，最终 `eval "$test_cmd"`。其中 `OP_TEST_COMMAND` 可直接进入 eval；`rel` 也进入 npm 命令字符串。
- 影响：hook 会在主会话文件编辑后自动执行。若环境变量或路径含 shell 元字符，可执行非预期命令。即便当前项目可信，hook 模块作为安装到用户全局/项目的基础设施，应该避免 eval。
- 建议：用数组执行命令；复杂 fallback 拆成显式函数，不把文件路径拼进 shell 字符串。`OP_TEST_COMMAND` 若必须支持 shell 片段，需明确文档标为“受信配置”，并避免与文件路径拼接。
- 置信度：高
- 优先级：HIGH

### HIGH-7：`install.sh` 全量安装时 `rm -rf` 目标，可能删除用户同名 skill/agent，违背“不覆盖用户已有”文档承诺

- 位置：
  - `install.sh:36-43`
  - 设计文档 §5.3 行 765-767 声称新增、不覆盖用户已有
- 现象：`install_one()` 对目标路径无条件 `rm -rf "$dst"` 后复制/软链。
- 影响：若用户已存在同名 skill/agent（尤其通用名如 `opstatus` 或未来冲突），会被静默删除。`--link` 同样删除目标。与零侵入/不覆盖承诺不一致。
- 建议：安装前检测目标是否存在且非 omni_powers 管理产物；默认拒绝并提示 `--force`。可写 marker 文件或检查 symlink 指向/文件头标识。升级自身产物时允许覆盖。
- 置信度：高
- 优先级：HIGH

### HIGH-8：`uninstall.sh --purge-project` 会删除整个 `docs/omni_powers/`，未确认其中是否有用户自建/迁移内容

- 位置：`uninstall.sh:100-104`
- 现象：项目级清理直接 `del "docs/omni_powers"`，无 profile/marker 校验，无二次针对项目数据的明确确认（除总确认外）。
- 影响：`docs/omni_powers/` 包含 spec、issues、decisions、progress、acceptance 等历史资产。卸载时直接删除可能造成不可逆数据损失；dry-run 可预览但默认命令仍危险。
- 建议：`--purge-project` 增加独立强确认，例如要求 `--purge-project --yes --i-understand-delete-op-data`；删除前备份到 timestamp tar 或移动到 `docs/omni_powers.deleted.<ts>`；校验 profile/README marker，避免误删用户同名目录。
- 置信度：高
- 优先级：HIGH

## 中低优先级问题（MEDIUM / LOW）

### MEDIUM-1：`hooks/README.md` 引用 design 章节错误，容易误导维护者

- 位置：`hooks/README.md:43,59`
- 现象：README 写“subagent 失效见 design §8.1”，但已读设计文档中相关内容在 §0.1、§2.5、§3.3、§4.1。README 末尾写详见 §2.5/§3.3/§4.1，前表仍残留 §8.1。
- 影响：维护者查错章节，降低文档可信度。
- 建议：统一修正为 `design §0.1 / §2.5 / §3.3 / §4.1`。
- 置信度：高
- 优先级：MEDIUM

### MEDIUM-2：`hooks/git/pre-commit` 保护对象和提示文案与设计不一致

- 位置：`hooks/git/pre-commit:3-5,16-22`
- 现象：注释写“approved/in_progress 状态的生效规格不允许直接 commit”，但匹配范围包含 `docs/omni_powers/op_blueprint/baselines/*`、`op_blueprint/*.md`；这些文件通常没有 frontmatter `status`，因此不会被拦。提示中引用“design §5.2 spec 变更子流程”，而设计中 spec 变更子流程在 §2.4，§5.2 是 profile 机制。
- 影响：用户以为 baselines/blueprint 全受保护，实际只有带 `status: approved|in_progress` 的文件受保护。文档与行为不一致。
- 建议：拆分规则：`op_blueprint/specs/*.md` 按 status 拦；`op_blueprint/baselines/**` 与关键 blueprint 文档按 e2e/closer 合法通道单独拦或明确不拦。修正文案章节。
- 置信度：高
- 优先级：MEDIUM

### MEDIUM-3：`pre_tool_use.sh` 的 Bash 危险命令匹配过窄且可能误判

- 位置：`hooks/pre_tool_use.sh:17-28`
- 现象：只匹配少数模式：`git reset --hard`、`push --force`、`push -f`、`clean -fd`、`checkout -- .`。未覆盖 `git clean -xdf`、`git restore .`、`git checkout -f`、`git reset --merge`、`git branch -D`、`rm -rf` 等危险操作；同时命令出现在字符串/注释中也会误拦。
- 影响：作为 advisory 可接受，但 README/设计若被理解成强防线会过度乐观。危险命令可轻易绕过。
- 建议：文档明确“仅拦常见误操作”；若要增强，使用 shell parser 很重，不建议过度实现。最低限度补 `git clean -xdf`、`git restore`、`git checkout -f`、`git branch -D`。
- 置信度：高
- 优先级：MEDIUM

### MEDIUM-4：`pre_tool_use.sh` 无法识别 `Edit` 目标路径外的多文件变更语义，行级敏感度只覆盖单个 old/new 字符串

- 位置：`hooks/pre_tool_use.sh:76-88`
- 现象：`MultiEdit` 进入测试文件分支，但仅在 `tool_name=Edit` 时检查 `old_string/new_string`；`Write` 和 `MultiEdit` 修改 expect/assert 不会触发警告。
- 影响：行级敏感度的“触碰断言需归因”覆盖不完整。
- 建议：对 `MultiEdit` 遍历 `.tool_input.edits[]`；对 `Write` 检查 `.tool_input.content`。仍保持 WARN 不阻断。
- 置信度：高
- 优先级：MEDIUM

### MEDIUM-5：`post_tool_use.sh` 证据文件可能记录误导性 exit code

- 位置：`hooks/post_tool_use.sh:57-58`
- 现象：`eval "$test_cmd" 2>&1 | head -200` 后 `echo "--- exit: $? ---"` 记录的是管道最后命令 `head` 的退出码，而非测试命令退出码。未启用 `pipefail`。
- 影响：测试失败时 evidence 可能显示 `exit: 0`，SubagentStop 只看证据新鲜度，更容易形成“有证据但证据误导”。
- 建议：启用 `set -o pipefail`，或把测试输出写临时文件后截断展示，单独保存测试命令真实退出码。
- 置信度：高
- 优先级：MEDIUM

### MEDIUM-6：`post_tool_use.sh` 优先 npm/pytest，导致显式 `OP_TEST_COMMAND` 被忽略

- 位置：`hooks/post_tool_use.sh:32-40`
- 现象：只有没有 `package.json scripts.test` 且没有 pytest 标志时才使用 `OP_TEST_COMMAND`。
- 影响：用户显式配置的测试入口无法覆盖自动猜测。monorepo 或非 npm test 项目中容易跑错测试。
- 建议：优先使用 `OP_TEST_COMMAND`；没有时再自动探测。
- 置信度：高
- 优先级：MEDIUM

### MEDIUM-7：`stop.sh` 只校验证据存在/新鲜，不校验证据中测试是否通过

- 位置：`hooks/stop.sh:36-45`
- 现象：SubagentStop 找到 5 分钟内 `test_evidence_*.log` 即放行，不读取 `--- exit:` 或 PASS/FAIL。
- 影响：设计承认 SubagentStop 只验存在不验真伪；但当前 `post_tool_use.sh` exit 记录也不可靠，组合后会让红测试也放行。作为 advisory 可以接受，但与“机器证据”心智有落差。
- 建议：若保持轻量，至少在 evidence 中写 `VERDICT=PASS|FAIL`，Stop 对 FAIL 给 WARN 或 BLOCK（按设计取舍）。同时保留“证据可伪造”声明。
- 置信度：高
- 优先级：MEDIUM

### MEDIUM-8：`settings.template.json` 未注册 PreToolUse[Task]，与设计和 README hook 清单不一致

- 位置：
  - `hooks/settings.template.json:4-35`
  - 设计文档 §4.1 行 682
- 现象：模板只注册 PreToolUse `Edit|Write|MultiEdit|Bash`、PostToolUse、SubagentStop、Stop；未注册 PreToolUse[Task] dispatch 协议 advisory 留痕。
- 影响：设计声称的 dispatch 留痕不会发生，审计链缺一段。
- 建议：若该防线仍需要，补 Task matcher 与对应脚本处理分支；若已决定不做，删除设计/README 对该 hook 的描述。
- 置信度：高
- 优先级：MEDIUM

### MEDIUM-9：`install.sh` 未安装 `hooks/`，但 settings.template 依赖 `$OP_HOME/hooks/run-hook.cmd`

- 位置：`install.sh:46-59`、`hooks/settings.template.json:8,16,24,31`
- 现象：安装脚本安装 skills、agents、scripts 到 `~/.claude/`，但没有复制/链接 `hooks/`。settings.template 运行时通过 `$OP_HOME/hooks/...` 引用仓库路径。
- 影响：heavy 模式必须依赖 `--set-ophome` 指向原仓库，且原仓库不能移动/删除。若用户只全局安装后移动源码仓库，hook 会失效。README/设计说“装一次全局”但实际 hook 不在全局安装产物中。
- 建议：要么安装 `hooks/` 到 `$CLAUDE_HOME/hooks/omni_powers/` 并让模板引用全局副本；要么文档明确 heavy 依赖保留 OP_HOME 仓库路径。
- 置信度：高
- 优先级：MEDIUM

### MEDIUM-10：`install.sh` 只 chmod skill 内 shell，未 chmod 全局共享 scripts

- 位置：`install.sh:60-62`
- 现象：copy 模式下只对 `$SKILLS_DST/{opinit,oprun,oplinit,oplintake,oplrun}` 中 `.sh` chmod；`$CLAUDE_HOME/scripts/omni_powers` 下 `.sh` 未 chmod。
- 影响：若后续通过直接执行共享脚本路径而非 `bash script.sh`，会权限失败。当前多数说明使用 `bash`，但共享脚本目录作为统一入口，最好保持可执行。
- 建议：同时 `find "$SCRIPTS_DST" -name '*.sh' -exec chmod +x {} +`，并处理 hooks/git 文件权限。
- 置信度：中
- 优先级：MEDIUM

### MEDIUM-11：`uninstall.sh` 帮助命令使用 `sed`，与“脚本尽量跨平台/最少依赖”不一致

- 位置：`uninstall.sh:27-28`
- 现象：`-h|--help` 调用 `sed -n '2,20p' "$0"`。
- 影响：Git Bash/macOS/Linux 通常有 sed，实际风险低；但既然其他脚本强调 bash/jq/git，帮助依赖 sed 不大必要。
- 建议：可接受；若想减依赖，用 here-doc 输出帮助。
- 置信度：中
- 优先级：LOW

### MEDIUM-12：`build_lite.sh` 与设计 §5.5 当前状态互相拉扯，容易让维护者误解 lite 副本是否已淘汰

- 位置：
  - `scripts/build_lite.sh:2-8`
  - 设计文档 §5.5 行 803-825
- 现象：设计先说“消灭 per-skill 副本同步机制”，后又说“lite 副本暂保留，build_lite.sh 暂留维护副本同步”。脚本仍以副本漂移校验为主。
- 影响：维护者不清楚新脚本应改共享 `scripts/` 还是 lite 副本。容易产生修一处漏一处。
- 建议：在 README/脚本头明确当前过渡态：哪些脚本仍有 lite 副本、哪些已迁到共享目录、删除条件是什么。
- 置信度：高
- 优先级：MEDIUM

### MEDIUM-13：`op_check_env.sh` 顶层版本不支持 lite fallback，与用户给出的运行前检查“两版通用”不一致

- 位置：`scripts/op_check_env.sh:30-44`
- 现象：顶层脚本强制 `OP_HOME` 存在。用户任务前置说明要求：`OP_ROOT="${OP_SCRIPT_ROOT:-$OP_HOME}"`，lite 版无 OP_HOME 校验。设计 §5.5 也要求 profile 分支，lite 跳过 OP_HOME。
- 影响：lite 通过共享脚本调用顶层 `scripts/op_check_env.sh` 时会因未设 OP_HOME 失败。虽然 lite 副本可能另有改造版，但本审阅范围内的共享脚本不满足“两版通用”。
- 建议：顶层 `op_check_env.sh` 支持 `OP_PROFILE=lite` 时跳过 OP_HOME，或用 `OP_SCRIPT_ROOT` fallback 校验脚本根。未知 profile 应 die。
- 置信度：高
- 优先级：MEDIUM

### MEDIUM-14：`op_jq.sh status` 对不存在 TID 返回空且 exit 0

- 位置：`scripts/op_jq.sh:61-64`
- 现象：`jq -r '.tasks[] | select(.id==$tid) | .status'` 找不到任务时输出空，仍成功。
- 影响：调用方若只看退出码会误以为查询成功，导致调度/状态推进静默异常。
- 建议：统一加 `jq -e` 或后置判空；不存在 TID 时 exit 1 并输出明确错误。
- 置信度：高
- 优先级：MEDIUM

### MEDIUM-15：`op_jq.sh deps` 未检测依赖 TID 不存在

- 位置：`scripts/op_jq.sh:29-46`
- 现象：对每个依赖 `d` 查询 status；若依赖任务不存在，`st` 为空，只输出 `Txxxx:` 并视为未就绪 WARN。
- 影响：tasks_list 损坏或 spec 拆分错误不会硬失败，调度问题可能延后暴露。
- 建议：依赖 TID 不存在应 `FAIL`；只有存在但非 done 才 WARN/非就绪。
- 置信度：高
- 优先级：MEDIUM

### MEDIUM-16：`op_status.sh` 名称/注释混淆，实际是“更新状态”不是“渲染状态”

- 位置：`scripts/op_status.sh:2-7`
- 现象：文件名 `op_status.sh` 与文档 `/opstatus` 容易混淆；注释写 `op-status：更新 tasks_list.json`。设计中 opstatus 是读取渲染，人类可读状态报告。
- 影响：维护者可能误调用或把更新脚本当查询脚本。当前脚本属于 mutator，风险高于只读 status。
- 建议：若兼容允许，改名为 `op_set_status.sh`；若不能改名，脚本头和文档明确“内部 mutator，不是 /opstatus 渲染器”。
- 置信度：高
- 优先级：MEDIUM

### MEDIUM-17：`op_status.sh --batch` 未校验 TID 是否存在，可能静默无效

- 位置：`scripts/op_status.sh:66-72`
- 现象：batch 模式下 jq map 不存在的 TID 不报错，仍输出 `[OK] ...`。
- 影响：状态推进脚本可能显示成功，但实际未更新任何任务。
- 建议：更新前计算请求 TID 与 `.tasks[].id` 差集；存在缺失则 die。
- 置信度：高
- 优先级：MEDIUM

### MEDIUM-18：`op_status.sh` 使用 `echo "$tids" | jq -R`，输入含空格不会规整

- 位置：`scripts/op_status.sh:67-70`
- 现象：`T0001, T0002` 会生成 `" T0002"`，匹配失败。
- 影响：手工批量操作容易部分静默失败。
- 建议：split 后 map gsub 去首尾空白，或要求无空格并显式校验。
- 置信度：高
- 优先级：LOW

### MEDIUM-19：`op_trailer_unlock.sh` fallback 依赖 `od`，但环境检查未覆盖 openssl/od

- 位置：`scripts/op_trailer_unlock.sh:27-32,51-58`、`scripts/op_check_env.sh:19-24`
- 现象：secret 生成优先 openssl，fallback `/dev/urandom | od`；HMAC 必须 openssl。环境检查只检查 jq/git/bash/OP_HOME。
- 影响：最小环境中 e2e 解锁到 commit 阶段才失败，错误较晚。
- 建议：heavy 环境检查补 openssl；若 HMAC 必须 openssl，则不要把 `/dev/urandom` fallback 写成完整替代，只用于 secret 生成。
- 置信度：高
- 优先级：MEDIUM

### MEDIUM-20：`op_worktree_setup.sh` git 版本检测正则无法识别 10.x 及更高主版本

- 位置：`scripts/op_worktree_setup.sh:18`
- 现象：正则支持 `2.25+`、`3-9.x`，不支持未来 `10.x`。
- 影响：未来版本误报 WARN。短期无实际影响。
- 建议：用 `git version --build-options` 后解析 semver，或简化为尝试 `git sparse-checkout -h` 能力检测。
- 置信度：中
- 优先级：LOW

### MEDIUM-21：`op_worktree_setup.sh` eval sparse 排除范围不足，monorepo 非 `packages/*/src` 仍会泄露源码

- 位置：`scripts/op_worktree_setup.sh:50-60`
- 现象：只排除 `/src/` 和 `/packages/*/src/`，未排除 `apps/*/src/`、`frontend/src`、`backend/src`、`lib/`、`server/` 等常见源码目录。
- 影响：evaluator 防抄实现是 advisory，但当前规则对常见 monorepo 布局覆盖不足，容易无意读到源码。
- 建议：不要试图猜所有源码目录。更稳妥做法是 eval worktree 采用白名单挂载：spec、blueprint、生效 baselines、构建产物、e2e、acceptance 目录，而不是全仓 `/*` 后排除少数目录。
- 置信度：高
- 优先级：MEDIUM

### MEDIUM-22：`op_worktree_setup.sh` 应用 sparse 失败后吞错，可能在隔离失效时继续流程

- 位置：`scripts/op_worktree_setup.sh:68-92`
- 现象：`git read-tree -mu HEAD 2>/dev/null || git checkout HEAD -- . 2>/dev/null || true` 最终总是成功；后续只 WARN。
- 影响：隔离失败是设计中重要降级信号。继续执行可能让调用方误认为 worktree 可用。
- 建议：保留 advisory 语义时至少返回特定非零码或要求调用方显式确认降级。对 eval worktree，建议隔离失败直接 FAIL，除非用户显式允许 lite/降级。
- 置信度：高
- 优先级：MEDIUM

### MEDIUM-23：`op_worktree_teardown.sh` 用 `rm -rf "$wt_path"` 兜底，路径误传时危险

- 位置：`scripts/op_worktree_teardown.sh:10-14`
- 现象：若 `git worktree list` 未匹配，就直接 `rm -rf "$wt_path"`。
- 影响：调用方传错路径可能删除非 worktree 目录。该脚本属于清理工具，应默认保守。
- 建议：仅允许删除位于约定根（如 `.op_worktrees/` 或 `../op_worktrees/`）下的路径；或检查目录内 `.git` 文件包含 `gitdir:` 且指向当前仓库 worktree 管理目录。
- 置信度：高
- 优先级：MEDIUM

### LOW-1：`commit-msg` 错字影响专业度

- 位置：`hooks/git/commit-msg:64`
- 现象：`staged 文件变了中国需重跑 op_trailer_unlock.sh`，应为“后需”。
- 影响：不影响功能，但影响用户信任。
- 建议：修正文案。
- 置信度：高
- 优先级：LOW

### LOW-2：`op_check_env.sh` 注释称依赖 bash 4+，但实际未用 bash 4 特性

- 位置：`scripts/op_check_env.sh:25-28`
- 现象：注释/警告写“脚本依赖 bash 4+ 特性”，本文件未使用 bash 4 特性。项目中部分脚本刻意避免关联数组以支持 macOS bash 3.2。
- 影响：macOS 用户可能误以为系统 bash 不支持。
- 建议：改为“需 bash；部分脚本避免 bash 4 特性以兼容 macOS 3.2”，或仅检查是否 bash。
- 置信度：中
- 优先级：LOW

## 改进建议

1. 安全类脚本统一抽公共库：
   - `repo_root()`
   - `staged_paths_z()`
   - `current_against_tree()`
   - `require_cmd()`
   - `die()`
   目前相同逻辑在 commit-msg/pre-commit/op_trailer_unlock 等多处复制，已出现语义漂移。

2. 将“路径清单安全”作为脚本规范：所有 git 文件路径用 `-z`，禁止 `awk '{print $2}'` 解析 porcelain，禁止以空格分割路径。

3. 明确 hook 的安全等级：
   - 主会话 advisory hook：pre_tool_use/post_tool_use/stop
   - git 层 hook：commit-msg/pre-commit
   - 结构隔离脚本：worktree setup/teardown
   - 未来硬门：merge gate
   README 每项标注“硬/软/advisory/未覆盖 subagent”。

4. 安装/卸载加入 marker 机制：
   - 安装产物写 `.omni_powers_managed` 或文件头 marker。
   - uninstall 只删除 marker 命中的产物。
   - install 遇到非 marker 目标默认拒绝，避免覆盖用户文件。

5. 对 lite/heavy 过渡状态建一张脚本矩阵：共享脚本、lite 副本、heavy skill 内脚本分别列出来源与同步方式。当前设计与 `build_lite.sh` 说明存在过渡态张力。

6. 对 e2e trailer 改为绑定 staged 内容摘要后，增加负向用例：生成 trailer 后修改同一路径 e2e 内容，应被 commit-msg 拒绝。

7. `post_tool_use.sh` 证据格式建议标准化：
   - `VERDICT=PASS|FAIL|NONE`
   - `COMMAND=...`
   - `EXIT_CODE=n`
   - `OUTPUT_FILE=...`
   Stop hook 只读 verdict 行，避免解析长日志。

## 不确定项 / 可能误报

1. `op_merge_gate.sh` 不在本次审阅范围内。部分 HIGH（如 dev worktree 暴露流程文件）可能会被 merge gate 在回流时拦住，但仍不符合设计中“worktree 不物化流程文件”的隔离目标。

2. `opinit_register_hooks.sh` 等 hook 注册脚本不在本次范围内。`settings.template.json` 未注册 Task hook、install 未安装 hooks 的实际影响，可能被 opinit 阶段另行补偿。

3. lite 改造版脚本（`skills/oplrun/scripts/*` 等）不在本次审阅范围内。`scripts/op_check_env.sh` 强依赖 OP_HOME 的问题，若 lite 永远使用副本则不会立刻影响 lite；但与共享脚本方向仍冲突。

4. 未执行脚本，跨平台问题（Windows CMD quoting、Git Bash `cygpath`、BSD/GNU sed）基于静态阅读判断，需后续在目标平台验证。

5. `post_tool_use.sh` 的 eval 风险取决于 hook 输入与项目路径是否可信。作为全局安装基础设施，按保守安全标准计为 HIGH；在完全可信本地项目中实际攻击面较小。
