# Omni Powers: Claude Code 全流程开发方案设计

> **定位**：设计档案——系统怎么设计及为什么。不进运行时上下文。运行时操作见 `$OP_HOME/RULES.md`，agent 行为见 `agents/*.md`，skill 流程见 `skills/*/SKILL.md`。
>
> **两模式一份设计**：heavy（全量：task 分支拓扑 + merge gate + worktree 隔离 + blueprint 真相源 + hook advisory）与 lite（零侵入：不加 hook、无分支拓扑、不改用户项目已有文件）。执行内核（spec/验收标准/不变量/TDD/双裁决/验收/状态机/角色职责）两版共享；差异收敛在环境集成层（§5）。安装统一走仓库 `install.sh` 一次装齐 `~/.claude/`，**按项目 init 选模式**：`/opinit`=heavy，`/oplinit`=lite，同一项目只认一个 profile。

---

## 0. 设计原则

**两个核心病灶**（本系统一切机制都在治这两点）：测试变绿 ≠ 功能正确；agent 不理解功能背后的语义。

1. **规格是唯一契约。** 实现、测试、验收三方对着同一份人审过的工作 spec 干活，切断同源污染。
2. **两层规格，资产与工单分离。** 生效规格（op_blueprint/specs/）回答"系统是什么"，只收经实现和验收淬炼的结论；工作 spec（op_execution/specs/）回答"这次做什么"，用完归档。前者由后者喂养。（lite 无 blueprint 真相源，工作 spec 兼任生效规格，§5）
3. **能在 spec 期解决的难题，不留给执行期。** 方案设计在写 spec 时内联完成，人工触点合并进闸门 A；执行期不设新的人工阻塞点。
4. **契约边界规则：决策是否需要进 spec 文本。** 不进 spec 的小决策（选库/选内部算法/选路径）→ 直接做，不记录；需要进 spec 的决策 → leader 改 task spec（变更子流程）+ 记 decisions.md（spec-delta）+ 事后报告（闸门 C）。执行期所有决策 agent 自决，不阻塞等人（§2.4）。
5. **不变量优先于场景。** 工作 spec 强制填不变量，填不出即视为没理解需求。
6. **测试按耦合物分层，按保护物设防。** 行为层（E2E+回归）是"行为不变"的法官，永久锁定（归 evaluator；implementer worktree 不挂 `e2e/` 防无意耦合，merge gate 拦其变更入主分支——§0.1/§3.4；BUG-* 由 evaluator/leader 落盘，§3.1/§3.3）；结构层（单测）随代码结构机械适配，断言是红线。只保证有一层防篡改且足以拦住 bug。
7. **证据由机器产出——"机器"必须在被监督者控制之外。** hook 自动跑测试对 subagent 已失效——Claude Code 的 subagent（Agent 工具派发的 agent）不触发 PreToolUse/PostToolUse，deny 整体失效（bypass 与否结论一致）。implementer 的测试输出是它自己跑 Bash 产生、自己写进 report 的，可伪造（SubagentStop 只验"存在新鲜输出文件"，验不了真伪）。可信度靠 reviewer 双裁决 + evaluator 独立验收 + merge gate（P1 起，受保护路径变更进不了主分支，§3.4）兜底。不变核心：bash 先算状态，LLM 再决策——凡确定性计算（工作集清单核算/状态判定/diff 打包）都交脚本，不留给模型。
8. **plan 是分布式信息，不是文档。** 顺序依赖住 tasks_list.json（机读）+ leader_checkpoint（人扫）；跨 task 技术决策复制进每个相关 spec（自足）；接口契约以代码形式先提交（编译器强制，严格强于文档签名）；工作集（文件级清单）住 tasks_list.json（merge gate 越界检查的参考）。独立 plan 文档只会是这四处的过期复印件。
9. **task 即 commit；粒度沿低耦合缝隙切。** 沿层/模块/数据流阶段的缝隙切；"task 即 commit"由 leader squash-merge 兑现（§3.4）。**task 严格串行执行**——tasks_list 的 depends_on 只记录依赖事实，不授权并行：多 implementer 并行意味着共享流程文件（decisions.md/issues/tasks_list——单一物理副本直写主 repo，§3.4）并发写入 + 多 task 分支同时回流 merge，冲突协议未建前不放开。模型/基建升级后若开并行，先解决共享文件写入协议再放开。
10. **循环必须有上限，发现必须有去处。** review/fix 最多两轮；修不完的和范围外的统一落 issues。
11. **正常路径下，人只出现在两个位置：闸门 A（事前审 spec，含技术决策与可测性契约）、事后报告（验收报告 + spec 变更决策表 + P0/P1 issue，一次 oprun 结束呈报；heavy/lite 同步，A18）。** 异常路径仍有人裁：review 两轮到顶升级、验收三轮到顶升级、阻塞 issue 转 task——这些是异常出口，不是常设闸门。闸门 A 预算 **15-30 分钟/需求**（一次 intake 拆出的全部 task spec 一次呈审）：spec 含不变量(INV)+验收标准(AC)+边界+三类技术决策+可测性契约，是全系统唯一质量单点，5-10 分钟审不完只会橡皮图章——spec 错则三方全错且无人能拦。事后报告由 leader 自审 closer 提案后生成（执行中不打扰用户；自审深度：快速审只读自然语言，>5 条变更或跨功能 baseline/e2e 升级详细审）；人不审文件/函数清单——那是杠杆错位。
12. **护栏按需付费，定期做减法。** 每个组件都是对"当前模型做不到"的假设，模型升级后重新审视。

### 0.1 安全增量的诚实声明

**sparse-checkout 的能力边界（全文隔离声明的前提）**：worktree 共享主 repo 的 object store，`git show HEAD:src/x`、`git log -p -- src/`、`git sparse-checkout add src` 单命令即可读到被排除路径——sparse-checkout 只控制工作目录物化，**不是访问控制**。因此它的定位是**防无意耦合**（agent 正常读文件流程碰不到被排除路径，足以防"顺手抄实现/顺手改 e2e"），**不防有意规避**。全文凡称"结构隔离"均指此 advisory 级别；真正的硬底线是两条：

- **写入硬底线（P1，真正的生效点）**：leader 主会话是主分支唯一写入口，merge 前跑机械校验——受保护路径 diff 必须为零（merge gate，§3.4）。implementer 在自己分支内怎么折腾都行，进主分支必过此门；检查点在被监督者控制之外。
heavy 防篡改两层现状：implementer 无 e2e（sparse-checkout，advisory 防无意耦合；硬拦靠 merge gate）、evaluator 无 src（sparse-checkout 排除 src/tasks/decisions，advisory 防无意耦合）。可信度靠 reviewer 双裁决 + evaluator 独立验收 + merge gate（P1 起）兜底。git < 2.25 或不开 worktree 模式时，sparse-checkout 层退化为纯纪律（脚本 WARN），merge gate 不受影响。

**信任根声明**：merge gate 是 leader 主会话跑的脚本——决定跑不跑、解读结果、执行 merge 的主体都是 leader（LLM）。本系统不在 leader 身上再加机械拦截（e2e trailer 自锁是 leader commit 侧的特例防线，§2.5，未推广到所有 merge）。**硬底线之"硬"以 leader 执行协议为前提**；leader 失守（被上下文注入诱导跳过 gate / 无视 REJECT 直接 merge）的检测靠 **git 历史审计 + 闸门 A 人审 + 事后报告**，不靠机械拦截。这是本系统信任根的诚实定位——总得有一个信任根，这里就是 leader + 闸门 A（事前 spec 人审）+ trailer 机械证据（§3.3，事后；当前 `op_trailer_unlock.sh` 仅覆盖 e2e 提交，gate trailer 随 P1 merge gate 落地，D12）。

**防线定位原则（针对 subagent 产物）**：所有针对 subagent（implementer/evaluator）产物的验证一律放在**子代理返回主会话后**——leader 亲验（跑测试命令 + 读关键 diff）+ reviewer 双裁决 + merge gate 机械校验，**不依赖子代理内部是否触发 hook**。"hook 对 subagent 失效"不是缺陷，是 design 选择"返回后验证而非子代理内拦截"的原因；advisory hook（行级敏感度等）只作主会话 leader 场景的曝光兜底。子代理内 hook 生效与否不影响安全模型——防线在主会话侧，无需实测子代理内 hook 行为。

交付状态见 §0.2 能力矩阵与 §4.2 分阶段路径。

### 0.2 能力矩阵（防线实现状态单一真相源）

各防线的实现手段与交付阶段**只在此表维护**；正文各节只写机制，状态一律查此表。§4.2 阶段清单描述"每阶段交付什么"，条目状态以本表为准，两处不重复标注。

| 防线/能力 | 实现手段 | 交付阶段 | 级别 | 未落地失效后果 |
|---|---|---|---|---|
| implementer e2e 排除 | worktree sparse-checkout 不挂 `e2e/`（`op_worktree_setup.sh dev`） | **已落地**（git 2.25+） | advisory（防无意耦合，§0.1） | implementer 顺手改行为层测试 |
| evaluator src 排除 | worktree sparse-checkout 无 `src/**`+task 目录+decisions.md（`op_worktree_setup.sh eval`） | **已落地**（git 2.25+） | advisory（防无意耦合，§0.1） | evaluator 顺手抄实现 |
| **merge gate（写入硬底线）** | leader 唯一主分支写入口 + **白名单**机械校验（task 分支允许触碰 = workset ∪ `tasks/{TID}/report.md` ∪ 结构层测试路径，其余 REJECT，§3.4）+ review verdict 读主分支 review.md 末行 | P1 | 硬（被监督者之外，信任根声明 §0.1） | 受保护路径变更混入主分支 |
| e2e/BUG-* 合法写入通道（leader trailer 自锁） | leader 唯一提交入口 + commit trailer 配对（§2.5） | P1 | 硬 | leader 被诱导误提交篡改行为层测试 |
| spec 写保护 | git pre-commit + 主会话 PreToolUse + merge gate 覆盖 | P1（已达目标） | 硬（merge gate 起） | 规格静默漂移 |
| reviewer 双裁决 | 提示词 + 流程（不依赖 hook） | P0（已达目标） | 纪律 | 规格偏航/测试不可信漏检 |
| SubagentStop 完成门禁 | hook 验状态 + 新鲜输出存在（防递归见 §3.3） | P1 | advisory（验存在不验真伪） | subagent 空手交工 |
| /oprun 启动注入 | checkpoint+tasks_list+git 状态（/oprun 触发读取重建，非每会话强灌） | P1 | — | compact 后手动 /oprun 恢复（spec 漂移复查同在 /oprun 启动跑） |
| scripts/ 基础套件 | 工作集清单核算/eval brief 组装/收口脚本等（§4.1） | P1 | — | 确定性计算留给模型 |
| evaluator baseline 对照评 | 对照评 | P2 | — | 跨迭代回归漏检 |
| 系统层夜跑回归 | 独立 CI 任务（e2e 全集 + domain 不变量 + 测试质量体检） | P2+/P3 | — | 新 task 弄坏旧功能漏检（evaluator 只验单 task AC，不重跑历史） |
| closer gate（机械校验）| `op_closer_gate.sh` 路径白名单校验（越界 `git checkout` 撤销，§2.6） | **已落地**（D3） | 硬 | closer 越界写入漏检（closer 权限最大约束最少） |
| lite P0 处置（A18）| oplrun 结束报告汇总 open P0，不事中阻断（§5.8）| 随 lite 完善 | — | P0 静默放行（事后报告 + 中断权补救） |

过渡期全线通用兜底：reviewer 双裁决 + evaluator 独立验收 + merge gate（P1 起）。

---

## 1. 目录结构：omni_powers 三区制（两版共用布局）

**op_blueprint = "应该是什么"（稳定契约）；op_execution = "现在在干什么"（只放活的东西）；op_record = "发生过什么"（append-only）。** lite 复用同一布局，op_blueprint 仅占位（§5.7）。

