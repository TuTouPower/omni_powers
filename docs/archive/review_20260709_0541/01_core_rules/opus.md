## 当前模型判断依据
根据系统配置，主会话环境提示显示当前由 `default_model` 驱动，环境变量 `env.ANTHROPIC_DEFAULT_OPUS_MODEL` 值为 `default_opus[1m]`，表明当前正在使用 Opus 4.5 模型进行深度架构和规则层面的只读审阅。

## 审阅范围
审阅了以下核心规则及设计文档文件，排除了 `vendors/` 与 `docs/archive/` 目录：
- `/home/karon/karson_ubuntu/omni_powers/.gitattributes`
- `/home/karon/karson_ubuntu/omni_powers/.gitignore`
- `/home/karon/karson_ubuntu/omni_powers/CLAUDE.md`
- `/home/karon/karson_ubuntu/omni_powers/RULES.md`
- `/home/karon/karson_ubuntu/omni_powers/docs/omni_powers_design.md`

## 高优先级问题（CRITICAL / HIGH）

### 1. RULES.md 回滚指南中状态参数使用了中文，与 ASCII 机读状态标准冲突
- **位置**：`RULES.md` 第 67 行
- **现象**：回滚步骤第 2 步写道：`bash $OP_HOME/scripts/op_status.sh {TID} 待开始`。然而，`RULES.md` 第 133 行及第 147 行明确规定：“`tasks_list.json.status` 枚举机读值一律使用 ASCII 值（如 `ready`），脚本/agent 不得自创状态串；脚本内 jq/grep 比较一律用左列 ASCII 值”。
- **影响**：如果 Agent 或人类操作者照着第 67 行说明回滚，将中文 `待开始` 传给 `op_status.sh` 脚本，将导致状态写入 `tasks_list.json` 后无法被其他使用 jq/grep 的脚本正常过滤（它们仅识别 `ready`），从而使整个状态流转和恢复机制失效。
- **建议**：将 `待开始` 修改为 `ready`。
- **置信度**：High
- **优先级**：HIGH

### 2. SubagentStop 在隔离的 subagent 容器中检查 tasks_list.json 存在物理访问障碍
- **位置**：`docs/omni_powers_design.md` 第 596 行 和 第 626 行
- **现象**：第 596 行规定 `SubagentStop` 完成门禁在交工时要检查 `tasks_list.json` 状态。但在第 626 行中明确指出，为了防范源码和流程污染，“流程文件（含 `tasks_list.json`）只在主 worktree 一份物理副本，subagent worktree 不挂载 `op_execution/` 和 `op_record/`”。
- **影响**：由于 `tasks_list.json` 物理上不在 subagent 的工作空间内，`SubagentStop` 作为运行在 subagent 会话退出时的钩子，将无法找到或读取该文件，直接导致门禁脚本报错、拒绝收工，流水线在该节点发生物理性阻塞。
- **建议**：
  - 方案 A：在 subagent 隔离 worktree 的挂载白名单中，将 `tasks_list.json` 以只读（readonly）或 sparse-checkout 仅暴露该文件的方式提供。
  - 方案 B：明确 `SubagentStop` 的执行和校验是由主会话侧（leader 监视子代理返回时）执行，而非在子代理内部执行。
- **置信度**：High
- **优先级**：HIGH

### 3. lite 流程文档把 evaluator 验收与 commit/收口顺序写反
- **位置**：
  - `CLAUDE.md` 第 31-36 行
  - `RULES.md` 第 135-137 行
  - `docs/omni_powers_design.md` 第 853-866 行
- **现象**：
  - `CLAUDE.md` 写 lite task 循环为 `implementer → leader 自验 → reviewer → 收口 → per-task 裸评 → P0 检查 → 归档`。
  - `RULES.md` lite 分叉写 `完成 = review PASS + leader commit + per-task 裸评 PASS + P0 检查过 + 归档`，并写 `review PASS → git add workset + commit → per-task 裸评 → P0 检查 → 归档`。
  - 但 `docs/omni_powers_design.md` §5.6 明确写 `PASS → evaluator per-task 裸评（验收前置，D6——先验 PASS 才 commit）→ PASS → leader 收口（git add 实际 diff + commit + 归档）`。
- **影响**：
  - 运行手册与 README 可能驱动 leader 在 evaluator 验收前提交/收口，破坏“验收前置”设计。
  - lite 无 merge gate、无 worktree 隔离，若 commit 早于验收，失败回流与污染控制更弱，任务状态和 Git 历史会出现“已提交但未验收”窗口。
- **建议**：
  - 统一为 design §5.6 的顺序：`implementer → leader 自验 → reviewer → evaluator 裸评（≤3 轮，先验 PASS）→ leader 收口/commit/归档 → P0 汇总/结束报告`。
  - 修改 `CLAUDE.md` 快速开始 lite 描述。
  - 修改 `RULES.md` lite 表格中的“状态机/收口/闸门”行，避免出现“commit 在 evaluator 前”。
