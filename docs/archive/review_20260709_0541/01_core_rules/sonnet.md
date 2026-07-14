# Sonnet 视角审阅报告：01_core_rules

## 当前模型判断依据

`/home/karon/.claude/settings.json` 顶层 `model` 字段为 `haiku`；`env.ANTHROPIC_DEFAULT_SONNET_MODEL` 为 `default_sonnet[1m]`。按用户要求以 Sonnet 视角审阅，不参考其他模型结论。本路不设 model 字段，与当前会话模型解耦。

## 审阅范围

以下 5 个文件，排除 `vendors/` 与 `docs/archive/`：

| 文件 | 行数 | 职责 |
|---|---|---|
| `.gitattributes` | 12 | 跨平台 LF 行尾强制 |
| `.gitignore` | 3 | 版本控制排除规则 |
| `CLAUDE.md` | 108 | 项目门牌：快速开始、目录结构、安装/卸载、依赖、文档索引 |
| `RULES.md` | 149 | 运行时操作手册：状态机、compact 恢复、跨 agent 铁律、profile 分叉 |
| `docs/omni_powers_design.md` | 910 | 设计档案：原则、目录、heavy 流程、横切机制、lite 模式、工程部署 |

---

## 高优先级问题（CRITICAL / HIGH）

### HIGH-1: RULES.md 硬编码 `$OP_HOME` 与 lite 模式不兼容

- **位置**: `RULES.md:5,6,8,41,65,67,68,78,93,102,113,124`
- **现象**: RULES.md 主体大量使用 `$OP_HOME` 绝对路径引用脚本（如 `$OP_HOME/scripts/op_status.sh`、`$OP_HOME/agents/*.md`、`$OP_HOME/docs/omni_powers_design.md`、`$OP_HOME/skills/*/SKILL.md`），但这些引用均位于 profile 分叉声明（第 122 行）之前。lite 用户不设 `$OP_HOME`，compact 恢复时按前 120 行指引会走到死路径。
- **影响**: lite 用户在 compact 恢复时读到 `$OP_HOME/scripts/op_jq.sh` 这类路径将找不到文件，无法正确重建状态。RULES.md 的前 120 行实际上只能给 heavy 用户读，与「两版共用一份 RULES.md」的设计意图冲突。
- **建议**: 在文件开头增加全局说明：「以下含 `$OP_HOME` 的路径为 heavy 模式专用；lite 用户请直接跳至『profile 分叉』段，脚本来址以 `${OP_SCRIPT_ROOT:-$OP_HOME}` fallback 为准」。或者将 heavy/lite 的路径寻址约定前置到文件顶部，让所有引用点自动适用。
- **置信度**: 高
- **优先级**: HIGH

### HIGH-2: RULES.md 使用 `$SCRIPTS` 变量但设计文档使用 `$OP_SCRIPT_ROOT`——两套命名并存

- **位置**: `RULES.md:142` vs `docs/omni_powers_design.md:783-788`
- **现象**: RULES.md 在 lite compact 恢复段定义 `$SCRIPTS` = "oplrun skill 安装目录下的 `scripts/` 子目录，如 `~/.claude/skills/oplrun/scripts`"。设计文档 §5.4 定义 `OP_SCRIPT_ROOT` 为 fallback 变量的根，指向 `~/.claude/scripts/omni_powers/`。两个变量指向完全不同的目录（skills 内嵌副本 vs install.sh 共享目录），且命名不一致。
- **影响**: leader 在 lite 模式下不知道该用哪个变量定位脚本；如果 agent 内部用 `OP_SCRIPT_ROOT` 而 RULES.md 指引用 `$SCRIPTS`，会导致 compact 恢复时找不到正确的脚本路径。这与设计文档 §5.5 所说「消灭 per-skill 副本同步机制」方向矛盾——`$SCRIPTS` 指向的正是 skill 内嵌副本，恰是计划淘汰的。
- **建议**: 统一为一个变量名（`OP_SCRIPT_ROOT`），RULES.md 更新引用；若 lite 副本尚未完全淘汰（如 §5.5 所述「完整归并待重构」），应明确标注 `$SCRIPTS` 为过渡方案，并给出迁移截止条件。
- **置信度**: 高
- **优先级**: HIGH

### HIGH-3: 设计文档中 `op_script()` resolver 存在参数丢失问题

