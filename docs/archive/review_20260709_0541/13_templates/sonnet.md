# Sonnet 审阅报告：模块 13_templates（docs_template/omni_powers/ 全 18 模板）

## 当前模型判断依据

settings.json 顶层 `model=haiku`，`ANTHROPIC_DEFAULT_SONNET_MODEL=default_sonnet`。本审阅以 sonnet 视角独立判断，不参考其他路审阅结果。设计上下文来源为 `/home/karon/karson_ubuntu/omni_powers/docs/omni_powers_design.md`（§0-§5.9）。

## 审阅范围

`docs_template/omni_powers/` 下全部 18 个模板文件：

| # | 文件 | 用途 |
|---|------|------|
| 1 | README.md | 模板总索引与命名约定 |
| 2 | index.md | 文档导航总图（三态模型） |
| 3 | op_blueprint/prd.md | 产品需求文档模板 |
| 4 | op_blueprint/architecture.md | 系统架构模板 |
| 5 | op_blueprint/conventions.md | 编码约定模板 |
| 6 | op_blueprint/domain.md | 领域模型模板 |
| 7 | op_blueprint/test.md | 测试策略模板 |
| 8 | op_blueprint/spec_index.md | 功能规格索引模板 |
| 9 | op_blueprint/specs/{feature}.md | 生效规格模板 |
| 10 | op_blueprint/baselines/baselines_index.md | 基准快照索引模板 |
| 11 | op_execution/tasks_list.json | task 清单模板 |
| 12 | op_execution/leader_checkpoint.md | checkpoint 模板 |
| 13 | op_execution/tasks/{TID}/report.md | 实现报告模板 |
| 14 | op_execution/tasks/{TID}/review.md | 双裁决审查模板 |
| 15 | op_execution/issues/I-{YYYYMMDD}-{NN}.md | 泛 issue 模板 |
| 16 | op_execution/issues/{TID}_quality.md | 质量阻塞记录模板 |
| 17 | op_record/decisions.md | 历史决策记录模板 |
| 18 | op_record/progress.md | 进度日志模板 |

---

## 高优先级问题（CRITICAL / HIGH）

### CRITICAL-1：tasks_list.json 示例数据 `blocked_by: "resource"` 与 design 状态模型矛盾

- **位置**：`op_execution/tasks_list.json` 第 26-27 行，T0003 条目
- **现象**：示例中 T0003 的 `status: "blocked"` 同时 `blocked_by: "resource"`
- **影响**：design §1.1 明确定义 `blocked` 状态语义为「两轮到顶（本 task 质量失败）」，阻塞原因应为 `quality`（质量失败）。`resource`（资源阻塞，如等待外部依赖/等待用户输入）按 design 应归入 `suspended` 状态（「暂停 NEEDS_CONTEXT 等」）。模板给错示例导致 agent/脚本 对 `blocked` 状态产生歧义理解，status 枚举与 blocked_by 值域耦合错误。
- **建议**：T0003 条目要么将 `blocked_by` 改为 `"quality"`（质量失败场景），要么改为 `status: "suspended"` + 移除 `blocked_by` 字段（资源等待场景）。另建议 tasks_list.json 模板增加注释说明 `blocked_by` 值域（当前只有 `quality` 一个合法值）。
- **置信度**：高（design §1.1 状态表明确，模板示例直接违背）
- **优先级**：CRITICAL

### CRITICAL-2：index.md 漏列 design §1 目录结构中多个关键文件/目录

- **位置**：`index.md` op_execution 段、op_blueprint 段
- **现象**：design §1 目录结构中声明的以下条目在 index.md 中完全缺失：
  - `docs/omni_powers/profile`（单行 heavy|lite，compact 恢复第一步读它）
  - `docs/omni_powers/config`（项目级路径配置，D4-B 规划中）
  - `docs/omni_powers/.gitignore`（lite 的 oplinit 写入，§5.5）
  - 顶层 `e2e/` 目录（代码级永久资产，design §1 路径由 config.OP_E2E_DIR 定）
  - op_blueprint 段漏列 `baselines/{feature_key}/` 子目录（只列了 baselines_index.md）
  - op_record 段漏列 `acceptance/{TID}/`（已归档验收工作区，design §1 有）