```
<project>/
├── CLAUDE.md                        # heavy：请求用户批准启用 omni_powers，批准后新增一行执行 docs/omni_powers/index.md；**lite 不改此文件，靠 docs/omni_powers/profile 发现（§5.2）**
├── e2e/                             # 【代码，永久资产】**路径由 config.OP_E2E_DIR 定**（⚠️ **规划中——config parser 未落地，当前所有 `e2e/**` 规则硬编码、OP_E2E_DIR 不生效，D4-B**）——init 时问用户放哪，默认 heavy=顶层 `e2e/`、lite=`docs/omni_powers/e2e/`；**用户项目已有顶层 e2e/ 时 init 探测提示**（迁移子目录 / 显式豁免进保护 / 换路径），避免用户既有测试被锁
├── docs/omni_powers/               # 三区根目录（op_blueprint/op_execution/op_record）
│   ├── README.md                    # 给人看的
│   ├── index.md                     # 给 agent 看的目录页（heavy: SessionStart 注入其摘要 → /oprun 启动读其摘要）
│   ├── profile                      # 单行值 heavy | lite（§5.2，compact 恢复第一步先读它）
│   ├── config                       # 项目级路径配置：`OP_E2E_DIR=...`（相对项目根），脚本读此不硬编码（⚠️ 规划中，parser 未落地，D4-B）；init 时由用户定
│   ├── op_blueprint/                # heavy 真相源；lite 占位空壳（见 §5.7）
│   │   ├── prd.md                   # 产品级需求纪要（opinit blueprint-generator 初始化，需求澄清流程维护；各需求总意图）
│   │   ├── architecture.md          # 架构地图：分层、模块边界、跨模块契约（定向包主体）
│   │   ├── conventions.md           # 项目约定：编码/命名/提交/目录规范
│   │   ├── domain.md                # 领域模型 + 跨功能全局不变量（如"时间戳统一 UTC"）
│   │   ├── test.md                  # 测试宪章：可写性矩阵、红灯归因协议、危险模式清单
│   │   ├── spec_index.md            # specs/ 目录索引：功能清单 + 一句话说明 + 文件指引
│   │   ├── baselines/                # 【基准】各功能验收基准快照（leader 基于 closer 提案审批写入）
│   │   │   ├── baselines_index.md    #   基准文件索引：功能名→验收标准→文件 + 更新说明
│   │   │   ├── session-management/   #   按功能名分目录（与生效 specs/ 同键）
│   │   │   │   ├── AC-2_login_error.png
│   │   │   │   └── AC-3_cleanup.txt
│   │   │   └── darkmode/
│   │   │       └── AC-1_toggle.png
│   │   └── specs/                   # 【生效规格】各功能当前生效规格（heavy blueprint 提炼，每功能一份）
│   │       └── session-management.md
│   ├── op_execution/                # 只放活的东西
│   │   ├── specs/                   # 【工作 spec】task:spec = 1:1，按 TID 命名：
│   │   │   ├── T0001_darkmode.md     #   每 task 一份，自足（共享不变量/跨 task 技术决策复制进每个相关 spec，不引用）
│   │   │   └── T0002_pages.md        #   frontmatter: status: draft|approved（approved 后冻结，状态推进走 tasks_list）
│   │   │                            #   TID 全局单调递增 T0001/T0002…永不复用（e2e/baselines/归档按 TID 存）
│   │   │                            #   顺序依赖在 tasks_list.json（机读）+ leader_checkpoint（人扫），不进 spec 本体
│   │   ├── tasks_list.json          # 【task 元数据唯一源】id/title/status/spec/depends_on/workset
│   │   │                            #   预计工作集（文件级清单）；人读走 opstatus 渲染
│   │   ├── tasks/                   # 活跃任务目录（每 task 平铺 2 文件：report/review）
│   │   ├── issues/                  # 问题登记（含所属 spec 字段，技术债加 tech-debt 标签）
│   │   ├── acceptance/              # 验收工作区（按 TID）：evaluator 产出 + closer per-task 收尾提案
│   │   │   └── {TID}/               #   baselines/（新基准快照临时区）+ blueprint_update.md（closer 提案）
│   │   └── leader_checkpoint.md     # leader 检查点：当前活跃 spec、task 进度、下一步
│   └── op_record/
│       ├── decisions.md             # 设计探索全文（spec 编写者写）+ 执行期 spec 变更类决策（closer append），append-only
│       ├── progress.md              # 每 task 完成一行（commit 区间+review 结论+验收标准覆盖）
│       ├── specs/                   # 已归档工作 spec，按 TID
│       ├── tasks/                   # 已完成 task 的 report/review 归档
│       └── acceptance/              # 已归档 task 验收工作区（{TID}/：blueprint_update.md + baselines 快照）
```

**TID 编码**：全局单调递增 `T0001/T0002/…`，固定四位数宽度，永不复用（e2e/baselines/op_record 永久工件按 TID 存，复用会撞）。一次 intake 拆出的多个 task 连续编号；不同 intake 续编。spec 文件名 `specs/{TID}_{slug}.md`。

### 1.1 task 工作区（平铺，全部进 git）

```
docs/omni_powers/op_execution/
├── specs/{TID}_{slug}.md     # 工作 spec（task:spec 1:1，全员只读。验收标准/不变量/边界/技术决策/可测性契约。共享内容自足复制，不引用别的 spec）
├── tasks/{TID}/
│   ├── report.md              # implementer 写：顶部总报告（每轮覆盖为累积总结）+ 分 Round 追加（审计轨迹）+ FAIL 轮 Fix-N 修复说明（不进 review.md）
│   └── review.md              # 双裁决结论（单写者 = leader，主分支落盘；task 分支不许碰，merge gate 白名单 REJECT）
├── tasks_list.json            # task 元数据唯一源（id/title/status/spec/depends_on/workset）
├── leader_checkpoint.md
└── issues/
```

- spec 在 `op_execution/specs/{TID}_{slug}.md`，不在 task 目录。task:spec = 1:1，每份自足。
- **无 brief 文件**——dispatch 时 leader 在 prompt 给指针（TID + spec 路径 + workset/depends_on 由 dispatch 脚本从 tasks_list.json 提取注入，§2.4；tasks_list.json 不挂 agent worktree），agent 读 spec（契约）；heavy 按需读 blueprint（约定）；lite spec 自足。单一真相，零重复。
- report.md 顶部总报告（leader/reviewer 入口，一眼看当前状态）+ 下方分 Round 追加（FAIL 轮修复记录留得住）。一个文件，不设 context.md。
- 每 task 子目录内 2 文件平铺（report/review，不设 runs/ 等子目录、不设 gitignore），task 闭环后 git mv 到 `op_record/tasks/{TID}/` 归档。

**`tasks_list.json.status` 枚举（机读值 ASCII——跨平台 locale 无关，Windows Git Bash/PowerShell 下 jq/grep 比较稳定；opstatus 渲染层映射中文给人读，人类可读性不丢；两版统一）**：

| status（机读 ASCII） | 渲染中文 | 含义 | 出现位置 |
|---|---|---|---|
| `pending` | 待规划 | 刚从需求解析出，无 spec | §2.1 入口前 |
| `ready` | 待开始 | spec 就位未开发 | §2.2 闸门 A 后 |
| `in_progress` | 进行中 | implementer 在做 | §2.4 dispatch |
| `reviewing` | 审阅中 | reviewer 双裁决中 | §2.4 review |
| `closing` | 收口中 | closer per-task 收口（heavy 独有） | §2.6 per-task 收口 |
| `done` | 完成 | 已归档 | §2.4 步骤 7 |
| `suspended` | 挂起 | 暂停（NEEDS_CONTEXT 等） | 异常 |
| `blocked` | 阻塞 | 两轮到顶（本 task 质量失败）；下游因依赖未就绪不另设态，由调度器依 depends_on 不选中（§2.4） | §2.4 review 上限 |
| `obsolete` | 已废弃 | 方案调整放弃、未开始；spec 移 `op_record/specs/obsolete/`；tasks_list 保留（TID 不复用，单调性校验豁免） | 闸门 A 后 / intake 调整 |

脚本/agent 不得自创状态串；脚本内 jq/grep 比较一律用左列 ASCII 值。spec frontmatter status 独立（`draft`|`approved`，approved 后冻结）。

### 1.2 两层 spec 流转与归档（按 task）

- **task 级，验收后**（evaluator 验收 PASS → 闸门 C 收尾）：task 的全部验收标准验收 PASS → closer 产 per-task 收尾提案 → leader 审批 → 精华并入生效规格（后续 task 引用它作基准）→ 原文入 op_record/specs/ → **tasks_list 标完成**（不"清出"，保留全量便于 TID 单调性校验与 opstatus 渲染）。进入生效规格的是淬炼后的结论："待澄清"、被证伪的担忧不进；实现中发现的未预见边界行为 + 验收 FAIL 修复后的最终形态一并补进。（lite：无 closer/blueprint，leader 直接归档 spec 原文，§5.6）
- **TID 永不复用**——全局单调递增（编码规则见上）。
- **废弃 task（`obsolete`）**：方案调整放弃的已拆 task 标 `obsolete`（非 suspended/blocked——三者语义独立：废弃=不做、挂起=暂停、阻塞=质量失败），spec 移 `op_record/specs/obsolete/`，tasks_list 保留。TID 空洞不破坏单调性校验（校验语义是递增不复用，非连续无空洞）。

### 1.3 文档职责矩阵（去重边界）

每个文档单一职责，重复内容只留一份（独占者），其他文档"详见 X.md"。CLAUDE.md 是"门牌"（指路），不重复 blueprint 内容。**下表 `op_blueprint/` 各文档（prd/architecture/domain/conventions/test/spec_index/specs）heavy only——lite 下 op_blueprint 为空壳、一律不读（见 §5.7）；lite 规格读 `op_execution/specs/`。**

| 文档 | 唯一职责 | 不该有（指向即可） |
|---|---|---|
| `CLAUDE.md`（项目入口，heavy 管理路径） | 项目一句话定位 + dev/build/test 命令 + 指向 `op_blueprint/` 各文档；**lite 不改此文件，入口为 profile + index.md** | 技术栈/目录树/架构约束/命名/日志/调试规则 |
| `prd.md` | 产品需求：定位/用户/功能/成功标准/不做 | 技术实现 |
| `architecture.md` | 架构真相：**技术栈 + 目录结构 + 模块划分 + 数据流 + 跨模块契约**（唯一目录/技术栈真相） | 命名规范/编码风格（→ conventions） |
| `domain.md` | 领域语言（术语表）+ 跨功能**业务**不变量（如"刷新恢复""hook 隔离原则""AI 实例不进 store"） | 编码风格/实现细节（→ conventions） |
| `conventions.md` | 编码约定：命名/风格/文件组织/浏览器 API/不可变性/日志规则/适配器开发步骤（**编码独占**） | 业务不变量（→ domain）/架构（→ architecture） |
| `test.md` | 测试宪章：分层/覆盖/lane/Mock 规则/调试入口（CDP 等） | 命名/架构 |
| `spec_index.md` | **纯 specs/ 索引**：功能清单 + 一句话说明 + 文件指引 | 技术栈/架构/安全（→ architecture/domain） |
| `specs/{feature}.md` | 各功能生效规格：接口/数据模型/行为（每功能一份） | — |

**已有项目 opinit**：blueprint-generator 从 `docs/archive/` + git log + 现有代码提炼**已实现功能**到 `specs/{feature}.md`（非空，每功能一份），spec_index 索引；新增功能（未实现）不生成，留 `/opintake` 拆分时补。详见 `skills/opinit/SKILL.md` 步骤三。

---

## 2. heavy 流程

```
需求 ──► opintake "<需求>"
 │  （强制 spec——不需要 spec 的简单任务不该调本 skill，直接做。change type 仍决定测试规则，§3.1）
 ▼
[Stage 1] 工作 spec 编写 + task 拆分决策（含内联设计探索 + 可测性契约，task:spec 1:1，§2.2/§2.3）
 │         共享不变量/跨 task 技术决策复制进每个相关 spec（自足，不引用别的 spec）
 │         ──► 【闸门 A：15-30 分钟/需求——全部 task spec + 拆分一次呈审】──► approved，写保护
 │
[Stage 2] 落元数据（opintake 内自动）：tasks_list.json 就绪（顺序依赖机读）+ leader_checkpoint 依赖段
 │         ──► Stage 2 自检（扫 tasks_list.json 依赖 + 跨 task 决策遗漏）。**未发现遗漏则跳过；回补 spec 须重过闸门 A** ══► opintake 终点：task status=`待开始` + checkpoint 标注 spec 就绪
 ▼
 ──► oprun（从 checkpoint 续跑）
[Stage 3] 逐 task 循环（§2.4，严格串行）——每 task 走完整链后下一个：
 │   dispatch 指针（TID+spec 路径+workset/depends_on 注入）→ op-implementer（TDD：先写映射验收标准的失败单测贴 RED → 最小实现 → 绿）→ report.md（含 Fix-N）
 │   → op-reviewer 双裁决（≤2 轮，review-package 含 workset 对照）；两轮修不平 → 记 issue + task 标阻塞 + 下一个 task
 │   → op-evaluator 验收（**merge 前验**，task 分支上；非行为型 task 免派）：访问隔离 eval_brief（spec 条件强制+可测性契约+生效规格基线+启动方式+baselines 索引，**剥探索结论**，不含 implementer 产物）
 │     逐条验收标准 hard-pass gate + 固化 PASS 测试 + 破坏检查 + 对抗探索；范围内 FAIL → 同分支修复回流（≤3 轮）；到顶 → 记 issue + task 标阻塞 + 下一个 task；范围外 → issues
 │   → 验收 PASS → squash-merge 回主分支（过 merge gate **白名单**，§3.4）
 │   执行期决策（§2.4）：小决策（选库/算法/路径，不进 spec）直接做不记录；需进 spec 的 leader 改 task spec + 记 decisions.md（spec-delta）+ 事后报；不阻塞等人
 ▼
 task 验收 PASS ──► [Stage 4] closer 收尾 + leader 自审写入（§2.6，**无用户事中审批**）
 │   closer 一段式：产 per-task 收尾提案（提取红灯归因 append decisions + blueprint diff + baselines 合入段 + task 归档提案，吸收验收结果）
 │   → leader 自审提案 + 直接执行写入 op_blueprint + baselines 合入 + task 归档 + commit → 删 task 分支与 worktree → 下一个 task（执行中不打扰用户）
 │   P0/P1 issue 记录不阻断执行（P0 进结束报告，用户事后处置）
 │   leader 做 evaluator 二阶判断 → 偏差指令 → 积累校准素材
 │   （一次 oprun 全部 task 写完或中断 → 生成汇总报告给用户；lite 同步：oplrun 结束报告 + §5.8 P0 改事后）
 ▼
 全部 task 闭环 ──► [Stage 5] merge（§2.7）：系统层夜跑回归全过 → merge
```

**模型分配**（跨 Stage 前置）：

| 角色 | 推荐模型 | token 消耗 | 理由 |
|---|---|---|---|
| op-implementer | Sonnet（硬骨头升 Opus，超预算换 1M） | 1（最高） | 多轮代码生成+测试迭代，每 task 一次，频率最高 |
| op-evaluator | Opus | 2 | computer use 截图+多模态判断，单次贵；**per-task 验收后每 task 跑一次，频率与 task 数线性相关**（per-task 验收换独立视角，代价是调用频次上升）；对抗性思维 |
| op-reviewer | Opus | 3 | 读 spec+diff+report 做双裁决，只读不写，每 task 一次；强审弱错开同档盲区 |
| op-closer | Haiku（最轻量，heavy 独有） | 4（最低） | 读 review+spec+blueprint，写提案+追加 decisions |

模型由环境变量参数化：

+ `OP_IMPLEMENTER_MODEL` 
+ `OP_REVIEWER_MODEL` 
+  `OP_EVALUATOR_MODEL` 
+  `OP_CLOSER_MODEL`。

值填 `haiku` / `sonnet` / `opus` 三档之一，对应 `settings.json` 的 `ANTHROPIC_DEFAULT_*_MODEL` 解析出的实际模型。**未设则不传 model 参数，继承主会话当前模型**。表中推荐模型仅作用户配置参考，dispatch 不自动用。

token 消耗排序（定性，per-task 验收后 evaluator 频次上升）：implementer ≥ evaluator > reviewer > closer

### 2.1 change type 与测试规则

**强制 spec**：调本 skill 即默认每 task 一份 spec（task:spec 1:1）。不需要 spec 的简单任务（改样式、加索引、三行 fix）不该调本 skill——直接做即可。入口不做复杂度检查，信任用户判断。

**change type** 只决定测试规则与 验收标准侧重（权威矩阵见 §3.1）：

| 类型 | 流程形态 | 契约来源 |
|---|---|---|
| feat | 全流程 | 工作 spec |
| fix | 复现 → **先写必然失败的回归测试**（统一 `BUG-{id}_*.spec`，行为层）→ 根因 → 修 → 变绿（先红后绿，否则判假绿）。**红/绿的观察主体是 leader 主会话**（implementer worktree 无 e2e，无法自证先红）：implementer 产回归测试 patch 附 report → leader 落盘主 worktree e2e/ 并**亲跑确认红** → implementer 修 src（task 分支）→ merge 后 leader **亲跑确认绿**。暴露规格缺失则补生效规格 | 那条回归测试 |
| refactor | "行为不变"即契约，验收标准是等价性验证 | 行为层测试套件 |
| perf | benchmark 基线 → 改 → 复测，验收标准是量化指标 | benchmark 基线 |
| style/test | 见 §3.1 | — |

### 2.2 Stage 1：工作 spec（方案设计 + 可测性契约内聚于此）

#### spec 模板

```markdown
---
status: draft        # draft → approved（approved 后冻结；状态推进只走 tasks_list.status——免每次推进都解锁写保护）
type: feat           # feat | fix | refactor | perf | style | test | ...
---
# <名称>
## 一句话意图
## 不变量（INV——填不出 = 没理解需求；每条编号 INV-N，如 INV-1；与 domain.md/生效规格冲突必须显式标注）
   <!-- refactor 型此区最长：列出所有必须保持的行为契约 -->
## 验收场景（验收标准AC，Acceptance Criteria——每条编号 AC-N，如 AC-1；Then 必须用户可观察；每条须可直接翻译为可执行断言）
   <!-- feat: 用户能做什么新事 | refactor: 等价性验证 | perf: 量化指标 -->
## 边界与反例（竞态、并发、空状态、失败路径、刷新/重启、多显示器/多窗口）
## 不做的事
## 技术决策（三类内容，均随闸门 A 过人审）
### 条件强制：被 2+ task 依赖的决策
   - {数据模型/模块通信/状态存储/接口形状} —— {理由}
### 设计探索结论：命中方案先行信号时
   - 候选：{A / B / C}
   - 推荐：{选哪个} —— {复杂度与边界行为权衡 + 理由}
   - 已知坑：{坑}
   <!-- 完整探索过程存 decisions.md，此处只留结论。未命中信号则此区空 -->
### 可测性契约（必填）
   {写 spec 时顺手推导——验收标准的验收方式自然延伸；implementer 把测试缝当成和验收标准同级的交付义务}
   - 应用启动方式: {一条命令启动，如 npm start / ./app / ...}
   - AC-1 验收信号: {结构化优先——CLI stdout/API 响应/DB 查询/进程健康检查（**DOM/a11y 降 advisory，D7**）；视觉对照——截图/DOM，advisory}，关键入口: {URL / 菜单路径 / API 端点}
   - AC-1 通道: {CDP | cua | 直驱}（能用 CDP 的一律 CDP；CDP 做不到的 OS 原生壳层/浏览器 chrome 才 cua；无 UI 直驱）
   - AC-N 验收信号: {结构化/视觉信号}，通道: {CDP | cua | 直驱}，测试缝: {如"需测试收件箱 → 需 Mailpit + seed 账号"; "需验证导出 → 需 stats export 命令"}
   - 预期失败模式（**best effort——建议每条 AC 1 条，非硬门槛**——若 xxx 没做好，验收标准应该 FAIL；evaluator 验收 对照此表逐条试反例；D13）:
     - AC-1 若未正确实现则 {行为表现}，评估时专门试这个
     - AC-N 若未正确实现则 {行为表现}
## 待澄清 [NEEDS CLARIFICATION]（≤3 条，有则阻断——**leader 写 spec 阶段自筛解决；进闸门 A 前必须清空或显式标注为「待用户决策项」，不把未决项堆给闸门 A**）
<!-- 顺序依赖在 tasks_list.json（机读）+ leader_checkpoint（人扫），不进 spec 本体（避免闸门 A 写保护后追加冲突） -->
```

### 2.3 Stage 2：task 拆分（opintake 内自动完成）

#### plan 信息的四归宿

| plan 信息 | 归宿 | 消费者 |
|---|---|---|
| 顺序与依赖 | tasks_list.json（机读）+ leader_checkpoint（人扫） | leader（Stage 2 自检自动扫） |
| 跨 task 技术决策 | 复制进每个相关 task spec 的技术决策区（人审，自足） | implementer / evaluator |
| task 间接口契约 | **接口先行 task 以代码提交**（类型/schema，编译器强制——严格强于文档签名，文档会漂移代码不会）。**验收**：编译/类型检查通过 + 下游 task 能 import；reviewer 确认接口形状对齐 spec 技术决策 | implementer |
| 工作集（文件级清单） | tasks_list.json | leader（merge gate 越界检查参考，§3.4） |

三个消费者的裁定：**人不审文件/函数清单**（没有代码深度判断不了对错，拦截率≈0，杠杆全在行为层）；**leader 需要文件级工作集但纯属机械用途**；**implementer 拿 spec + tasks_list 该条元数据 + 接口代码，函数级内部结构自定**——实际触碰文件与预估偏差过大时，reviewer 规格合规裁决抓范围偏航。

#### task 元数据（tasks_list.json 一条记录）

task:spec = 1:1，任务卡即 tasks_list.json 的一条记录，**无独立文件**。字段：

```json
{
  "id": "T0003",
  "title": "<语义级标题，一句 commit message 能说清>",
  "status": "ready",
  "spec": "specs/T0003_xxx.md",
  "depends_on": ["T0001"],
  "workset": ["src/store/session.ts", "..."]
}
```

- `spec` 指向该 task 的契约（验收标准/不变量/边界/技术决策全在 spec，元数据不重复）。
- `workset` 文件级清单，merge gate 越界检查对照（§3.4）。
- **无 covers_ac/touches_inv**——task:spec 1:1，spec 的验收标准/不变量全是这 task 的，不另引用编号。
- **无"完成定义"**——即 spec 的验收场景，不重复。

#### 粒度判据（沿低耦合缝隙切）

- 沿层/模块/数据流阶段的缝隙切 task，"task 即 commit"——一个 task 一句 commit message 能说清。
- **拆分代价 = 被切开两半共享的部分**：先列缝再切，沿缝代价低。
- 天然不可分（横切重构/脚手架）→ 单 task 自足 spec，不硬锯。

### 2.4 Stage 3：逐 task 执行循环

leader-worker：leader 只编排，上下文只留状态；交接全走 task 目录文件；每 task 全新 subagent 独享完整上下文。**task 严格串行**——tasks_list 的 depends_on 只记录依赖事实，不授权并行（共享流程文件并发写入 + 多分支回流 merge，冲突协议未建前不放开）。

#### 单 task 循环

1. **dispatch op-implementer**（prompt 注入指针：TID + spec 路径 + **workset/depends_on 由 dispatch 脚本从 tasks_list.json 提取注入**，agent 不自行 jq 现读——tasks_list.json 不挂给 implementer worktree；heavy 按需读 blueprint 约定）
   - TDD：先写映射验收标准的失败单测，贴 RED → 最小实现 → 测试证据
   - 证据可信度：implementer 自跑自贴，靠 reviewer + evaluator 兜底
   - 写 report.md（顶部总报告覆盖 + 分 Round 追加；**FAIL 轮的 Fix-N 修复说明也追加到 report.md，不进 review.md**——review.md 单写者 = leader）→ 返回 `DONE | BLOCKED | NEEDS_CONTEXT`
2. **dispatch op-reviewer**（只读 review-package：report + 三点 diff + spec + **workset 对照表**，脚本打包注入，reviewer 无 checkout 不自行 jq）
   - diff 为脚本生成的三点 diff：heavy = `dispatch 锚点 sha...task 分支头`；lite = `dispatch 锚点 sha...工作区`（**锚定 dispatch 时记录的 sha**，防 implementer 自行 commit 致 diff 空），防挑选性呈现（§3.4）
   - 双裁决：
     - **规格合规**：覆盖 spec 验收标准？偏离 spec/自由发挥/范围偏航（实际工作集 vs workset）？契约边界复核——需进 spec 的决策是否走了变更子流程（decisions.md 有 spec-delta 记录）？未走而实改 spec = 越界打回；小决策（选库/算法/路径，不进 spec）不审
     - **测试可信**：测的是验收标准还是 mock？断言用户可观察？异步时序对？命中危险模式？（refactor 加审：结构层变更是否只动调用部分？删除的覆盖仍在？）
   - **verdict 落盘（单写者化）**：reviewer 在返回文本末行给 verdict + 范围外发现的暂存段，**leader 落盘到主分支 `tasks/{TID}/review.md`**（单写者 = leader；task 分支对 review.md 的任何变更被 merge gate 白名单 REJECT）。review.md 按追加写（每轮 verdict 追加，末行为最新，对齐 report.md 模式，保留历史 FAIL 归因不丢）。范围外发现由 leader 收口时落 issues 并赋 P（对齐 evaluator 协议）。merge gate 从主分支 review.md 末行读 verdict
3. **处理 findings**（不按严重度分流，有问题就处理）：
   - 范围内、能修 → implementer fix（见 review 循环上限）
   - 范围内、需改 spec → spec 变更子流程（本节下文，agent 自决改 + 事后报）
   - 范围外（不属本 task spec）→ 落 issues（赋 P 级，§3.2），不当场修
4. **双裁决 PASS → dispatch op-evaluator 验收**（**验收挪到 merge 前**，task 分支上验，构建产物从 task 分支构建；每 task 一次，验收该 task spec 的验收标准）
   - **非行为型 task 免派**：接口先行/脚手架/纯内部重构类 task 无用户可观察行为，hard-pass gate 无从落地，免派 evaluator，验收由 reviewer + 编译器/类型检查承担（task 的 change type + workset 性质判定，oprun dispatch 时标注）
   - 访问隔离：eval_brief 机械组装（spec 条件强制 + 可测性契约 + 生效规格开工前基线 + 启动方式 + baselines 索引，**剥"设计探索结论/已知坑"段**，不含 implementer 产物），机制详述见 §2.5
   - 逐条验收标准 hard-pass gate + 固化 PASS 测试 + 破坏检查 + 对抗探索
   - 范围内 FAIL → 修复 task 回流（≤3 轮，同 task 分支续做）；到顶 → 记 issue + task 标阻塞 + 下一个 task；范围外 → issues
5. **验收 PASS → merge gate 校验 + squash-merge 回主分支**（§3.4；**白名单**：task 分支允许触碰 = workset ∪ `tasks/{TID}/report.md` ∪ 结构层测试路径，其余 REJECT——review.md/spec/e2e/op_blueprint/decisions.md/tasks_list 全在黑名单侧）→ 进 Stage 4（closer 收尾 + 闸门 C，§2.6）

#### review 循环上限

- review → fix → re-review 为一轮；**最多两轮**
- 两轮修不平大概率是结构问题（方案错/拆分错/规格歧义），继续循环只是烧 token
- **到顶处置**（两轮仍有范围内问题修不平）：记 issue + task 标阻塞 + 下一个 task。阻塞本身是有效信号，issue 留待后续处理，不许静默 commit
- **阻塞 task 的归因沉淀**：closer 只在验收 PASS 触发，阻塞 task 不进 closer——但阻塞恰是归因最有价值（结构问题/规格歧义）。review 两轮到顶 / 验收三轮到顶标阻塞时，leader 亲提（或派 closer 做 blocked 形态）把 report.md 的红灯归因段 append 到 decisions.md（来源标记 blocked-attribution），不让归因停在 report.md

#### 执行期决策（agent 自决，事后报）

执行期一切决策由 agent 自己判断，不阻塞等人。先问一句——**这个决策需要进 spec 吗？**

| 类型 | 判据 | 记录 decisions.md | 处理 |
|---|---|---|---|
| **小决策** | 不进 spec（选库/算法/路径） | 不记录 | 直接做 |
| **需进 spec 的决策** | 要改 spec 文本 | 记录 | 走 spec 变更子流程（下） |

#### spec 变更子流程

1. **发起**：发现者（implementer report / reviewer 复核 / evaluator 验收）→ leader。
2. **记录决策 + 受影响清单**：leader 写 delta（原文引用 + 改后文本 + 理由，逐条）append 到 decisions.md（来源标记 spec-delta）。**强制列受影响清单**：delta 触碰哪些 spec 的哪些 AC/INV/边界/技术决策 + 受影响 task 清单（依赖该 spec 的所有 task）。脚本 grep 决策关键行核对覆盖——漏列受影响 spec/task = 打回补全。
3. **改 spec**：leader 解锁 task spec（heavy: git 解锁脚本；lite: 直接改）→ 应用 delta → 重新 commit + 恢复写保护。
4. **task 处置（不引入 cancelled 终态）**：
   - **当前 task**（发起 delta 的、或正在做的）：更新其 tasks_list 记录（workset/依赖可能变）
   - **后续 task**：扫 tasks_list 所有未完成 task，检查是否受 delta 影响（依赖的 spec/AC/INV 与 delta 相交），受影响的逐个更新 tasks_list 记录
   - **从当前 task 重新跑 implementer**（同 TID，不重拆、不开新 TID——TID 单调不复用）
   - 已归档 task 不回溯（历史快照），其实现若因 delta 失效由后续验收/系统层回归暴露，走正常 fix 流程
5. **继续**：流水线不停，事后报告（闸门 C 呈报 spec 变更决策表）。

#### 红灯归因协议（test.md + opred skill）

测试红 → 默认实现错。复现 → 读断言（保护哪条验收标准/不变量）→ 读实现（解释为何不符）→ 归因：

+ 实现 bug，只改实现；
+ 测试写错，写明错因（锁定文件需人工解锁；含 fix 场景"原测试供奉了 bug"须给依据——INV-x/用户报告）；
+ 规格变了，走变更子流程。没有归因不准碰测试。

**归因记录路径**：implementer 对 decisions.md 无写权（§3.4 流程文件单副本在主 worktree）——归因写进 report.md 的归因段，closer 收口时提取 append 到 decisions.md（来源标记 red-attribution）；锁定文件归因由 leader 执行解锁与落盘。

#### leader 上下文收敛与 subagent 重派

**leader 亲跑收敛**：leader 是全系统状态一致性单点，长跑必 compact——亲跑测试输出/读 diff hunk 会灌满上下文。heavy 侧"亲跑验证"统一收敛为**"脚本跑 + 单行 verdict 回传"**（对齐 lite op_read_verdict 形态）：leader dispatch 后只读脚本回传的 verdict 行（PASS/FAIL + 证据指针路径），不把完整测试输出/diff 灌进主会话上下文。完整证据留在 report.md/acceptance/，二阶判断时按指针取。

**subagent 重派协议**：subagent 崩溃/超时（task 卡"进行中"、worktree 残留）时，leader 按 report.md 顶部总报告判定恢复点：
- report 有累积总结（上次中断点清晰）→ 复用同 task 分支续做，dispatch prompt 指明"从 report Round-N 续"
- report 无总结 / worktree 损坏 → 重切 task 分支重做（同 TID，report.md 保留前次记录追加，不覆盖）
- worktree 残留检测：dispatch 前 `git worktree list` 查 `op/task/{TID}` 是否存在，存在则复用或清理后重建


### 2.5 evaluator 验收机制

op-evaluator 在 Stage 3 task 循环内介入（每 task 一次，**merge 前验**）。per-task 验证：双裁决 PASS 后、squash-merge 前派 evaluator（构建产物从 task 分支构建）**自己操作应用**复现该 task spec 的验收标准，逐条验收标准 binary gate（hard-pass gate）+ 固化 PASS 测试 + 破坏检查 + 对抗探索，逐条验收标准报告。范围内 FAIL → 修复 task 回流（≤3 轮）；**到顶处置**：验收标准是 binary gate，不存在"降级落 issue"——到顶即记 issue + task 标阻塞 + 下一个 task。**review 上限 2 轮（reviewer 裁决）与验收回流上限 3 轮（evaluator 发现验收标准不通过后的修复重验）性质不同，独立设定**；范围外发现（不属本 task spec 验收标准的问题/可用性建议）→ issues（§3.2）。PASS → 派 op-closer 一段式收口（§2.6）。

**非行为型 task 免派规则**：evaluator 是最贵护栏（Opus + computer use，频次与 task 数线性），与原则 12"按需付费"有张力。无用户可观察行为的 task，hard-pass gate 无从落地，一律免派——验收由 reviewer + 编译器/类型检查承担。免派判据（task 的 change type + spec AC 性质，oprun dispatch 时标注）：
- **接口先行 task**（AC = 编译通过 + 下游可 import，无运行时行为）
- **脚手架/工程化 task**（AC = 配置/目录结构就位，无运行时行为）
- **纯内部重构 task**（AC = 行为等价性，已有行为层测试覆盖；reviewer 加审"结构层变更是否只动调用部分 + 删除的覆盖仍在更高层"）

免派 task 在 tasks_list 标 `eval: skip`（**task schema 字段 `eval: "required"|"skip"` + `eval_reason`，D9**——oprun 机械判定免派，非临场判断；spec frontmatter 亦可标），oprun 跳过 dispatch evaluator，直接进 closer。其余 task（有用户可观察行为 AC）一律派。

#### evaluator 访问隔离与防放水

stock model 默认对 LLM 产出宽容——能发现 bug 但会说服自己"不太严重"放行，或只测成功路径不探边界。隔离防"抄实现"（evaluator 读源码后照着实现写测试→实现错→测试跟着错→一起绿）靠以下机制。

**访问隔离（结构单层 + 报告回流，不依赖 hook 拦截）**：

1. **结构隔离层**：evaluator 在独立 worktree 工作（`op_worktree_setup.sh eval`），文件系统通过 sparse-checkout 只挂载 spec + 生效规格（开工前基线）+ baselines 索引 + 应用启动方式 + 构建产物（Electron 可执行文件 / web dist / 扩展 .zip / 服务二进制）+ `e2e/`。源码 `src/**`、task 目录（`op_execution/tasks/**` + `op_record/tasks/**`）、`op_record/decisions.md` 不物化到工作目录——**防无意耦合**：正常读文件流程碰不到，但 object store 共享，git 底层命令可绕（§0.1）。evaluator 操作的应用包由 leader 人工构建后交付到 op-eval worktree。
   - **非 UI 类（API/DB/CLI/进程）**：构建产物 + 结构化信号（stdout/API 响应/DB 查询/进程日志）直接完整可验。
   - **UI 类**：evaluator 操作构建产物启动的应用（computer use / 独立机器点击），自由探 UI 边界；视觉信号作锚点由 evaluator 多模态对照。
2. **报告回流层（脚本机械组装，保留——不依赖 hook）**：brief 由 `skills/oprun/scripts/op_assemble_eval_brief.sh {TID}` 生成，内容源全固定路径 cat（工作 spec / 生效规格开工前基线 / baselines 索引 / 应用启动方式），leader 不参与内容生成、只 dispatch。evaluator 作为独立 subagent 只读 brief 文件，leader 主会话上下文（满是 task 交接污染）物理上传不过去——脚本取代纪律性白名单。per-task 阶段不写 op_blueprint，故验收时生效规格天然是开工前版本，隔离防线不被自家归档流程打穿。
3. **dispatch 协议层（advisory 留痕，非拦截）**：leader 调 evaluator 的 prompt 固定模板（"读 {eval_brief_path}，按 eval_brief 执行评估"）。Task matcher 能 fire 但 deny 拦不住 dispatch，故这层只做**事后审计/留痕**（记 dispatch prompt 日志备查），不主张拦截——内容通道闭环靠第 1 层（源码不在）+ 第 2 层（eval_brief 机械组装），不靠 dispatch 拦截。

**evaluator 读写权（目标由结构 + 脚本共同实现，非 hook 拦截）**：
- **读权**：工作 spec + 生效规格（开工前基线）+ baselines 索引 + 应用启动方式（eval_brief 机械组装提供）+ 构建产物；其余禁止读。靠 worktree 不挂载实现（src/tasks/decisions 物理不在，见 §0.1）。
- **写权**：`e2e/`（固化 PASS 测试，经 leader 审后入主分支，§3.4）+ `op_execution/acceptance/{TID}/`（baseline 快照 + 验收报告 + **范围外发现的 issue 草稿**——evaluator 不直写 `issues/`，草稿由 leader 收口时落盘登记并赋 P 级，与 §3.2 落盘者赋 P 级规则一致）；其余禁止写（尤其 `op_blueprint/`——per-task 由 leader 基于 closer 提案写）。靠 worktree 挂载范围 + 写路径限定。

**防放水机制**：
1. **hard-pass gate**（evaluator prompt 内置）：每条验收标准binary gate。亲自观察到 Then 子句的用户可观察行为 → PASS。观察不到、推测→FAIL。无法确定→INSUFFICIENT_EVIDENCE。禁止推论式 PASS。**纯视觉验收标准由 evaluator 多模态 hard-pass 判定（可 FAIL）；「视觉不进机械硬门」仅指夜跑回归不因视觉 diff 自动阻断——两件事不同主体**。
2. **预期失败模式**（spec 可测性契约，**best effort——建议每条 AC 1 条反例，非硬门槛**）：若 xxx 没做好则 验收标准应该 FAIL。evaluator 验收 逐条试。零 token 零 agent，写 spec 时顺手加。强制数量反促成凑数，价值在"逼反向思考"而非条数（D13）。
3. **破坏检查**（机械）：固化测试必须能红——关功能开关或改断言期望，确认它真的会因错误实现而失败。**能力边界**：改断言期望必然红，只证明断言在执行、不证明测试与实现真耦合；功能开关多数应用没有。此检查拦"恒真断言"这类低级假测试。

#### 验收基准快照

evaluator 验收评估分两模式，evaluator **自己操作应用**复现验收标准（computer use / 后期独立机器点击，非看图对照），基准快照解决两模式间的对齐：

通道选择遵守 opspec 决策树：**CDP 优先，cua 补齐，直驱垫后**。Chromium 渲染层走 CDP；OS 原生壳层/浏览器 chrome/系统对话框走 cua；无 UI 行为走 Bash/HTTP/SQL 直驱。

- **首次评（裸评建基准）**：无 baseline。evaluator 自己操作应用触发验收标准的 Then，对照 spec 推导期望→亲自观察。PASS 须经 hard-pass gate（亲自操作观察到 Then 子句用户可观察行为）+ 破坏检查（固化测试能红）才存基准——基准是"验过能红"的 PASS 证据，锚定它才安全。
- **重验（对照评）**（**P2 阶段交付，当前不可用，见 §0.2**）：evaluator 重新操作应用复现同一验收标准路径，**逐步对照 baseline 记录的"该观察到什么" + spec 目标**判断。截图不是比对对象，是"上次操作到这步看到了啥"的参考锚点；结构化信号才是机械比对的硬证据。结果——一致 / REGRESSION（视觉层 advisory 不阻断）/ 预期改进（更新基准，走提案制）。

**baseline 按信号性质分三层**（不按应用类型枚举；任何有外部可观察产物的系统都覆盖——DB/API/进程/消息/定时任务都有，形态由应用暴露的可观察接口决定）：

| 层 | 性质 | 进硬门 | 例子（跨类型） |
|---|---|---|---|
| 结构化/语义 | 可机械断言、可复现、零放水 | ✅ 硬门主体 | stdout/stderr/exit code；API 请求响应体/状态码/副作用；DB 查询结果/schema/迁移 diff；进程健康检查/日志关键行；消息 payload/顺序；定时任务触发后副作用（DB 状态/输出文件） |
| 视觉/DOM | 多模态对照，evaluator 自己判 | 不进机械硬门（advisory） | 截图——操作到某步"该看到啥"的锚点，由 evaluator 多模态对照（看语义级差异、不被渲染噪声炸；靠 hard-pass gate + 预期失败模式兜）；DOM/a11y tree——CSS/组件重组/兄弟节点增减触发不匹配且通常非行为回归，advisory 不阻断（D7）；a11y 语义层（role/name/state）规范化后可作 evaluator 判断锚点 |
| 操作 | evaluator 主动 | —（验收手段，非 baseline 内容） | computer use/独立机器点击，按可测性契约的启动方式+测试缝自己驱动到 Then |

**快照格式规范**：每类信号对应的文件格式与标准化规则（CLI 输出过滤时间戳行、DB 排除自增列、DOM 取 a11y tree 文本表示等）在 conventions.md 定义；design 层声明**格式规范存在且必须遵守**——含可变数据（时间戳/自增 ID）的快照会产 false positive 破坏回归检测可信度。false positive 由 evaluator 判定后走提案更新基准。

**硬门信号确定性优先**：能拿结构化语义（stdout/API/DB/进程/消息——**DOM/a11y 除外，flaky 降 advisory**）的优先它进硬门；纯视觉与 DOM 信号不进机械硬门（flaky 且放水），交 evaluator 综合判断。**夜跑回归的判定以结构化硬门信号为准，视觉/DOM 对照不阻断**——非 UI 类 baseline 前期就完整可用，UI 类随 evaluator 操作能力（前期受限/后期独立机器）逐步补全。baselines 另服务 leader 二阶判断（spec Then + 基准信号 + evaluator 证据三样对照抓放水）。

快照写入 `op_execution/acceptance/{TID}/baselines/`（验收工作区，evaluator 无 op_blueprint 写权限），文件命名映射验收标准（`AC-2_login_error.txt`/`.dom.html`/`.png`，按信号类型选扩展）。

**后续重验**（修复 task 回流后的二次验收），读基准的位置按时序分：

- **同次验收内重验**（首次 FAIL→修 task→二次评，per-task 收尾未跑）：读 `op_execution/acceptance/{TID}/baselines/`——首次评刚存的临时区，此阶段 `op_blueprint/baselines/` 仍为空（合入要等 closer 提案 + leader 审批，§2.6）。**该验收标准首次评 FAIL 则无 baseline，重验退化为首次裸评逻辑（建基准），不进对照门**。
- **跨 task / 后续迭代重验**（前 task 已收尾合入）：读 `op_blueprint/baselines/baselines_index.md` 找已有基准快照。

结构化硬门信号不一致且非预期改进 → 直接 FAIL；视觉锚点差异 → evaluator 综合判（advisory，不机械阻断）；预期改进 → 更新基准快照（仍写 `acceptance/{TID}/baselines/`，走提案制）。

**baselines/baselines_index.md 格式**：

```markdown
# baselines 索引（按功能名，与 specs/ 同键）

## session-management（2026-07-03）
| 文件 | 对应验收标准 | 类型 | 说明 |
|---|---|---|---|
| session-management/AC-2_login_error.png | AC-2 | 截图 | 错误密码登录提示 |
| session-management/AC-3_cleanup.txt | AC-3 | CLI 输出 | 超时清理日志 |

## darkmode（2026-07-02）
| 文件 | 对应验收标准 | 类型 | 说明 |
|---|---|---|---|
| darkmode/AC-1_toggle.png | AC-1 | 截图 | 切换前后对比 |
```

#### BUG-*/e2e 合法写入通道