- **位置**: `docs/omni_powers_design.md:783-791`
- **现象**: `op_script()` 示例函数写为 `bash "$d/$1"; return $?`，未传递后续参数 `"${@:2}"`。若脚本需要参数（如 `op_status.sh T0001 in_progress`），只有脚本名被传递，参数全部丢失。
- **影响**: 引用此模式的 agent 或文档读者会写出有缺陷的 resolver；脚本调用静默失败（因缺少参数），错误难以排查。
- **建议**: 改为 `bash "$d/$1" "${@:2}"; return $?`。同时检查 agents 目录下的实际 agent 文件是否已存在此 bug。
- **置信度**: 高
- **优先级**: HIGH

### HIGH-4: 设计文档 §2.4 reviewer diff 中的"三点 diff"术语未定义

- **位置**: `docs/omni_powers_design.md:328`
- **现象**: 「diff 为脚本生成的三点 diff：heavy = `dispatch 锚点 sha...task 分支头`；lite = `dispatch 锚点 sha...工作区`」。但"三点 diff"在全文仅出现这一次，从未定义。从上下文猜测指 `git diff A...B`（三点语法，即 merge-base 对称差），但 lite 版本的 `dispatch 锚点 sha...工作区` 语法不对——`...` 三点语法两端都必须是 commit，工作区不是 commit。
- **影响**: 读者无法准确理解 review-package 的 diff 生成逻辑；按字面实现可能写出错误的 git 命令。lite 侧的 diff 来源在 §5.6（`git diff HEAD`）与 §3.4（`dispatch 锚点 sha...工作区`）表述不一致。
- **建议**: 在首次出现处定义"三点 diff"（即 `git diff A...B` = 从 merge-base 到 B 的变化），并修正 lite 侧为两点的 `git diff <anchor> -- <工作区文件>` 语义。统一 §3.4、§5.6 的 diff 来源表述。
- **置信度**: 高
- **优先级**: HIGH

---

## 中低优先级问题（MEDIUM / LOW）

### MEDIUM-1: `.gitignore` 缺少常见编辑器/OS 临时文件排除

- **位置**: `.gitignore:1-3`
- **现象**: `.gitignore` 仅含 `/vendors/` 和 `docs/review_*/` 两条规则。缺少 `.DS_Store`（macOS）、`*~`/`*.swp`/`*.swo`（vim）、`.idea/`（JetBrains）等常见排除模式。
- **影响**: 开发者使用 macOS 或 vim 编辑文件时，临时文件可能被误提交。虽然发生率低（已有 `.gitattributes` 的 LF 保护说明团队关注跨平台），但补充几行无害。
- **建议**: 增加 `**/.DS_Store`、`*~`、`*.swp`、`*.swo`、`.idea/`。可选，不影响核心功能。
- **置信度**: 中
- **优先级**: LOW

### MEDIUM-2: CLAUDE.md "快速开始"段与设计文档 §4.1 存在冗余但不冲突

- **位置**: `CLAUDE.md:7-15` vs `docs/omni_powers_design.md:648-694`
- **现象**: CLAUDE.md 的安装说明与设计文档 §4.1 描述了相同的安装流程。设计文档 §1.3 规定「每个文档单一职责，重复内容只留一份」，但这条规则本身针对的是**使用 omni_powers 的项目**的 CLAUDE.md 与 blueprint 的关系。omni_powers 自身的 CLAUDE.md 作为项目门牌，简要复述安装流程是合理的入门指引。
- **影响**: 两处内容若不同步更新会造成矛盾；当前版本一致，暂无问题。
- **建议**: 在 CLAUDE.md 安装段加一行「详细说明见 `docs/omni_powers_design.md` §4.1」，确保读者知道权威来源。
- **置信度**: 中
- **优先级**: LOW

### MEDIUM-3: RULES.md 状态机表格中 `blocked_by` 字段的 `resource` 与 `quality` 值与 tasks_list.json 的 ASCII 状态枚举不在同一层级

- **位置**: `RULES.md:37` vs `docs/omni_powers_design.md:133-147`
- **现象**: RULES.md 第 37 行 `blocked` 状态的 `blocked_by` 取值为 `resource`/`quality`/`spawn`（三个小写英文词），而设计文档 §1.1 的 tasks_list.json status 枚举表只定义了 8 个状态值（pending/ready/in_progress/reviewing/closing/done/suspended/blocked/obsolete）。`blocked_by` 的子类型枚举在设计文档中没有独立表格，只在 RULES.md 的阻塞项处理表中出现。
- **影响**: 实现 `op_status.sh` 时，脚本开发者可能只在设计文档中找枚举定义而漏掉 `blocked_by` 子类型，导致校验逻辑不完整。
- **建议**: 将 `blocked_by` 子类型枚举（`resource`/`quality`/`spawn`）补充到设计文档 §1.1 的 status 枚举表附近，或至少在设计文档中引用 RULES.md 的阻塞项处理表。
- **置信度**: 中
- **优先级**: LOW

