# 01_core_rules 审阅报告（haiku 视角）

## 当前模型判断依据

`/home/karon/.claude/settings.json` 顶层 `model: haiku`；`env.ANTHROPIC_MODEL: default_model`；`env.ANTHROPIC_DEFAULT_HAIKU_MODEL: default_haiku[1m]`。主会话环境提示显示由 `default_haiku[1m]` 驱动。本次审阅 haiku 路不设 model 字段，继承主会话。可观测来源确认当前为 haiku。

## 审阅范围

- `.gitattributes`
- `.gitignore`
- `CLAUDE.md`
- `RULES.md`
- `docs/omni_powers_design.md`

五个文件全量逐段读完。以下按优先级汇报。

---

## 高优先级问题（CRITICAL / HIGH）

### H1. CLAUDE.md 与 design 文档的 per-task 验收时序描述冲突

**位置**：`CLAUDE.md:24` vs `docs/omni_powers_design.md:337`（§2.4 第 4 步）、`:633`（§3.4 回流协议第 4 步）、`:191`（Stage 3 流程图）

**现象**：
- CLAUDE.md 第 24 行描述 Oprun 流程为：`task 循环（review → merge → per-task 验收 → closer 收尾 → 闸门 C → 归档）`
- design 文档 §2.4 第 4 步明确：「**双裁决 PASS → dispatch op-evaluator 验收**（**验收挪到 merge 前**，task 分支上验）」
- design 文档 §3.4 回流协议第 4 步：「**验收（merge 前验）**：双裁决 PASS 后派 evaluator 在 task 分支验」，第 5 步才是 merge gate + squash-merge

**影响**：CLAUDE.md 是用户安装后看到的项目入口（门牌），展示的时序与实际设计相反——验收在 merge 后会误导用户理解为「merge 完才验收」，而设计是「验收 PASS 才 merge」。这是核心安全机制的时序，颠倒会让读者对「验收在 task 分支验、构建产物从 task 分支构建」的前提产生误解。轻信 CLAUDE.md 的人会认为验收是对已 merge 代码的回归性验证，与 hard-pass gate 在 merge 前拦截的定位矛盾。

**建议**：把 CLAUDE.md:24 改为对齐设计实际顺序，例如：`task 循环（review → merge 前验（evaluator）→ merge gate → closer 收尾 → 闸门 C → 归档）`。

**置信度**：高。多文件交叉核对一致。

**优先级**：HIGH。CLAUDE.md 是门牌，时序颠倒传播误解风险高，但当前文件不直接驱动执行（执行靠 RULES.md + SKILL.md），故非 CRITICAL。

---

### H2. CLAUDE.md lite 状态机流程描述漏掉 evaluator

**位置**：`CLAUDE.md:33`

**现象**：lite 命令注释写：
```
/oplrun  # task 循环（implementer → leader 自验 → reviewer → 收口 → per-task 裸评 → P0 检查 → 归档）
```
对照 design §5.6 lite 入口流程（`:854-866`）：顺序是 `implementer → leader 自验 → reviewer → per-task 裸评（evaluator）→ leader 收口（commit+归档）`。

CLAUDE.md 写「收口」在「per-task 裸评」之前，与 design「裸评 PASS 才 leader 收口（D6——先验 PASS 才 commit）」直接冲突。design §5.6 第 865 行明确：「PASS → leader 收口（git add + commit + 归档，§5.9/D6，无闸门 C）」，验收前置是 D6 明文规则。

**影响**：与 H1 同类问题——CLAUDE.md 描述收口在裸评之前，与 D6「先验 PASS 才 commit」的核心约束相反。用户按 CLAUDE.md 理解会以为 lite 是「先 commit 再验证」，而实际是「先验证再 commit」。这影响 lite 的 commit 时机判定（acceptance 前置 vs 后置）。

**建议**：CLAUDE.md:33 改为：`task 循环（implementer → leader 自验 → reviewer → per-task 裸评 → 收口 commit → P0 检查 → 归档）`，与 design §5.6 对齐。

**置信度**：高。D6 明文约束 + design 流程图双重确认。

**优先级**：HIGH。门牌信息错误直接误导 lite 用户的 commit 时机。

---

### H3. RULES.md lite 状态机缺 obsolete 态，与 heavy 段及 design §1.1 矛盾

**位置**：`RULES.md:130-142`（profile 分叉 lite 表格）