- **影响**：index.md 定位是「给 agent 看的目录页，SessionStart 注入其摘要」。agent 通过此文件建立项目导航心智模型，关键入口缺失导致：compact 恢复后 agent 找不到 profile 文件（恢复流程第一步即告失败）；找不到 config 导致 E2E 路径回退硬编码（D4-B 未落地前的过渡期尤其致命）；不知道 e2e/ 存在导致 evaluator 产出无处安放。
- **建议**：补全 index.md 使其与 design §1 目录结构完全对齐：op_execution 段增加 `profile`（带注释"单行 heavy|lite，compact 恢复第一步读"）、`config`（带注释"D4-B 规划中"）、`.gitignore`；op_blueprint 段增加 `baselines/{功能名}/` 子目录说明；新增独立段或注释提及项目根 `e2e/` 目录及其保护语义。
- **置信度**：高（design §1 的完整目录结构与 index.md 逐一对照可得）
- **优先级**：CRITICAL

### HIGH-1：5 个 blueprint 模板的 design 引用号 `§3.3` 全部错误，应为 `§1.3`

- **位置**：
  - `op_blueprint/architecture.md` 第 3 行
  - `op_blueprint/conventions.md` 第 3 行
  - `op_blueprint/domain.md` 第 3 行
  - `op_blueprint/test.md` 第 3 行
  - `op_blueprint/prd.md` 第 3 行
- **现象**：以上模板统一写 `> 职责（design §3.3）：...`。design §3.3 是「机械护栏」（三员防护 + hook 映射表），与 blueprint 各文档的职责定义无关。正确的职责矩阵在 design §1.3「文档职责矩阵（去重边界）」。
- **影响**：读者按引用跳转到 design §3.3 看到的全是 hook/gate/CI 护栏机制，找不到文档职责定义，定位成本高。5 个文件同源错误，批量误导。
- **建议**：5 个文件的 `design §3.3` 批量改为 `design §1.3`。
- **置信度**：高（逐文件对照 design §1.3 表格可确认，职责描述一字不差对应）
- **优先级**：HIGH

### HIGH-2：README.md 引用不存在的 design 章节号

- **位置**：`README.md`
  - 第 12 行 review.md 条目："(单写者 = leader...Fix-N 并入 report.md)" 虽内容正确但省略了 design 引用
  - 第 29-33 行的 blueprint 模板表，各条目职责注释写 `design §3.3`（同 HIGH-1 错误）
  - 第 47 行 decisions.md 条目："design §7.2 / RULES.md"
- **现象**：
  - design 文档总共 5 个大节（§0-§5），最大节号 §5.9。`§7.2` 不存在于 design 文档任何位置。
  - §3.3 同 HIGH-1，应改为 §1.3。
- **影响**：README.md 是模板总索引（"新建文件时拷对应模板"），用户抄模板时可能跟着写错误引用，传播面广。错误的引用号使维护者无法定位设计依据，降低模板可信度。
- **建议**：decisions.md 条目的 `design §7.2 / RULES.md` 应改为 `design §2.6（closer 收尾与闸门 C）`。同时修正 5 个 blueprint 模板的 `§3.3` → `§1.3`（对齐 HIGH-1）。
- **置信度**：高
- **优先级**：HIGH

### HIGH-3：leader_checkpoint.md 硬编码 heavy 脚本路径，lite 不可用

- **位置**：`op_execution/leader_checkpoint.md` 第 3-4 行
- **现象**：
  ```
  > 每 task 闭环后由 `op_checkpoint.sh {TID}` 自动生成机械部分...
  > 写完应跑 `bash "$OP_HOME/skills/oprun/scripts/close_check.sh" {TID}` ...
  ```
  `$OP_HOME` 在 lite 模式下未设置（lite 不要求 `--set-ophome`），且脚本路径 `skills/oprun/scripts/` 是 heavy 独有的 skills 内 scripts 布局。lite 的脚本在 `~/.claude/scripts/omni_powers/` 或由 `OP_SCRIPT_ROOT` 指向。