### MEDIUM-4: 设计文档 §2.5 evaluator 验收"构建产物从 task 分支构建"与 leader 构建交付的职责边界模糊

- **位置**: `docs/omni_powers_design.md:409-411`
- **现象**: §2.5 结构隔离层说「evaluator 操作的应用包由 leader 人工构建后交付到 op-eval worktree」，但同时 §2.4 步骤 4 说「构建产物从 task 分支构建」。两处对"谁构建"的表述不一致——前者暗示 leader 构建（人工），后者暗示 evaluator 在 task 分支上构建（自动）。
- **影响**: 实现时可能产生歧义：是 leader 每次手动构建再交付，还是 evaluator 自己从 task 分支构建？前者对 leader 负担重且违背自动化原则，后者要求 evaluator worktree 能访问 task 分支的构建工具链。
- **建议**: 明确职责边界。建议表述为「leader 确保 task 分支可构建（构建依赖就位），evaluator 在 eval worktree 自行构建 task 分支产物」，或反之明确 leader 构建并交付的场景（如跨平台构建需要特定环境）。
- **置信度**: 中
- **优先级**: MEDIUM

### MEDIUM-5: 设计文档 §5.5 同一脚本在 heavy 有两个搜索目录——priority 解析可能引发静默选错版本

- **位置**: `docs/omni_powers_design.md:785-787`
- **现象**: `op_script()` resolver 先搜 `$root/scripts`，再搜 `$root/skills/oprun/scripts`。若两份同名脚本因维护不同步而内容分歧（如 `op_status.sh` 在 `scripts/` 与 `skills/oprun/scripts/` 各有一份），resolver 总是取第一个找到的，不会报警。
- **影响**: heavy 模式下，如果 `skills/oprun/scripts/` 里的某脚本是实际需要的版本但被 `scripts/` 的同名文件"遮蔽"，会导致静默行为错误。§5.5 提到"lite 副本暂保留"，说明确实存在两份副本并存的过渡期。
- **建议**: resolver 在找到脚本后检查另一目录是否也存在同名文件，若存在则 `WARN` 输出两个路径供排查。同时在 fully migrated 后删掉冗余目录，消除双路径设计。
- **置信度**: 中
- **优先级**: MEDIUM

### MEDIUM-6: 设计文档 §3.4 merge gate 白名单中"结构层测试路径"定义模糊

- **位置**: `docs/omni_powers_design.md:635`
- **现象**: 白名单允许触碰 `*.test.*` 等"实现侧测试"，但括号内仅写 `*.test.*` 一个模式。不同语言测试文件命名不同（`_test.go`、`test_*.py`、`*.spec.ts`、`*Test.java`），当前定义不完整。
- **影响**: 非 `*.test.*` 命名的单元测试文件可能被 merge gate 误拦，导致 implementer 无法提交合法的结构层测试变更。或者相反——白名单过宽导致非测试文件漏入。
- **建议**: 明确结构层测试路径的完整 glob 集合，或改为「实现侧测试目录（如 `__tests__/`、`*_test.go`、`test_*.py` 等受语言/框架约定约束）」，并在 `conventions.md` 中定义项目实际使用的测试文件模式。merge gate 脚本应从 `conventions.md` 读取模式而非硬编码。
- **置信度**: 中
- **优先级**: MEDIUM

### LOW-1: CLAUDE.md 树形目录中 `RULES.md` 缩进不一致

- **位置**: `CLAUDE.md:42-78`
- **现象**: 目录树中，`RULES.md`（第 43 行）以 `├──` 起始，但与下方 `install.sh`（第 45 行）之间有一个空行（第 44 行）。在同一棵逻辑树中插入空行会打断视觉连续性。虽然不影响功能，但降低了可读性。
- **影响**: 极小。纯格式问题。
- **建议**: 删除第 44 行空行，使树形连续。
- **置信度**: 高
- **优先级**: LOW

### LOW-2: `.gitattributes` 未覆盖所有仓库内文件类型