**现象**：
- RULES.md 第 21 行 heavy 状态机列出：`pending → ready → in_progress → reviewing → closing → done` + `suspended` + `blocked` + `obsolete`
- design §1.1（`:133-146`）status 枚举表**明确「两版统一」**：所有 9 个状态（含 obsolete）跨 heavy/lite 统一，机读 ASCII
- RULES.md lite 分叉段（第 135 行）只声明「**无『收口中』态**」，未声明 lite 删除 obsolete
- 但 design §5.6（`:832-838`）lite 状态机图里**也漏画 obsolete**（图中只有 pending/ready/in_progress/reviewing/done/suspended/blocked）

**矛盾点**：design §1.1 说状态枚举「两版统一」含 obsolete，但 §5.6 状态图却把 obsolete 漏掉；RULES.md 在 lite 分叉段未明确 obsolete 是否保留。lite 用户废弃一个 task 时，读 RULES.md lite 分叉无法确认能不能用 obsolete 状态。

**影响**：lite 实操时废弃 task 的状态语义不明——废弃态是两版共用还是 lite 独有？RULES.md 是 compact 恢复入口（第一文件），此处留白会让恢复时状态机判断模糊。

**建议**：
1. RULES.md lite 分叉表格补一行：「状态机 | heavy 全态（含 obsolete/suspended/blocked）；**仅删『收口中』态**」——把「obsolete/suspended/blocked 都保留」讲清。
2. design §5.6 状态图补 `obsolete` 节点（与 §1.1 一致）。

**置信度**：高。§1.1 明文「两版统一」，§5.6 图缺节点。

**优先级**：HIGH。状态机是运行时核心，compact 恢复第一手读物。

---

### H4. RULES.md 回滚段用中文字面量「待开始」「待规划」与 opstatus 脚本入参约定不一致

**位置**：`RULES.md:68`

**现象**：
- design §1.1（`:147`）明确：「脚本内 jq/grep 比较一律用左列 ASCII 值」「脚本/agent 不得自创状态串」
- RULES.md 第 41 行状态修改命令：`bash $OP_HOME/scripts/op_status.sh <TID> <status> [blocked_by]`——入参应为 ASCII（如 `ready`）
- RULES.md 第 68 行回滚步骤却写：`bash $OP_HOME/scripts/op_status.sh {TID} 待开始`

`待开始` 是中文渲染值（opstatus 映射层用），不是脚本机读值（design §1.1 表格明确 ASCII=`ready`）。直接照抄回滚命令会因状态串不匹配失败。

同样问题见 `RULES.md:61`「恢复后据是否已生成 spec 回到 `待开始` 或 `待规划`」、`:36` done 含义行用中文——但这些是描述，非脚本命令，风险较低；第 68 行是**直接可执行的命令文本**，是 HIGH。

**影响**：用户/agent 照回滚段执行 `op_status.sh {TID} 待开始` 会失败（脚本比较 ASCII）。RULES.md 是 compact 恢复入口，恢复场景下 agent 可能直接抄这行命令。

**建议**：RULES.md:68 改为 `bash $OP_HOME/scripts/op_status.sh {TID} ready`；全文件审查脚本命令入参，统一用 ASCII 状态值。描述文字（含义列、挂起段）可保留中文渲染值，但**命令文本必须 ASCII**。

**置信度**：高。design §1.1 ASCII 约定明确，脚本入参对照清晰。

**优先级**：HIGH。可直接执行命令出错 = 实操阻塞。

---

### H5. design 文档 §2.5「破坏检查」能力边界声明与 §3.1 refactor 矩阵存在张力但未交叉引用

**位置**：`docs/omni_powers_design.md:422`（§2.5 破坏检查能力边界）vs `:559`（§3.1 refactor 行为层「完全冻结」）

**现象**：
- §2.5 破坏检查（`:422`）自述能力边界：「改断言期望必然红，只证明断言在执行、不证明测试与实现真耦合；功能开关多数应用没有。此检查拦『恒真断言』这类低级假测试。」
- §3.1 refactor 行（`:559`）行为层「完全冻结」，断言期望值不许变——变了自动重归类为 feat/fix

refactor 场景下，结构层单测断言期望**不许变**（§3.1），但破坏检查的核心手段是**改断言期望**验证能红（§2.5）。两者在 refactor 场景下手段上直接冲突：破坏检查要求改断言，refactor 禁止改断言。文档未说明这层关系——破坏检查在 refactor 场景如何适用？是只对 feat/fix 起效，还是 refactor 行为层冻结不影响破坏检查（因为破坏检查是临时改后还原）？