- **影响**：lite 用户或 agent 按模板指令跑上述命令会因 `$OP_HOME` 为空或路径不存在而失败。lite 下 leader 写 checkpoint 时需要手动调整命令路径，模板未提供 lite 分支指引。
- **建议**：模板增加 profile 感知说明——使用 design §5.4 的 fallback 写法：`${OP_SCRIPT_ROOT:-$OP_HOME}`，或分 heavy/lite 两行注释。例如：
  ```
  > heavy: `bash "$OP_HOME/skills/oprun/scripts/close_check.sh" {TID}`
  > lite: `bash "${OP_SCRIPT_ROOT:-$OP_HOME}/op_close_post.sh" {TID}`
  ```
- **置信度**：高（design §5.4/§5.5 明确定义两版脚本寻址差异）
- **优先级**：HIGH

### HIGH-4：tasks/{TID}/review.md 引用不存在的 design §7.2

- **位置**：`op_execution/tasks/{TID}/review.md` 第 34 行注释
- **现象**：
  ```
  - review ≤ 2 轮（design §7.2 / RULES.md）；第 2 轮仍 FAIL → 阻塞
  ```
  design 无 §7.2。review 上限规则在 design §2.4「review 循环上限」段。
- **影响**：review 模板是 reviewer agent 读取的核心文档，错误引用削弱 reviewer 追溯设计依据的能力。
- **建议**：改为 `design §2.4（review 循环上限）`。
- **置信度**：高
- **优先级**：HIGH

### HIGH-5：tasks/{TID}/report.md 引用不存在的 design A21

- **位置**：`op_execution/tasks/{TID}/report.md` 第 18 行
- **现象**：
  ```
  {贴实现者自跑测试命令与关键输出——subagent 不触发 hook，无自动测试结果，design A21}
  ```
  design 文档中无 A21 编号。subagent hook 不触发的说明在 design §0.1、§3.3（机械护栏前提段）、§4.1（hooks 段注释）。
- **影响**：implementer agent 读 report 模板时，A21 引用无法追溯，对"为何需要手动贴测试输出"的机制理解缺失。
- **建议**：改为 `design §3.3（hook 对 subagent 整体失效）` 或直接删除编号引用（内容已自说明）。
- **置信度**：高
- **优先级**：HIGH

### HIGH-6：{TID}_quality.md 使用独立 ID 体系，与 design §3.2 的 `I-YYYYMMDD-NN` 不一致

- **位置**：`op_execution/issues/{TID}_quality.md` 全文
- **现象**：该模板使用 `issue_id: {TID}_quality` 作为 ID，文件名也是 `{TID}_quality.md`。而 design §3.2 定义的 issue ID 规范为 `I-YYYYMMDD-NN`（如 I-20260702-01）。`_quality` 后缀是另一种命名体系。
- **影响**：两套 ID 体系共存导致：issue 索引和检索需要两套逻辑（按 YYYYMMDD-NN 查不到 quality 类 issue）；`optriage` 按统一 ID 规范扫描时漏扫 quality 类 issue；归档与引用混乱。
- **建议**：统一到 design §3.2 的 `I-YYYYMMDD-NN` 体系。quality 类 issue 通过 `tags: [quality, blocker]` 区分，不通过 ID 命名区分。模板文件名改为 `I-{YYYYMMDD}-{NN}.md`（同泛 issue 模板），内容注释"review 满 2 轮仍 FAIL 时写，tags 加 quality+blocker"。如果坚持独立命名，则需要在 design §3.2 补文档化。
- **置信度**：高（design §3.2 只定义了一种 ID 格式，未提 quality 后缀特例）
- **优先级**：HIGH

### HIGH-7：progress.md 格式与 design 描述不一致

- **位置**：`op_record/progress.md` 第 4-6 行
- **现象**：模板格式为 `{TID} | {feature} | YYYY-MM-DD | 完成`，并标注 `与 op_close_post.sh 一致，design §3`。design §1 目录结构中对 progress.md 的描述是：「每 task 完成一行（commit 区间+review 结论+验收标准覆盖）」。模板缺 commit 区间和 review 结论两个字段。另外 `design §3` 引用不存在。
- **影响**：progress.md 定位是事后追溯「发生了什么事」，缺失 commit 区间则无法从 progress 直接定位到 git history 中的对应提交；缺失 review 结论则无法一眼看出 task 是通过还是阻塞后恢复。信息完整性下降降低 progress 的独立可读性。
- **建议**：扩展格式为 `{TID} | {feature} | {commit_range} | {review_verdict} | YYYY-MM-DD | 完成`，或至少增加 commit 区间。修正 `design §3` → `design §1（目录结构-progress.md）`。
- **置信度**：中（design §1 的描述可能只是概括而非格式规范，但模板声明的格式字段与概要描述差距明显）
- **优先级**：HIGH