merge gate 对 task 分支的 `e2e/**` 变更一律 REJECT（§3.4），但存在合法写入路径：evaluator 固化 PASS 测试、leader 落盘 BUG-* patch、closer 提案后 leader 改跨功能既有 e2e。三条路径统一收敛到 **leader 主会话唯一 e2e 提交入口**——这是 merge gate 通道规则的自然特例，不是独立机制。

- evaluator/implementer **只产 patch/文件，不直接 commit 到主分支 e2e/**——evaluator 固化的 PASS 测试写入自己 worktree 的 e2e/（其 worktree 挂 e2e/，见上），由 leader 审后经 eval 分支合入（§3.4）；implementer 的 BUG-* patch 附 report 经 leader 落盘（§2.1 fix 流程）。
- **主分支侧自锁（防 leader 被诱导误提交）**：pre-commit 白名单机制——leader 提交 e2e 变更时带 **commit trailer + 解锁脚本配对**（trailer 由解锁脚本一次性生成、绑定 commit-sha 防重放；解锁脚本输出不进 agent 可读文件；校验不依赖 agent 可写状态）。**复杂度取舍**：此层防的是"leader 主会话被上下文注入诱导 commit"这一低概率场景，且 merge gate 已拦 task 分支侧——故实现从最简版起步（trailer 存在性校验），HMAC 签名等强化等观察到真实绕过案例再加，不预付。
- **trailer 失效后恢复路径**：失败提交可重跑解锁脚本再生 trailer，不必 --no-verify。
- **实施顺序铁律：合法入口机制先于主分支侧硬锁上线**——硬锁先行会把 evaluator 锁死；入口先行则过渡期与现状等价（merge gate 已拦 task 分支，主分支侧无锁但有审计）。

本节锁定方向与顺序，防止实现时滑向「evaluator 也被锁死」或「解锁通道形同虚设」两个极端。

### 2.6 Stage 4：closer 收尾与闸门 C

Stage 4（task 验收 PASS 后触发）：leader 派 op-closer 做一段式收尾。

#### closer 一段式收口

closer 做一次完整收口——产 per-task 收尾提案 `op_execution/acceptance/{TID}/blueprint_update.md`（blueprint diff + baselines 合入段 + task 归档提案，吸收验收结果）+ 提取本 task 的红灯归因 append `decisions.md`（来源 red-attribution；spec-delta 由 leader 变更子流程写，不经 closer；小决策不收）+ 转 reviewer 暂存 issue。生效规格只收经验收淬炼的结论，归档提案吸收验收结果。

**closer 权限（单条清单）**：仅写 `decisions.md` + 转暂存 issue 到 `issues/` + 写 `acceptance/{TID}/blueprint_update.md` 提案；不跑脚本、不碰 git、不改 status、不 stage、不碰 spec、不碰 op_blueprint（提案由 leader 闸门 C 审批后写入）。脚本（tasks_list.json/git mv/progress）全归 leader。

**closer gate（机械校验）**：closer 是四角色里权限最大约束最少的（主 worktree 完整 checkout，物理能写 src/spec/e2e/op_blueprint 的一切，PreToolUse 对 subagent 失效，又不走分支所以 merge gate 管不着）。补偿：closer 返回后 leader 跑 `op_closer_gate.sh {TID}`——机械校验本次 closer 触碰路径 ⊆ {`op_record/decisions.md`, `op_execution/issues/`, `op_execution/acceptance/{TID}/`}，越界即 `git checkout` 撤销 + 告警，提案不进闸门 C。一个 `git status --porcelain` 对照脚本的成本。

**decisions.md append 协议（多写者幂等）**：decisions.md 是多写者 append-only 文件（红灯归因 red-attribution/解锁、leader 降级 delta、spec-delta、closer 收口、lite leader-close），不冲突的前提是 task 串行 + **单一物理副本直写主 worktree**（§3.4，subagent worktree 不挂此文件，写入一律经 report→closer 提取或 leader 亲写）。每个 append 块头部带机械标识 `[来源标记 | TID | Round-N | 日期]`——中断/重试/恢复场景按标识判重（同 TID+来源+轮次已存在则跳过）。

#### per-task closer 提案

op-closer 产「blueprint 更新提案」写入 `op_execution/acceptance/{TID}/blueprint_update.md`，diff 形态覆盖 `op_blueprint/` 全部文档（specs/{feature}.md、architecture.md、domain.md、conventions.md、baselines/ 等）：这条新增、这条修改、这条因被上游覆盖而删除，各附一句理由。只留"现在是什么"，过滤被否方案/临时假设。**含 baselines 合入段**（新增/更新/删除各附验收标准与理由）+ **task 归档提案**（TID 标记完成——永不复用）。**吸收验收结果**：实现中发现的未预见边界行为、FAIL 修复后的最终形态一并写入。

- **铁律**：op-closer 对 `op_blueprint/` 无写权限；不碰 git、不改 status、不归档、不盖戳、不 stage。

#### leader 自审执行（**无用户事中审批**——closer 提案由 leader 自审直接写入，不 per-task 打断用户；事后报告见下）

**执行模型（autonomy-first）**：closer per-task 产提案（吸收该 task 验收结果），写入 `acceptance/{TID}/blueprint_update.md`；leader 自审提案 + 直接执行写入（不呈报用户事中审批）。执行中不打扰用户——P0/P1 issue 记录不阻断（P0 进结束报告，用户事后处置），AC/INV spec-delta 也由 leader 自主改（不事中阻断）。用户随时可中断 oprun，中断记 issue。

leader 自审 closer 提案后执行：

- **采纳** → 执行写入 `op_blueprint/`（specs + baselines 合入）→ task 归档（spec 原文入 `op_record/specs/`、task 目录入 `op_record/tasks/{TID}/`、acceptance 工作区入 `op_record/acceptance/{TID}/`、tasks_list 标完成、progress 追加）→ commit → 删 task 分支与 worktree
- **部分采纳** → leader 逐条标采纳/修改 + 自行改定提案文本后执行写入（closer 不重提——执行中不打扰用户意味着 leader 自决，不回 closer 循环）
- **驳回** → 回 evaluator 重验收，或 leader 自改提案

**自审深度（升级阈值）**：默认快速审（只读呈报四样，二阶判断抽 1-2 条 baseline 对照）；提案变更条目 **>5 条** 或含跨功能 baseline/e2e 更新时，自动升级为详细自审（逐条 baseline 对照 + evaluator 证据复核）。阈值 5 可由项目 conventions 覆盖。

#### 事后报告（一次 oprun 结束，呈报用户）

**触发**：一次 oprun 的全部 task 写完，或用户中断 oprun。

**报告内容**：blueprint diff（规格新增/修改/删除）+ baselines 合入（基准新增/更新/删除）+ task 完成情况（含归档）+ 累积 issues（P0/P1，P0 在报告标注）+ AC/INV 变更记录（leader 自主改的 spec-delta）+ 验收标准追溯矩阵（closer 提案含）+ spec 变更决策表（decisions.md spec-delta）。人不审文件/函数清单——那是杠杆错位。

**报告后处置**：用户审核报告，发现不对则记 issue 或 `git revert` 整批 commit（leader 不自动回滚）。报告是"事后知情 + 可驳回"，非事前 gate。

#### baselines 合入流程

closer 在 blueprint_update.md 的 baselines 段列出新增/更新/删除（各附验收标准与理由），leader 自审后：

- 新基准从 `acceptance/{TID}/baselines/`（**临时区，按 TID**）合入 `op_blueprint/baselines/{feature_key}/`（**合入区，按 feature_key**——feature_key 闸门 A 阶段确定，入 task spec frontmatter / tasks_list，closer 只能引用不能重新判断，D10）
- 更新 `op_blueprint/baselines/baselines_index.md`（追加/修改对应行）
- 删除的基准从 op_blueprint 移除

**跨功能更新**：一个 task（如 T0003_contact）的实现可能合法改变**另一个功能**（如 darkmode）的页面布局，使该功能旧基准"不一致"。验收时 evaluator 标记该功能基准为 NEEDS_UPDATE，closer 收尾提案里附该功能基准更新段（注明被哪个验收标准 触发），leader 审批后更新该功能基准。规则：跨功能更新必须经 closer 提案 + leader 审批，evaluator 不直接改 op_blueprint；**只动 `op_blueprint/baselines/{功能名}/`**——若该功能的语义契约本身变了（验收标准/不变量改），另开该功能的 spec 变更子流程，不混在 baseline 更新里；**既有 e2e 同规则**：需改另一功能既有 e2e 时，走 closer 提案 + leader 审批（§3.1 改既有 e2e = spec 变更），evaluator 不直接改。

#### 二阶判断

leader 做 evaluator 二阶判断时对照基准——spec 的 Then 文字 + baselines 里的结构化信号/视觉锚点 + evaluator 的操作证据。三样对照，一眼能看出 evaluator 有没有放水（结构化信号没复现 / 截图里错误提示根本没出现就判了 PASS）。放水则写偏差指令，积累校准素材。

（lite: 同步——oplrun 结束报告 + §5.8 P0 改事后，不事中停）

### 2.7 Stage 5：merge 与系统层回归

merge 前跑**系统层验证**：e2e/ 全集 + domain.md 与生效规格不变量回归，失败自动开 issue（§3.2）。系统层随 spec 数自动增长——新东西弄坏旧东西没有，靠全集回归兜。**已知洞**：cua 通道验收的 AC 无法固化为 CI 可重放测试（无头环境驱动不了 OS 原生壳层），这类验收标准 不在夜跑覆盖内——固化时在 e2e 目录留 `AC-N.cua-manual` 占位标记（记录该 AC 靠什么人工/对照评手段回归），防"全集绿"被误读为全覆盖。全过 → merge。

系统层夜跑（每晚/合并前触发）：非 Claude Code hook，独立 CI 任务（**P2+/P3 阶段交付，当前不可用，见 §0.2**）。判定以结构化硬门信号为准（视觉对照不阻断，§2.5）。

---

## 3. 横切机制

### 3.1 测试可写性矩阵

**原理：测试耦合于什么，决定它能随什么而改；保护什么，决定绝不能随什么而改。**

- **行为层** = `e2e/` 全部 + `BUG-*` 回归测试（**BUG-* 一律放 `e2e/` 下**，如 `e2e/regression/BUG-{id}_*.spec`——不散落其他测试目录，否则 implementer worktree "不挂 e2e/" 与 merge gate 的保护均覆盖不到）。只通过界面/接口/存储效果说话，不 import 内部函数。**归 evaluator 所有；既有修改对 implementer 的防线**：worktree 不挂 `e2e/` 防无意耦合（advisory，§0.1）+ merge gate 拦 task 分支的 e2e 变更入主分支（硬，§3.4）。`BUG-*` 新增属 fix 流程（先红后绿的观察主体是 leader，§2.1），由 evaluator 验收时写或 implementer 产 patch 附 report 由 leader 落盘——implementer 不直接落盘到 `e2e/`。
- **结构层** = implementer 的单元/组件测试，耦合于函数名、模块路径、内部接口。**归 implementer 所有。**

| | 行为层（e2e/ + BUG-*） | 结构层（单测） |
|---|---|---|
| **feat** | 只有 evaluator 可新增；改既有 = spec 变更，人批 | 自由新增；改既有断言走归因 |
| **fix** | 新增回归测试（先红后绿）；既有测试**供奉了 bug** 时改它属归因"测试写错"，须写明依据（INV-x/用户报告） | 同左 |
| **refactor** | **完全冻结**（等价性法官） | **机械适配自由**（import/调用/mock 挂载点跟改）；**断言期望值不许变**——变了 = 行为变了 = 自动重归类为 feat/fix 回走 spec 流程（免费的偷改行为检测器）；删除需 reviewer 确认覆盖仍在更高层 |
| **perf** | 冻结 + 允许新增 benchmark | 同 refactor |
| **style** | formatter 纯格式放行；语义变更冻结 | 纯格式放行（formatter 改测试也只动格式，不触断言）；语义变更冻结 |
| **test** | 归 evaluator 操作 | 开放，逐条断言归因 |

hook 执行粒度：**按路径分强度**（e2e/ 与 BUG-* 主会话硬阻断；subagent 场景真正的强制在 merge gate（§3.4），hook 只是主会话第一道；普通 *.test.* 走警告层）；**警告层按行分敏感度**（只动 import/setup/调用行静默放行，改名零摩擦防警告疲劳；触碰 expect/assert 行强制说明理由）。归因协议管的不是"改没改"，是"凭什么改"。（lite 无 hook 也无 merge gate——无分支拓扑，此段矩阵作为 reviewer 判定依据内联进 reviewer lite 分支，§5.7）

### 3.2 issues 机制

**一切"现在不修"的问题必须有档案，禁止只存在于对话里。**

五入口：review 两轮到顶残留（§2.4）；reviewer 范围外发现；evaluator 范围外发现/非阻断可用性建议（§2.5）；系统层夜跑失败（§2.7）；定期体检产出（§3.3）。

**P 级（P0-P3）是 issue 排期语义**，落 issue 时赋值。review 不按严重度分流——范围内问题修（fix 循环），范围外问题落 issue。**落盘者赋 P（统一协议）**：reviewer 范围外发现写进返回文本暂存段（reviewer 无 checkout，不直写 `issues/`）→ leader 收口时落盘 `issues/` 并赋 P；evaluator 范围外发现同走"草稿写 acceptance → leader 收口落盘赋 P"（§2.5）；夜跑/体检由脚本直接落盘赋 P。optriage 每 task 收尾复核可升降级（分诊需全局视野，是 P 级最终裁定者）。P0 只能由人或 optriage 复核确认（阻断语义重，不许 agent 单方面赋 P0 后静默放行——赋了就会触发阻断检查，语义自洽）。

```markdown
---
id: I-20260702-01
title: 会话列表 200+ 会话滚动掉帧
source: evaluator 范围外（T0003 验收）    # review 两轮到顶 / reviewer 范围外 / evaluator 范围外 / 系统层夜跑 / 定期体检
spec: T0003
severity: P0 | P1 | P2 | P3            # P0 阻断上线 / P1 下个 spec 前必修 / P2 排期 / P3 可容忍
tags: [tech-debt]                       # 可选，与 P0-P3 正交
status: open | triaged | converted | closed
converted_to: T05                       # 转 task 后填对应 TID
blocks_merge: true | false              # P0 默认 true；P1 默认 false；用户显式豁免需记 decisions
---
```

铁律：**issue 不直接改代码，转正式 task 后走对应 change type 流程**（fix 带回归测试先红后绿）——issues 是登记处不是免检通道。每 task 收尾时 optriage 一次；**P0 进结束报告标注**（heavy/lite 同步，A18）：不事中阻断归档，用户报告后处置（转修复 / 显式豁免记 decisions / `git revert` 整批）。P1 默认进入下个 task 前必修；若用户显式豁免，必须记录 decisions。

### 3.3 机械护栏

防"偷偷改绿"按强度排序。**前提**：hook 的 deny 对 subagent 整体失效（§2.5 前提），implementer/evaluator 均为 subagent——主防线靠 **merge gate（§3.4）+ 结构 + CI 层**；hook 拦截仅主会话 leader 场景有效，作 advisory。各防线实现状态见 §0.2 能力矩阵，本节只写机制。

1. **merge gate + 行为层保护**（写入硬底线，§3.4）：`e2e/**`（含 BUG-*）+spec+`op_blueprint/`+decisions.md 的 task 分支变更在 merge 时机械 REJECT；合法变更各走专属通道（spec 变更子流程 / e2e leader 入口 / closer 提案）。implementer worktree 不挂 `e2e/` 防无意耦合（advisory，§0.1）。归因经 report 由 closer 提取记 decisions.md（§2.4）。**对称地，evaluator worktree 挂载 `e2e/`（用于固化 PASS 测试），但无 `src/**`**（详见 §2.5 结构隔离层）。
2. **访问隔离**（结构性，详见 §2.5）：evaluator 仅接触 spec + 构建产物 + baselines——靠 worktree 无 src 实现（advisory，防无意耦合，§0.1）。
3. **机器证据**：PostToolUse[src/**] 自动跑受影响测试（仅主会话 leader 场景有效，subagent 场景完全不触发）；subagent 靠 **SubagentStop**（matcher 按 agent_type 过滤）检查 tasks_list.json 状态 + 新鲜测试输出，缺则拒收工——只验"存在"不验"真伪"。hook 脚本开头必检查 stdin 的 `stop_hook_active` 字段防递归；禁 --no-verify。结构层单测明确不设防，由行为层兜住。
4. **spec 写保护**（merge gate 为主，git 原生辅助）：approved 的 spec 路径变更被 merge gate REJECT（task 分支侧，硬）；主分支侧 git pre-commit 拦 leader 误改 + 主会话 PreToolUse 拦截（走 §2.4 变更子流程）；/oprun 启动时 git diff --quiet 校验，防"好心更新规格"漂移。
5. **警告+留痕**（advisory 兜底，仅主会话生效）：结构层测试编辑按行敏感度——import/setup/调用行静默；expect/assert 行强制说明理由。危险模式：删除/反转 expect、toBe→toContain/正则/>=、timeout/阈值增大、.skip/.only、删测试文件或 it 块、test 文件加 eslint-disable。价值在曝光不在阻止；subagent 场景靠 reviewer 双裁决兜。
6. **定期体检**（每周/CI 异步，独立 CI 任务，**P3 交付，当前不可用**）：skip/only 计数、timeout 增幅、恒假断言、纯存在性断言 E2E；触碰不变量模块抽样跑变异测试（杀不死变异体的测试判假重写；**骨架 `scripts/op_mutation_check.sh` 做 == ↔ != 变异自检，专业变异测试用 mutmut/stryker**）。产出落 issues（§3.2）。调度/工具选择随 P3 定。

**防线层 ↔ 实现手段映射**（⚠️ 主防线 1/2/3 的 hook 拦截仅主会话 leader 场景有效——配齐 hook ≠ 安全）：

| 防线层 | 实现手段 | §4.1 Claude hook？ |
|---|---|---|
| 1 merge gate + 行为层保护 | leader 唯一主分支写入口 + `op_merge_gate.sh` 受保护路径零 diff（§3.4）+ worktree 不挂 e2e（advisory） | ❌ 非 hook（git 拓扑 + 脚本） |
| 2 访问隔离 | evaluator worktree 无 src（advisory，防无意耦合，§0.1/§2.5） | ❌ 非 hook（结构） |
| 3 机器证据 | PostToolUse[src/**] + SubagentStop | 🟡 hook（仅主会话，subagent 失效） |
| 4 spec 写保护 | merge gate（task 分支侧）+ git pre-commit + 主会话 PreToolUse（主分支侧） | 🟡 半 hook（gate + git + hook） |
| 5 警告留痕 | 主会话 PreToolUse[Edit/Write] 行级敏感度 | ✅ hook（仅主会话，subagent 失效） |
| 6 定期体检 | 独立 CI 任务 | ❌ 非 hook（CI） |

### 3.4 git 拓扑与主分支回流协议（merge gate——写入硬底线所在；**P1 交付，op_merge_gate.sh 当前未落地，见 §0.2**）

**为什么这节是安全模型的生效点**：pre-commit 拦不住 subagent（hook 失效，§2.5 前提）、implementer 在自己分支上 git 层保护全部无效、sparse-checkout 只防无意耦合（§0.1）。链条推到底：**唯一在被监督者控制之外的检查点是 leader 把分支合回主分支的时刻**。证据须在被监督者控制之外，故把这个时刻升为一等机制，而非工程细节。

#### 角色 × 文件系统视图

| 角色 | 工作位置 | checkout 形态 | 分支 |
|---|---|---|---|
| leader | 主会话，主 worktree | 完整 checkout | 主分支（唯一写入口） |
| op-implementer | 独立 worktree | sparse：排除 `e2e/` | `op/task/{TID}`（从主分支头切出） |
| op-evaluator | 独立 worktree（基于 task 分支切出） | sparse：排除 `src/**`+task 目录+decisions.md | `op/task/{TID}`（验收在 task 分支，eval worktree 同分支 sparse 隔离） |
| op-reviewer | 只读，不需要 checkout | 读 leader 提供的 review-package（diff + report + spec + workset 对照表，脚本生成）；review 结论在返回文本末行给出，**由 leader 落盘到主分支 `tasks/{TID}/review.md`**（单写者 = leader；task 分支对 review.md 变更被 merge gate 白名单 REJECT，implementer 不碰——Fix-N 并入 report.md） | — |
| op-closer | 主 worktree 内工作（heavy） | 完整（只写 `decisions.md` + `issues/` + `acceptance/{TID}/` 提案，权限清单 §2.6） | 主分支（写入经 leader commit） |

流程文件（tasks_list.json / checkpoint / issues / decisions.md / review.md）**只在主 worktree 一份物理副本**，implementer/evaluator worktree 不挂 `op_execution/`+`op_record/`，例外仅三处：task 目录挂给 implementer 写 **report.md（不含 review.md——review.md 单写者 = leader，主分支落盘）**；`op_execution/specs/{TID}_{slug}.md` 只读挂给 implementer（dispatch 指针指向 spec 路径，§1.1）；`op_execution/acceptance/{TID}/` 挂给 evaluator（其唯一可写流程目录）——消除"worktree 副本独立导致下一个 agent 看不到写入"的根源。**tasks_list.json 不挂给任何 subagent**——workset/depends_on 由 dispatch 脚本提取注入 prompt/review-package。

#### 回流协议（per-task）

1. **切出**：leader 从主分支头创建 `op/task/{TID}` + implementer worktree（`op_worktree_setup.sh dev`）。**记录 dispatch 锚点 sha**（= 主分支头；lite 下作 reviewer diff 锚点，防 implementer 自行 commit 致 diff 空）。
2. **实现**：implementer 在自己分支自由 commit（多轮 fix 的中间 commit 都留在 task 分支）；测试证据写 report.md；FAIL 轮 Fix-N 也写 report.md（不进 review.md）。
3. **review**：reviewer 读 review-package（report + 三点 diff + spec + workset 对照表），diff ref 对固定为 `dispatch 锚点 sha...op/task/{TID}`（heavy）/ `dispatch 锚点 sha...工作区`（lite）。fix 轮同分支追加 commit，re-review 同 ref 对。verdict 由 leader 落盘主分支 review.md。
4. **验收（merge 前验）**：双裁决 PASS 后派 evaluator 在 task 分支验（构建产物从 task 分支构建）。验收 FAIL 同分支续做修复（≤3 轮）；验收 PASS 才进 merge gate。非行为型 task 免派（§2.4）。
5. **merge gate（机械校验，`op_merge_gate.sh`，PASS 才许合；白名单）**：
   - **白名单允许触碰**：workset ∪ `tasks/{TID}/report.md` ∪ 结构层测试路径（`*.test.*` 等实现侧测试）。**其余一律 REJECT**——含 `tasks/{TID}/review.md`（leader 主分支写）、`op_execution/specs/**`、`e2e/**`、`op_blueprint/**`、`op_record/**`、tasks_list.json、issues/、progress.md、leader_checkpoint.md。合法变更走专属通道（spec 变更子流程 / e2e leader 入口 / closer 提案）。
   - review verdict PASS 存在（读**主分支** review.md 末行）。
   - 工作集越界：实际 diff 文件集对照注入的 workset，超限即 REJECT（advisory 升硬）。
6. **squash-merge**：leader `git merge --squash op/task/{TID}` → 单 commit 进主分支（兑现 task 即 commit）；commit message 引用 TID+验收标准。**冲突处置**：串行执行下主分支自 task 切出后仅有 leader 的流程文件 commit，src 冲突理论不发生；一旦发生（切出后主分支动过 src）→ 停下按 spec 变更子流程处理，**leader 不代 implementer 解决 src 冲突**（避免 leader 写实现代码，越权且上下文污染）。
7. **收尾**：closer 一段式收尾 + 闸门 C 归档（§2.6，此时删 task 分支与 worktree）。

**evaluator 产物回流**：验收在 task 分支验，固化 PASS 测试写 **evaluator worktree 的 `e2e/`**（§2.5，evaluator worktree 挂载 e2e/）；leader 审后经专属通道合 e2e 进主分支（merge gate 白名单对 task 分支 e2e 变更一律 REJECT，eval 产物走 leader 入口）。**验收报告/baselines/issue 草稿写 `op_execution/acceptance/{TID}/`**（evaluator 唯一可写流程目录）。

---

## 4. 工程部署

### 4.1 插件结构与安装

> **安装模型**（非 Claude Code plugin 市场机制）：用户 git clone 本仓库 → 跑 `bash install.sh` **一次装齐**两模式全部 skill+agent 进 `~/.claude/`（`--set-ophome` 将 OP_HOME 写入 `~/.claude/settings.json` env 段，heavy 需要；只用 lite 可省；`--link` 开发模式软链）→ **按项目 init 选模式**：项目内跑 `/opinit`（heavy：三区骨架 + profile=heavy + hooks 注册）或 `/oplinit`（lite：三区骨架 + profile=lite，不加 hook 不碰项目配置）。同一项目只认一个 profile（§5.2）。skill/agent/hook/脚本通过 `$OP_HOME`（heavy）或 `${OP_SCRIPT_ROOT:-$OP_HOME}` fallback（两版共用 agent，§5.4）引用资源，使用方项目数据走 `$CLAUDE_PROJECT_DIR`（Claude 内置）。

```
对外 skill（7）——用户心智模型："装一次、每项目 init 一次、进料、跑、看"
  heavy 入口（3）:
    opinit      heavy 初始化（一次性）：三区骨架 + profile=heavy + hooks 注册
    opintake    需求入口：分拣 → spec（含设计探索+可测性契约）
                → 闸门 A → 自动拆 task → tasks_list.json 写入 `status=ready` 的 task ══ 终点：task ready（待开始）
    oprun       从 checkpoint 续跑：task 循环（review → merge → per-task 验收 → closer 收尾 → 闸门 C → 归档）
                leader 即 controller，被本 skill 驱动
  lite 入口（3）:
    oplinit     lite 初始化（一次性）：三区骨架 + profile=lite（零侵入：不加 hook、不改项目配置与已有文档）
    oplintake   需求入口：spec + 拆 task + 闸门 A（脚本自包含）
    oplrun      task 循环（leader 自验代 hook）→ evaluator 裸评 → P0 检查 → 归档
  两版共用入口（1）:
    opstatus    读 tasks_list.json + checkpoint，渲染人类可读状态报告（profile 感知）

内部 skill（3，两版共享）
  opspec      模板+假设先行+不变量强制+内联设计探索+可测性契约（profile 感知：lite 不要求 blueprint 映射）── opintake 调用
  opred       红灯归因协议 ── implementer/reviewer 共同引用
  optriage    issue 分级与转 task ── leader 收尾时调用（留此不并入 closer：分诊需全局视野）

agents（4，装 ~/.claude/agents/，两版共用文件——环境入口 profile 化 fallback，§5.4）
  op-implementer    读 spec + jq tasks_list 元数据，TDD 实现，写 report（顶部总报告+分轮追加）；
                    设计 task 复用之（dispatch prompt 指明"只产方案纸"，派发仍按 OP_*_MODEL 规则）
  op-reviewer       双裁决：规格合规 + 测试可信（lite 分支内联可写性矩阵最小集）
  op-evaluator      验收方（Stage 3 循环内）：智能评估→固化→破坏检查→对抗探索
                    hard-pass gate + 预期失败模式 + 访问隔离（lite 分支：裸评退化，§5.7）
  op-closer         heavy 独有（lite 不派发）。一段式（per-task，验收 PASS 后）：产 blueprint_update.md
                    提案（diff 覆盖 op_blueprint 全部文档 + baselines 合入段 + task 归档，吸收验收结果）+ append decisions.md + 转暂存 issue；对 op_blueprint 无写权（closer gate 机械校验）

hooks（heavy 独有；⚠️ deny 对 subagent 整体失效——下列 hook 仅主会话 leader 场景作 advisory 生效；subagent 写入强制靠 merge gate §3.4、读取隔离靠 worktree 结构 §2.5；lite 零 hook）
  PreToolUse[Edit/Write]   主会话守门（subagent deny 失效）：spec 写保护/op_blueprint 写拦截（仅 leader 审批流程可写）/行级敏感度。e2e/**+BUG-* 主会话 advisory；subagent 侧由 merge gate 拦（§3.4）
  PreToolUse[Task]         dispatch 协议 advisory 留痕：fire 能读 dispatch prompt 记日志，deny 拦不住 launch；不作拦截主张
  PostToolUse[src/**]      主会话场景自动跑受影响测试留证据；subagent 场景不触发，靠 SubagentStop 兜（验存在不验真伪，§3.3 第 3 层）
  SubagentStop             完成门禁（拦 subagent 交工，matcher 按 agent_type 过滤）：检查 tasks_list 状态 + 新鲜测试输出，缺则拒收；脚本开头必检查 stdin 的 stop_hook_active 防递归
  Stop                     leader 收尾门禁：状态 + 新鲜证据
  PreToolUse[Bash]         主会话拦 --no-verify 及危险 git 操作

scripts/（确定性计算全归 bash，不留给模型；lite 自带副本与差异见 §5.5）
  工作集清单核算 / review-package 生成（含三点 diff，§3.4）/ eval brief 机械组装（op_assemble_eval_brief.sh，lite 裸评简化版）
  / op_worktree_setup.sh（dev/eval 挂载范围）/ op_merge_gate.sh（受保护路径零 diff 校验，§3.4）
  / op_close_pre.sh + op_close_post.sh（per-task 收口；lite 砍 op_close_pre，见 §5.5）/ tasks_list 读写 / checkpoint 读写
```

**用户旅程**：`install.sh` 一次（全局）→ 每项目 `/opinit` 或 `/oplinit` 一次 → 每需求 `opintake`/`oplintake "..."` → 批 spec（闸门 A）→ `oprun`/`oplrun` → 中途 `opstatus` → heavy/lite 都事后报告（oprun/oplrun 结束生成"验收报告 + spec 变更决策表 + P0/P1 issue"）。两个命令干活，一个看状态，人只在闸门 A 点头一次 + 看结束报告。

### 4.2 分阶段交付路径

> 条目实现状态查 §0.2 能力矩阵；本节只写各阶段交付内容与**该阶段系统诚实定位**。

**P0（第一阶段，零基建）**：install.sh + opinit/oplinit 双 init；change type 测试规则 + spec 模板与命名约定（含可测性契约，task:spec 1:1）+ 闸门 A + 审批即 commit；tasks_list + task=commit；红灯归因、可写性矩阵、review 两轮上限、契约边界规则进 RULES.md/test.md；完成必须贴测试输出；issues 手工登记。**worktree 隔离可行性验证启动**（evaluator/implementer worktree 挂载范围 + sparse-checkout 跨平台验证——Linux/macOS/Windows Git Bash/WSL 行为差异）。**验证通过是 P1 落地的前置**。
**→ 此阶段系统是什么**：spec 纪律 + reviewer 双裁决 + 状态机。无独立验收（evaluator 人工降级）、无防篡改强制（全靠角色提示词 + 人审）——价值主张是"结构化的开发流程"，不是"防作弊的开发流程"。

**P1（第二阶段，git 拓扑 + merge gate）**：**分支拓扑与回流协议落地（§3.4）：task 分支 + `op_merge_gate.sh` 受保护路径零 diff 校验 + leader squash-merge 唯一入口**——写入硬底线就位；implementer/evaluator worktree sparse-checkout（advisory 防无意耦合）；证据链；spec 写保护并入 merge gate + git pre-commit；checkpoint/tasks_list.json（/oprun 启动读取重建进度，spec 漂移复查同在 /oprun 启动跑）；行级敏感度警告（主会话 advisory）；SubagentStop 完成门禁 + stop_hook_active 防递归；scripts/ 基础套件。
**→ 此阶段系统是什么**：P0 + 写入侧防篡改闭环（受保护路径变更进不了主分支）。读取侧仍 advisory、测试证据仍可伪造、独立验收仍降级。

**P2（第三阶段，持续演进）**：生效规格与 domain.md 沉淀；变异测试体检；issues triage 节奏；模型升级后审视护栏做减法。**独立验证环境增强**（独立机器自由操作 UI）。baseline 快照（evaluator 固化 PASS 时存）随验收机制上线即建，系统化对照评延后至此阶段。

---

## 5. lite 模式

> **lite 安全声明见 §0.1**：两版同靠 reviewer 双裁决 + evaluator 验收兜底。

系统切两层：

- **执行内核**（干什么、判定标准）：spec、验收标准/不变量、TDD、双裁决、验收对抗、状态机、Agent 职责——**与模式无关，共享**。
- **环境集成层**（怎么装、怎么校验、脚本怎么定位）：安装、证据校验、脚本寻址、blueprint 来源、闸门数、收口角色——**heavy/lite 全部差异收敛在此**。

差异面压缩到环境集成层，两版最大复用，Agent 与 spec 逻辑单点维护，同步演进。

**lite 的定位**：degraded mode，不是 heavy 同等安全版——无 hook、无 worktree 隔离、无 baseline 对照、evaluator 裸评（**evaluator 验收独立性显著弱于 heavy，详见 §5.7**）。用它换零侵入。

### 5.1 两版差异面（收敛后 6 点）

| 维度 | heavy | lite |
|---|---|---|
| 项目 init | `/opinit`：三区骨架 + profile=heavy + hook 注册 + 归档旧文档 + 重构 CLAUDE.md | `/oplinit`：三区骨架 + profile=lite（不加 hook、不碰项目配置与已有文档） |
| git 拓扑 | task 分支 + merge gate + leader squash-merge（§3.4） | 主分支直改（无分支/worktree/merge gate；收口前 leader `git add {workset}`）——写入防线整体退化为 leader 亲验 |
| 证据校验 | hook 机器强制（advisory，§0.2）+ merge gate（硬，§3.4） | leader 每轮亲自验证（§5.9） |
| 脚本/环境入口定位 | `$OP_HOME` | `${OP_SCRIPT_ROOT:-$OP_HOME}` fallback，lite 指向共享 scripts 目录（install.sh 装的 `~/.claude/scripts/omni_powers/`，§5.4/§5.5） |
| blueprint 来源 | 提炼用户 CLAUDE.md/docs/代码 | 无 blueprint 真相源，只建自己的树（连锁退化见 §5.7） |
| 闸门 | A + C 两处人工批复 | 默认 A 一处 + P0 阻断检查（§5.8）；异常仍升级人裁 |
| 收口角色 | op-closer 独立 Agent | leader 代劳（减 closer） |

**其余流程骨架共享**：三执行 agent 职责、spec 模板、双裁决、状态机（lite 去"收口中"态）、depends_on、compact 恢复；**安全/证据能力按 §5.7 退化**（evaluator 验收 lite 裸评，不共享 heavy 的隔离/baseline 对照）。

**lite→heavy 迁移不是切 profile。** 迁移 = 显式重初始化，最小步骤：跑 `/opinit`（hook 注册 + blueprint 骨架 + profile 改写，需处理 profile 互斥 die——用户显式确认迁移意图后清 profile 重写）；blueprint 补建（blueprint-generator 从已有代码 + `op_execution/specs/` 归档提炼生效规格）；已归档 spec 的功能归属核对（lite 期无 blueprint，迁移后 closer/leader 据代码 + spec 重新判断归属功能）；关键 task E2E 重跑 + 按 heavy 标准补 baseline（lite 期无 baseline，跨迭代回归从迁移点起算）。有代价，不可无缝。

### 5.2 profile 机制

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
| 已有 `docs/omni_powers/` 但无 profile | **默认 die，要求用户显式跑 /opinit 或 /oplinit 指明**；不自动推断。若必须兼容旧版本，仅凭项目内 hook 配置痕迹（heavy 独有的 .claude/hooks 注册记录）判定——**禁用 `$OP_HOME` 与 op_blueprint 实体探测**（lite 也建 op_blueprint 空壳，$OP_HOME 是全局环境，均非项目级证据） |

入口校验：opintake/oprun/oplintake/oplrun 均在步骤零校验 profile，模式不符则 die。

### 5.3 零侵入的精确边界

lite「零侵入」= **不侵入用户项目**：不加项目 hook + 不改 Claude Code 配置 + 不改用户项目已有文件（**含 CLAUDE.md——故 lite 无自动发现：新会话/compact 后无 SessionStart 注入（A17 已去）、无 CLAUDE.md 指路，靠用户手动 `/oplrun` 触发，skill 读 profile + checkpoint 重建状态，D8**）。全局 `~/.claude` 的一次性全量安装（install.sh）是用户主动配置，不算侵入。允许的写入：

| 允许写入 | 说明 |
|---|---|
| `~/.claude/skills/`（install.sh，两模式全部 skill） | 新增，不覆盖用户已有 |
| `~/.claude/agents/op-*.md`（install.sh） | 四角色 agent 定义（新增，供 `subagent_type` 派发） |
| 项目内 `docs/omni_powers/`（含 `docs/omni_powers/e2e/` 验收资产）（oplinit / 运行期） | 新增独立子目录，不改用户已有文档。**lite 验收 E2E 默认写 `docs/omni_powers/e2e/`（零侵入，不进用户测试 runner 自动发现）；用户显式同意才写顶层 `e2e/`**（heavy 路径，见 §1） |

lite 禁止写入：

| 禁止 | 原因 |
|---|---|
| `~/.claude/settings.json` | lite 不需要 hook、不需要 `$OP_HOME` env（heavy 用户跑 `install.sh --set-ophome` 才写） |
| 用户项目已有文件（CLAUDE.md/README/docs/*） | 不归档、不重构、不提炼作 blueprint |

### 5.4 环境入口 profile 化（两版共用一份 agent 文件）

**现状**：三执行 agent（implementer/reviewer/evaluator）的环境检查入口已用 fallback 写法（下）；仅 closer 保留硬编码 `$OP_HOME`（heavy 独有，OP_SCRIPT_ROOT 不注入 closer 正确）。lite 无 env 可依，靠 dispatch 注入 OP_SCRIPT_ROOT。

**解法：fallback 变量写法**：

```bash
# agent 内 op_script() 双路径 resolver（heavy 脚本分 scripts/ 与 skills/oprun/scripts/，lite 共享目录平铺；单行 fallback 不够，必须用 resolver）：
#   op_script() {
#     local root="${OP_SCRIPT_ROOT:-$OP_HOME}"
#     for d in "$root/scripts" "$root/skills/oprun/scripts"; do
#       [ -f "$d/$1" ] && { bash "$d/$1"; return $?; }
#     done
#     echo "FATAL: $1 not found under OP_SCRIPT_ROOT" >&2; exit 1
#   }
```

- **变量约定**：`OP_SCRIPT_ROOT`（脚本根）+ `OP_PROFILE`（`heavy`|`lite`）。leader dispatch prompt 里注入，agent 读它。
- **heavy 现状不动**：`OP_SCRIPT_ROOT` 未注入时 fallback 到 `$OP_HOME`，heavy 行为零变化。
- **lite 共享脚本**：`OP_SCRIPT_ROOT` 指向 install.sh 装的共享目录 `~/.claude/scripts/omni_powers/`（与 heavy 同源脚本，profile 分支判定差异，§5.5）。
- 实现细节：agent 内 `op_script()` 双路径 resolver（heavy 脚本分 `scripts/` 与 `skills/oprun/scripts/` 两目录、lite 平铺，单行 fallback 不够）。
- **前置探活（避免延迟失败）**：三执行 agent 在 resolver 后立即校验根目录存在——`${OP_SCRIPT_ROOT:-$OP_HOME}` 解析结果为空或目录不存在 → agent 输出明确 FATAL 并停在首个脚本调用前，不在后续零散脚本调用处才失败（错误定位成本高）。
- agent 派发机制两版相同：`subagent_type: "op-implementer"`。**agent markdown 是静态文件，靠 fallback 写法两版共用一份**。

### 5.5 lite 脚本定位（共享目录）

lite 与 omni_powers 仓库物理分离，但 **install.sh 已统一装 `~/.claude/`**——同时落一份共享 scripts 目录供 lite 固定路径引用，**消灭 per-skill 副本同步机制**（旧方案 B 的 `build_lite.sh` 副本校验 + 三份 `op_check_env` 互检不再需要）。

**安装模型**：`install.sh` 装 `~/.claude/scripts/omni_powers/`（heavy + lite 共用脚本根）。lite skill 不再各自带 `scripts/` 副本，SKILL.md 与 agent.md 统一用 `${OP_SCRIPT_ROOT:-$OP_HOME}` fallback（§5.4）定位到这份共享脚本。

**脚本 profile 入口约定**：heavy/lite 两版共用的脚本必须在入口校验 `OP_PROFILE` 存在且为已知值（heavy|lite），未知值 `die` 而非静默按 heavy 路径执行——防新增脚本只考虑 heavy 致 lite 静默异常。

**lite 脚本差异收敛在脚本内 profile 分支**（不再复制改造版，单份脚本内 `OP_PROFILE=lite` 判定）：

| 脚本 | lite 分支差异（脚本内 `OP_PROFILE=lite` 判定） |
|---|---|
| op_status.sh | 状态枚举去「收口中」 |
| op_coder_check.sh | 环境入口 fallback 变量 |
| op_close_post.sh | 跳过 `status=closing` 前置检查；完成态用 lite 状态机（§1.1） |
| op_check_env.sh | 只校验 jq/git（跳过 OP_HOME 段） |
| op_assemble_eval_brief.sh | 裸评简化：跳基线/baselines 段（§5.7）+ 剥探索结论 |
| close_check.sh | 完成态定义随状态机 |
| op_close_pre.sh | lite 不调用（其唯一职责标「收口中」，lite 无此态） |
| op_new_task.sh | lite 用 jq `.tasks += [{...}]` helper |

**删「收口中」态的因果链**不变：删状态 → lite 不调 op_close_pre → 收口是 leader 瞬时操作（review PASS 直接 op_close_post）。三者同一决策的三面，改任一处须同步另两处。

**副本同步淘汰（渐进，D5）**：install.sh 已装 `scripts/` 到全局 `~/.claude/scripts/omni_powers/`（heavy/lite 共用基础）；lite 副本（`skills/oplrun/scripts/`）暂保留并与 heavy 同步内容（ASCII/obsolete/删 skipped，A16/A20/D1）。**完整归并（删 lite 副本 + oplrun SCRIPTS 寻址共享目录）待重构**——lite 无 OP_HOME，共享寻址方案待定（`build_lite.sh` 暂留维护副本同步）。

其他实现补充不变：骨架模板由 `oplinit_skeleton.sh` 内联生成（无独立 templates/）；oplintake spec 模板内联进 SKILL.md（opspec 留 profile 感知段供直接调用兜底）；oplinit 写 `docs/omni_powers/.gitignore`（忽略 `*.lock`，只在自己子目录内）；oplrun 收口前 `git add`（按实际 diff 文件集）。

### 5.6 lite 状态机与工作流

沿用 heavy 的 task 状态机，**仅删「收口中」态**（收口在 lite 是 leader 瞬时操作，不占 task 态）：

```
pending → ready → in_progress → reviewing → done
  ↓             ↑ FAIL(≤2轮)
suspended ───────────┘
   2轮FAIL → blocked（下游保持 ready，调度器依 depends_on 不选中，不设 skipped 态）
```

- 不新增「验收中」task 态。evaluator 验收是 **per-task 阶段活动**（每 task 收口后跑一次），不是 task 状态——与 heavy 模型一致。
- 状态语义（含义/blocked_by/阻塞传播/挂起/回滚）完全复用 RULES.md，lite 只在 profile 分叉段声明「无收口中态」。

**lite 入口流程**（与 §2 heavy 流程同构，差异见 §5.1）：

```
/oplintake "<需求>"：
校验 profile=lite（非则 die；骨架职责在 /oplinit，与 heavy opinit 对称）
spec 编写：leader 主会话按模板生成 op_execution/specs/{TID}_{slug}.md（验收标准 + 不变量 + 内联设计探索）
拆 task 写 op_execution/tasks_list.json（depends_on 机读）
【闸门 A】呈报全部 task spec + 拆分给用户审（预算同 heavy：15-30 分钟/需求）
   人批 → status: approved（无 git 写保护 hook；靠约定 + git diff 可回溯）
终点：task status=ready，写 leader_checkpoint.md，交给 /oplrun

/oplrun：
读 profile（校验 lite）+ leader_checkpoint.md + jq 查 tasks_list.json
循环（每 task，选 depends_on 全 done、ID 最小，严格串行）：
  派 op-implementer → TDD → tasks/{TID}/report.md
  leader 亲自验证（§5.9）：读 report evidence 路径 + 跑测试命令读 verdict + 读关键 diff hunk
  派 op-reviewer → 双裁决 → tasks/{TID}/review.md（末行 verdict）
    （lite diff 来源：无分支拓扑，review-package 的 diff = leader 内联生成的 `git diff HEAD`——
     本 task 未提交变更对 HEAD，新增文件先 `git add -N` 纳入；无独立脚本，随 leader 亲验步骤一并做）
    ├─ FAIL → 回 implementer 修 → re-review（一轮；上限同 heavy 两轮）
    ├─ 两轮到顶仍 FAIL → blocked(quality)，写 issues，下游保持 ready（A16）
    └─ PASS → evaluator per-task 裸评（**验收前置，D6——先验 PASS 才 commit**）：派 op-evaluator（裸评退化，§5.7，A11 提示词级隔离）→ E2E + 验收标准逐条 + 破坏检查 + 对抗探索
        ├─ FAIL(≤3轮) → 修复 task 回流重验（到顶异常人裁）
        └─ PASS → leader 收口（git add 实际 diff + commit + 归档，§5.9/D6，无闸门 C）→ 下一个 task（P0 进结束报告不事中阻断，A18/§5.8）
全部 task 闭环 → oplrun 结束报告（A18）
```

### 5.7 blueprint 缺失的连锁退化矩阵

lite 无 blueprint 真相源，不只影响 closer——逐角色退化：

| 消费者 | 缺失的 blueprint 部件 | lite 退化形态 |
|---|---|---|
| op-implementer | architecture.md / conventions.md（定向包） | 无架构地图/编码规范，只能靠 spec 单文档 + 现有代码归纳 |
| op-reviewer | test.md（可写性矩阵、危险模式清单） | 判定依据内联进 reviewer lite 分支 prompt（从 §3.1 蒸馏最小集） |
| op-evaluator | specs/{feature}.md 生效规格 + baselines/ | **裸评退化**（下） |
| leader | baselines_index.md | 无二阶判断对照素材 |

**evaluator 裸评退化**——lite 分支显式定义：

- **能做**：逐条验收标准评估、跑/写 E2E、破坏检查、对抗探索（首次评）。**独立性靠提示词级隔离维持**（lite dispatch prompt + evaluator.md lite 分支强制"禁止主动 Read src/** 与 task 目录实现细节，E2E 期望只能从 spec 推导"，A11）——无文件系统隔离（evaluator 物理能读 src/，提示词约束是 lite 唯一防线，弱于 heavy 结构隔离；无法机械拦截有意规避）。
- **不能做**：worktree 结构隔离（evaluator 能读到 src/ 与 task 目录，防"抄实现"底线失效）、baseline 对照评、跨迭代回归检测。
- **实现**：evaluator.md 加 profile=lite 分支，跳过基准模式判定 / 存基准 / 重验对照逻辑（heavy 下是活代码，lite 下 skip）。
- **brief 组装 lite 形态**：lite 自带简化版 `op_assemble_eval_brief.sh`——只 cat 工作 spec + 验收标准 + 启动方式，跳过基线/baselines 段。不整段 skip（evaluator 仍需 brief），是简化。

**op_blueprint/ 占位规则**：lite 下 op_blueprint/ 为空壳，仅为路径兼容（避免共享脚本找不到目录）。**oplinit 在其中落一个单行 README**：「lite 模式：此目录非契约源，规格读 `op_execution/specs/`」——防 agent 把「目录为空」误推断为「项目无约定」。implementer 定向包、reviewer 判定、evaluator 生效规格/eval_brief **一律不读 op_blueprint/**。

**opspec profile 参数**：heavy 可引用 op_blueprint/specs 映射；lite 只生成 op_execution/specs/{TID}_{slug}.md 单份，不要求 blueprint 映射。功能归属（feature_key）闸门 A 阶段入 task spec frontmatter，closer/leader 只引用（D10）。

### 5.8 lite 的 P0 处置（事后报告，A18 同步）

heavy/lite 都事后报告（A18）：P0 issue 不事中阻断归档，进 oplrun 结束报告标注，用户报告后处置。lite 无 closer，但 P0 在 evaluator 范围外发现时落 `op_execution/issues/`（severity: P0），oplrun 结束报告汇总所有 open P0（issue 清单 + 来源 task + 阻断原因），用户三选一：转修复 task 回流 / 显式豁免（记 decisions，来源标记 leader-close）/ `git revert` 整批。P1 进 checkpoint 提醒（下个 spec 前必修）。

### 5.9 无 hook 的替代

**纪律替代**：

| heavy hook 职责 | lite 替代 |
|---|---|
| 校验"新鲜机器证据"防作弊 | leader 收 subagent 返回后**亲自跑测试命令 + 读关键 diff** 再判（比 heavy SubagentStop 强——leader 亲跑是独立复核，不是验文件存在） |
| `current_task` 注入 + SubagentStop 校验 | leader 循环内自持 task 指针，写 leader_checkpoint.md |
| spec 写保护 + merge gate 拦受保护路径（§3.4） | lite 无分支拓扑，无 merge gate；**spec 写保护机械校验**：oplrun 收口前对 `op_execution/specs/**` 跑 `git diff <dispatch锚点sha> -- specs/` 非零即停（A19——用 dispatch 锚点 sha 而非裸 git diff，防 implementer `git add`/commit 抹平）——堵 implementer 主分支直改 spec 致同源污染 |

**oplrun 收口机械补强（补预估 workset 与 commit 锚点两个洞）**：

- **按实际 diff add**：oplrun 收口 `git add` 用实际 `git diff` 文件集，非预估 workset——implementer 合法新增的 workset 外文件不会被丢出 commit（workset 是预估清单，偏差由 reviewer 抓，advisory）
- **dispatch 锚点 sha**：dispatch implementer 时记 HEAD sha，reviewer `git diff` 锚定该 sha 而非 HEAD——防 implementer 自行 commit 致 diff 空（review-package 整体失明）
- **dirty-tree 检查**：oplrun 验收 PASS 后、归档前跑 `git status`，非干净即停——防 evaluator 裸评后残留未提交改动污染下个 task