**影响**：执行 refactor task 时，evaluator 跑破坏检查会临时改断言——但 §3.1 说 refactor 断言期望不许变。agent 读 design 会困惑：破坏检查的「临时改」算不算违反 §3.1？两节都没有交叉引用，语义边界靠读者自行推断。

**建议**：§2.5 破坏检查段或 §3.1 refactor 行补一句交叉说明，明确「破坏检查是验收阶段的临时性验证操作（改后还原），不受 §3.1 change type 矩阵的断言约束约束；矩阵约束的是 task 实现交付时的断言状态」。

**置信度**：中。可能是设计上默认破坏检查临时性，但文档确实未明说。

**优先级**：HIGH（边界模糊会导致执行期 agent 自相矛盾的判断；若理解为永久改则违反 refactor 冻结）。

---

### H6. design §0.2 能力矩阵「closer gate 已落地」与 RULES.md「不做」段 closer 权限表述不一致

**位置**：`docs/omni_powers_design.md:56`（§0.2 能力矩阵 closer gate 行）vs `RULES.md:147`

**现象**：
- design §0.2 closer gate 行（`:56`）：实现手段 = `op_closer_gate.sh` 路径白名单校验（**越界 `git checkout` 撤销**，§2.6），状态「**已落地**（D3）」
- RULES.md 第 147 行 closer 权限红线：仅写 `decisions.md` + 转暂存 issue + 写 `acceptance/{TID}/blueprint_update.md` 提案
- 但 design §2.6（`:492`）closer gate 描述：「越界即 `git checkout` 撤销 + 告警，提案不进闸门 C」

RULES.md「不做」段完全没提 closer gate 的存在与越界撤销机制。RULES.md 是运行时操作手册，closer gate 是 closer 越界的硬防线（design 定为「硬」级），运行时手册缺这条会让 leader/agent 不知道收口后有个自动撤销步骤。

**影响**：leader 跑收口流程时若不知道 closer gate 会 `git checkout` 撤销越界写入，可能把 closer 的越界输出当有效产物处理，或误判 closer 提案丢失（实被 gate 撤销）。运行时手册漏掉一个已落地的硬防线。

**建议**：RULES.md closer 相关段（第 147 行或「跨 agent 铁律」）补一句 closer gate 的存在与触发条件，指向 design §2.6。

**置信度**：中高。能力矩阵标「已落地」，运行时手册无对应条目。

**优先级**：HIGH。已落地防线在运行时手册缺描述 = 运行时不感知该机制。

---

## 中低优先级问题（MEDIUM / LOW）

### M1. .gitignore 忽略 `docs/review_*/` 但未在 CLAUDE.md/docs 说明用途

**位置**：`.gitignore:2`

**现象**：`.gitignore` 忽略 `docs/review_*/`（本次审阅报告就写在这类目录下）。这是多模型审阅产物目录，但 CLAUDE.md、design 文档均未提及 `docs/review_*/` 的用途与生命周期。

**影响**：低。审阅产物不进 git 合理，但新贡献者读到 .gitignore 会困惑这目录是何物。

**建议**：.gitignore 补注释，或在 CLAUDE.md 依赖/相关文档段提一句「审阅产物目录 docs/review_*/ 不入版本控制」。

**置信度**：高。
**优先级**：LOW。

---

### M2. design §1 目录结构 e2e/ 路径 config 化声明与正文大量硬编码 e2e/ 存在过渡期认知负担

**位置**：`docs/omni_powers_design.md:70`（§1 目录结构 e2e/ 行）

**现象**：第 70 行 e2e/ 路径声明「⚠️ 规划中——config parser 未落地，当前所有 `e2e/**` 规则硬编码、OP_E2E_DIR 不生效，D4-B」。声明诚实，但全文（§2.5、§3.1、§3.4、§3.3 等）大量出现 `e2e/**` 字面量，读者需时刻记住「当前全是硬编码」。

**影响**：低。声明已在 §1 集中标注，但 D4-B 落地前，任何改 e2e 路径的需求都会触碰散落多处的硬编码。

**建议**：在 §0.2 能力矩阵或 §1 顶部集中列出「当前 e2e 硬编码出现位置」（grep 清单），便于 D4-B 落地时一次性替换。

**置信度**：高。
**优先级**：MEDIUM（过渡期维护成本）。

---

### M3. design §2.4 「verdict 落盘（单写者化）」描述冗长且与 §3.4 角色视图重复

**位置**：`docs/omni_powers_design.md:332`

