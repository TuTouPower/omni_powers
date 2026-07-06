# Omni Powers: Claude Code 全流程开发方案设计（heavy + lite 合并版）

> **定位**：设计档案——系统当前怎么设计及为什么。不进运行时上下文。运行时操作见 `$OP_HOME/RULES.md`，agent 行为见 `agents/*.md`，skill 流程见 `skills/*/SKILL.md`。决策依据与演变史见 `docs/op_decisions.md`。
>
> **两模式一份设计**：本文档同时覆盖 **heavy**（全量：hook advisory + worktree 隔离目标 + blueprint 真相源）与 **lite**（零侵入：不加 hook、不改用户项目已有文件）。执行内核（spec/AC/不变量/TDD/双裁决/验收/状态机/角色职责）两版共享；差异全部收敛在**环境集成层**（§13）。安装统一走仓库 `install.sh` 一次装齐 `~/.claude/`，**按项目 init 选模式**：`/opinit`=heavy，`/oplinit`=lite，同一项目只认一个 profile。
>
> 原 `omni_powers_lite_design.md` 已并入本文档（§13-§15），原文移 `docs/archive/`。

**按问题导航**：

| 你要问 | 去看 |
|---|---|
| heavy/lite 的区别到底是什么 | §13 差异面表 |
| lite 缺了什么 | §14.3 退化矩阵 |
| 当前到底安全不安全 | §0.1 诚实声明 + §0.2 能力快照表 |
| hook 为什么不是安全防线 | §10 映射表 + `op_decisions.md` D18 |
| 一个 task 从创建到归档经历了什么 | §7.1 循环 + §7.4 收口 |
| evaluator 怎么保证不放水 | §8.1 防放水四层 |
| 可测性契约是什么、为什么重要 | §5.1 模板 ③ |
| 安全什么时候真正落地 | §12 P2 |

---

## 0. 设计原则

**两个核心病灶**（本系统一切机制都在治这两点）：①测试变绿 ≠ 功能正确；②agent 不理解功能背后的语义。

1. **规格是唯一契约。** 实现、测试、验收三方对着同一份人审过的工作 spec 干活，切断同源污染。
2. **两层规格，资产与工单分离。** 生效规格（op_blueprint/specs/）回答"系统是什么"，只收经实现和验收淬炼的结论；工作 spec（op_execution/specs/）回答"这次做什么"，用完归档。前者由后者喂养。（lite 无 blueprint 真相源，工作 spec 兼任生效规格，§14）
3. **能在 spec 期解决的难题，不留给执行期。** 方案设计在写 spec 时内联完成，人工触点合并进闸门 A；执行期不设新的人工阻塞点。
4. **契约边界规则：执行期决策分两种。** spec 约束范围内的决策（选库/选内部算法/选路径）→ agent 自决 + 记录 + 闸门 C 批量报审；需要改动 spec 文本的发现（INV 守不住/AC 做不到）→ 停下走 spec 变更子流程（人批）。分界线机械：该决策是否需要改 spec 文本。
5. **不变量优先于场景。** 工作 spec 强制填不变量，填不出即视为没理解需求。
6. **测试按耦合物分层，按保护物设防。** 行为层（E2E+回归）是"行为不变"的法官，永久锁定（归 evaluator；目标形态下 implementer 经 **worktree 对称隔离**无法触碰——implementer worktree 不挂 `e2e/`，BUG-* 由 evaluator/leader 转交，§2/§10——hook 对 subagent 拦截失效见 §8.1 前提；当前过渡期为纪律约束/advisory）；结构层（单测）随代码结构机械适配，断言是红线。只保证有一层防篡改且足以拦住 bug。
7. **证据由机器产出——"机器"必须在被监督者控制之外。**
   - **当前（过渡期）**：hook 自动跑测试对 subagent 已失效（D18：PostToolUse 对 subagent 不触发），implementer 的测试输出是它自己跑 Bash 产生、自己写进 report 的——**可伪造**（SubagentStop 只验"存在新鲜输出文件"，验不了真伪）。可信度靠 reviewer 双裁决 + Stage 4 独立验收兜底，不靠"机器证据"三个字。
   - **目标（P2）**：per-task 证据 CI 化——implementer 分支 push 触发 CI 跑测试，结果以 CI 为准（agent 无法篡改 CI 结果），与 evaluator 构建产物链路共用同一套 CI 基建（§10.1）。
   - **不变核心**：bash 先算状态，LLM 再决策——凡确定性计算（工作集核算/状态判定/diff 打包）都交脚本，不留给模型。
8. **plan 是分布式信息，不是文档。** 顺序依赖住 tasks_list.json（机读）+ leader_checkpoint（人扫）；跨 task 决策住 spec；接口契约以代码形式先提交（编译器强制，严格强于文档签名）；工作集住任务卡（脚本核算的一等工件）。独立 plan 文档只会是这四处的过期复印件。
9. **task 即 commit；粒度由工作集决定。** 沿低耦合缝隙切。**task 严格串行执行**——tasks_list 的 depends_on 只表达"无依赖"事实，不授权并行：多 implementer 并行意味着多 worktree 同时 append decisions.md 等共享文件，append-only 多写者文件是 git 合并最差场景；当前没有真实并行需求，不为不存在的场景设计合并协议。模型/基建升级后若开并行，先解决共享文件写入协议再放开。
10. **循环必须有上限，发现必须有去处。** review/fix 最多两轮；修不完的和范围外的统一落 issues。
11. **正常路径下，人只出现在两个位置：闸门 A（审 spec，含技术决策与可测性契约）、闸门 C（验收报告 + 自决决策表 + P0/P1 issue；lite 无闸门 C，见 §14）。** 异常路径仍有人裁：spec 变更子流程、review 两轮到顶 Critical 升级、Stage 4 三轮到顶升级、阻塞 issue 转 task——这些是异常出口，不是常设闸门。闸门 A 预算 **15-30 分钟/叶子**：spec 含不变量+AC+边界+三类技术决策+可测性契约（每 AC 信号/通道/测试缝/预期失败模式），是全系统唯一质量单点，5-10 分钟审不完只会橡皮图章——spec 错则三方全错且无人能拦，这半小时是全流程杠杆最高的人工投入。闸门 C 1-2 分钟，只读自然语言；人不审文件/函数清单——那是杠杆错位。
12. **护栏按需付费，定期做减法。** 每个组件都是对"当前模型做不到"的假设，模型升级后重新审视。

### 0.1 安全增量的诚实声明（读者必读）

**P2 落地前，heavy 相对 lite 的防篡改增量接近零。** heavy 的三大安全卖点——evaluator worktree 无 src、implementer worktree 无 e2e、per-task 机器证据——当前全是「目标形态，过渡期 advisory」（hook 对 subagent 失效，D18）。当前跑 heavy 真实多买到的是：**流程资产**（blueprint/baselines/生效规格沉淀、closer 审计链、闸门 C 报审）+ 主会话 advisory hook + git 层部分保护，**不是安全**。防篡改层面当前 heavy≈lite，两版都靠 reviewer 双裁决 + Stage 4 独立验收兜底。硬隔离与 CI 证据链在 §12 P2 落地后此声明作废。

### 0.2 当前能力快照表（单一状态真相源）

各防线的当前/目标状态**只在此表维护**；正文各节只写机制不重复状态声明，状态一律查此表。

| 防线/能力 | 当前状态 | 目标状态 | 落地阶段 | 失效后果 |
|---|---|---|---|---|
| implementer e2e 对称隔离 | advisory（普通 worktree 未排除目录） | worktree 不挂 `e2e/`（sparse-checkout） | P2 | implementer 可偷改行为层测试 |
| evaluator 无 src 隔离 | advisory（纪律约束） | worktree 无 `src/**`+task 目录+decisions.md | P2 | evaluator 抄实现，测试与实现一起错 |
| per-task 机器证据 | implementer 自跑自贴（可伪造）；SubagentStop 验存在不验真伪 | CI 跑测试，结果为准 | P2 | 假绿证据进 report |
| e2e 集成信号 | 无（implementer 盲跑到 Stage 4） | CI 只读跑 e2e 全集回传 | P2 | 集成断裂延迟到最贵反馈环暴露 |
| e2e/BUG-* git 硬锁 | 未落地 | git 层 + leader 唯一提交入口（§8.3） | P2（入口机制前置） | 行为层测试被篡改 |
| spec 写保护 | git pre-commit + 主会话 hook advisory | 同当前（已达目标） | P1 | 规格静默漂移 |
| evaluator baseline 对照评 | 未落地（首评裸评已可用） | 对照评 + 钓鱼审计 | P3 | 跨迭代回归漏检 |
| lite P0 阻断检查 | 待落 oplrun | 归档前扫 open P0 停下问用户 | 待实现 | P0 静默放行 |
| lite 上下文水位流程门 | 待落 oplrun | 连续超阈值暂停（§14.1） | 待实现 | leader 静默失能 |

过渡期全线通用兜底：reviewer 双裁决 + Stage 4 独立验收。

---

## 1. 入口分拣：两个正交判定

### 1.1 写不写工作 spec？——三条判据（与 change type 无关）

命中任意一条就写：①**跨范围**（多模块/需拆 task）；②**改契约**（接口、数据模型、模块边界）；③**高代价**（数据损坏、不可逆迁移、性能回退、安全）。

三条全不中（改样式、加索引、改变量名、三行 fix）→ 不写 spec 不进 task 机制，契约就是任务卡一句话或那条回归测试。**轻量直做门禁**：按 change type 测试规则（§2）+ 机器证据（贴测试输出）+ commit，不派 reviewer/evaluator、不走 task 循环。轻量 fix 同样可新增 `BUG-{id}_*.spec` 回归（带归因+解锁审批，§10），既有 BUG-* 硬锁。

例：测试框架迁移（refactor，中①②）、模块重划（三条全中）、核算算法更换（中③）→ 写 spec；查询加索引 → 直接干。**spec 与否看规模和风险，不看类型。**

### 1.2 change type？——只决定测试规则（§2）和退化流程形态

| 类型 | 流程形态 | 契约来源 |
|---|---|---|
| **feat** | 全流程（若写 spec）或轻量直做 | 工作 spec / 任务卡 |
| **fix** | 复现 → **先写必然失败的回归测试**（统一 `BUG-{id}_*.spec` 命名，行为层；implementer 新增带归因+解锁审批，§10）→ 根因 → 修 → 变绿（先红后绿，否则判假绿）；暴露规格缺失则补生效规格 | 那条回归测试 |
| **style** | 不进流程，formatter/linter（测试规则见 §2） | — |
| **refactor** | "行为不变"即契约；大型的写 spec，AC 是等价性验证 | 行为层测试套件 |
| **perf** | benchmark 基线 → 改 → 复测；大型的写 spec，AC 是量化指标 | benchmark 基线 |
| **test** | 断言变更逐条归因 | 既有 AC/INV |

---

## 2. 测试可写性矩阵

**原理：测试耦合于什么，决定它能随什么而改；保护什么，决定绝不能随什么而改。**

- **行为层** = `e2e/` 全部 + `BUG-*` 回归测试。只通过界面/接口/存储效果说话，不 import 内部函数。**归 evaluator 所有；既有修改 implementer 无写权**（worktree 对称隔离：implementer worktree 不挂 `e2e/`，§10；hook 对 subagent 拦截失效，硬锁靠结构非 hook）。`BUG-*` 新增属 fix 流程（带归因+解锁审批，§1.2），由 evaluator 验收时写或 implementer 产 patch 由 leader 转交——implementer 不直接落盘到 `e2e/`。
- **e2e 只读信号回传（P2，与对称隔离配套）**：implementer 无 e2e 写权 ≠ 全程盲跑集成。目标形态下 CI 在 implementer 分支**只读跑 e2e 全集并回传结果**（只给信号不给写权，不破坏隔离）——否则集成断裂积累到 Stage 4 叶子级验收才暴露，走 ≤3 轮修复回流是全系统最贵的反馈环。与 per-task 证据 CI 化（原则 7）同一套 CI 基建。
- **结构层** = implementer 的单元/组件测试，耦合于函数名、模块路径、内部接口。**归 implementer 所有。**