- **置信度**：High
- **优先级**：HIGH

### 4. lite 脚本定位在 design 内部、RULES 与 CLAUDE.md 之间不一致
- **位置**：
  - `CLAUDE.md` 第 36 行
  - `RULES.md` 第 134 行、第 142 行
  - `docs/omni_powers_design.md` 第 777-825 行
- **现象**：
  - `CLAUDE.md` 称 lite “脚本自包含”。
  - `RULES.md` 第 134 行 称 lite 指向共享 scripts 目录 `~/.claude/scripts/omni_powers/`。
  - `RULES.md` 第 142 行 又称 compact 恢复中 `$SCRIPTS = ~/.claude/skills/oplrun/scripts`。
  - design §5.5 前半称“消灭 per-skill 副本同步机制”“lite skill 不再各自带 scripts/ 副本”；但同节后半又写“lite 副本暂保留”“完整归并待重构”“共享寻址方案待定”。
- **影响**：
  - agent/skill 在 lite 下无法形成唯一脚本根契约，compact 恢复、dispatch 注入、环境检查可能找错脚本。
  - 开发者无法判断应维护共享脚本、skill 内副本，还是两者都维护；漂移风险高。
  - “脚本自包含”与“共享目录”是相反安装模型，会影响 install/uninstall、路径 fallback 和测试策略。
- **建议**：
  - 选定单一当前真相源：若当前仍保留 `skills/oplrun/scripts/`，则 design §5.5 前半改为目标态/规划中，`RULES.md` 第 134 行不应宣称共享目录已生效。
  - 若共享目录已生效，则删除 `RULES.md` 第 142 行的 `~/.claude/skills/oplrun/scripts` 说法，并修改 `CLAUDE.md` “脚本自包含”。
  - 在 design §0.2 能力矩阵增加“lite 脚本共享目录/副本归并”状态，避免正文两套状态并存。
- **置信度**：High
- **优先级**：HIGH

### 5. RULES.md compact 恢复入口与 profile-first 规则冲突
- **位置**：
  - `RULES.md` 第 8 行、第 86-105 行、第 122-142 行
  - `docs/omni_powers_design.md` 第 739-758 行
- **现象**：
  - `RULES.md` 顶部与 compact 恢复章节写：读本文件 + jq 查 `tasks_list.json` + 读 `leader_checkpoint.md`。
  - 同文件 profile 分叉又写“compact 恢复第一步先读 profile”。
  - design §5.2 明确 profile 是 compact 恢复第一步，用于判断 heavy/lite、脚本寻址、是否有 closer/闸门 C。
- **影响**：
  - compact 后若先按 heavy 默认 `$OP_HOME/scripts` 或 heavy 状态机读取，就可能在 lite 项目中执行错误脚本、期待不存在的 hook/closer/closing 态。
  - 与“同一项目只认一个 profile”的互斥保护冲突。
- **建议**：
  - `RULES.md` 顶部 compact 恢复改为：先读 `docs/omni_powers/profile`，再按 profile 选择脚本根与状态机，然后 jq 查 tasks_list/checkpoint。
  - heavy/lite 分叉表只保留差异，不再让前文默认流程覆盖 profile-first。
- **置信度**：High
- **优先级**：HIGH

## 中低优先级问题（MEDIUM / LOW）

### 1. RULES.md 表格中状态 `closing` 缺失前置“验收 PASS”条件描述
- **位置**：`RULES.md` 第 35 行表格 `closing` 状态描述
- **现象**：表格中 `closing` 的含义为“双裁决 PASS + merge gate PASS 后，leader 跑 `op_close_pre.sh` 标此态，closer per-task 收口进行中”。这里漏掉了“evaluator 验收 PASS”前置条件。
- **影响**：容易对调度器或 Agent 造成误导，混淆“验收前置”的时序关系（根据设计，验收发生在 merge gate 之前，即：双裁决 PASS -> 验收 PASS -> merge gate PASS）。
- **建议**：在 `closing` 的含义描述中，补充“验收 PASS”作为前置条件。
- **置信度**：High
- **优先级**：MEDIUM

### 2. lite 模式下 spec 写保护校验路径不正确
- **位置**：`docs/omni_powers_design.md` 第 903 行
- **现象**：设计指出，在 `oplrun` 收口前对 `op_execution/specs/**` 跑 `git diff <dispatch锚点sha> -- specs/`。然而在 omni_powers 架构中，工作 specs 的实际路径是 `docs/omni_powers/op_execution/specs/`，在项目根目录下并不存在 `specs/` 目录。
- **影响**：如果直接以 `specs/` 作为 git 路径参数运行，git 会因为目录不存在而默默跳过校验或报错，导致 lite 模式下对工作 specs 文件的写保护校验完全失效，implementer 偷偷修改 spec 的行为将无法被拦截。
- **建议**：将路径修正为 `docs/omni_powers/op_execution/specs/`。
- **置信度**：High
- **优先级**：MEDIUM