**现象**：§2.4 第 2 步对 reviewer verdict 落盘机制描述很长（约 200 字），与 §3.4 角色 × 文件系统视图表（`:623` reviewer 行）内容高度重叠——都讲「leader 落盘主分支 review.md、单写者、task 分支不许碰、merge gate 白名单 REJECT」。

**影响**：低。设计档案允许适度重复以保各节自足，但此处重复度高，维护时两处需同步。

**建议**：§2.4 第 2 步 verdict 落盘压缩为一句 + 指向 §3.4 角色视图表，减少同步成本。

**置信度**：中。
**优先级**：LOW。

---

### M4. CLAUDE.md「快速开始」install 命令占位符 `<omni_powers_repo>` 未给实际值或说明

**位置**：`CLAUDE.md:12`

**现象**：`git clone <omni_powers_repo> && cd omni_powers`——`<omni_powers_repo>` 是占位符，但未说明是 GitHub/Gitee 哪个仓库、实际 URL 是什么。README 通常会给真实 clone 地址。

**影响**：低。用户需自行找仓库地址。但作为门牌文档，clone 地址缺失增加上手摩擦。

**建议**：补实际仓库 URL（若仓库公开），或注明「仓库地址见内部文档/私有部署」。

**置信度**：高。
**优先级**：LOW。

---

### M5. design §2.3 task 元数据 JSON 示例 status 用 `ready`，但同段标题说「刚拆出」

**位置**：`docs/omni_powers_design.md:299`

**现象**：§2.3 task 元数据示例 JSON：`"status": "ready"`。上下文是 opintake 拆 task 后的状态。按 §1.1 枚举表，`ready` = 待开始（spec 就位），`pending` = 待规划（无 spec）。opintake 拆 task 时 spec 已生成（§2.2），所以 `ready` 合理。

但 §2.3 标题「task 拆分（opintake 内自动完成）」+ 示例 status=ready，读者可能误以为「拆分即 ready」。实际 pending→ready 的转换依赖 spec 就位（§1.1）。示例没问题，但缺一句说明 status 取值时机。

**影响**：低。示例值正确，仅缺时机说明。

**建议**：示例 JSON 下补一句「status 在 spec 就位后为 `ready`（闸门 A 后），opintake 入口前为 `pending`」。

**置信度**：中。
**优先级**：LOW。

---

### M6. RULES.md 第 142 行 compact 恢复段 `$SCRIPTS` 路径示例与 §5.4 共享目录约定可能漂移

**位置**：`RULES.md:142`

**现象**：lite compact 恢复段写：`$SCRIPTS = oplrun skill 安装目录下的 scripts/ 子目录，如 ~/.claude/skills/oplrun/scripts`。

但 design §5.5（`:805`）说 lite 脚本统一指向 install.sh 装的共享目录 `~/.claude/scripts/omni_powers/`，且 §5.5（`:824`）提「lite 副本（skills/oplrun/scripts/）暂保留」、完整归并待重构。

RULES.md 例子指向「oplrun skill 目录下」，与 design 的共享目录目标（`~/.claude/scripts/omni_powers/`）不一致。当前是过渡期两份并存，但 RULES.md 只举了副本路径，没提共享目录。

**影响**：中。compact 恢复时若按 RULES.md 例子寻址，可能命中待淘汰的副本而非共享目录，或在副本归并后路径失效。

**建议**：RULES.md:142 补共享目录路径 `~/.claude/scripts/omni_powers/` 作为主寻址点，oplrun/scripts 副本标为「过渡期保留」。

**置信度**：中高。design §5.5 共享目录是目标，RULES.md 未同步。

**优先级**：MEDIUM。过渡期路径漂移会影响 lite compact 恢复。

---

### M7. design §3.1「可写性矩阵」lite 无 hook 声明与 §5.7 reviewer 退化矩阵表述分散

**位置**：`docs/omni_powers_design.md:564`（§3.1 末尾）vs `:876`（§5.7 reviewer 行）

**现象**：§3.1 末尾（`:564`）：「lite 无 hook 也无 merge gate——无分支拓扑，此段矩阵作为 reviewer 判定依据内联进 reviewer lite 分支 prompt（§5.7）」。§5.7 reviewer 退化行（`:876`）：「判定依据内联进 reviewer lite 分支 prompt（从 §3.1 蒸馏最小集）」。

两处互指，但都没给出「蒸馏后的最小集」具体内容。设计档案指向 agent.md 实现，可接受；但读者想知道 lite reviewer 到底用哪几条规则时，design 层无答案。