| | 行为层（e2e/ + BUG-*） | 结构层（单测） |
|---|---|---|
| **feat** | 只有 evaluator 可新增；改既有 = spec 变更，人批 | 自由新增；改既有断言走归因 |
| **fix** | 新增回归测试（先红后绿）；既有测试**供奉了 bug** 时改它属归因(b)，须写明依据（INV-x/用户报告） | 同左 |
| **refactor** | **完全冻结**（等价性法官） | **机械适配自由**（import/调用/mock 挂载点跟改）；**断言期望值不许变**——变了 = 行为变了 = 自动重归类为 feat/fix 回走 spec 流程（免费的偷改行为检测器）；删除需 reviewer 确认覆盖仍在更高层 |
| **perf** | 冻结 + 允许新增 benchmark | 同 refactor |
| **style** | formatter 纯格式放行；语义变更冻结 | 同左 |
| **test** | 归 evaluator 操作 | 开放，逐条断言归因 |

hook 执行粒度：**按路径分强度**（e2e/ 与 BUG-* 硬阻断，全局拦截——不查锁清单；普通 *.test.* 走警告层）；**警告层按行分敏感度**（只动 import/setup/调用行静默放行，改名零摩擦防警告疲劳；触碰 expect/assert 行强制说明理由）。归因协议管的不是"改没改"，是"凭什么改"。（lite 无 hook，此段矩阵作为 reviewer 判定依据内联进 reviewer lite 分支，§14）

---

## 3. 目录结构：omni_powers 三区制（两版共用布局）

**op_blueprint = "应该是什么"（稳定契约）；op_execution = "现在在干什么"（只放活的东西）；op_record = "发生过什么"（append-only）。** lite 复用同一布局，op_blueprint 仅占位（§14）。

```
<project>/
├── CLAUDE.md                        # 请求用户批准启用 omni_powers；批准后新增一行执行 docs/omni_powers/index.md（lite 不改此文件）
├── e2e/                             # 【代码，永久资产】按 spec 前缀分目录的验收 E2E 全集，系统层定期全量跑（两版路径统一）
│   └── {前缀}/                      #   叶子验收 E2E + BUG-{id}_*.spec 回归测试（BUG-* 与 e2e 同目录，按前缀归属）
├── docs/omni_powers/               # 三区根目录（op_blueprint/op_execution/op_record）
│   ├── README.md                    # 给人看的
│   ├── index.md                     # 给 agent 看的目录页（heavy: SessionStart 注入其摘要）
│   ├── profile                      # 单行值 heavy | lite（§13.1，compact 恢复第一步先读它）
│   ├── op_blueprint/
│   │   ├── prd.md                   # 产品级需求纪要（opinit blueprint-generator 初始化，需求澄清流程维护；各需求总意图）
│   │   ├── architecture.md          # 架构地图：分层、模块边界、跨模块契约（定向包主体）
│   │   ├── conventions.md           # 项目约定：编码/命名/提交/目录规范
│   │   ├── domain.md                # 领域模型 + 跨功能全局不变量（如"时间戳统一 UTC"）
│   │   ├── test.md                  # 测试宪章：可写性矩阵、红灯归因协议、危险模式清单
│   │   ├── spec_index.md            # specs/ 目录索引：功能清单 + 一句话说明 + 文件指引
│   │   ├── baselines/                # 【基准】各功能验收基准快照（leader 基于 closer 提案审批写入）
│   │   │   ├── baselines_index.md    #   基准文件索引：功能名→AC→文件 + 更新说明
│   │   │   ├── session-management/   #   按功能名分目录（与 specs/ 同键，spec↔baseline 1:1，零桥接）
│   │   │   │   ├── AC-2_login_error.png
│   │   │   │   └── AC-3_cleanup.txt
│   │   │   └── darkmode/
│   │   │       └── AC-1_toggle.png
│   │   └── specs/                   # 【生效规格】各功能当前生效规格，每叶子闭环时整理更新
│   │       └── session-management.md
│   ├── op_execution/                # 只放活的东西
│   │   ├── specs/                   # 【工作 spec】前缀编号：
│   │   │   ├── a_darkmode.md        #   单需求不拆：一个文件即叶子
│   │   │   ├── b_website.md         #   总述：总意图+拆分依据+b01/b02 顺序依赖（不审不验）
│   │   │   ├── b01_pages.md         #   叶子：流水线处理单元（审批/验收/task 挂叶子上）
│   │   │   └── b02_contact.md       #   frontmatter: status: draft|approved|in_progress|done
│   │   │                            #   封顶两层：b01 还要拆 = 第一刀切错，回头重切 b 层
│   │   │                            #   顺序依赖在 tasks_list.json（机读）+ leader_checkpoint（人扫），不进 spec 本体
│   │   ├── tasks_list.json          # 【唯一 task 真相源】id/status/所属spec/覆盖AC/触碰INV/depends_on/
│   │   │                            #   风险探针/预计工作集（脚本核算）；人读走 opstatus 渲染
│   │   ├── tasks/                   # 活跃任务目录（每 task 平铺 3 文件：brief/report/review）
│   │   ├── issues/                  # 问题登记（含所属 spec 字段，技术债加 tech-debt 标签）
│   │   ├── acceptance/              # 验收工作区（按 spec 前缀）：evaluator 产出 + closer per-leaf 收尾提案
│   │   │   └── {前缀}/              #   baselines/（新基准快照临时区）+ blueprint_update.md（closer 提案）
│   │   └── leader_checkpoint.md     # leader 检查点：当前活跃 spec、task 进度、下一步
│   └── op_record/
│       ├── decisions.md             # 设计探索全文（spec 编写者写）+ 执行期自决决策（closer append），append-only
│       ├── progress.md              # 每 task 完成一行（commit 区间+review 结论+AC 覆盖）
│       ├── specs/                   # 已归档工作 spec，平铺（前缀保留组关系）
│       ├── tasks/                   # 已完成 task 的 brief/report/review 归档
│       └── acceptance/              # 已归档叶子验收工作区（{前缀}/：blueprint_update.md + baselines 快照）
```

**spec 前缀编码**：单调递增永不复用（e2e/baselines/op_record 永久工件按前缀存，复用会撞）。a-z 用尽后转双字母 `aa, ab, ..., az, ba, ...`（字典序仍单调，脚本按字符串排序天然正确）。

### 3.1 task 工作区（平铺，全部进 git）

```
docs/omni_powers/op_execution/
├── specs/{前缀}.md           # 工作 spec（叶子共享，全员只读。AC/INV/边界/技术决策/可测性契约）
├── tasks/{TID}/
│   ├── brief.md               # leader 生成（任务卡 + 定向包 + 指向 spec 路径，不复制 spec 全文）
│   ├── report.md              # implementer 写：顶部总报告（每轮覆盖为累积总结）+ 分 Round 追加（审计轨迹）
│   └── review.md              # reviewer 写双裁决，FAIL 轮 implementer 追加 Fix-N
├── tasks_list.json            # 唯一 task 真相源
├── leader_checkpoint.md
└── issues/
```

- spec 在 `op_execution/specs/{前缀}.md`，叶子共享，不在 task 目录。
- brief 指向 spec 路径（`工作 spec: op_execution/specs/{前缀}.md`），不复制 spec 全文——spec 是单源，brief 重复会失同步。
- report.md 顶部总报告（leader/reviewer 入口，一眼看当前状态）+ 下方分 Round 追加（FAIL 轮修复记录留得住）。一个文件，不设 context.md。
- 每 task 子目录内 3 文件平铺（brief/report/review，不设 runs/ 等子目录、不设 gitignore），task 闭环后 git mv 到 `op_record/tasks/{TID}/` 归档。

### 3.2 两层 spec 流转与归档（按叶子，不等兄弟）

- **叶子级，验收后**（Stage 4 验收 PASS → Stage 5 闸门 C 收尾）：b01 所有 task 闭环 → 验收 PASS → closer 产 per-leaf 收尾提案 → leader 审批 → 精华并入生效规格（后续 b02/b03 引用它作基准）→ 原文入 op_record/specs/ → tasks_list 清出其 task。进入生效规格的是淬炼后的结论："待澄清"、被证伪的担忧不进；实现中发现的未预见边界行为 + 验收 FAIL 修复后的最终形态一并补进。（lite：无 closer/blueprint，leader 直接归档 spec 原文，§14）
- **组级，延迟**：总述随最后一个叶子（或砍尾：剩余标 cancelled）归档，追加五行完成情况。**前缀永不复用**——前缀单调递增（编码规则见 §3 尾注）。

### 3.3 文档职责矩阵（去重边界）

每个文档单一职责，重复内容只留一份（独占者），其他文档"详见 X.md"。CLAUDE.md 是"门牌"（指路），不重复 blueprint 内容。

| 文档 | 唯一职责 | 不该有（指向即可） |
|---|---|---|
| `CLAUDE.md`（项目入口） | 项目一句话定位 + dev/build/test 命令 + 指向 `op_blueprint/` 各文档 | 技术栈/目录树/架构约束/命名/日志/调试规则 |
| `prd.md` | 产品需求：定位/用户/功能/成功标准/不做 | 技术实现 |
| `architecture.md` | 架构真相：**技术栈 + 目录结构 + 模块划分 + 数据流 + 跨模块契约**（唯一目录/技术栈真相） | 命名规范/编码风格（→ conventions） |
| `domain.md` | 领域语言（术语表）+ 跨功能**业务**不变量（如"刷新恢复""hook 隔离原则""AI 实例不进 store"） | 编码风格/实现细节（→ conventions） |
| `conventions.md` | 编码约定：命名/风格/文件组织/浏览器 API/不可变性/日志规则/适配器开发步骤（**编码独占**） | 业务不变量（→ domain）/架构（→ architecture） |
| `test.md` | 测试宪章：分层/覆盖/lane/Mock 规则/调试入口（CDP 等） | 命名/架构 |
| `spec_index.md` | **纯 specs/ 索引**：功能清单 + 一句话说明 + 文件指引 | 技术栈/架构/安全（→ architecture/domain） |
| `specs/{feature}.md` | 各功能生效规格：接口/数据模型/行为（每功能一份） | — |

**常见重复治理**：
- 目录结构/技术栈 → `architecture.md` 独占（CLAUDE.md/spec_index 删）
- 命名/编码风格/日志规则/不可变性/适配器步骤 → `conventions.md` 独占
- 业务术语（如 bot→ai）→ `domain.md` 独占
- 调试入口（CDP 端口等）→ `test.md` 独占

**已有项目 opinit**：blueprint-generator 从 `docs/archive/` + git log + 现有代码提炼**已实现功能**到 `specs/{feature}.md`（非空，每功能一份），spec_index 索引；新增功能（未实现）不生成，留 `/opintake` 拆分时补。详见 `skills/opinit/SKILL.md` 步骤三。

---

## 4. 全流程总览（对应用户旅程：opintake 管 Stage 0-2，oprun 管 Stage 3-6）

