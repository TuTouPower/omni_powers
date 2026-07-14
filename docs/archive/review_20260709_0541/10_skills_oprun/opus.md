## 当前模型判断依据
- 顶层配置判断：`/home/karon/.claude/settings.json` 指明默认模型。
- 环境变量检测：`env.ANTHROPIC_MODEL` 的值为 `default_model`。
- 本次审阅明确授权为 opus 视角，以 opus 审阅要求开展深度分析。

## 审阅范围
本审阅对 `skills/oprun` 模块下的所有脚本和文档进行了全量审阅，无抽样。涉及文件：
- `/home/karon/karson_ubuntu/omni_powers/skills/oprun/SKILL.md`
- `/home/karon/karson_ubuntu/omni_powers/skills/oprun/scripts/close_check.sh`
- `/home/karon/karson_ubuntu/omni_powers/skills/oprun/scripts/op_assemble_eval_brief.sh`
- `/home/karon/karson_ubuntu/omni_powers/skills/oprun/scripts/op_checkpoint.sh`
- `/home/karon/karson_ubuntu/omni_powers/skills/oprun/scripts/op_close_post.sh`
- `/home/karon/karson_ubuntu/omni_powers/skills/oprun/scripts/op_close_pre.sh`
- `/home/karon/karson_ubuntu/omni_powers/skills/oprun/scripts/op_coder_check.sh`
- `/home/karon/karson_ubuntu/omni_powers/skills/oprun/scripts/op_read_verdict.sh`

## 高优先级问题（CRITICAL / HIGH）

### 1. `op_close_post.sh` 幂等重跑时 specs 和 acceptance 归档被跳过
- **位置**：`/home/karon/karson_ubuntu/omni_powers/skills/oprun/scripts/op_close_post.sh`（行 20-30，行 51-66）
- **现象**：当 `ACTIVE_DIR` 指向 `ARCHIVE_DIR` 时（例如第一次运行部分归档发生失败后重跑），整个归档逻辑 `if [ "$ACTIVE_DIR" = "$TASK_DIR" ]` 被跳过。这会导致 specs 归档（`git mv "$SPEC_SRC"`）和 acceptance 归档（`git mv "$ACCEPT_SRC"`）在重跑中被静默忽略。
- **影响**：破坏了流动工作区的活区清理原子性，导致重跑失败后残留 `op_execution/specs/` 或 `op_execution/acceptance/` 历史工件，干扰后续流程。
- **建议**：解耦宏观的 `ACTIVE_DIR` 状态，单独针对每个要移走的文件/文件夹做幂等性的 `git mv`（例如检测源文件存在且目标不存在才执行）。
- **置信度**：HIGH
- **优先级**：HIGH

### 2. `op_close_post.sh` 幂等重跑时因已移动的 eval.md 检查而崩溃
- **位置**：`/home/karon/karson_ubuntu/omni_powers/skills/oprun/scripts/op_close_post.sh`（行 44-48）
- **现象**：脚本写死从 `op_execution/acceptance/$TID/eval.md` 校验 verdict。若上一次执行时 `ACCEPT_SRC` 已成功被 `git mv` 到了 `op_record/acceptance/`，在幂等重跑时，该路径下不再存在 `eval.md`，校验会因 `[ -s "$EVAL_MD" ]` 返回假而报错退出。
- **影响**：使得本该具备幂等特性的归档脚本在第二次执行时直接崩溃报错，无法成功收口。
- **建议**：若 `ACTIVE_DIR` 已经是归档状态，应读取归档目录下的 `eval.md` 进行校验，或检测到已归档时直接豁免此处的 `eval.md` 检验。
- **置信度**：HIGH
- **优先级**：HIGH

### 3. `op_close_post.sh` 缺少 specs 和 acceptance 归档路径的 git add
- **位置**：`/home/karon/karson_ubuntu/omni_powers/skills/oprun/scripts/op_close_post.sh`（行 89-93）
- **现象**：脚本进行了 `git mv` 归档 specs 和 acceptance，但在最终的 `git add` 暂存清单中漏掉了它们，仅有任务归档目录、progress.md 和 tasks_list.json。
- **影响**：导致 commit 提交时，这些被移动的规格文件和验收结果文件夹成了未暂存改动（unstaged），造成工作区不干净和提交缺失。
- **建议**：在 `git add` 参数中补上 `"docs/omni_powers/op_record/specs/"` 和 `"docs/omni_powers/op_record/acceptance/$TID"`。
- **置信度**：HIGH
- **优先级**：HIGH