**影响**：低。实现层（reviewer.md lite 分支）应给出，design 层指向即可。

**建议**：§5.7 reviewer 退化行补一句「最小集 = feat/fix 行为层规则 + refactor 冻结 + 断言归因」，给读者一个锚点。

**置信度**：中。
**优先级**：LOW。

---

### M8. RULES.md 第 98 行 `op_jq.sh skipped` 命令与 A16「不设 skipped 态」矛盾

**位置**：`RULES.md:98`

**现象**：compact 恢复命令清单第 98 行：`bash $OP_HOME/scripts/op_jq.sh skipped  # 跳过`。

但 RULES.md 第 51 行（A16 下游传播段）明确：「**不设 skipped 态**，调度器派生」；design §1.1 枚举表也无 `skipped` 状态（`:133-146` 只到 obsolete）。

`op_jq.sh skipped` 命令查的是一个不存在的状态。要么脚本里有兼容旧逻辑的遗留，要么文档命令清单未随 A16 清理。

**影响**：中。compact 恢复时 agent 跑 `op_jq.sh skipped` 会返回空或报错，浪费一步且产生困惑（为何查 skipped？是不是漏了什么？）。

**建议**：RULES.md:98 删除 `skipped` 命令行，或改为注释说明「skipped 态已废弃（A16），下游保持 ready 由调度器派生」。

**置信度**：高。A16 明文不设 skipped，命令清单却是遗留。

**优先级**：MEDIUM（实为 HIGH 候选，但仅影响 compact 恢复一步，降为 MEDIUM）。

---

### M9. design §2.5 evaluator 读写权「写权」段提到 issue 草稿路径与 §3.2 issue 机制描述分散

**位置**：`docs/omni_powers_design.md:417`（§2.5 写权）vs `:572`（§3.2 落盘者赋 P）

**现象**：§2.5 evaluator 写权（`:417`）：范围外发现 issue 草稿写 `op_execution/acceptance/{TID}/`，由 leader 收口落盘。§3.2（`:572`）：evaluator 范围外发现走「草稿写 acceptance → leader 收口落盘赋 P」。两处一致，但 §3.2 的 issue frontmatter 模板（`:574-586`）没标「草稿存放位置」字段，evaluator 写草稿时按什么 frontmatter？文档未示。

**影响**：低。流程清晰，仅 frontmatter 模板缺「草稿→正式」过渡说明。

**建议**：§3.2 issue frontmatter 模板补注释「evaluator 草稿先写 acceptance/{TID}/，leader 收口时按本模板落盘 issues/」。

**置信度**：中。
**优先级**：LOW。

---

### L1. .gitattributes 缺 `*.json` 已含但未覆盖 `*.yaml`/`*.yml`

**位置**：`.gitattributes:9`

**现象**：强制 LF 覆盖 `*.sh`/`*.bats`/`*.cmd`/`*.json`/`*.md`/`*.sh.tmpl`。但项目 design 文档提 `$MY_FILE_CONFIG/service_configs/ports.yaml`（全局约定），且 omni_powers 未来可能用 yaml 配置（OP_E2E_DIR 等）。当前无 yaml 文件，但 config parser 落地后会引入。

**影响**：低。当前无 yaml，预防性建议。

**建议**：补 `*.yaml text eol=lf` / `*.yml text eol=lf`，为 D4-B config 落地预留。

**置信度**：高。
**优先级**：LOW。

---

### L2. CLAUDE.md「依赖」段 jq 安装指引缺 macOS

**位置**：`CLAUDE.md:90`

**现象**：jq 安装指引只给 Windows（choco/scoop/官网），没给 macOS/Linux。全局 CLAUDE.md 说「Mac 允许使用 Docker」，项目可能跨平台。macOS 用户 `brew install jq`、Linux `apt install jq` 缺失。

**影响**：低。macOS/Linux 用户通常已装 jq，但门牌文档缺主流平台指引不完整。

**建议**：补 macOS（`brew install jq`）与 Linux（`apt install jq` / `dnf install jq`）。

**置信度**：高。
**优先级**：LOW。

---

### L3. design 文档 §2.6「自审深度升级阈值」5 条未说明计数口径

**位置**：`docs/omni_powers_design.md:512`

**现象**：自审深度升级阈值「>5 条」自动升级详细审。但「条」指什么？blueprint diff 条目数？baselines 合入段数？task 归档提案条数？三者合计？未定义计数口径。

**影响**：低。leader 自审时需自行解释「5 条」边界，不同解释导致升级阈值漂移。