```
需求 ──► opintake "<需求>"          （lite: oplintake，流程同构，差异见 §14）
 │
[Stage 0] 入口分拣（§1）：change type + 三判据；三判据全不中 → 轻量直做，结束
 ▼ 尺寸测试：不能一次审完+一轮验收 → 拆 x_总述 + x01/x02 叶子（逐叶子走以下）
 ▼
[Stage 1] 工作 spec 编写（含内联设计探索 + 可测性契约，§5）
 │         ──► 【闸门 A：15-30 分钟/叶子，原则 11】──► approved，写保护
 │
[Stage 2] task 拆分（opintake 内自动完成，§6）
 │         → tasks_list.json 就绪（顺序依赖机读）+ leader_checkpoint 依赖段
 │         ──► Stage 2 自检（自动：扫 tasks_list.json 依赖 + 拆 task 自检——跨 task 决策遗漏则回补 spec 再过 A，可跳过）══► opintake 终点：task status=`待开始` + checkpoint 标注 spec 就绪
 ▼
 ──► oprun（从 checkpoint 续跑）      （lite: oplrun）
[Stage 3] 逐 task 循环（§7，严格串行）：brief → op-implementer → 测试证据
 │         → op-reviewer 双裁决（≤2 轮）→ op-closer per-task 收口（仅 append decisions.md；lite: leader 代劳）
 │         → task 目录归档 + checkpoint/progress 更新 + commit
 │         契约边界内决策：自决+记 report.md，closer 提取后 append decisions.md，不停
 │         破契约：spec 变更子流程（人批）
 │         （技术探针验证：风险探针 task 后 implementer 在 report 附探针脚本+输出，leader 只读总报告，≤10 分钟、非正式验收、不派 evaluator）
 ▼
[Stage 4] spec 级验收（§8）：op-evaluator（仅 Stage 4 介入）
 │         访问隔离：brief 只有 spec+生效规格（开工前基线）+启动方式+baselines 索引，不含 implementer 产物
 │         评估（hard-pass gate）→ 固化 PASS 测试 → 破坏检查 → 对抗探索
 │         → 逐 AC 报告；范围内 FAIL → 修复 task 回流（≤3 轮：到顶 Critical→升级人裁决/转设计 task，Important/Minor→落 issue）；范围外 → issues
 │         PASS → 派 op-closer 产 per-leaf 收尾提案（blueprint diff + baselines 合入 + 叶子归档，吸收验收结果）
 ▼
[Stage 5] 收尾（每叶子）：本叶子 AC 追溯矩阵；末叶子额外做全分支汇总 review ──► 【闸门 C：1-2 分钟】
 │         leader 审批 closer 收尾提案 → 写入 op_blueprint + baselines 合入 + 叶子归档 + commit
 │         呈报四样（各有主）：验收报告（evaluator 产，§8）+ AC 追溯矩阵（closer per-leaf 提案含）
 │                           + 自决决策表（脚本从 decisions.md 提取带标记的）+ P0/P1 issue（脚本从 issues/ 提；P0 默认阻断，用户可显式豁免并记 decisions）
 │         leader 做 evaluator 二阶判断 → 偏差指令 → 积累校准素材
 │         （lite: 无闸门 C，但保留 P0 阻断检查——open P0 issue 存在时停下问用户，§14.2）
 └──► [Stage 6] merge
```

---

## 5. Stage 1：工作 spec（方案设计 + 可测性契约内聚于此）

### 5.1 模板

```markdown
---
status: draft        # draft → approved → in_progress → done / cancelled
type: feat           # feat | refactor | perf | ...（决定测试规则与 AC 侧重）
feature: <功能名>    # heavy: 对应 op_blueprint/specs/{功能名}.md，closer 合入 baseline 时按此映射（§8.2）
                     # lite: 仅作前缀标识（值=spec 前缀，供 e2e/acceptance 目录命名），不映射 blueprint——保留字段便于 lite→heavy 迁移
---
# <名称>
## 一句话意图
## 不变量（填不出 = 没理解需求；与 domain.md/生效规格冲突必须显式标注）
   <!-- refactor 型此区最长：列出所有必须保持的行为契约 -->
## 验收场景（即 AC，Acceptance Criteria——全文 AC-N 编号指此区条目；Then 必须用户可观察；每条须可直接翻译为可执行断言）
   <!-- feat: 用户能做什么新事 | refactor: 等价性验证 | perf: 量化指标 -->
## 边界与反例（竞态、并发、空状态、失败路径、刷新/重启、多显示器/多窗口）
## 不做的事
## 技术决策（三类内容，均随闸门 A 过人审）
### ①【条件强制】被 2+ task 依赖的决策
   - {数据模型/模块通信/状态存储/接口形状} —— {理由}
### ②【设计探索结论】命中方案先行信号时
   - 候选：{A / B / C}
   - 推荐：{选哪个} —— {复杂度与边界行为权衡 + 理由}
   - 已知坑：{坑}
   <!-- 完整探索过程存 decisions.md，此处只留结论。未命中信号则此区空 -->
### ③【可测性契约】（必填）
   {写 spec 时顺手推导——AC 的验收方式自然延伸；implementer 把测试缝当成和 AC 同级的交付义务}
   - 应用启动方式: {一条命令启动，如 npm start / ./app / ...}
   - AC-1 验收信号: {结构化优先——DOM/a11y/CLI stdout/API 响应/DB 查询/进程健康检查；视觉对照——截图，advisory}，关键入口: {URL / 菜单路径 / API 端点}
   - AC-1 通道: {CDP | cua | 直驱}（能用 CDP 的一律 CDP；CDP 做不到的 OS 原生壳层/浏览器 chrome 才 cua；无 UI 直驱）
   - AC-N 验收信号: {结构化/视觉信号}，通道: {CDP | cua | 直驱}，测试缝: {如"需测试收件箱 → 需 Mailpit + seed 账号"; "需验证导出 → 需 stats export 命令"}
   - 预期失败模式（每 AC 至少 1 条——若 xxx 没做好，AC 应该 FAIL；evaluator Stage 4 对照此表逐条试反例）:
     - AC-1 若未正确实现则 {行为表现}，评估时专门试这个
     - AC-N 若未正确实现则 {行为表现}
## 待澄清 [NEEDS CLARIFICATION]（≤3 条，有则阻断）
<!-- 顺序依赖在 tasks_list.json（机读）+ leader_checkpoint（人扫），不进 spec 本体（避免闸门 A 写保护后追加冲突） -->
```

### 5.2 方案先行（设计探索，spec 期内联）

**触发信号（写 spec 时机械判定）**：①某 INV/AC 涉及"正确性需论证而非目测"的计算（核算、对账、并发一致性、时间切分）；②验收标准含"高效/准确/一致"等需算法保证的词。命中 → spec 编写（leader 主会话，建议闸门 A 前 `/model` 切 Opus）内联做设计探索，结论进技术决策区，**闸门 A 一次审完需求与方案，不另设人工点**。方案纸值得人多花两分钟——5 分钟拦返工 3 天。

**执行期兜底（信号③）**：implementer BLOCKED 或同一 task 两轮 review 不过 → leader 决定插设计 task，dispatch op-implementer 执行（brief 标"只产方案纸不写码"，model 临时升 Opus，reviewer 审，**不设人工门**）→ 结论记 decisions.md 打标记 → 继续 → 闸门 C 批量报审。

**契约边界规则**：执行期一切决策先问一句——**需要改 spec 文本吗？** 不需要（spec 约束内选库/选内部算法/选路径）→ 自决 + 记录 + 打标记，流水线不停；需要（INV 守不住/AC 做不到/契约要变）→ spec 变更子流程（下）。带着已知作废的契约继续跑，越跑返工越大——这是执行期唯一允许阻塞等人的情形。

**spec 变更子流程**（被 §7.1/§7.3/§10 引用，定义在此）：

1. **发起**：发现者（implementer 经 report BLOCKED 上报 / reviewer 契约边界复核打回 / evaluator 验收发现）→ leader 汇总，leader 是唯一发起执行人。
2. **提 delta**：leader 在主会话写 delta（原文引用 + 改后文本 + 理由，逐条），呈报用户——**审批属闸门 A 同级**（改的是同一份人审过的契约），非新闸门。
3. **人批后**：leader 解锁 spec（heavy: git 层解锁脚本；lite: 直接改）→ 应用 delta → 重新 commit + 恢复写保护 → delta 全文 append 到 decisions.md（来源标记 spec-delta）。
4. **task 处置**：leader 扫 tasks_list.json，受影响 task（覆盖 AC/触碰 INV 与 delta 相交）——未开始的改任务卡；进行中/已完成的标 `cancelled` 并重拆（已有 commit 不 revert，append-only 历史，同 §6.3 重切规则）。

### 5.3 其他规则

写 spec 前先输出假设清单一并供审；审批即 commit + 写保护；闸门 A 预算 15-30 分钟/叶子（原则 11），焦点：不变量覆盖沉默失败区（数据隔离/持久化/权限）、边界含竞态与失败路径、Then 全部可翻译为断言、技术决策无遗漏、**可测性契约完整**（测试缝全覆盖、预期失败模式每 AC 至少 1 条）。（"拆 task 发现跨 task 决策遗漏"不在此——拆 task 在 Stage 2，归 Stage 2 自检（自动）检查，见 §4。）

---

## 6. Stage 2：task 拆分（opintake 内自动完成）

### 6.1 plan 信息的四归宿

| plan 信息 | 归宿 | 消费者 |
|---|---|---|
| 顺序与依赖 | tasks_list.json（机读）+ leader_checkpoint（人扫） | leader（Stage 2 自检自动扫） |
| 跨 task 技术决策 | spec 技术决策区（人审） | coder / evaluator |
| task 间接口契约 | **接口先行 task 以代码提交**（类型/schema，编译器强制——严格强于文档签名，文档会漂移代码不会）。**验收**：编译/类型检查通过 + 下游 task 能 import；reviewer 确认接口形状对齐 spec 技术决策 | coder |
| 工作集（文件级） | 任务卡（**脚本 tokenize 核算的一等工件**，非 agent 拍脑袋） | leader（拆分预算/冲突检测/锁管理） |

三个消费者的裁定：**人不审文件/函数清单**（没有代码深度判断不了对错，拦截率≈0，杠杆全在行为层）；**leader 需要文件级工作集但纯属机械用途**；**coder 拿 spec + 任务卡 + 接口代码，函数级内部结构自定**——实际触碰文件与预估偏差过大时，reviewer 规格合规裁决抓范围偏航。

### 6.2 任务卡

```markdown
# T03：<语义级标题，一句 commit message 能说清>       状态: todo
所属 spec: b01    类型: 实现 | 设计 | 修复（来自 issue/验收 FAIL）
覆盖 AC: AC-1, AC-2    触碰 INV: INV-1（⇒ 对应 E2E 在 Stage 4 由 evaluator 固化）
依赖: T01    风险探针: 否
预计工作集: src/store/session.ts, ... （脚本核算 ~46K tokens）
## 完成定义（sprint contract）
- 行为: <可测试的行为描述>    - 验证: <哪些测试、哪条命令>
```

> 任务卡不设「可并行」字段——task 严格串行执行（原则 9）。depends_on 只用于排序与阻塞传播。

### 6.3 粒度判据（工作集，不是行数）

- token 消耗 ≈ 工作集 × 2-3；**拆分代价 = 被切开两半共享的工作集**，沿低耦合缝隙切（层/模块/数据流阶段），先列缝再核量。
- 预算红线 ≈ 名义上限一半：`spec + 任务卡 + 工作集` 超 60-80K 即警惕——要的是全程模型舒适区。
- 逃生阀：能沿缝拆的拆；天然不可分（横切重构/脚手架）→ **换 1M 模型，禁止硬锯出不可运行的中间状态**。合并判据对称：重叠过大半且合并后在预算内 → 合并。
- 降细拆惩罚：①brief 附定向包（architecture.md + conventions 摘要，brief 结构见 §3.1；lite 无 blueprint，定向包退化见 §14.3）；②**接口先行排序**（§6.1 表第 3 行）；③接受部分重复读入是买来的干净上下文。
- **执行中途 task 再拆分归 leader**（同叶子内 task 级：NEEDS_CONTEXT / 预算爆 / 两轮不过转设计 task）：现场沿缝切 task 或换 1M——**spec 叶子封顶两层不变，叶子本身中途不能再拆**，切错则回 opintake 重切上一层 b。判据与 opintake 共用同一套 scripts/ 核算脚本，规则只写一份。
- **叶子重切后的存量处理**：已有 commit 不 revert（append-only 历史），已有 task 标 `cancelled`；重切产生新叶子前缀或同前缀重拆，decisions.md 记重切原因 + 受影响 commit/task 清单。

---

## 7. Stage 3：逐 task 执行循环（oprun / oplrun）

leader-worker：leader 只编排，上下文只留状态；交接全走 task 目录文件；每 task 全新 subagent 独享完整上下文。**task 严格串行**（原则 9）。

### 7.1 单 task 循环