### HIGH-8：decisions.md 在 README.md 与 design 中定位描述不一致

- **位置**：`README.md` 第 26 行 vs `design §2.6` vs `index.md` 第 42 行
- **现象**：
  - README.md：「设计探索 + spec-delta（leader 变更子流程）+ 红灯归因（closer 提取），append-only」
  - index.md：「决策记录（spec 编写者设计探索 + closer 执行期自决，append-only）」
  - design §2.6 closer 段：「产 per-task 收尾提案... + 提取本 task 的红灯归因 append decisions.md...」
  - design §2.4 spec 变更子流程：「leader 写 delta...append 到 decisions.md（来源标记 spec-delta）」
  三处描述对 decisions.md 写者集合不一致。index.md 只提 spec 编写者 + closer；README.md 提 leader（变更子流程）+ closer；design 实际覆盖 spec 编写者 + leader（spec-delta）+ closer（red-attribution）+ lite leader-close（§5.9）。
- **影响**：写者权限模糊导致 agent 对"谁什么时候写什么"理解不一致，可能遗漏写入义务或越权写入。
- **建议**：README.md 和 index.md 统一为完整描述：「设计探索（spec 编写者）+ spec 变更记录（leader，来源 spec-delta）+ 红灯归因提取（closer，来源 red-attribution）+ lite leader 收口（来源 leader-close），append-only，多写者幂等（design §2.6）」
- **置信度**：高
- **优先级**：HIGH

---

## 中低优先级问题（MEDIUM / LOW）

### MEDIUM-1：I-{YYYYMMDD}-{NN}.md 的 YAML frontmatter 中 pipe 符号易被误解析

- **位置**：`op_execution/issues/I-{YYYYMMDD}-{NN}.md` 第 8-10 行
- **现象**：`severity: P0 | P1 | P2 | P3` 和 `status: open | triaged | converted | closed` 中的 `|` 在 YAML 中是 flow sequence 或 literal block 的控制字符。虽然用引号包裹则无问题，但模板未加引号。
- **影响**：用户照抄模板不加引号时，YAML parser 可能把 `P0 | P1 | P2 | P3` 误解析或报错。
- **建议**：将占位符值加双引号：`severity: "P0 | P1 | P2 | P3"`，或改为注释说明（`severity: P0  # 可选 P0/P1/P2/P3`）。
- **置信度**：中（取决于用户使用的 YAML parser 严格程度）
- **优先级**：MEDIUM

### MEDIUM-2：{feature}.md 模板缺失 baselines 引用段

- **位置**：`op_blueprint/specs/{feature}.md` 全文
- **现象**：index.md 描述生效规格含「含 baselines 引用」，但该模板没有任何 baselines 相关内容。baselines 与 AC 的映射关系只在 baselines_index.md 中维护，生效规格模板中未建立双向引用。
- **影响**：agent 读生效规格时不知道哪些 AC 有对应的 baseline 快照，需要在 spec 与 baselines_index 间来回跳转。
- **建议**：在生效规格模板末尾增加可选的「验收基准」段，格式如 `- AC-N: 见 baselines/{feature}/AC-N_*.{txt|png}`，与 baselines_index.md 交叉引用。
- **置信度**：中（取决于是否认为 spec→baseline 引用属于 spec 职责还是纯索引职责）
- **优先级**：MEDIUM

### MEDIUM-3：test.md 引用 opspec「通道判定」但未指明具体位置

- **位置**：`op_blueprint/test.md` 第 19-20 行
- **现象**：「通道判定见 opspec「通道判定」：Chromium 渲染的用 CDP...」——opspec 是 skill（`skills/opspec/SKILL.md`），其中的通道判定逻辑分散在 spec 模板的可测性契约段与 opspec 决策树段落，无独立「通道判定」节。
- **影响**：用户按指引去找「通道判定」节可能找不到（opspec SKILL.md 中没有以此为标题的独立段落）。
- **建议**：改为「通道判定见 opspec（skills/opspec/SKILL.md）中可测性契约的通道选择决策树」。
- **置信度**：中
- **优先级**：MEDIUM