- **位置**: `.gitattributes:1-11`
- **现象**: 仓库含 `.tmpl` 文件（已覆盖 `*.sh.tmpl`），但若将来增加 `.py`、`.js`、`.yaml`、`.toml` 等文件，需手工补充 LF 规则。当前仓库无这些文件，暂不影响。
- **影响**: 将来新增文件类型可能因遗漏而产生 CRLF 污染。但仓库当前不含这些类型，暂无实际风险。
- **建议**: 在 `.gitattributes` 顶部加注释提醒"新增文件类型时评估是否需要显式 LF 规则"。或改 `* text=auto eol=lf` 为更积极的 `* text eol=lf`（去掉 auto，对所有文件强制 LF）。
- **置信度**: 中
- **优先级**: LOW

### LOW-3: 设计文档 §2.2 模板中 `[NEEDS CLARIFICATION]` 的清理规则可操作性不足

- **位置**: `docs/omni_powers_design.md:274-275`
- **现象**: 「leader 写 spec 阶段自筛解决；进闸门 A 前必须清空或显式标注为『待用户决策项』」——"自筛解决"的具体手段未定义。是指 leader 自行假设后标注、还是通过追问用户解决？"显式标注为待用户决策项"的格式也未给出。
- **影响**: leader 写 spec 时若遇到无法自筛的问题，可能困惑于该以什么格式呈现给闸门 A 中的用户。实际影响小——leader 通常可以灵活处理。
- **建议**: 增加一行格式示例：`- **待用户决策**: {问题描述} → {两个选项}，推荐 {选项}，理由：{一句话}`。
- **置信度**: 中
- **优先级**: LOW

---

## 改进建议

### S1: 增加 RULES.md 的 profile-aware 路径解析层

当前 RULES.md 的前 120 行对 lite 用户几乎不可用。建议在文件顶部增加全局路径解析约定，让所有脚本引用点自动区分 heavy/lite。例如：

```
脚本定位规则（compact 恢复先读此段）：
- 有 $OP_HOME → heavy，脚本在 $OP_HOME/scripts/ 与 $OP_HOME/skills/oprun/scripts/
- 无 $OP_HOME → lite，脚本在 ${OP_SCRIPT_ROOT:-~/.claude/scripts/omni_powers/}
- 下文所有 `bash ...` 命令中脚本路径依此规则解析
```

### S2: 设计文档 §0.2 能力矩阵中"当前不可用"项应更显眼

能力矩阵中有 3 项标记为 P2+/P3"当前不可用"（系统层夜跑回归、evaluator baseline 对照评、定期体检）。这些信息对读者理解系统实际能力边界至关重要，但分散在表格中不够显眼。建议在矩阵上方加一行汇总：「当前不可用：系统层夜跑回归(P2+)、定期体检(P3)；仅首次裸评可用无对照评：evaluator baseline(P2)」。

### S3: 设计文档 §5.6 lite 流程图与 §2 heavy 流程图排版对齐

§2 有详细的 ASCII 流程图，§5.6 的 lite 流程只有缩进文本描述。建议给 lite 也画一个简化版流程图，方便对比两模式差异（当前对比需要读者在 §2 和 §5.6 之间来回跳）。

---

## 不确定项 / 可能误报

### U1: RULES.md `$SCRIPTS` 与设计文档 `$OP_SCRIPT_ROOT` 的差异是否已在实际 skill 文件中解决

RULES.md 的 `$SCRIPTS` 可能是 `oplrun/SKILL.md` 内部定义的局部变量，仅供 oplrun skill 上下文使用；设计文档的 `$OP_SCRIPT_ROOT` 是 agent 内部使用的环境变量。两者作用域不同，未必冲突。但 RULES.md 作为"跨 agent/skill 的全局运行时视图"，应统一引用标准变量名。当前无法确认——需读取 `oplrun/SKILL.md` 和 agents 文件交叉验证。

### U2: 设计文档 §2.5 中"evaluator 操作的应用包由 leader 人工构建后交付"是否已过时

考虑到 P2+ 的独立验证环境规划，当前过渡期可能是 leader 手动构建。但若实际实现中 evaluator 已能在 worktree 内自行构建（task 分支上的构建工具链就位），则此句应更新。无法确认当前实现状态。

### U3: MEDIUM-6 中结构层测试路径的 glob 定义是否需要进 conventions.md

假设项目使用多语言（如 Go + Python + TypeScript），conventions.md 只定义一套 glob 可能不够。但在 conventions.md 中按语言/目录分段定义是合理的。不确认项目是否实际需要多语言测试路径支持。