**建议**：§2.6 明确「5 条 = blueprint_update.md 的 diff 条目（新增+修改+删除）总数，不含 baselines 合入段与归档提案」或类似口径。

**置信度**：中。
**优先级**：LOW。

---

### L4. design §2.7「系统层夜跑」与 §0.2 能力矩阵「P2+/P3」阶段标注措辞不一

**位置**：`docs/omni_powers_design.md:55`（§0.2）vs `:542`（§2.7）vs `:599`（§3.3 第 6 层）

**现象**：
- §0.2（`:55`）：系统层夜跑 = P2+/P3 阶段
- §2.7（`:542`）：系统层夜跑 = P2+/P3 阶段
- §3.3 第 6 层定期体检（`:599`）：P3 交付

「P2+」与「P3」混用，P2+ 含 P2，但 §3.3 体检只标 P3。夜跑与体检是否同一交付阶段？

**影响**：低。阶段标注措辞不一增加读图成本。

**建议**：统一为「系统层夜跑（P2 启动骨架，P3 完整变异测试）」或明确夜跑与体检的阶段关系。

**置信度**：中。
**优先级**：LOW。

---

## 改进建议

1. **CLAUDE.md 门牌时序校正（H1/H2）**：CLAUDE.md 第 24、33 行的流程时序与 design 冲突，应作为首批修复——门牌是用户第一印象，时序颠倒传播面最广。

2. **状态值 ASCII 统一审查（H4/M8）**：RULES.md 内脚本命令入参全部核对 ASCII 状态值（`ready` 非「待开始」、删 `skipped` 遗留命令）。建议加一个 grep 检查脚本或 pre-commit 校验，防中文状态串混入命令文本。

3. **状态机 lite 分叉补全（H3）**：RULES.md lite 分叉表格明确「仅删 closing，obsolete/suspended/blocked 全保留」，消除 lite 状态机歧义。

4. **运行时手册补已落地防线（H6）**：closer gate 已落地（D3）但 RULES.md 无描述，运行时手册应同步硬防线清单，至少提一句指向 design §2.6。

5. **跨节冲突交叉引用（H5）**：破坏检查 vs refactor 断言冻结的张力，补一句交叉说明即可消除歧义。

6. **路径约定同步（M6）**：RULES.md lite compact 恢复段补共享脚本目录 `~/.claude/scripts/omni_powers/` 作为主寻址点，对齐 design §5.5 归并目标。

7. **e2e 硬编码集中索引（M2）**：D4-B 落地前，design §1 或 §0.2 集中列出 e2e 硬编码出现位置，便于一次性替换。

---

## 不确定项 / 可能误报

1. **H1/H2 时序冲突**：可能 CLAUDE.md 是有意简化（「per-task 验收」泛指验收环节，不强调 merge 前后）。但即便简化，顺序写反（review → merge → 验收）仍会误导，因为读者会按字面理解时序。若 maintainer 确认是简化且接受误导风险，可降级。但建议修正。

2. **H5 破坏检查 vs refactor**：可能设计默认「破坏检查是临时验证操作，改后还原，不触 §3.1 冻结」。这个推断合理但文档未明说，故标 HIGH 待 maintainer 确认。若确认是默认共识，降为 LOW 补一句说明即可。

3. **M6 `$SCRIPTS` 路径**：可能当前 lite 副本仍生效（§5.5 说「暂保留」），RULES.md 例子指向副本在过渡期正确。但共享目录是目标，RULES.md 至少应双路径并列。若 maintainer 确认过渡期以副本为准，可降级。

4. **M8 `op_jq.sh skipped`**：可能脚本 `op_jq.sh` 内部对 `skipped` 有兼容处理（返回空 + 提示已废弃），属于向后兼容。但 RULES.md 命令清单保留废弃命令仍需清理。若脚本已处理，降为 LOW。

5. **L3 自审阈值「5 条」**：可能项目 conventions 已覆盖（design 说「阈值 5 可由项目 conventions 覆盖」），具体口径在 conventions 定义。但 design 层未给默认口径，仍建议补。

6. **设计档案的「诚实声明」风格**：本文档大量使用「⚠️ 规划中」「当前不可用」「P1 交付」等阶段标注，是有意为之的诚实定位（§0.1 安全增量诚实声明）。审阅中多处「未落地」类发现（如 M2 e2e 硬编码、L4 阶段标注）属于已声明状态，非缺陷——maintainer 可能已知且有意保留。这类项优先级均压低。