```
 1. leader 生成 brief（任务卡 + spec 路径 + 定向包）
 2. dispatch op-implementer：
    TDD（先写映射 AC 的失败单测，贴 RED）→ 最小实现 → 测试证据
    （证据可信度见原则 7：过渡期 implementer 自跑自贴，靠 reviewer+Stage 4 兜底；P2 CI 化后以 CI 结果为准）
    → 写 report.md（顶部总报告覆盖 + 分 Round 追加）→ DONE | BLOCKED | NEEDS_CONTEXT
 3. dispatch op-reviewer（只读 brief+report+diff+spec），双裁决：
    ① 规格合规：覆盖声明 AC？偏离 spec/自由发挥/范围偏航（实际工作集 vs 预估）？**契约边界复核**：implementer 自决的"不需改 spec"决策逐条审，真在 spec 约束内？实际需改 spec 则打回变更子流程（防自决越界）。
    ② 测试可信：测的是 AC 还是 mock？断言用户可观察？异步时序对？命中危险模式？
      refactor 加审：结构层变更是否只动调用部分？删除的覆盖仍在？
 4. findings：范围内 → fix 循环（7.2）；范围外 → issues，不当场修
 5. 双裁决 PASS → 收口：
    heavy: 派 op-closer per-task 收口（轻）——直接 append 决策到 decisions.md（append-only，不经 leader 审批）；
           不产 blueprint 提案、不碰 op_blueprint（留到 Stage 4 验收后 per-leaf 统一做，§7.4）
    lite:  leader 代劳（§14）——op_close_post → git commit → append decisions.md（来源标记 leader-close）
 6. task 目录 git mv 归档到 op_record/tasks/{TID}/ → tasks_list.json + checkpoint + progress 更新 + commit
```

### 7.2 review 循环上限

```
review → fix → re-review = 一轮；最多两轮。
到顶残留按严重度分流：
 · Critical（规格不合规/测试不可信）→ task 置 blocked + issue + 升级人裁决
     （**呈报用户，由用户四选一**：降级接受/重拆/换更强模型/插设计 task 改思路）——不许静默 commit
     · 降级接受须同步记 spec delta 到 decisions.md（实现与 spec 的偏差 + 下次收尾补 spec），不能裸接受偏离——否则"规格唯一契约"破裂
 · Important/Minor → 照常 commit，残留落 issue 延后
```

两轮修不平大概率是结构问题（方案错/拆分错/规格歧义），继续循环只是烧 token。与"同一问题 3 次修复失败 = 停下升级"同源。

### 7.3 红灯归因协议（test.md + opred skill）

测试红 → 默认实现错。复现 → 读断言（保护哪条 AC/INV）→ 读实现（解释为何不符）→ 归因：（a）实现 bug，只改实现；（b）测试写错，写明错因（锁定文件需人工解锁，归因记 decisions.md；含 fix 场景"原测试供奉了 bug"须给依据）；（c）规格变了，走变更子流程。没有归因不准碰测试。

### 7.4 收口（heavy: closer 提案制，两段节奏；lite: leader 代劳）

closer 拆成两种节奏：per-task 只做轻的那半（append decisions），blueprint 提案 + baselines 合入 + 叶子归档提案统一移到 Stage 4 验收 PASS 之后 per-leaf 做一次。这样生效规格只收经验收淬炼的结论（原则 2），evaluator 读到的生效规格是开工前基线（不被本次实现污染，隔离防线自洽），归档提案能吸收验收结果。

**per-task 收口（轻，task 闭环即做）**——closer 与 leader 分工：

1. leader 跑 `skills/oprun/scripts/op_close_pre.sh {TID}`：`tasks_list.json` 标记 `status=收口中`（**不盖戳 spec**——approved spec 受写保护，per-task 不碰，免被自家 hook 拦）。
2. **op-closer 只做这两件事**：将 reviewer 标【暂存】的问题确定性写入 `op_execution/issues/`（加 `tech-debt` 标签，不二次筛选）+ append 本 task 的架构/自决决策到 `op_record/decisions.md`。
3. leader 跑 `skills/oprun/scripts/op_close_post.sh {TID}`：**前置检查**——确认 review verdict PASS + decisions.md 存在本 TID 的 closer append 块（无则 die，防 leader 在 closer 完成前抢跑丢内容）→ git mv 归档 task 目录到 `op_record/tasks/{TID}/`、追加 progress、`tasks_list.json` 标 `status=完成`。

**closer per-task 权限（单条清单）**：仅写 `decisions.md` + 转暂存 issue 到 `issues/`；不跑脚本、不碰 git、不改 status、不 stage、不产 blueprint 提案、不碰 spec、不碰 op_blueprint。脚本（tasks_list.json/git mv/progress）全归 leader。

**decisions.md append 协议（多写者幂等）**：decisions.md 是多写者 append-only 文件（红灯归因/解锁、leader 降级 delta、spec delta、closer 收口、lite leader-close），不冲突的前提是 task 串行（原则 9）。每个 append 块头部带机械标识 `[来源标记 | TID | Round-N | 日期]`——中断/重试/恢复场景按标识判重（同 TID+来源+轮次已存在则跳过），`op_close_post.sh` 按 TID 查块做前置检查（上）。

**per-leaf 收尾（重，Stage 4 验收 PASS 后做一次）**：

1. 所有 task 闭环 → Stage 4 验收 PASS → leader 派 op-closer 做叶子收尾。
2. op-closer 产「blueprint 更新提案」写入 `op_execution/acceptance/{前缀}/blueprint_update.md`，diff 形态覆盖 `op_blueprint/` 全部文档（specs/{feature}.md、architecture.md、domain.md、conventions.md、baselines/ 等）：这条新增、这条修改、这条因被上游覆盖而删除，各附一句理由。只留"现在是什么"，过滤被否方案/临时假设。**含 baselines 合入段**（新增/更新/删除各附 AC 与理由）+ **叶子归档提案**（总述关闭、前缀标记完成——永不复用）。**吸收验收结果**：实现中发现的未预见边界行为、FAIL 修复后的最终形态一并写入。
   - **铁律**：op-closer 对 `op_blueprint/` 无写权限；不碰 git、不改 status、不归档、不盖戳、不 stage。
3. leader 审批 closer 的收尾提案（可全批/部分批/驳回）：
   - **全批** → 执行写入 `op_blueprint/`（specs + baselines 合入）→ 叶子归档（spec 原文入 `op_record/specs/`、acceptance 工作区入 `op_record/acceptance/{前缀}/`）→ commit
   - **部分批** → leader 逐条标采纳/修改/驳回 + 批注，closer 按批注修订提案重提（循环至全批）
   - **驳回** → 回 Stage 4 重验收，或 closer 重写提案

**lite 收口（leader 代劳，无 closer）**：per-task——review PASS 后 leader 直接 `op_close_post`（lite 砍除 op_close_pre，无「收口中」态）→ git commit → append decisions.md（来源标记 **`leader-close`**，与 heavy closer 来源区分，保审计链完整）。per-leaf——Stage 4 PASS 后 leader 归档叶子 + 完结报告，无 blueprint 提案（lite 无真相源）；**归档前跑 P0 阻断检查**（§14.2）。

### 7.5 模型分配

> **spec 编写（含设计探索）归 leader 主会话**，不走 dispatch，继承当前模型——闸门 A 前 `/model` 切 Opus（错误放大系数最大，自身 token 极少）。设计 task 复用 op-implementer（brief 指明"只产方案纸"），派发时仍遵守 OP_*_MODEL 规则：设了按 env 传，未设不传 model。

> 下表是**推荐档**（design 建议）；实际以 `OP_*_MODEL` 环境变量为准，未设则继承主会话当前模型（本节末段）。token 消耗排序：implementer > evaluator > reviewer > closer（定性推断，待实测——evaluator 用 Opus + computer use 单次绝对消耗可能超 implementer 多轮累计）。

| 角色 | 推荐模型 | token 消耗 | 理由 |
|---|---|---|---|
| op-implementer | Sonnet（硬骨头升 Opus，超预算换 1M） | 1（最高） | 多轮代码生成+测试迭代，每 task 一次，频率最高 |
| op-evaluator | Opus | 2 | computer use 截图+多模态判断，单次贵但每叶子 spec 只跑一次，频率低；对抗性思维 |
| op-reviewer | Opus | 3 | 读 spec+diff+report 做双裁决，只读不写，每 task 一次；强审弱错开同档盲区 |
| op-closer | Haiku（最轻量，heavy 独有） | 4（最低） | 读 review+spec+blueprint，写提案+追加 decisions |

模型由环境变量参数化：`OP_IMPLEMENTER_MODEL` / `OP_REVIEWER_MODEL` / `OP_EVALUATOR_MODEL` / `OP_CLOSER_MODEL`。值填 `haiku` / `sonnet` / `opus` 三档之一，对应 `settings.json` 的 `ANTHROPIC_DEFAULT_*_MODEL` 解析出的实际模型。**未设则不传 model 参数，继承主会话当前模型**（用户可用 `/model` 随时切换）。设了哪个就覆盖该 agent 用对应档位。**dispatch 时绝不准自行指定 model**——读 OP_*_MODEL，设了传，没设不传（继承主会话）；推荐档（本节表）仅作用户配置参考，dispatch 不自动用。

---

## 8. 三层验证体系

| 层 | 频率 | 内容 | 管什么 |
|---|---|---|---|
| **task 层** | 每 task，分钟级 | 机器门禁：映射测试+构建+reviewer 双裁决（≤2 轮）。不派 evaluator。证据可信度见原则 7（过渡期自跑自贴，P2 CI 化） | 增量本身对不对 |
| **spec 层** | 每叶子一轮 | ①evaluator **自己操作应用**复现 AC（computer use/独立机器，非看图对照）→固化 PASS 测试→破坏检查→对抗探索。逐 AC 报告+操作轨迹+观察信号。②**hard-pass gate**：每条 AC binary gate，亲自操作观察到 Then 才 PASS，禁止推论式 PASS。③首次验收建基准快照（**结构化信号**进硬门机械断言、**视觉**作锚点由 evaluator 多模态对照），重验重新操作对照基准（lite 裸评退化见 §14） | 用户拿到的能力真能用吗；**集成断没断**；测试有判别力吗 |
| **系统层** | 每晚/合并前 | e2e/ 全集 + domain.md 与生效规格不变量回归；失败自动开 issue | 新东西弄坏旧东西没有；随 spec 数自动增长 |

例外：**技术探针验证**（风险探针 task，每 spec 至多一两个）——implementer 在 report 附探针脚本+输出，leader 只读总报告判断路线是否被证伪，≤10 分钟，**非正式验收、不派 evaluator**（evaluator 仅 Stage 4）。与方案先行一前一后，分别夹住"想错了"和"环境不配合"。

### 8.1 evaluator 访问隔离与刻薄化调教

stock model 默认对 LLM 产出宽容——能发现 bug 但会说服自己"不太严重"放行，或只测成功路径不探边界。隔离防"抄实现"（evaluator 读源码后照着实现写测试→实现错→测试跟着错→一起绿），放水靠以下机制。

**访问隔离（结构单层 + 报告回流，不依赖 hook 拦截）**：

> ⚠️ **前提**：PreToolUse hook 对 subagent 的工具调用 deny 整体失效——evaluator/implementer/reviewer/closer 全是 subagent，按身份分级的 hook 拦截（Read/Grep/Bash/dispatch）在常规运行下就不 work，与 `--dangerously-skip-permissions` 无关（依据见 `op_decisions.md` D18）。结论：隔离硬底线必须是**结构隔离**（源码物理不在 evaluator 文件系统），不靠 hook 拦截，也不靠 frontmatter `tools` 配置级限制。

1. **结构隔离层（硬底线）**：evaluator 在独立 worktree 工作，文件系统只挂载 spec + 生效规格（开工前基线）+ baselines 索引 + 应用启动方式 + 构建产物（Electron 可执行文件 / web dist / 扩展 .zip / 服务二进制）+ `e2e/`。源码 `src/**`、task 目录（`op_execution/tasks/**` + `op_record/tasks/**`）、`op_record/decisions.md` 物理不挂载——结构上不可能读，纪律禁止次要。implementer 分支跑 CI 构建产出打包好的应用供 evaluator 操作（CI 三合一之一，§10.1）。（当前/目标状态见 §0.2 快照表）
   - **非 UI 类（API/DB/CLI/进程）**：构建产物 + 结构化信号（stdout/API 响应/DB 查询/进程日志）直接完整可验。
   - **UI 类**：evaluator 操作构建产物启动的应用（computer use / 独立机器点击），自由探 UI 边界；视觉信号作锚点由 evaluator 多模态对照。