### 3. design 中 `op_script()` 示例实现与上层调用形态不匹配
- **位置**：`docs/omni_powers_design.md` 第 783-792 行
- **现象**：注释说 agent 内 `op_script()` resolver，但示例函数内部直接 `bash "$d/$1"; return $?`。开头运行约定常见调用形态是 `bash "$(op_script op_check_env.sh)"`，需要 `op_script` 输出脚本路径，而不是直接执行脚本。
- **影响**：复制该函数会导致双重 bash 调用失败：命令替换拿到的是被执行脚本 stdout，而非路径。
- **建议**：resolver 示例改为只输出路径：遍历目录，找到后 `printf '%s\n' "$d/$1"; return 0`。
- **置信度**：High
- **优先级**：MEDIUM

### 4. RULES.md 的入口环境检查仍只写 `$OP_HOME`，未体现 lite fallback
- **位置**：`RULES.md` 第 111-112 行
- **现象**：跨 agent 铁律写任何 skill/agent 入口先跑 `bash "$OP_HOME/scripts/op_check_env.sh"`。但 lite 差异要求 `${OP_SCRIPT_ROOT:-$OP_HOME}` fallback。
- **影响**：lite agent 若照 RULES 顶层铁律执行，会因无 `$OP_HOME` 或脚本路径不同而失败。
- **建议**：将入口环境检查示例的路径引用改为 `resolver` 机制。
- **置信度**：High
- **优先级**：MEDIUM

### 5. .gitattributes 强制 Windows CMD 脚本 LF 行尾可能引入潜在解析问题
- **位置**：`.gitattributes` 第 8 行
- **现象**：定义了 `*.cmd text eol=lf`。
- **影响**：Windows 批处理（`.cmd` / `.bat`）解释器对 LF 换行符非常敏感。在处理括号多行嵌套（如 `if (...) else (...)`）、for 循环或特定特殊字符时，LF 可能会导致 cmd.exe 解析语法错误。
- **建议**：建议将 `*.cmd` 更改为 `text eol=crlf` 或直接从强制 LF 列表中移出。
- **置信度**：Medium
- **优先级**：LOW

### 6. RULES.md 中硬编码的 `$OP_HOME` 可能误导 lite 模式下的 Agent 脚本定位
- **位置**：`RULES.md` 第 41 行、第 67 行、第 93-100 行
- **现象**：为了方便人类阅读或提供操作范例，RULES.md 大量直接写出了类似 `bash $OP_HOME/scripts/op_status.sh` 这样的重度模式路径。但 lite 模式下，系统不配置 `$OP_HOME`。
- **影响**：在 lite 模式下运行的 Agent 或人类开发者在 compact 恢复时，如果直接复制这些示例命令会因为找不到环境变量而报错，影响恢复效率。
- **建议**：在 `RULES.md` 的 profile 分叉（第 122 行）或文件头部增加统领性说明，指明：“在 lite 模式下，示例中的 `$OP_HOME` 须替换为 `$SCRIPTS` 共享脚本根路径或 `${OP_SCRIPT_ROOT}` 对应位置”。
- **置信度**：High
- **优先级**：LOW

## 改进建议

### 1. 完善全局 .gitignore 中的临时锁文件过滤
- **现状**：目前根目录的 `.gitignore` 仅忽略了 `/vendors/` 和 `docs/review_*/`。但系统中广泛使用了进程/文件锁（如 `*.lock` 文件）。
- **改进点**：在根目录的 `.gitignore` 中加入对常见临时文件和工作流锁文件的全局忽略，防止由于未正常清理的本地锁文件被意外提交。

### 2. 优化 subagent 派发时 `OP_PROFILE` 变量的透传机制
- **现状**：脚本内部依靠 `OP_PROFILE` 判断 heavy/lite 分支。由于 subagent 是 fresh dispatch，环境变量不自动继承。
- **改进点**：在设计文档的派发（dispatch）部分，明确增加在主会话生成子会话时，必须通过命令行 `env` 注入或 prompt 第一行显式初始化并 export 环境变量 `OP_PROFILE` 的协议规范。

### 3. 为“当前实现状态 vs 目标设计”建立单一标注规则
- **建议**：对尚未落地、部分落地、已落地能力统一使用能力矩阵维护。正文只描述机制，不混写“已消灭/暂保留/待重构”三种状态。

## 不确定项 / 可能误报

### 1. decisions.md 追加协议中关于日期格式的模糊性
- **描述**：`RULES.md` 第 147 行规定 decisions.md 的 append 标识中包含 `日期` 字段（如 `[来源标记 | TID | Round-N | 日期]`），但并未在 conventions.md 中强制定义其格式（如 ISO-8601 或特定本地化格式）。
- **可能影响**：不同语言环境/操作系统的 Agent 写入的日期格式若不一致，可能导致依靠正则判重的幂等机制失效。
- **确认**：需确认底层脚本或 agent-prompts 中是否有固定的时间戳提取指令强制约束了该格式，如无，应补齐约束。