### MEDIUM-4：architecture.md 模板无跨模块契约的具体示例

- **位置**：`op_blueprint/architecture.md` 第 20-23 行
- **现象**：跨模块契约表只给出表头，无一行示例数据。同为 blueprint 模板的 domain.md 给出了术语表的示例行 `{术语} | {english_name} | {定义}`。
- **影响**：跨模块契约是 architecture.md 的核心价值（唯一架构真相中「模块间怎么通信」的部分），空表头给用户的填充指引弱于有示例行的模板。
- **建议**：增加一行示例，如 `| IAuthProvider | ui | auth-core | 输入 credential 返回 session token；错误返回 null（不抛异常） |`
- **置信度**：中
- **优先级**：MEDIUM

### MEDIUM-5：leader_checkpoint.md 无 profile 感知说明

- **位置**：`op_execution/leader_checkpoint.md` 全文
- **现象**：模板的注释指令全部假设 heavy 环境（引用 `$OP_HOME` 路径、`close_check.sh` 验收）。lite 下的 checkpoint 同样需要此模板，但行为差异（无 closer、验收前置 D6、commit 在裸评 PASS 后）未体现。
- **影响**：lite leader 按模板指令操作时执行不存在的脚本路径，或遗漏 lite 特有的收口步骤。同 HIGH-3 但侧重不同——HIGH-3 关注脚本路径不可用，MEDIUM-5 关注流程步骤差异未标注。
- **建议**：模板顶部增加 profile 注释段：
  ```
  > heavy: close_check.sh 验收 + 闸门 C 归档
  > lite: leader 自验后 git add + commit（验收前置 D6），无闸门 C
  ```
- **置信度**：高
- **优先级**：MEDIUM

### MEDIUM-6：tasks_list.json 中 `depends_on: null` 与空数组 `[]` 两种表示并存，无约定说明

- **位置**：`op_execution/tasks_list.json` T0001（`depends_on: null`）vs design §2.3 示例（`depends_on: ["T0001"]`）
- **现象**：模板示例中 T0001 用 `null` 表示无依赖，T0002 用 `["T0001"]` 表示有依赖，而 T0003 用 `["T0001"]` 表示有依赖。design §2.3 定义的元数据示例只有 `depends_on: ["T0001"]` 一种形式，未提及 null。
- **影响**：脚本用 `jq` 做依赖检查时，`null` vs `[]` 需要不同处理逻辑（`select(.depends_on != null)` vs `select(.depends_on | length > 0)`）。不统一增加脚本处理复杂度。
- **建议**：统一使用 `[]` 表示无依赖（空数组语义更清晰且 jq 的 `length > 0` 判断直接工作）。design §2.3 字段定义应同时明确。
- **置信度**：中
- **优先级**：MEDIUM

### LOW-1：conventions.md 模板的「修改代码后」段与 CLAUDE.md 全局指令重复

- **位置**：`op_blueprint/conventions.md` 第 42-43 行
- **现象**：`检查 docs/ 和 CLAUDE.md 是否受影响，一并更新` 与用户全局 CLAUDE.md 中的相同规则完全重复。
- **影响**：无功能问题，conventions.md 是项目级约定，复制全局规则是合理的局部自治。仅指出重复供参考。
- **建议**：保留（项目级约定应自足），可通过注释说明与全局规则的关系。
- **置信度**：高
- **优先级**：LOW

### LOW-2：README.md 中 acceptance 工作区标注「运行时生成」但无模板文件

- **位置**：`README.md` 第 22-23 行
- **现象**：README 表格中包含 `op_execution/acceptance/` 条目，注明「evaluator 验收工作区（运行时生成）」。该路径在模板目录下无对应模板文件，README 也无指向具体模板的链接。
- **影响**：用户不知道 acceptance 下应该生成什么文件结构（baselines/、blueprint_update.md 等），只能靠 design 文档或运行时脚本推断。
- **建议**：要么在表格中注明子文件结构（`acceptance/{TID}/baselines/` + `blueprint_update.md`），要么新增对应的模板目录骨架。
- **置信度**：高
- **优先级**：LOW