### 4. `op_assemble_eval_brief.sh` 设计探索段剥离正则匹配失效
- **位置**：`/home/karon/karson_ubuntu/omni_powers/skills/oprun/scripts/op_assemble_eval_brief.sh`（行 36）
- **现象**：`awk` 使用正则 `/^## 设计探索结论/` 来匹配过滤设计探索结论段。然而，根据系统设计规范（`docs/omni_powers_design.md` §2.2）以及 `opspec` 的模板定义，“设计探索结论”是一个三级标题（`### 设计探索结论`）。
- **影响**：
  1. 正则因标题级数不匹配（二级匹配三级）而失效，导致“设计探索结论”被完整输出给 evaluator，违背防 evaluator 被过程带偏的设计初衷。
  2. 若用户将其改写为二级标题，又因 `skip` 标志无法在三级子标题（例如可测性契约）处重置，进而误杀过滤掉后续非设计探索的全部有效内容。
- **建议**：修复正则以兼容三级标题，并在同级或更高标题（如 `## ` 或其他 `### ` 级）被处理时能够安全重置 `skip`。例如使用 `awk '/^###? 设计探索结论/{skip=1; next} /^##? /{skip=0} !skip'`。
- **置信度**：HIGH
- **优先级**：HIGH

## 中低优先级问题（MEDIUM / LOW）

### 1. `close_check.sh` 误报 specs/acceptance 的合法归档为非本 task 改动
- **位置**：`/home/karon/karson_ubuntu/omni_powers/skills/oprun/scripts/close_check.sh`（行 43）
- **现象**：`git status` 过滤时，仅过滤排除了 `arch` 变量（即 `op_record/tasks/$TID`），却漏掉了同属此任务归档产物的 specs 归档和 acceptance 归档。
- **影响**：导致 `close_check.sh` 会警告存在非本 task 的残留改动，造成 [WARN] 噪音干扰。
- **建议**：扩展排除的正则，将整个 `op_record/specs` 与 `op_record/acceptance` 区域的变更一同进行排除过滤。
- **置信度**：HIGH
- **优先级**：MEDIUM

### 2. `SKILL.md` 中存在多处引号未闭合和 sed 命令跨平台隐患
- **位置**：`/home/karon/karson_ubuntu/omni_powers/skills/oprun/SKILL.md`（行 174, 268, 143-145）
- **现象**：
  - 行 174: `bash "$OP_HOME/scripts/op_status.sh {TID} blocked spawn` 缺失右双引号。
  - 行 268: `bash "$OP_HOME/skills/oprun/scripts/op_checkpoint.sh {TID}` 及下一行 `close_check.sh` 均缺失右双引号。
  - 行 143-145: 在重定向 current_task 时写了 `sed -i`，未指定临时文件替换，在 macOS 上执行此样例命令会直接报错。
- **影响**：用户或 leader 引用/执行文档内的命令时会遇到 shell 语法错和跨平台报错。
- **建议**：在 `SKILL.md` 中闭合双引号，同时修改 `sed` 的写法或给出跨平台安全提示。
- **置信度**：HIGH
- **优先级**：MEDIUM

### 3. `op_checkpoint.sh` 传递多行变量风险及匹配标题缺失时静默失败
- **位置**：`/home/karon/karson_ubuntu/omni_powers/skills/oprun/scripts/op_checkpoint.sh`（行 22, 51-55）
- **现象**：
  - 用 `awk -v repl="$(cat ...)"` 的形式通过 shell 传递多行带有换行的段落。在特定环境（如 Windows Git Bash）中，多行 `-v` 变量传递可能发生截断或转义异常。
  - 如果 `leader_checkpoint.md` 里的特定定位标题被破坏或不存在，替换过程会静默失败，不会给出报错提示。
- **影响**：特定平台下的可靠性隐患，数据同步可能产生静默遗漏。
- **建议**：在 awk 内部通过 `getline` 直接读取临时文件文件，同时检测若未发生任何替换则打印 error 或 warn。
- **置信度**：HIGH
- **优先级**：LOW

## 改进建议
1. **统一的幂等工具函数**：将 `git mv` 包装成幂等函数，确保源文件存在且目标不存在时安全移动，避免在复杂的重跑机制中由于硬编码条件导致流程中断。
2. **规范化 markdown 过滤**：设计探索剥离可以使用结构化更强的 markdown parser 工具或标准段落提取脚本，仅靠 awk 简单的正则规则在文档格式微调时极易因失效而污染 evaluator 环境。

## 不确定项 / 可能误报
1. **`SKILL.md` 中 `git branch -r` 提取主分支的机制**：如果本地是一个纯离线的 repo（无远程配置），`git branch -r` 输出为空，导致管道中的 `grep` 非 0 报错。该设计可能假定 Omni Powers 总是运行在有远程仓库的项目中，因此该假设可能合理，但仍可考虑优化。
2. **`feat/op-eval` 分支重名冲突**：在 worktree setup 中若 evaluator 分支被写死，可能导致并发或多工作区时的 checkout 冲突，通常 `op_worktree_setup.sh` 本身应有解耦或随机化逻辑，故这取决于 setup 脚本的实现。