2. **报告回流层（脚本机械组装，保留——不依赖 hook）**：brief 由 `skills/oprun/scripts/op_assemble_eval_brief.sh {前缀}` 生成，内容源全固定路径 cat（工作 spec / 生效规格开工前基线 / baselines 索引 / 应用启动方式），leader 不参与内容生成、只 dispatch。evaluator 作为独立 subagent 只读 brief 文件，leader 主会话上下文（满是 task 交接污染）物理上传不过去——脚本取代纪律性白名单。per-task 阶段不写 op_blueprint，故验收时生效规格天然是开工前版本，隔离防线不被自家归档流程打穿。
3. **dispatch 协议层（advisory 留痕，非拦截）**：leader 调 evaluator 的 prompt 固定模板（"读 {brief_path}，按 brief 执行评估"）。Task matcher 能 fire 但 deny 拦不住 dispatch（依据见 D18），故这层只做**事后审计/留痕**（记 dispatch prompt 日志备查），不主张拦截——内容通道闭环靠第 1 层（源码不在）+ 第 2 层（brief 机械组装），不靠 dispatch 拦截。

**evaluator 读写权（目标由结构 + 脚本共同实现，当前结构层未落地，非 hook 拦截）**：
- **读权**：工作 spec + 生效规格（开工前基线）+ baselines 索引 + 应用启动方式（brief 机械组装提供）+ 构建产物；其余禁止读。目标靠 worktree 不挂载实现（src/tasks/decisions 物理不在）；当前过渡期为纪律约束。
- **写权**：`e2e/`（固化 PASS 测试）+ `op_execution/acceptance/{前缀}/`（baseline 快照 + 验收报告）；其余禁止写（尤其 `op_blueprint/`——per-leaf 由 leader 基于 closer 提案写）。目标靠 worktree 挂载范围 + 写路径限定；当前过渡期为纪律约束。
- **Bash 读源码审计**：advisory 降级——subagent 场景拦不住（依据见 D18），正则拦 `cat/head/tail/git show` 命中 `src|tasks` 仅主会话 leader 场景有效，evaluator subagent 场景无效。可靠方案纯靠第 1 层结构隔离（源码不在文件系统 = 结构上不可能）。

**防放水机制**：
1. **hard-pass gate**（evaluator prompt 内置）：每条 AC binary gate。亲自观察到 Then 子句的用户可观察行为 → PASS。观察不到、推测→FAIL。无法确定→INSUFFICIENT_EVIDENCE。禁止推论式 PASS。
2. **预期失败模式**（spec 可测性契约）：每 AC 附 1 条反例——若 xxx 没做好则 AC 应该 FAIL。evaluator Stage 4 逐条试。零 token 零 agent，写 spec 时顺手加。
3. **破坏检查**（机械）：固化测试必须能红——关功能开关或改断言期望，确认它真的会因错误实现而失败。
4. **刻薄化调教循环**（持续；其中钓鱼审计 **P3 落地**——依赖独立验证环境副本基建，就绪前收敛判据暂缓，防放水靠前三层）：
   - 每次验收后，leader 随机抽 1-2 条 AC 做**二阶判断**：评估深度够不够？是否只测了成功路径？
   - 放水则写**偏差指令**——"AC-N 你只测了提交成功，边界的密码错误转向路径没测。补测后重新判定。"——而非"你上次偏了 12%"。指令型比评分型更有用。
   - 每 5 条偏差指令 → 选 2 条最典型改写为 few-shot 校准样例进 evaluator prompt。旧样例可淘汰。
   - **收敛标准（钓鱼审计，独立于上游质量）**：leader 定期钓鱼——在**独立验证环境副本**里植一个已知 bug（或悄悄关掉某条 AC 的功能开关），看 evaluator 抓不抓得到。**不进 git、不改源分支**（否则破坏 reviewer PASS 证据 + append-only 历史）。测的是判别力本身，不随 implementer 质量起伏（上游越烂 evaluator 越容易找到独有 bug，不能拿它当收敛判据）。连续 3 次钓鱼全中 → 降频抽查（每 5 spec 一次）。漏钓 → 每次全查并补 few-shot 校准。
   - ⚠️ 钓鱼审计依赖「独立验证环境副本」基建（独立构建链路 + 副本管理脚本），P3 与独立验证环境增强一并落地（§12）。

### 8.2 验收基准快照

evaluator 的 Stage 4 评估分两模式，evaluator **自己操作应用**复现 AC（computer use / 后期独立机器点击，非看图对照），基准快照解决两模式间的对齐：

通道选择遵守 opspec 决策树：**CDP 优先，cua 补齐，直驱垫后**。Chromium 渲染层走 CDP；OS 原生壳层/浏览器 chrome/系统对话框走 cua；无 UI 行为走 Bash/HTTP/SQL 直驱。

- **首次评（裸评建基准）**：无 baseline。evaluator 自己操作应用触发 AC 的 Then，对照 spec 推导期望→亲自观察。PASS 须经 hard-pass gate（亲自操作观察到 Then 子句用户可观察行为）+ 破坏检查（固化测试能红）才存基准——基准是"验过能红"的 PASS 证据，锚定它才安全。
- **重验（对照评）**：evaluator 重新操作应用复现同一 AC 路径，**逐步对照 baseline 记录的"该观察到什么" + spec 目标**判断。截图不是比对对象，是"上次操作到这步看到了啥"的参考锚点；结构化信号才是机械比对的硬证据。结果——一致 / REGRESSION（视觉层 advisory 不阻断）/ 预期改进（更新基准，走提案制）。

**baseline 按信号性质分三层**（不按应用类型枚举；任何有外部可观察产物的系统都覆盖——DB/API/进程/消息/定时任务都有，形态由应用暴露的可观察接口决定）：

| 层 | 性质 | 进硬门 | 例子（跨类型） |
|---|---|---|---|
| 结构化/语义 | 可机械断言、可复现、零放水 | ✅ 硬门主体 | DOM/a11y tree；stdout/stderr/exit code；API 请求响应体/状态码/副作用；DB 查询结果/schema/迁移 diff；进程健康检查/日志关键行；消息 payload/顺序；定时任务触发后副作用（DB 状态/输出文件） |
| 视觉 | 多模态对照，evaluator 自己判 | ❌ 不进机械硬门 | 截图——操作到某步"该看到啥"的锚点，由 evaluator 多模态对照（看语义级差异、不被渲染噪声炸；但继承 stock model 放水，靠 §8.1 hard-pass gate+预期失败模式+钓鱼审计兜） |
| 操作 | evaluator 主动 | —（验收手段，非 baseline 内容） | computer use/独立机器点击，按可测性契约的启动方式+测试缝自己驱动到 Then |

**硬门信号确定性优先**：能拿结构化语义（DOM/a11y/stdout/数据）的优先它进硬门；纯视觉信号不进机械硬门（flaky 且放水），交 evaluator 综合判断。**夜跑回归的判定以结构化硬门信号为准，视觉对照不阻断**——非 UI 类 baseline 前期就完整可用，UI 类随 evaluator 操作能力（前期受限/后期独立机器）逐步补全。baselines 另服务 leader 二阶判断（spec Then + 基准信号 + evaluator 证据三样对照抓放水）。

快照写入 `op_execution/acceptance/{前缀}/baselines/`（验收工作区，evaluator 无 op_blueprint 写权限），文件命名映射 AC（`AC-2_login_error.txt`/`.dom.html`/`.png`，按信号类型选扩展）。

**后续重验**（修复 task 回流后的二次验收），读基准的位置按时序分：

- **同 Stage 4 内重验**（首次 FAIL→修 task→二次评，per-leaf 收尾未跑）：读 `op_execution/acceptance/{前缀}/baselines/`——首次评刚存的临时区，此阶段 `op_blueprint/baselines/` 仍为空（合入要等 closer 提案 + leader 审批，§7.4）。
- **跨叶子 / 后续迭代重验**（前叶子已收尾合入）：读 `op_blueprint/baselines/baselines_index.md` 找已有基准快照。

结构化硬门信号不一致且非预期改进 → 直接 FAIL；视觉锚点差异 → evaluator 综合判（advisory，不机械阻断）；预期改进 → 更新基准快照（仍写 `acceptance/{前缀}/baselines/`，走提案制）。

**per-leaf 收尾提案 + leader 审批**（Stage 4 验收 PASS 后，closer 产、leader 批，§7.4）：closer 在 blueprint_update.md 的 baselines 段列出新增/更新/删除（各附 AC 与理由），leader 审批后：

- 新基准从 `acceptance/{前缀}/baselines/`（**临时区，按前缀**）合入 `op_blueprint/baselines/{功能名}/`（**合入区，按功能名**——closer 提案声明工作前缀→功能名映射，工作 spec frontmatter 的 `feature` 字段提供，§5.1）
- 更新 `op_blueprint/baselines/baselines_index.md`（追加/修改对应行）
- 删除的基准从 op_blueprint 移除

**跨功能更新**：一个工作前缀（如 b02_contact）的实现可能合法改变**另一个功能**（如 darkmode）的页面布局，使该功能旧基准"不一致"。验收时 evaluator 标记该功能基准为 NEEDS_UPDATE，closer 收尾提案里附该功能基准更新段（注明被哪个 AC 触发），leader 审批后更新该功能基准。规则：①跨功能更新必须经 closer 提案 + leader 审批，evaluator 不直接改 op_blueprint；②**只动 `op_blueprint/baselines/{功能名}/`**——若该功能的语义契约本身变了（AC/INV 改），另开该功能的 spec 变更子流程，不混在 baseline 更新里；③**既有 e2e 同规则**：需改另一功能既有 e2e 时，走 closer 提案 + leader 审批（§2 改既有 e2e = spec 变更），evaluator 不直接改。

**baselines/baselines_index.md 格式**：

```markdown
# baselines 索引（按功能名，与 specs/ 同键）

## session-management（2026-07-03）
| 文件 | 对应 AC | 类型 | 说明 |
|---|---|---|---|
| session-management/AC-2_login_error.png | AC-2 | 截图 | 错误密码登录提示 |
| session-management/AC-3_cleanup.txt | AC-3 | CLI 输出 | 超时清理日志 |

## darkmode（2026-07-02）
| 文件 | 对应 AC | 类型 | 说明 |
|---|---|---|---|
| darkmode/AC-1_toggle.png | AC-1 | 截图 | 切换前后对比 |
```

**二阶判断素材**：leader 做 evaluator 二阶判断时对照基准——spec 的 Then 文字 + baselines 里的结构化信号/视觉锚点 + evaluator 的操作证据。三样对照，一眼能看出 evaluator 有没有放水（结构化信号没复现 / 截图里错误提示根本没出现就判了 PASS）。

### 8.3 BUG-*/e2e 合法写入通道（方向已定，P2 前置设计项）

git pre-commit 硬锁 `e2e/**`，但存在合法写入路径：evaluator 固化 PASS 测试、leader 转交 BUG-* patch、closer 提案后 leader 改跨功能既有 e2e。git hook 层分不清「谁」在提交（D18 式身份识别困境）。

**已定方向：leader 主会话作唯一 e2e 提交入口。**