### LOW-3：test.md 的 lane 表 cua 行注释 `// channel: cua` 使用了非标准注释语法

- **位置**：`op_blueprint/test.md` 第 18 行
- **现象**：`cua | CUA driver...（// channel: cua 标注）` —— `//` 在 Markdown 表格中不是注释语法，会被直接渲染为文本。
- **影响**：仅影响可读性，不影响功能。
- **建议**：改为 Markdown 兼容写法，如 `cua | CUA driver（代码标注 \`// channel: cua\`）`
- **置信度**：高
- **优先级**：LOW

---

## 改进建议

### 建议 1：建立模板与 design 章节的交叉引用一致性校验

当前 18 个模板中有 5 个引用 `design §3.3`（全部错误），2 个引用不存在章节号（`§7.2`、`A21`），1 个引用 `design §3`（过于宽泛）。建议在 CI 或 `build_lite.sh` 中增加一个机械检查：从模板中提取所有 `design §N.N` / `design AN` 引用，对照 design.md 实际章节号做存在性验证。这可以防止未来章节号变动后模板引用漂移。

### 建议 2：为 lite 模式增加模板 profile 标注

当前全部 18 个模板均未区分 heavy/lite。其中至少 3 个模板（leader_checkpoint.md、tasks_list.json 的 closing 状态、review.md 的 closer 引用）在 lite 下需做调整。建议每个模板文件顶部增加一行 profile 标注：
```
> profile: heavy | heavy+lite（共用） | heavy+lite（lite 分支见注释）
```
降低 lite leader 按 heavy 模板操作的风险。

### 建议 3：统一 tasks_list.json 的 `blocked_by` 字段值域

当前 design §1.1 中 `blocked` 状态只定义了质量失败场景，但 `blocked_by` 字段值域未在 design 或模板中显式枚举。建议在 design §1.1 状态表增加 `blocked_by` 列，枚举合法值（如 `quality`），并在 tasks_list.json 模板或注释中声明。

### 建议 4：考虑增加 acceptance 工作区模板

当前 `docs_template/omni_powers/op_execution/` 下无 `acceptance/` 目录模板。design 中 acceptance 工作区有明确的结构（`{TID}/baselines/` + `blueprint_update.md`），closer 和 evaluator 都依赖此结构。增加模板可降低 agent 对 acceptance 目录结构的理解成本。

---

## 不确定项 / 可能误报

1. **design §7.2 引用**（HIGH-2、HIGH-4）：确认 design.md 全文中搜索不到 `§7.2` 或 `7.2` 章节标题。但有可能 `§7.2` 指向的是外部文档 RULES.md 的章节（review.md 注释写的是 `design §7.2 / RULES.md`，可能本意是 RULES.md 的 §7.2）。即便如此，模板注释仍应精确引用，不应让读者猜测。

2. **blocked_by: "resource" 是否为合理值**（CRITICAL-1）：如果 `blocked` 状态的语义已从纯粹的"质量失败"扩展到"因任何原因阻塞"，则 `resource` 可接受。但从 design §1.1 的状态表来看，`suspended` 更匹配"资源等待"语义。若是 design 的意图已演进但未同步更新模板，则属于 design docs 滞后而非模板错误。

3. **progress.md 格式**（HIGH-7）：`op_close_post.sh` 是脚本实现，其实际写入格式可能已包含 commit 区间和 review 结论。如果脚本实现比模板描述更完整，则问题在模板文档滞后而非格式设计缺失。确认需要查看 `op_close_post.sh` 源码。

4. **{TID}_quality.md 的 ID 体系**（HIGH-6）：若 quality 类 issue 在 optriage 和 issues 索引中有独立的处理路径（如不参与常规 triage 而直接转 task），则独立命名可能是有意设计。但 design §3.2 未提此特例，无法判断。

5. **`$OP_HOME` 在模板注释中的使用**（HIGH-3）：如果模板的使用场景严格限定在 heavy 模式（即 lite 用户不应参考此模板的注释指令），则硬编码 `$OP_HOME` 不算问题。但当前模板未在任何地方声明 profile 限定。