- evaluator/implementer **只产 patch/文件，不直接 commit 到 e2e/**——evaluator 固化的 PASS 测试写入自己 worktree 的 e2e/（其 worktree 挂 e2e/，§8.1），由 leader 审后带入主分支提交；implementer 的 BUG-* patch 经 leader 转交（既有模式，§2）——三条合法路径收敛到同一个信任边界。
- pre-commit 白名单机制：leader 提交 e2e 变更时带特定 **commit trailer + 解锁脚本配对**（trailer 由解锁脚本一次性生成、提交后失效，防 trailer 被 agent 抄用）；无配对 trailer 的 e2e 变更一律拒绝。
- **实施顺序铁律：合法入口机制先于硬锁上线**（P2 内排序）——硬锁先行会把 evaluator 锁死；入口先行则过渡期与现状等价（无锁但有审计）。

trailer 生成/校验细节、失败回滚随 P2 实现定；本节锁定的是方向与顺序，防止实现时滑向「evaluator 也被锁死」或「解锁通道形同虚设」两个极端。

---

## 9. issues 机制

**一切"现在不修"的问题必须有档案，禁止只存在于对话里。**

五入口：review 两轮到顶残留；reviewer 范围外发现；evaluator 范围外发现/非阻断可用性建议；系统层夜跑失败；定期体检产出。

```markdown
---
id: I-20260702-01
title: 会话列表 200+ 会话滚动掉帧
source: evaluator 范围外（b01 验收）    # review 两轮到顶 / reviewer 范围外 / evaluator 范围外 / 系统层夜跑 / 定期体检
spec: b01
severity: P0 | P1 | P2 | P3            # P0 阻断上线 / P1 下个 spec 前必修 / P2 排期 / P3 可容忍
tags: [tech-debt]                       # 可选，与 P0-P3 正交
status: open | triaged | converted | closed
converted_to: T05                       # 转 task 后填对应 TID
blocks_merge: true | false              # P0 默认 true；P1 默认 false；用户显式豁免需记 decisions
---
```

铁律：**issue 不直接改代码，转正式 task 后走对应 change type 流程**（fix 带回归测试先红后绿）——issues 是登记处不是免检通道。每叶子收尾时 optriage 一次；**P0 默认阻断**：heavy 阻断闸门 C；lite 无闸门 C 但保留同语义检查——oplrun 叶子归档前扫 issues/，存在 open P0 则停下问用户（豁免记 decisions，§14.2）。P1 默认进入下个 spec 前必修；若用户显式豁免，必须记录 decisions。

---

## 10. 机械护栏（heavy：hooks + 结构 + git 层；lite：无 hook，见 §14）

防"偷偷改绿"按强度排序。⚠️ **前提**：PreToolUse deny 对 subagent 整体失效（依据见 D18），implementer/evaluator 均为 subagent——主防线靠**结构 + git + CI 层**；hook 拦截仅主会话 leader 场景有效，作 advisory。各防线**当前/目标状态一律见 §0.2 快照表**，本节只写机制。

1. **结构隔离 + 行为层保护**（worktree 对称 + git 层）：`e2e/**` 对 implementer 靠 **worktree 对称隔离**——implementer worktree 不挂 `e2e/`（§2）。`BUG-*` 新增属 fix 流程（带归因+解锁审批，§1.2），由 evaluator 验收时写或 implementer 产 patch 由 leader 转交；既有 `e2e/`+`BUG-*` 修改硬锁靠 **git 层**（branch protection + pre-commit/post-receive，在 git 操作层而非 Claude 工具层——绕开 subagent deny 失效；合法写入统一走 leader 唯一入口，§8.3）。归因记 decisions.md。
2. **访问隔离**（结构性，详见 §8.1）：evaluator 仅接触 spec + 构建产物 + baselines——靠 worktree 无 src 实现（非 hook）。
3. **机器证据**（机制分两代，原则 7）：
   - **hook 代（过渡期）**：PostToolUse[src/**] 自动跑受影响测试（仅主会话触发）；subagent 靠 **SubagentStop**（matcher 按 agent_type 过滤）检查 tasks_list.json 状态 + 新鲜测试输出，缺则拒收工——只验"存在"不验"真伪"。hook 脚本开头必检查 stdin 的 `stop_hook_active` 字段防递归；禁 --no-verify。结构层单测明确不设防，由行为层兜住。
   - **CI 代（P2）**：implementer 分支 push 触发 CI 跑测试 + 只读跑 e2e 全集回传结果（§2），reviewer/leader 以 CI 结果为准——证据链脱离被监督者控制。接口定义见 §10.1。
4. **spec 写保护**（git 原生为主）：approved/in_progress 受 git pre-commit 拦 spec 路径变更（走 §5.2 变更子流程）；主会话额外 PreToolUse 拦截；SessionStart 注入前 git diff --quiet 校验，防"好心更新规格"漂移。
5. **警告+留痕**（advisory 兜底，仅主会话生效）：结构层测试编辑按行敏感度——import/setup/调用行静默；expect/assert 行强制说明理由。危险模式：删除/反转 expect、toBe→toContain/正则/>=、timeout/阈值增大、.skip/.only、删测试文件或 it 块、test 文件加 eslint-disable。价值在曝光不在阻止；subagent 场景靠 reviewer 双裁决兜。
6. **定期体检**（每周/CI 异步，独立 CI 任务）：skip/only 计数、timeout 增幅、恒假断言、纯存在性断言 E2E；触碰 INV 模块抽样跑变异测试（杀不死变异体的测试判假重写）。产出落 issues。调度/工具选择随 P3 定。

**防线层 ↔ 实现手段映射**（⚠️ 读者注意：主防线 1/2/3-CI 代**不在** §11 hook 清单里——配齐 hook ≠ 安全；当前安全水位见 §0.2）：

| §10 防线层 | 实现手段 | §11 Claude hook？ |
|---|---|---|
| 1 结构隔离 + 行为层保护 | worktree 对称（无 e2e/）+ git branch protection / pre-commit / post-receive + leader 唯一入口（§8.3） | ❌ 非 hook（结构 + git） |
| 2 访问隔离 | evaluator worktree 无 src（§8.1） | ❌ 非 hook（结构） |
| 3 机器证据 | hook 代：PostToolUse[src/**] + SubagentStop；CI 代：CI 跑测试 + e2e 只读信号（§10.1） | 🟡 hook 代 hook / CI 代 CI |
| 4 spec 写保护 | git pre-commit（拦 spec 路径）+ 主会话 PreToolUse[Edit/Write] | 🟡 半 hook（git + hook） |
| 5 警告留痕 | 主会话 PreToolUse[Edit/Write] 行级敏感度 | ✅ hook（仅主会话，subagent 失效） |
| 6 定期体检 | 独立 CI 任务 | ❌ 非 hook（CI） |

### 10.1 CI 最小接口（P2 基建依赖）

P2 的「CI 证据链三合一」不绑定具体工具（GitHub Actions / GitLab CI / Gitea Actions / Jenkins 均可），满足三个最小接口即可：

1. **分支 push 触发跑测试**：跑项目测试套件，输出结构化结果文件（JSON/JUnit XML），reviewer/leader 读结果文件裁决——对应 per-task 证据 CI 化（原则 7）。
2. **只读跑 e2e**：跑 `e2e/` 全集回传结果，不写代码——对应集成信号回传（§2）。
3. **构建产物生产**：从指定分支构建可运行应用包（Electron 可执行 / web dist / 服务二进制），归档至 evaluator 可取路径——对应 evaluator 隔离验收（§8.1 第 1 层）。

三接口共用一套 CI 配置框架、按 §12 P2 顺序整体交付（用户裁决：不拆独立里程碑）。无远程 CI 的项目可用本地等价物（git post-receive 触发脚本 + 结果文件落固定路径）实现同三接口——"CI"的本质要求只是**在被监督者控制之外执行**。

---

## 11. 插件结构（统一 install.sh 安装 + 按项目 init 选模式）

> **安装模型**（非 Claude Code plugin 市场机制）：用户 git clone 本仓库 → 跑 `bash install.sh` **一次装齐**两模式全部 skill+agent 进 `~/.claude/`（`--set-ophome` 将 OP_HOME 写入 `~/.claude/settings.json` env 段，heavy 需要；只用 lite 可省；`--link` 开发模式软链）→ **按项目 init 选模式**：项目内跑 `/opinit`（heavy：三区骨架 + profile=heavy + hooks 注册）或 `/oplinit`（lite：三区骨架 + profile=lite，不加 hook 不碰项目配置）。同一项目只认一个 profile（§13.1）。skill/agent/hook/脚本通过 `$OP_HOME`（heavy）或 `${OP_SCRIPT_ROOT:-$OP_HOME}` fallback（两版共用 agent，§13.3）引用资源，使用方项目数据走 `$CLAUDE_PROJECT_DIR`（Claude 内置）。废弃 `$CLAUDE_PLUGIN_ROOT` / plugin.json / hooks.json / `claude plugins install` / 手动 export OP_HOME 机制。

```
对外 skill（7）——用户心智模型："装一次、每项目 init 一次、进料、跑、看"
  heavy 入口（4）:
    opinit      heavy 初始化（一次性）：三区骨架 + profile=heavy + hooks 注册
    opintake    需求入口：分拣 → spec（含设计探索+可测性契约）
                → 闸门 A → 自动拆 task → tasks_list.json 写入 `status=待开始` 的 task ══ 终点：task 待开始
    oprun       从 checkpoint 续跑：task 循环 → spec 级验收 → 闸门 C → 归档
                leader 即 controller，被本 skill 驱动
    opstatus    读 tasks_list.json + checkpoint，渲染人类可读状态报告（profile 感知，两版共用）
  lite 入口（3）:
    oplinit     lite 初始化（一次性）：三区骨架 + profile=lite（零侵入：不加 hook、不改项目配置与已有文档）
    oplintake   需求入口：spec + 拆 task + 闸门 A（脚本自包含）
    oplrun      task 循环（leader 自验代 hook）→ Stage 4 裸评 → P0 检查 → 归档

内部 skill（3，两版共享）
  opspec      模板+假设先行+不变量强制+内联设计探索+可测性契约（profile 感知：lite 不要求 blueprint 映射）── opintake 调用
  opred       红灯归因协议 ── implementer/reviewer 共同引用
  optriage    issue 分级与转 task ── leader 收尾时调用（留此不并入 closer：分诊需全局视野）

agents（4，装 ~/.claude/agents/，两版共用文件——环境入口 profile 化 fallback，§13.3）
  op-implementer    读 brief，TDD 实现，写 report（顶部总报告+分轮追加）；
                    设计 task 复用之（brief 指明"只产方案纸"，派发仍按 OP_*_MODEL 规则）
  op-reviewer       双裁决：规格合规 + 测试可信；预置刻薄化调教 + 防借口表（lite 分支内联可写性矩阵最小集）
  op-evaluator      验收方（仅 Stage 4）：智能评估→固化→破坏检查→对抗探索
                    hard-pass gate + 预期失败模式 + 访问隔离（lite 分支：裸评退化，§14）
  op-closer         heavy 独有（lite 不派发）。两段节奏：per-task 仅 append decisions.md；per-leaf 产 blueprint_update.md
                    提案（diff 覆盖 op_blueprint 全部文档 + baselines 合入段 + 叶子归档，吸收验收结果）
                    对 op_blueprint 无写权

hooks（heavy 独有；⚠️ 前提：PreToolUse/PostToolUse deny 对 subagent 整体失效，依据见 D18——下列 hook 仅主会话 leader 场景作 advisory 生效；subagent 隔离靠 worktree 结构 §8.1/§10；lite 零 hook）
  PreToolUse[Edit/Write]   主会话守门（subagent deny 失效）：spec 写保护/op_blueprint 写拦截（仅 leader 审批流程可写）/行级敏感度。e2e/**+BUG-* 主会话 advisory；subagent 靠 worktree 对称目标 + git 层（§10）
  PreToolUse[Task]         dispatch 协议 advisory 留痕：fire 能读 dispatch prompt 记日志，deny 拦不住 launch（依据见 D18）；不作拦截主张
  PostToolUse[src/**]      主会话场景自动跑受影响测试留证据；subagent 场景不触发，靠 SubagentStop 兜（验存在不验真伪，§10 第 3 层）
  SubagentStop             完成门禁（拦 subagent 交工，matcher 按 agent_type 过滤）：检查 tasks_list 状态 + 新鲜测试输出，缺则拒收；脚本开头必检查 stdin 的 stop_hook_active 防递归
  Stop                     leader 收尾门禁：状态 + 新鲜证据
  SessionStart             动态计算注入（checkpoint+tasks_list+git 状态 → 当前 spec/task/下一步，1-2K token）+ approved spec 完整性校验
  PreToolUse[Bash]         主会话拦 --no-verify 及危险 git 操作

scripts/（确定性计算全归 bash，不留给模型；lite 自带副本与差异见 §13.4）
  工作集 tokenize 核算 / review-package 生成 / eval brief 机械组装（op_assemble_eval_brief.sh，lite 裸评简化版）
  / op_close_pre.sh + op_close_post.sh（per-task 收口；lite 砍 op_close_pre，见 §13.4）/ tasks_list 读写 / checkpoint 读写
```

**用户旅程**：`install.sh` 一次（全局）→ 每项目 `/opinit` 或 `/oplinit` 一次 → 每需求 `opintake`/`oplintake "..."` → 批 spec（闸门 A）→ `oprun`/`oplrun` → 中途 `opstatus` → heavy 闸门 C 批"验收报告 + 自决决策表 + P0/P1 issue"；lite 自动完结（P0 检查兜底）。两个命令干活，一个看状态，heavy 人工两次点头 / lite 一次。

---

## 12. 落地路线

**P0（第一周，零基建）**：install.sh + opinit/oplinit 双 init；入口分拣两判定 + spec 模板与命名约定（含可测性契约）+ 闸门 A + 审批即 commit；任务卡 + task=commit；红灯归因、可写性矩阵、review 两轮上限、契约边界规则进 RULES.md/test.md；完成必须贴测试输出；issues 手工登记。**worktree 无 src 工程 spike 启动**（evaluator/implementer worktree 挂载范围 + CI 构建产物生产链路可行性 + **sparse-checkout 跨平台验证**——Linux/macOS/Windows Git Bash/WSL 行为差异；spike 结论反馈 §12 排期，**失败不重设计 P2：备选方案为独立浅 clone 按路径过滤**，同样达成"源码物理不在"）。

**P1（第二周，结构 + git 层）**：e2e/\*\*+BUG-* **worktree 对称隔离**（implementer worktree 不挂 e2e/）+ **git 层保护**（branch protection + pre-commit/post-receive hook，绕过 subagent deny 失效）；证据链；spec 写保护（git 原生为主，主会话 hook advisory）；SessionStart 动态注入 + checkpoint/tasks_list.json；行级敏感度警告（主会话 advisory）；**SubagentStop 完成门禁 + stop_hook_active 防递归**；scripts/ 基础套件（不再写死"五件套"）。**worktree 无 src spike 定型**（P0 起的 spike 在此定型）。

**P2（第三-四周，subagent 层 + CI 证据链）**：先落 **reviewer 双裁决 + closer 两段节奏**（per-task append decisions / per-leaf 验收后提案）+ 循环上限（review ≤2 轮、Stage 4 验收 ≤3 轮）+ issues 自动登记 → **e2e 合法写入入口机制**（§8.3 已定方向：leader 唯一入口 + trailer 配对；**入口先于硬锁上线**）→ **CI 证据链三合一**（接口定义 §10.1，同一套 CI 基建整体交付）：①per-task 证据 CI 化（原则 7）；②implementer 分支 CI 只读跑 e2e 全集回传集成信号（§2）；③evaluator 构建产物生产链路（§8.1 第 1 层）。→ 再落 **op-evaluator 浏览器基建作为自举第一 spec**（Electron/扩展驱动是最高技术风险，顺便用流程验证流程）。⚠️ **自举例外**：evaluator Stage 4 能力正是这条 spec 要造的东西，引导期首 spec 走**人工/降级验收**（leader 对照 spec + 破坏检查手工做），evaluator 上线后才转标准 Stage 4。→ evaluator Stage 4（评估→固化→破坏检查）→ e2e/ 夜跑 → 叶子归档流。**evaluator worktree 无 src 从 P2 起硬要求，用 sparse-checkout 实现**（implementer worktree 排除 `e2e/`、evaluator worktree 排除 `src/**`+task 目录+`decisions.md`；hook 对 subagent 失效，纯靠结构隔离，依据见 D18；spike 失败备选见 P0）+ e2e 既有修改 git 硬锁（入口机制就绪后）+ **防放水前三层（hard-pass gate + 预期失败模式 + 破坏检查）prompt/spec/脚本内置，P2 全上**（几乎免费）。P2 完成后 §0.1 安全增量声明作废、§0.2 快照表更新。

**P3（持续）**：生效规格与 domain.md 沉淀；变异测试体检；issues triage 节奏；模型升级后审视护栏做减法。**独立验证环境增强**（CI 构建产物链路优化 + 独立机器自由操作 UI——P2 worktree 无 src 已是基线，P3 做体验/可靠性增强，非从零交付）+ **钓鱼审计基建**（独立验证环境副本 + 植 bug 脚本，§8.1 第 4 层收敛判据的前置）。**防放水后两层（baseline 对照评 + 刻薄化调教循环/钓鱼审计）等前三层上线后观察到真实放水案例再加**——基准维护与二阶判断是持续运营成本，未验证假设前不预付。注意：**P2 已建 baseline 快照**（evaluator 固化 PASS 时存），P3 才做系统化对照评/钓鱼调教，不是 baseline 本身 P3 才有。

---

## 13. 两版共存架构（环境集成层）

系统切两层：

- **执行内核**（干什么、判定标准）：spec、AC/不变量、TDD、双裁决、验收对抗、状态机、Agent 职责——**与模式无关，共享**。
- **环境集成层**（怎么装、怎么校验、脚本怎么定位）：安装、证据校验、脚本寻址、blueprint 来源、闸门数、收口角色——**heavy/lite 全部差异收敛在此**。

差异面压缩到环境集成层，两版最大复用，Agent 与 spec 逻辑单点维护，同步演进。

**两版差异面（收敛后 6 点）**：

| 维度 | heavy | lite |
|---|---|---|
| 项目 init | `/opinit`：三区骨架 + profile=heavy + hook 注册 + 归档旧文档 + 重构 CLAUDE.md | `/oplinit`：三区骨架 + profile=lite（不加 hook、不碰项目配置与已有文档） |
| 证据校验 | hook 机器强制（PostToolUse/SubagentStop，advisory 边界见 §10 第 3 层） | leader 每轮亲自验证（§14.1 上下文账 + 水位检查） |
| 脚本/环境入口定位 | `$OP_HOME` | `${OP_SCRIPT_ROOT:-$OP_HOME}` fallback，lite dispatch 注入 skill 自带目录（§13.3） |
| blueprint 来源 | 提炼用户 CLAUDE.md/docs/代码 | 无 blueprint 真相源，只建自己的树（连锁退化见 §14） |
| 闸门 | A + C 两处人工批复 | 默认 A 一处 + P0 阻断检查（§14.2）；异常仍升级人裁 |
| 收口角色 | op-closer 独立 Agent | leader 代劳（减 closer） |

**其余全部共享**：三执行 agent 职责、spec 模板、双裁决、Stage 4 验收+对抗+E2E、状态机（lite 去"收口中"态）、depends_on、compact 恢复。

**lite 的诚实定位**：lite 是 **degraded mode**，不是 heavy 同等安全版——无 hook、无 worktree 隔离目标、无 baseline 对照、evaluator 裸评。用它换零侵入。但按 §0.1，P2 前两版防篡改水位实际接近；P2 后 heavy 拉开差距。

**lite→heavy 迁移不是切 profile。** 迁移 = 显式重初始化，最小步骤：①跑 `/opinit`（hook 注册 + blueprint 骨架 + profile 改写，需处理 profile 互斥 die——用户显式确认迁移意图后清 profile 重写）；②blueprint 补建（blueprint-generator 从已有代码 + `op_execution/specs/` 归档提炼生效规格）；③已归档 spec 的 `feature` 字段映射校验（lite 下仅前缀标识，迁移后须对齐功能名）；④关键叶子 E2E 重跑 + 按 heavy 标准补 baseline（lite 期无 baseline，跨迭代回归从迁移点起算）。有代价，不可无缝——文档不给「随时可升」错觉。

### 13.1 profile 机制

项目首次 init 时落 `docs/omni_powers/profile`（单行值 `heavy` | `lite`）。

作用：

- **compact 恢复**：leader 读 profile 判断走哪套编排、是否期待 hook、脚本怎么寻址。**compact 恢复第一步先读它**（RULES.md）。
- **共享脚本 / opstatus**：读 profile 决定环境入口寻址（`$OP_HOME` 还是 dispatch 注入）与是否有 closer/闸门 C 阶段。
- **互斥保护**：同一项目只认一个 profile，防混跑污染状态。

判定表：

| 场景 | 动作 |
|---|---|
| `/oplinit` 首次运行，无 profile | 写 `profile=lite` |
| `/opinit` 首次运行，无 profile | 写 `profile=heavy` |
| 已有 profile 与当前 skill 模式冲突 | die 提示，不混跑（不清场、不转换，要求用户显式处理） |
| 已有 `docs/omni_powers/` 但无 profile | 检测 heavy 残留（探 op_blueprint 有无实体内容 / `$OP_HOME`）再定 lite/die |

入口校验：opintake/oprun/oplintake/oplrun 均在步骤零校验 profile，模式不符则 die。

### 13.2 零侵入的精确边界（lite）

lite「零侵入」= **不侵入用户项目**：不加项目 hook + 不改 Claude Code 配置 + 不改用户项目已有文件。全局 `~/.claude` 的一次性全量安装（install.sh）是用户主动配置，不算侵入。允许的写入：

| 允许写入 | 说明 |
|---|---|
| `~/.claude/skills/`（install.sh，两模式全部 skill） | 新增，不覆盖用户已有 |
| `~/.claude/agents/op-*.md`（install.sh） | 四角色 agent 定义（新增，供 `subagent_type` 派发） |
| 项目内 `docs/omni_powers/` + `e2e/`（oplinit / 运行期） | 新增独立子目录，不改用户已有文档；项目已有 `e2e/` 时共处（不覆盖，按前缀分子目录） |

lite 禁止写入：

| 禁止 | 原因 |
|---|---|
| `~/.claude/settings.json` | lite 不需要 hook、不需要 `$OP_HOME` env（heavy 用户跑 `install.sh --set-ophome` 才写） |
| 用户项目已有文件（CLAUDE.md/README/docs/*） | 不归档、不重构、不提炼作 blueprint |

### 13.3 环境入口 profile 化（两版共用一份 agent 文件）

**问题**：agent 定义里的环境检查入口硬编码 `$OP_HOME`（`op_check_env.sh` / `op_coder_check.sh` / `op_assemble_eval_brief.sh` 共 6 处），lite 无 env 可依。

**解法：fallback 变量写法**（已落地）：

```bash
# heavy 下 OP_SCRIPT_ROOT 未设 → 走 $OP_HOME；lite dispatch 注入 → 走 skill 自带目录
bash "${OP_SCRIPT_ROOT:-$OP_HOME}/scripts/op_check_env.sh"
```

- **变量约定**：`OP_SCRIPT_ROOT`（脚本根）+ `OP_PROFILE`（`heavy`|`lite`）。leader dispatch prompt 里注入，agent 读它。
- **heavy 现状不动**：`OP_SCRIPT_ROOT` 未注入时 fallback 到 `$OP_HOME`，heavy 行为零变化。
- **lite 自带脚本**：`OP_SCRIPT_ROOT` 指向 skill 自身目录（`${BASH_SOURCE[0]}` 自探测）。
- 实现细节：agent 内 `op_script()` 双路径 resolver（heavy 脚本分 `scripts/` 与 `skills/oprun/scripts/` 两目录、lite 平铺，单行 fallback 不够）。
- **前置探活（避免延迟失败）**：三执行 agent 在 resolver 后立即校验根目录存在——`${OP_SCRIPT_ROOT:-$OP_HOME}` 解析结果为空或目录不存在 → agent 输出明确 FATAL 并停在首个脚本调用前，不在后续零散脚本调用处才失败（错误定位成本高）。
- agent 派发机制两版相同：`subagent_type: "op-implementer"`。**agent markdown 是静态文件，靠 fallback 写法两版共用一份**。

### 13.4 lite 脚本自包含（方案 B）

lite 与 omni_powers 仓库物理分离（skill 装 `~/.claude/skills/`，仓库在别处），`$OP_HOME` 不存在 → **lite skill 自带所需脚本**到 skill 目录内：

```
~/.claude/skills/oplinit/
├── SKILL.md
└── scripts/          # op_check_env(仅jq/git) + oplinit_skeleton（三区骨架内联模板 + profile=lite + 互斥 die）
~/.claude/skills/oplintake/
├── SKILL.md
└── scripts/          # op_check_env(仅jq/git)
~/.claude/skills/oplrun/
├── SKILL.md
└── scripts/          # lite 脚本集（下表）
```

**lite 脚本集**（对照 oplrun 全链核出）：

| heavy 脚本 | lite 自带? | lite 版差异 |
|---|:-:|---|
| op_jq.sh | ✓ | 无（读相对路径 tasks_list.json） |
| op_status.sh | ✓ | 状态枚举去「收口中」 |
| op_coder_check.sh | ✓ | 环境入口 fallback 变量 |
| op_read_verdict.sh | ✓ | 无 |
| op_close_pre.sh | ✗ | **lite 砍除**（唯一职责是标「收口中」，lite 无此态——review PASS 后直接 op_close_post） |
| op_close_post.sh | ✓ | 无「收口中」前置、兄弟脚本 `${BASH_SOURCE}` 自探测（无 OP_HOME） |
| op_check_env.sh | ✓ | 只校验 jq/git（无 OP_HOME 段） |
| op_assemble_eval_brief.sh | ✓ | 裸评简化：跳基线/baselines 段（§14.3） |
| close_check.sh | ✓ | 完成态定义随状态机改 |
| op_new_task.sh | ✗ | lite 拆 task 用 jq `.tasks += [{...}]` 直接写 |
| test_lock.sh | ✗ | spec 写保护降级为约定（§14.1），不含 |
| op_checkpoint.sh | ✗ | leader 内联，不单列 |

**副本同步**：`scripts/build_lite.sh` 校验 lite 副本与 heavy 源一致（逐字节类 diff + 改造类标记断言 + 三份 op_check_env 互检），`--sync` 修复，避免手抄漂移。

其他实现补充（有意收窄，落地已验证）：骨架模板由 `oplinit_skeleton.sh` 内联生成（无独立 templates/）；oplintake spec 模板内联进 SKILL.md（opspec 留 profile 感知段供直接调用兜底）；oplinit 写 `docs/omni_powers/.gitignore`（忽略 `*.lock`，只在自己子目录内）；oplrun 收口前 `git add {workset}`（lite 无 worktree，不 add 会丢代码出 commit）。

---

## 14. lite 工作流与退化边界

### 14.0 lite 状态机

沿用 heavy 的 task 状态机，**仅删「收口中」态**（收口在 lite 是 leader 瞬时操作，不占 task 态）：

```
待规划 → 待开始 → 进行中 → 审阅中 → 完成
  ↓             ↑ FAIL(≤2轮)
挂起 ───────────┘
   2轮FAIL → 阻塞（下游跳过）
```

- 不新增「验收中」task 态。Stage 4 是 **spec 级阶段活动**（整份 spec 所有 task 闭环后跑一次），不是 per-task 状态——与 heavy 模型一致。
- 状态语义（含义/blocked_by/阻塞传播/挂起/回滚）完全复用 RULES.md，lite 只在 profile 分叉段声明「无收口中态」。
- **因果链一句话**：删「收口中」态 → 砍 `op_close_pre.sh`（其唯一职责是标此态，§13.4）→ 收口变 leader 瞬时操作（review PASS 直接 op_close_post）。三者是同一决策的三面，改任一处须同步另两处。

**lite 入口流程**（与 §4 同构）：

```
/oplintake "<需求>"：
⓪ 校验 profile=lite（非则 die；骨架职责在 /oplinit，与 heavy opinit 对称）
① spec 编写：leader 主会话按模板生成 op_execution/specs/{前缀}.md（AC + 不变量 + 内联设计探索）
② 拆 task 写 op_execution/tasks_list.json（depends_on 机读）
③ 【闸门 A】呈报 spec + task 拆分给用户审（预算同 heavy：15-30 分钟/叶子，原则 11）
   人批 → status: approved（无 git 写保护 hook；靠约定 + git diff 可回溯）
终点：task status=待开始，写 leader_checkpoint.md，交给 /oplrun

/oplrun：
读 profile（校验 lite）+ leader_checkpoint.md + jq 查 tasks_list.json
循环（每 task，选 depends_on 全完成、ID 最小，严格串行）：
  派 op-implementer → TDD → tasks/{TID}/report.md
  leader 亲自验证（§14.1）：读 report evidence 路径 + 跑测试命令读 verdict + 读关键 diff hunk
  派 op-reviewer → 双裁决 → tasks/{TID}/review.md（末行 verdict）
    ├─ FAIL 第1轮 → 回 implementer fail 模式修
    ├─ FAIL 第2轮 → 阻塞(quality)，写 issues，下游跳过（异常人裁）
    └─ PASS → leader 收口（§7.4 lite 段）
全 task 闭环 → Stage 4：派 op-evaluator（裸评退化，§14.3）→ E2E + AC逐条 + 破坏检查 + 对抗探索
  ├─ FAIL(≤3轮) → 修复 task 回流重验（到顶异常人裁）
  └─ PASS → 【P0 阻断检查，§14.2】→ leader 归档叶子 + 完结报告（无闸门 C）
```

### 14.1 无 hook 的替代与 leader 上下文账

**纪律替代**：

| heavy hook 职责 | lite 替代 |
|---|---|
| 校验"新鲜机器证据"防作弊 | leader 收 subagent 返回后**亲自跑测试命令 + 读关键 diff** 再判（注意：这比 heavy SubagentStop 强——leader 亲跑是独立复核，不是验文件存在） |
| `current_task` 注入 + SubagentStop 校验 | leader 循环内自持 task 指针，写 leader_checkpoint.md |
| spec 写保护（拦截未授权改动） | spec 由 leader 单点掌控；降级为约定 + git diff 可回溯（无强制拦截） |

**leader 自验的上下文账**：heavy 用 hook + subagent 隔离把 diff/测试输出挡在 leader 主会话外；lite leader 每 task 读 report + 跑测试 + 读 diff，N 个 task 后上下文膨胀。缓解策略（写入 oplrun 契约）：

1. **证据走文件**：implementer 把测试输出写 `tasks/{TID}/report.md` 的 evidence 段，leader **只读 verdict 行 + evidence 路径**，不把全量测试输出纳入上下文。
2. **只读关键 hunk**：leader 读 diff 时用 `git diff --stat` + 定向读改动核心 hunk，不全量 `git diff`。
3. **量级适配**：lite 更适合中小 task 量（单 spec ≤ ~8 task）；超大需求建议走 heavy。
4. **上下文水位流程门（非提示，硬约束）**：oplrun 每 N task（如 3）自检 leader 上下文水位——逼近阈值时第一次提示（`/compact` 或建议转 heavy）；**连续 2 次超阈值则升级为流程门：暂停循环**，呈报用户三选一（compact 后续跑 / 拆当前 spec 回 oplintake / 显式承担风险续跑——选三须记 decisions，来源标记 leader-close）。提示不阻断会滑入静默失能，流程门强制人在环。（heavy leader 不亲读证据、靠 checkpoint+compact 容错，故水位是 lite 独有硬约束）

### 14.2 lite 的 P0 阻断检查（补闸门 C 缺失的安全语义）

heavy 里 P0 issue 默认阻断闸门 C（§9）；lite 无闸门 C，若无补偿则 evaluator 范围外发现的 P0 会随自动归档静默放行——安全语义丢失。**补偿机制（一行检查，语义值钱）**：

- oplrun 在 Stage 4 PASS 后、叶子归档前，扫 `op_execution/issues/`：存在 `severity: P0` 且 `status: open` 的 issue → **停下呈报用户**（issue 清单 + 阻断原因），用户三选一：转修复 task 回流 / 显式豁免（记 decisions，来源标记 leader-close）/ 中止归档。
- 无 open P0 → 照常自动归档完结。P1 不阻断（与 heavy 同语义：下个 spec 前必修，进 checkpoint 提醒）。

### 14.3 blueprint 缺失的连锁退化矩阵

lite 无 blueprint 真相源，不只影响 closer——逐角色退化：

| 消费者 | 缺失的 blueprint 部件 | lite 退化形态 |
|---|---|---|
| op-implementer | architecture.md / conventions.md（定向包） | 无架构地图/编码规范，只能靠 spec 单文档 + 现有代码归纳 |
| op-reviewer | test.md（可写性矩阵、危险模式清单） | 判定依据内联进 reviewer lite 分支 prompt（从 §2 蒸馏最小集） |
| op-evaluator | specs/{feature}.md 生效规格 + baselines/ | **裸评退化**（下） |
| leader | baselines_index.md | 无二阶判断对照素材 |

**evaluator 裸评退化**（用户已确认接受）——lite 分支显式定义：

- **能做**：逐 AC 评估、跑/写 E2E、破坏检查、对抗探索（首次评）。
- **不能做**：worktree 结构隔离（evaluator 能读到 src/ 与 task 目录，防"抄实现"底线失效）、baseline 对照评、跨迭代回归检测。
- **实现**：evaluator.md 加 profile=lite 分支，跳过基准模式判定 / 存基准 / 重验对照逻辑（heavy 下是活代码，lite 下 skip）。
- **brief 组装 lite 形态**：lite 自带简化版 `op_assemble_eval_brief.sh`——只 cat 工作 spec + AC + 启动方式，跳过基线/baselines 段。不整段 skip（evaluator 仍需 brief），是简化。

**op_blueprint/ 占位规则**：lite 下 op_blueprint/ 为空壳，仅为路径兼容（避免共享脚本找不到目录）。**oplinit 在其中落一个单行 README**：「lite 模式：此目录非契约源，规格读 `op_execution/specs/`」——防 agent 把「目录为空」误推断为「项目无约定」，比纯提示词明令便宜且落在被读取现场。implementer 定向包、reviewer 判定、evaluator 生效规格/eval_brief **一律不读 op_blueprint/**。

**opspec profile 参数**：heavy 可引用 op_blueprint/specs 映射；lite 只生成 op_execution/specs/{前缀}.md 单份，不要求 blueprint 映射。`feature` frontmatter 字段 lite 保留但仅作前缀标识（§5.1），便于未来 lite→heavy 迁移。

---

## 15. lite 落地状态

> **落地状态（2026-07-06）**：核心链路已实现并端到端验证。唯一安装脚本 `install.sh`（heavy+lite 共用，10 skill + 4 agent，可选 --set-ophome）；lite 三入口 `oplinit`/`oplintake`/`oplrun`；三执行 agent profile 化 fallback + lite 分支；Stage 4 裸评接入；RULES profile 分叉段；CLAUDE.md 双模式入口；`build_lite.sh` 漂移校验；profile 互斥双向落地。验证覆盖：骨架/状态流转/profile 互斥/resolver 双版/收口归档链/Stage4 brief/settings 合并。
>
> **本合并版 + 审阅四轮处置后的新增决策（2026-07-07，随 §12 排期 / 待落项见 §0.2 快照表）**：per-task 证据 CI 化（原则 7，P2）；e2e 只读信号回传（§2，P2）；task 严格串行、任务卡去「可并行」字段（原则 9，文档生效）；闸门 A 15-30 分钟/叶子（原则 11，文档生效）；spec 前缀双字母编码（§3，文档生效）；decisions.md append 幂等标识 + `op_close_post` 前置检查（§7.4，待落脚本）；spec 变更子流程补定义（§5.2，文档生效）；§8.3 e2e 合法写入方向敲定 leader 唯一入口（§8.3，P2 前置）；CI 最小接口三接口（§10.1，P2）；worktree spike 备选方案（§12 P0，P2）；lite 水位流程门（§14.1，待落 oplrun）；lite P0 阻断检查（§14.2，待落 oplrun）；op_blueprint 占位 README（§14.3，待落 oplinit）；lite→heavy 迁移声明（§13，文档生效）；OP_SCRIPT_ROOT 前置探活（§13.3，待落 agent）。
>
> **决策明细**见 `docs/op_decisions.md` D20（合并版）+ D21（审阅处置）；审阅原文见 `docs/review/`；三轮 lite 审阅处置史见 `docs/archive/omni_powers_lite_design.md` §15。
