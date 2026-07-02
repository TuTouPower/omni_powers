# Omni Powers Harness v6: Claude Code 全流程开发方案设计

> v6 基于 v5 的讨论与落地裁定，修订要点：
> ①**删除 Stage 2 验收先行**——evaluator 仅 Stage 5 介入一次（评估→固化→破坏检查），可测性契约降格进 spec 模板；"先红后绿"替换为破坏检查；
> ②**evaluator 访问隔离 + 刻薄化调教**——stock model 默认对 LLM 产出宽容，靠 hard-pass gate + few-shot 校准 + 偏差指令循环调教；
> ③**op-closer 提案制**——closer 产 blueprint_update 提案（diff 形态覆盖 op_blueprint 全部文档），直接追加 decisions.md，对 op_blueprint 无写权；oparchive skill 删除；
> ④**controller = leader 主会话**——不单设 agent，被 oprun skill 驱动；
> ⑤**模型参数化**——OP_*_MODEL 环境变量三档（haiku/sonnet/opus），未设继承主会话当前模型；
> ⑥**术语"信封规则"→"契约边界规则"**；
> ⑦**task 目录平铺**——brief/report/review 三文件，spec 在 op_execution/specs/ 叶子共享，report.md 顶部总报告 + 分轮追加；
> ⑧**删 using-omni-powers meta skill**，路由归 SessionStart hook。
>
> 两个核心病灶不变：①测试变绿 ≠ 功能正确；②agent 不理解功能背后的语义。

---

## 0. 设计原则

1. **规格是唯一契约。** 实现、测试、验收三方对着同一份人审过的工作 spec 干活，切断同源污染。
2. **两层规格，资产与工单分离。** 生效规格（op_blueprint/specs/）回答"系统是什么"，只收经实现和验收淬炼的结论；工作 spec（op_execution/specs/）回答"这次做什么"，用完归档。前者由后者喂养。
3. **能在 spec 期解决的难题，不留给执行期。** 方案设计在写 spec 时内联完成，人工触点合并进闸门 A；执行期不设新的人工阻塞点。
4. **契约边界规则：执行期决策分两种。** spec 约束范围内的决策（选库/选内部算法/选路径）→ agent 自决 + 记录 + 闸门 C 批量报审；需要改动 spec 文本的发现（INV 守不住/AC 做不到）→ 停下走 spec 变更子流程（人批）。分界线机械：该决策是否需要改 spec 文本。
5. **不变量优先于场景。** 工作 spec 强制填不变量，填不出即视为没理解需求。
6. **测试按耦合物分层，按保护物设防。** 行为层（E2E+回归）是"行为不变"的法官，永久锁定（归 evaluator，implementer 无写权限）；结构层（单测）随代码结构机械适配，断言是红线。只保证有一层防篡改且足以拦住 bug。
7. **证据由机器产出。** hook 自动跑测试留原始输出；无新鲜机器证据的"完成"声明无效。**bash 先算状态，LLM 再决策**——凡确定性计算（工作集核算/状态判定/diff 打包）都交脚本，不留给模型。
8. **plan 是分布式信息，不是文档。** 顺序依赖住 tasks_list.json + spec 末尾执行图；跨 task 决策住 spec；接口契约以代码形式先提交（编译器强制，严格强于文档签名）；工作集住任务卡（脚本核算的一等工件）。独立 plan 文档只会是这四处的过期复印件。
9. **task 即 commit；粒度由工作集决定。** 沿低耦合缝隙切。
10. **循环必须有上限，发现必须有去处。** review/fix 最多两轮；修不完的和范围外的统一落 issues。
11. **人只出现在两个位置：闸门 A（审 spec，含技术决策与可测性契约）、闸门 C（验收报告 + 自决决策表 + P0/P1 issue）。** 每叶子 spec 合计 5-10 分钟，只读自然语言；人不审文件/函数清单——那是杠杆错位。
12. **护栏按需付费，定期做减法。** 每个组件都是对"当前模型做不到"的假设，模型升级后重新审视。

---

## 1. 入口分拣：两个正交判定

### 1.1 写不写工作 spec？——三条判据（与 change type 无关）

命中任意一条就写：①**跨范围**（多模块/需拆 task）；②**改契约**（接口、数据模型、模块边界）；③**高代价**（数据损坏、不可逆迁移、性能回退、安全）。

三条全不中（改样式、加索引、改变量名、三行 fix）→ 不写 spec 不进 task 机制，契约就是任务卡一句话或那条回归测试，门禁只剩测试规则 + 机器证据 + commit。

例：测试框架迁移（refactor，中①②）、模块重划（三条全中）、核算算法更换（中③）→ 写 spec；查询加索引 → 直接干。**spec 与否看规模和风险，不看类型。**

### 1.2 change type？——只决定测试规则（§2）和退化流程形态

| 类型 | 流程形态 | 契约来源 |
|---|---|---|
| **feat** | 全流程（若写 spec）或轻量直做 | 工作 spec / 任务卡 |
| **fix** | 复现 → **先写必然失败的回归测试** → 根因 → 修 → 变绿（先红后绿，否则判假绿）；暴露规格缺失则补生效规格 | 那条回归测试 |
| **style** | 不进流程，formatter/linter | — |
| **refactor** | "行为不变"即契约；大型的写 spec，AC 是等价性验证 | 行为层测试套件 |
| **perf** | benchmark 基线 → 改 → 复测；大型的写 spec，AC 是量化指标 | benchmark 基线 |
| **test** | 断言变更逐条归因 | 既有 AC/INV |

---

## 2. 测试可写性矩阵

**原理：测试耦合于什么，决定它能随什么而改；保护什么，决定绝不能随什么而改。**

- **行为层** = `e2e/` 全部 + `BUG-*` 回归测试。只通过界面/接口/存储效果说话，不 import 内部函数。**归 evaluator 所有，implementer 永久无写权限。**
- **结构层** = implementer 的单元/组件测试，耦合于函数名、模块路径、内部接口。**归 implementer 所有。**

| | 行为层（e2e/ + BUG-*） | 结构层（单测） |
|---|---|---|
| **feat** | 只有 evaluator 可新增；改既有 = spec 变更，人批 | 自由新增；改既有断言走归因 |
| **fix** | 新增回归测试（先红后绿）；既有测试**供奉了 bug** 时改它属归因(b)，须写明依据（INV-x/用户报告） | 同左 |
| **refactor** | **完全冻结**（等价性法官） | **机械适配自由**（import/调用/mock 挂载点跟改）；**断言期望值不许变**——变了 = 行为变了 = 自动重归类为 feat/fix 回走 spec 流程（免费的偷改行为检测器）；删除需 reviewer 确认覆盖仍在更高层 |
| **perf** | 冻结 + 允许新增 benchmark | 同 refactor |
| **style** | formatter 纯格式放行；语义变更冻结 | 同左 |
| **test** | 归 evaluator 操作 | 开放，逐条断言归因 |

hook 执行粒度：**按路径分强度**（e2e/ 与 BUG-* 硬阻断，全局拦截——不查锁清单；普通 *.test.* 走警告层）；**警告层按行分敏感度**（只动 import/setup/调用行静默放行，改名零摩擦防警告疲劳；触碰 expect/assert 行强制说明理由）。归因协议管的不是"改没改"，是"凭什么改"。

---

## 3. 目录结构：omni_powers 三区制

**op_blueprint = "应该是什么"（稳定契约）；op_execution = "现在在干什么"（只放活的东西）；op_record = "发生过什么"（append-only）。**

```
<project>/
├── CLAUDE.md                        # ≤100 行：铁律摘要 + 指向 omni_powers/index.md
├── e2e/                             # 【代码，永久资产】按 spec 前缀分目录的验收 E2E 全集，系统层定期全量跑
├── omni_powers/
│   ├── README.md                    # 给人看的
│   ├── index.md                     # 给 agent 看的目录页（SessionStart 注入其摘要）
│   ├── op_blueprint/
│   │   ├── prd.md                   # 产品级需求纪要（grill-me 产出；各需求总意图）
│   │   ├── architecture.md          # 架构地图：分层、模块边界、跨模块契约（定向包主体）
│   │   ├── conventions.md           # 项目约定：编码/命名/提交/目录规范
│   │   ├── domain.md                # 领域模型 + 跨功能全局不变量（如"时间戳统一 UTC"）
│   │   ├── test.md                  # 测试宪章：可写性矩阵、红灯归因协议、危险模式清单
│   │   ├── spec_index.md            # specs/ 目录索引：功能清单 + 一句话说明 + 文件指引
│   │   ├── baselines/                # 【基准】各功能验收基准快照（leader 基于 closer 提案审批写入）
│   │   │   ├── index.md              #   基准索引：每 spec + AC 映射 + 更新说明
│   │   │   ├── b01_session/          #   按 spec 前缀分目录
│   │   │   │   ├── AC-2_login_error.png
│   │   │   │   └── AC-3_cleanup.txt
│   │   │   └── a_darkmode/
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
│   │   │                            #   spec 末尾附执行图（拆分后追加：task 依赖概览+接口 task 位置，≤10 行）
│   │   ├── tasks_list.json          # 【唯一 task 真相源】id/status/所属spec/覆盖AC/触碰INV/depends_on/
│   │   │                            #   风险探针/预计工作集（脚本核算）；人读走 opstatus 渲染
│   │   ├── tasks/                   # 活跃任务目录（每 task 平铺 3 文件：brief/report/review）
│   │   ├── issues/                  # 问题登记（含所属 spec 字段，技术债加 tech-debt 标签）
│   │   └── leader_checkpoint.md     # leader 检查点：当前活跃 spec、task 进度、下一步
│   └── op_record/
│       ├── decisions.md             # 设计探索全文、执行期自决决策（closer 直接 append，append-only）
│       ├── progress.md              # 每 task 完成一行（commit 区间+review 结论+AC 覆盖）
│       ├── specs/                   # 已归档工作 spec，平铺（前缀保留组关系）
│       └── tasks/                   # 已完成 task 的 brief/report/review + blueprint_update.md 归档
```

### 3.1 task 工作区（平铺，全部进 git）

```
docs/omni_powers/op_execution/
├── specs/{前缀}.md           # 工作 spec（叶子共享，全员只读。AC/INV/边界/技术决策/可测性契约）
├── tasks/{TID}/
│   ├── brief.md               # leader 生成（任务卡 + 定向包 + 指向 spec 路径，不复制 spec 全文）
│   ├── report.md              # implementer 写：顶部总报告（每轮覆盖为累积总结）+ 分 Round 追加（审计轨迹）
│   ├── review.md              # reviewer 写双裁决，FAIL 轮 implementer 追加 Fix-N
│   └── baselines/             # evaluator 产出的新基准快照（临时，待 closer 提案 + leader 审批后合入 op_blueprint）
├── tasks_list.json            # 唯一 task 真相源
├── leader_checkpoint.md
└── issues/
```

- spec 在 `op_execution/specs/{前缀}.md`，叶子共享，不在 task 目录。
- brief 指向 spec 路径（`工作 spec: op_execution/specs/{前缀}.md`），不复制 spec 全文——spec 是单源，brief 重复会失同步。
- report.md 顶部总报告（leader/reviewer 入口，一眼看当前状态）+ 下方分 Round 追加（FAIL 轮修复记录留得住）。一个文件，删除了 v5 的 context.md。
- 不设 gitignore、不设子目录（3 文件平铺），task 闭环后 git mv 到 `op_record/tasks/{TID}/` 归档。

### 3.2 两层 spec 流转与归档（按叶子，不等兄弟）

- **叶子级，即时**（收尾一部分）：b01 完成 → 精华立即并入生效规格（后续 b02/b03 引用它作基准）→ 原文入 op_record/specs/ → tasks_list 清出其 task。进入生效规格的是淬炼后的结论："待澄清"、被证伪的担忧不进；实现中发现的未预见边界行为要补进。
- **组级，延迟**：总述随最后一个叶子（或砍尾：剩余标 cancelled）归档，追加五行完成情况，前缀释放。

---

## 4. 全流程总览（对应用户旅程：opintake 管 Stage 0-3，oprun 管 Stage 4-6）

```
需求 ──► opintake "<需求>"
 │
 ▼ 入口分拣（§1）：change type + 三判据；三判据全不中 → 轻量直做，结束
 ▼ 尺寸测试：不能一次审完+一轮验收 → 拆 x_总述 + x01/x02 叶子（逐叶子走以下）
 ▼
[Stage 1] 工作 spec 编写（含内联设计探索 + 可测性契约，§5）
 │         ──► 【闸门 A：2-5 分钟】──► approved，写保护
 │
[Stage 2] task 拆分（opintake 内自动完成，§6）
 │         → tasks_list.json 就绪 + 执行图追加进 spec
 │         ──► 轻闸门 B（扫执行图，可跳过）══► opintake 终点："就绪"状态
 ▼
 ──► oprun（从 checkpoint 续跑）
[Stage 3] 逐 task 循环（§7）：brief → op-implementer → hook 证据
 │         → op-reviewer 双裁决（≤2 轮）→ op-closer 收口提案
 │         → leader 审批蓝图变更 + commit → checkpoint/progress 更新
 │         契约边界内决策：自决+记 decisions.md 打标记，不停
 │         破契约：spec 变更子流程（人批）
 │         （风险探针 task 完成后可插 ≤10 分钟小验收）
 ▼
[Stage 4] spec 级验收（§8）：op-evaluator（only Stage 5 介入）
 │         访问隔离：brief 只有 spec+生效规格+启动方式，不含 implementer 产物
 │         评估（hard-pass gate）→ 固化 PASS 测试 → 破坏检查 → 对抗探索
 │         → 逐 AC 报告；范围内 FAIL → 修复 task 回流；范围外 → issues
 ▼
[Stage 5] 收尾：全分支 review + AC 追溯矩阵 ──► 【闸门 C：1-2 分钟】
 │         呈报三样：验收报告 + 自决决策表（否了哪条转 rework）+ P0/P1 issue（人定阻不阻断）
 │         leader 做 evaluator 二阶判断 → 偏差指令 → 积累校准素材
 └──► merge → 叶子归档（§3.2）
```

Stage 2（验收先行）已删除。evaluator 仅在全 task 闭环后的 Stage 5 介入一次。"可测性契约"作为 spec 模板必填小节（§5.1），闸门 A 一并过审——零新增 agent、零独立 token 消耗。原来的"时序隔离 + 提前锁定"替换为"**访问隔离 + 破坏检查**"。

---

## 5. Stage 1：工作 spec（方案设计 + 可测性契约内聚于此）

### 5.1 模板

```markdown
---
status: draft        # draft → approved → in_progress → done / cancelled
type: feat           # feat | refactor | perf | ...（决定测试规则与 AC 侧重）
---
# <名称>
## 一句话意图
## 不变量（填不出 = 没理解需求；与 domain.md/生效规格冲突必须显式标注）
   <!-- refactor 型此区最长：列出所有必须保持的行为契约 -->
## 验收场景（Then 必须用户可观察；每条须可直接翻译为可执行断言）
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
   - AC-1 测试方式: {computer use / CLI / 截图断言}，关键入口: {URL / 菜单路径 / API 端点}
   - AC-N 测试缝: {如"需测试收件箱 → 需 Mailpit + seed 账号"; "需验证导出 → 需 stats export 命令"}
   - 预期失败模式（每 AC 至少 1 条——若 xxx 没做好，AC 应该 FAIL；evaluator Stage 5 对照此表逐条试反例）:
     - AC-1 若未正确实现则 {行为表现}，评估时专门试这个
     - AC-N 若未正确实现则 {行为表现}
## 待澄清 [NEEDS CLARIFICATION]（≤3 条，有则阻断）
## 执行图（拆分后由 opintake 追加：task 依赖概览 + 接口 task 位置，≤10 行，闸门 B 扫这里）
```

### 5.2 方案先行（设计探索，spec 期内联）

**触发信号（写 spec 时机械判定）**：①某 INV/AC 涉及"正确性需论证而非目测"的计算（核算、对账、并发一致性、时间切分）；②验收标准含"高效/准确/一致"等需算法保证的词。命中 → spec 编写（Opus）内联做设计探索，结论进技术决策区，**闸门 A 一次审完需求与方案，不另设人工点**。方案纸值得人多花两分钟——5 分钟拦返工 3 天。

**执行期兜底（信号③）**：implementer BLOCKED 或同一 task 两轮 review 不过 → leader 现场插设计 task（Opus，产方案纸不写码，reviewer 审，**不设人工门**）→ 结论记 decisions.md 打标记 → 继续 → 闸门 C 批量报审。

**契约边界规则**：执行期一切决策先问一句——**需要改 spec 文本吗？** 不需要（spec 约束内选库/选内部算法/选路径）→ 自决 + 记录 + 打标记，流水线不停；需要（INV 守不住/AC 做不到/契约要变）→ spec 变更子流程：agent 提 delta → 人批 → 重新 commit → 受影响 task 失效重拆。带着已知作废的契约继续跑，越跑返工越大——这是执行期唯一允许阻塞等人的情形。

### 5.3 其他规则

写 spec 前先输出假设清单一并供审；审批即 commit + 写保护；闸门 A 焦点：不变量覆盖沉默失败区（数据隔离/持久化/权限）、边界含竞态与失败路径、Then 全部可翻译为断言、技术决策无遗漏（拆 task 时发现某 task 产出约束他人而 spec 未写 = 打回补 spec）、**可测性契约完整**（测试缝全覆盖、预期失败模式每 AC 至少 1 条）。

---

## 6. Stage 2：task 拆分（opintake 内自动完成）

### 6.1 plan 信息的四归宿（替代 plan 文档的最终裁定）

| plan 信息 | 归宿 | 消费者 |
|---|---|---|
| 顺序与依赖 | tasks_list.json（机读）+ spec 末尾执行图（人扫） | leader / 人（闸门 B） |
| 跨 task 技术决策 | spec 技术决策区（人审） | coder / evaluator |
| task 间接口契约 | **接口先行 task 以代码提交**（类型/schema，编译器强制——严格强于文档签名，文档会漂移代码不会） | coder |
| 工作集（文件级） | 任务卡（**脚本 tokenize 核算的一等工件**，非 agent 拍脑袋） | leader（拆分预算/并行冲突检测/锁管理） |

三个消费者的裁定：**人不审文件/函数清单**（没有代码深度判断不了对错，拦截率≈0，杠杆全在行为层）；**leader 需要文件级工作集但纯属机械用途**；**coder 拿 spec + 任务卡 + 接口代码，函数级内部结构自定**——实际触碰文件与预估偏差过大时，reviewer 规格合规裁决抓范围偏航。

### 6.2 任务卡

```markdown
# T03：<语义级标题，一句 commit message 能说清>       状态: todo
所属 spec: b01    类型: 实现 | 设计 | 修复（来自 issue/验收 FAIL）
覆盖 AC: AC-1, AC-2    触碰 INV: INV-1（⇒ 对应验收 E2E 已锁定）
依赖: T01    可并行: 否    风险探针: 否
预计工作集: src/store/session.ts, ... （脚本核算 ~46K tokens）
## 完成定义（sprint contract）
- 行为: <可测试的行为描述>    - 验证: <哪些测试、哪条命令>
```

### 6.3 粒度判据（工作集，不是行数）

- token 消耗 ≈ 工作集 × 2-3；**拆分代价 = 被切开两半共享的工作集**，沿低耦合缝隙切（层/模块/数据流阶段），先列缝再核量。
- 预算红线 ≈ 名义上限一半：`spec + 任务卡 + 工作集` 超 60-80K 即警惕——要的是全程模型舒适区。
- 逃生阀：能沿缝拆的拆；天然不可分（横切重构/脚手架）→ **换 1M 模型，禁止硬锯出不可运行的中间状态**。合并判据对称：重叠过大半且合并后在预算内 → 合并。
- 降细拆惩罚：①brief 附定向包（architecture.md + conventions 摘要）；②**接口先行排序**；③接受部分重复读入是买来的干净上下文。
- **执行中途再拆分归 leader**（NEEDS_CONTEXT / 预算爆 / 两轮不过转设计 task）：现场切一刀或换 1M，判据与 opintake 共用同一套 scripts/ 核算脚本，规则只写一份。

---

## 7. Stage 3：逐 task 执行循环（oprun）

leader-worker：leader 只编排，上下文只留状态；交接全走 task 目录文件；每 task 全新 subagent 独享完整上下文。

### 7.1 单 task 循环

```
 1. leader 生成 brief（任务卡 + spec 路径 + 定向包）
 2. dispatch op-implementer：
    TDD（先写映射 AC 的失败单测，贴 RED）→ 最小实现 → hook 自动跑测试留证据
    → 写 report.md（顶部总报告覆盖 + 分 Round 追加）→ DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT
 3. dispatch op-reviewer（只读 brief+report+diff+spec），双裁决：
    ① 规格合规：覆盖声明 AC？偏离 spec/自由发挥/范围偏航（实际工作集 vs 预估）？
    ② 测试可信：测的是 AC 还是 mock？断言用户可观察？异步时序对？命中危险模式？
      refactor 加审：结构层变更是否只动调用部分？删除的覆盖仍在？
 5. findings：范围内 → fix 循环（7.2）；范围外 → issues，不当场修
 6. 双裁决 PASS → 派 op-closer 做收口整理：
    - 产 blueprint_update.md 提案（diff 形态覆盖 op_blueprint 全部文档）
    - 直接 append 决策到 decisions.md（append-only，不经 leader 审批）
    - 末 task 顺带叶子级归档提案
 7. leader 审批 closer 的 blueprint 提案 → 执行实际写入 op_blueprint/ → commit
    → tasks_list.json + checkpoint + progress 更新
```

### 7.2 review 循环上限

```
review → fix → re-review = 一轮；最多两轮。
到顶残留按严重度分流：
 · Critical（规格不合规/测试不可信）→ task 置 blocked + issue + 升级人裁决
     （四选一：降级接受/重拆/换更强模型/插设计 task 改思路）——不许静默 commit
 · Important/Minor → 照常 commit，残留落 issue 延后
```

两轮修不平大概率是结构问题（方案错/拆分错/规格歧义），继续循环只是烧 token。与"同一问题 3 次修复失败 = 停下升级"同源。

### 7.3 红灯归因协议（test.md + CLAUDE.md）

测试红 → 默认实现错。复现 → 读断言（保护哪条 AC/INV）→ 读实现（解释为何不符）→ 归因：（a）实现 bug，只改实现；（b）测试写错，写明错因（锁定文件需人工解锁，归因记 decisions.md；含 fix 场景"原测试供奉了 bug"须给依据）；（c）规格变了，走变更子流程。没有归因不准碰测试。

### 7.4 收口（closer 提案制）

task 闭环分三段：

1. `scripts/op_close_pre.sh {TID}`：spec 盖戳 + `status=收口中`。
2. **op-closer 整理**：
   - 产「blueprint 更新提案」写入 `op_record/tasks/{TID}/blueprint_update.md`，diff 形态覆盖 `op_blueprint/` 全部文档（specs/{feature}.md、architecture.md、domain.md、conventions.md 等）：这条新增、这条修改、这条因被上游覆盖而删除，各附一句理由。只留"现在是什么"，过滤被否方案/临时假设。
   - 直接 append 决策到 `op_record/decisions.md`（append-only 历史，不经 leader 审批）。
   - 末 task 顺带做叶子级归档提案（总述关闭、前缀释放）。
   - **铁律**：op-closer 对 `op_blueprint/` 无写权限；不碰 git、不改 status、不归档、不盖戳、不 stage。
3. leader 审批 closer 的蓝图提案 → 执行实际写入 `op_blueprint/` → `scripts/op_close_post.sh {TID} {feature}` 确认 review verdict PASS、spec 已盖戳，git mv 归档、追加 progress、`status=完成`、git add 收口文档。

### 7.5 模型分配

| 角色 | 模型 | 理由 |
|---|---|---|
| spec 编写（含设计探索）/ 设计 task | Opus | 错误放大系数最大，自身 token 极少 |
| op-evaluator | Opus | 对抗性思维；每 spec 一轮，频率低 |
| op-reviewer | Opus | 只读单遍便宜；强审弱错开同档盲区 |

模型由环境变量参数化：`OP_IMPLEMENTER_MODEL` / `OP_REVIEWER_MODEL` / `OP_EVALUATOR_MODEL` / `OP_CLOSER_MODEL`。值填 `haiku` / `sonnet` / `opus` 三档之一，对应 `settings.json` 的 `ANTHROPIC_DEFAULT_*_MODEL` 解析出的实际模型。**未设则不传 model 参数，继承主会话当前模型**（用户可用 `/model` 随时切换）。设了哪个就覆盖该 agent 用对应档位。

---

## 8. 三层验证体系

| 层 | 频率 | 内容 | 管什么 |
|---|---|---|---|
| **task 层** | 每 task，分钟级 | 机器门禁：映射测试+构建+reviewer 双裁决（≤2 轮）。不派 evaluator | 增量本身对不对 |
| **spec 层** | 每叶子一轮 | ①evaluator 智能评估→固化 PASS 测试（+存基准快照）→破坏检查→对抗探索。逐 AC 报告+截图。②**hard-pass gate**：每条 AC binary gate，亲自观察证据才 PASS，禁止推论式 PASS。③首次验收存基准快照（`tasks/{TID}/baselines/`），后续验收对比基准检测回归 | 用户拿到的能力真能用吗；**集成断没断**；测试有判别力吗 |
| **系统层** | 每晚/合并前 | e2e/ 全集 + domain.md 与生效规格不变量回归；失败自动开 issue | 新东西弄坏旧东西没有；随 spec 数自动增长 |

例外：**风险探针**（每 spec 至多一两个）完成后插 ≤10 分钟小验收，尽早证伪技术路线——与方案先行一前一后，分别夹住"想错了"和"环境不配合"。

### 8.1 evaluator 访问隔离与刻薄化调教

stock model 默认对 LLM 产出宽容——能发现 bug 但会说服自己"不太严重"放行，或只测成功路径不探边界。隔离防"抄实现"（evaluator 读源码后照着实现写测试→实现错→测试跟着错→一起绿），放水靠以下机制。

**访问隔离（两层）**：
1. **文件系统层**：**初期 worktree + hook**——evaluator 在隔离 worktree 中工作，hook 硬拦 Read/Grep 命中 `src/**`（机械可审计，零基建）。**后期升级为独立验证环境**：implementer 分支跑 CI 构建产出打包好的应用（Electron 可执行文件 / web dist / 扩展 .zip），evaluator 环境里只有构建产物 + spec + e2e/，源码不在其文件系统中。结构上不可能 > 纪律上不允许。
2. **报告回流层**：leader 组装 evaluator brief 时，**输入白名单只有 spec + 生效规格 + 应用启动方式**，不含 implementer 的 report、diff、review。

**防放水机制**：
1. **hard-pass gate**（evaluator prompt 内置）：每条 AC binary gate。亲自观察到 Then 子句的用户可观察行为 → PASS。观察不到、推测→FAIL。无法确定→INSUFFICIENT_EVIDENCE。禁止推论式 PASS。
2. **预期失败模式**（spec 可测性契约）：每 AC 附 1 条反例——若 xxx 没做好则 AC 应该 FAIL。evaluator Stage 5 逐条试。零 token 零 agent，写 spec 时顺手加。
3. **破坏检查**（机械）：固化测试必须能红——关功能开关或改断言期望，确认它真的会因错误实现而失败。
4. **刻薄化调教循环**（持续）：
   - 每次验收后，leader 随机抽 1-2 条 AC 做**二阶判断**：评估深度够不够？是否只测了成功路径？
   - 放水则写**偏差指令**——"AC-N 你只测了提交成功，边界的密码错误转向路径没测。补测后重新判定。"——而非"你上次偏了 12%"。指令型比评分型更有用。
   - 每 5 条偏差指令 → 选 2 条最典型改写为 few-shot 校准样例进 evaluator prompt。旧样例可淘汰。
   - **收敛标准**：连续 3 spec 验收，evaluator 提出的 FAIL 项至少 1 条是 implementer/reviewer 都未发现的真 bug；或夜跑 30 天内抓到 ≥1 次回归。达到 → 降频抽查（每 5 spec 一次）。未达到 → 每次全查。

### 8.2 验收基准快照

evaluator 每次 Stage 5 是"裸评"——面对跑起来的应用，对照 spec 文字判断 PASS/FAIL。首次评和第十次评之间没有"上次长什么样"的记忆，每次都得重新理解 spec→推导期望→观察实际。基准快照解决这个对齐问题。

**首次验收**：每 AC PASS 后，存一份基准快照：

- Web 应用：全页截图 + 关键交互态截图（下拉展开/弹窗/错误态）
- CLI 应用：命令 + stdout/stderr 原文
- 存储验证：数据库查询结果 / 文件内容快照

快照写入 `op_execution/tasks/{TID}/baselines/`（evaluator 无 op_blueprint 写权限，和 closer 提案制一致），文件命名映射 AC（`AC-2_login_error.png`、`AC-3_cleanup.txt`）。

**后续重验**（修复 task 回流后的二次验收、夜跑回归），evaluator 先读 `op_blueprint/baselines/index.md` 找到已有基准快照，逐条对比——新截图/输出和基准不一致且非预期改进 → 标记 REGRESSION；是预期改进 → 更新基准快照（仍写 `tasks/{TID}/baselines/`，走提案制）。

**closer 提案 + leader 审批**：closer 在 blueprint_update.md 末尾追加 baselines 段（新增/更新/删除各附 AC 与理由），leader 审批后：

- 新基准从 `tasks/{TID}/baselines/` 合入 `op_blueprint/baselines/{前缀}/`
- 更新 `op_blueprint/baselines/index.md`（追加/修改对应行）
- 删除的基准从 op_blueprint 移除

**baselines/index.md 格式**：

```markdown
# baselines 索引

## b01_session（2026-07-03）
| 文件 | 对应 AC | 类型 | 说明 |
|---|---|---|---|
| b01_session/AC-2_login_error.png | AC-2 | 截图 | 错误密码登录提示 |
| b01_session/AC-3_cleanup.txt | AC-3 | CLI 输出 | 超时清理日志 |

## a_darkmode（2026-07-02）
| 文件 | 对应 AC | 类型 | 说明 |
|---|---|---|---|
| a_darkmode/AC-1_toggle.png | AC-1 | 截图 | 切换前后对比 |
```

**二阶判断素材**：leader 做 evaluator 二阶判断时对照基准——spec 的 Then 文字 + baselines 里的截图/输出 + evaluator 的评估证据。三样对照，一眼能看出 evaluator 有没有放水（截图里错误提示根本没出现就判了 PASS）。

---

## 9. issues 机制

**一切"现在不修"的问题必须有档案，禁止只存在于对话里。**

五入口：review 两轮到顶残留；reviewer 范围外发现；evaluator 范围外发现/非阻断可用性建议；系统层夜跑失败；定期体检产出。

```markdown
# I-20260702-01: 会话列表 200+ 会话滚动掉帧
来源: evaluator 范围外（b01 验收）    所属 spec: b01
严重度: P0 阻断上线 / P1 下个 spec 前必修 / P2 排期 / P3 可容忍
标签: tech-debt（可选，与 P0-P3 正交）
状态: open → triaged → 转 task → closed
```

铁律：**issue 不直接改代码，转正式 task 后走对应 change type 流程**（fix 带回归测试先红后绿）——issues 是登记处不是免检通道。每叶子收尾时 optriage 一次；P0/P1 在闸门 C 呈报，人定阻不阻断 merge。

---

## 10. 机械护栏（hooks）

防"偷偷改绿"按强度排序，前三层是主防线：

1. **物理锁**（PreToolUse 硬阻断）：`e2e/**` 与 `BUG-*` 对 implementer 全局拦截（不查锁清单，直接路径匹配）。解锁走人工，归因记 decisions.md。
2. **访问隔离**（结构性）：evaluator 仅接触 spec + 应用产物，不接触源码或 implementer 交接文件；文件系统层（worktree+hook）+ 报告回流层（brief 白名单）。
3. **机器证据**（PostToolUse + Stop）：改 `src/**` 自动跑受影响测试留原始输出；Stop 检查 tasks_list.json 状态+新鲜测试输出，缺则拒收工；禁 --no-verify。结构层单测明确不设防，由行为层兜住。
4. **spec 写保护**（git 原生）：approved/in_progress 受 PreToolUse 拦截（改 spec 走变更子流程）；SessionStart 注入前 git diff --quiet 校验，防"好心更新规格"漂移。
5. **警告+留痕**（兜底）：结构层测试编辑按行敏感度——import/setup/调用行静默；expect/assert 行强制说明理由。危险模式：删除/反转 expect、toBe→toContain/正则/>=、timeout/阈值增大、.skip/.only、删测试文件或 it 块、test 文件加 eslint-disable。价值在曝光不在阻止。
6. **定期体检**（每周/CI 异步）：skip/only 计数、timeout 增幅、恒假断言、纯存在性断言 E2E；触碰 INV 模块抽样跑变异测试（杀不死变异体的测试判假重写）。产出落 issues。

---

## 11. 插件结构（omni-powers plugin）

```
对外 skill（4）——用户心智模型："进料、跑、看"三个动作 + 一次安装
  opinit      生成 omni_powers 三区骨架 + hooks 注册（一次性）
  opintake    需求入口：分拣 → spec（含设计探索+可测性契约）
              → 闸门 A → 自动拆 task → tasks_list.json 就绪 + 执行图入 spec ══ 终点："就绪"
  oprun       从 checkpoint 续跑：task 循环 → spec 级验收 → 闸门 C → 归档
              leader 即 controller，被本 skill 驱动
  opstatus    读 tasks_list.json + checkpoint，渲染人类可读状态报告
              （JSON 给机器和 hook，opstatus 给人——一份数据两个视图）

内部 skill（5）
  opspec      模板+假设先行+不变量强制+内联设计探索+可测性契约 ── opintake 调用
  opred       红灯归因协议 ── implementer/reviewer 共同引用
  optriage    issue 分级与转 task ── leader 收尾时调用（留此不并入 closer：分诊需全局视野）

agents（4）
  op-implementer    读 brief，TDD 实现，写 report（顶部总报告+分轮追加）；
                    设计 task 复用之（brief 指明"只产方案纸"，临时把 model 设为 opus）
  op-reviewer       双裁决：规格合规 + 测试可信；预置刻薄化调教 + 防借口表
  op-evaluator      验收方（仅 Stage 5）：智能评估→固化→破坏检查→对抗探索
                    hard-pass gate + 预期失败模式 + 访问隔离
  op-closer         收口整理：产 blueprint_update.md 提案（diff 形态覆盖 op_blueprint 全部文档）
                    + 直接追加 decisions.md（append-only），对 op_blueprint 无写权
                    末 task 顺带叶子级归档提案

hooks（5）
  PreToolUse[Edit/Write]   统一守门：e2e/**+BUG-* 硬阻断/spec 写保护/行级敏感度/op_blueprint 写拦截
  PostToolUse[src/**]      自动跑受影响测试留证据
  Stop                     完成门禁：状态 + 新鲜证据
  SessionStart             动态计算注入（checkpoint+tasks_list+git 状态 → 当前 spec/task/下一步，1-2K token）
                           + approved spec 完整性校验；路由注入取代 meta skill
  PreToolUse[Bash]         拦 --no-verify 及危险 git 操作

scripts/（确定性计算全归 bash，不留给模型）
  工作集 tokenize 核算 / review-package 生成 / test-lock 管理 / tasks_list 读写 / checkpoint 读写
```

**用户旅程**：`opinit` 一次 → 每需求 `opintake "..."` → 批 spec（闸门 A）→ `oprun` → 中途 `opstatus` → 闸门 C 批"验收报告 + 自决决策表 + P0/P1 issue"。两个命令干活，一个看状态，人工两次点头。

---

## 12. 落地路线

**P0（第一周，零基建）**：opinit 骨架；入口分拣两判定 + spec 模板与命名约定（含可测性契约）+ 闸门 A + 审批即 commit；任务卡 + task=commit；红灯归因、可写性矩阵、review 两轮上限、契约边界规则进 test.md/CLAUDE.md；完成必须贴测试输出；issues 手工登记。

**P1（第二周，hook 层）**：e2e/**+BUG-* 全局物理锁、证据链、spec 写保护（frontmatter 状态感知）、SessionStart 动态注入 + checkpoint/tasks_list.json、行级敏感度警告、scripts/ 五件套。

**P2（第三-四周，subagent 层）**：op-evaluator 浏览器基建作为自举第一 spec（Electron/扩展驱动是最高技术风险，顺便用流程验证流程）→ evaluator Stage 5（评估→固化→破坏检查，含 hard-pass gate + few-shot 校准 + 偏差指令循环）→ reviewer 双裁决 + closer 提案制 + 循环上限 + issues 自动登记 → e2e/ 夜跑 → 叶子归档流。

**P3（持续）**：生效规格与 domain.md 沉淀；变异测试体检；issues triage 节奏；刻薄化调教收敛达标后降频；模型升级后审视护栏做减法。

---

## 13. v5→v6 变更对照表

| 项目 | v5 | v6 |
|---|---|---|
| controller | 独立 Sonnet agent（身份模糊） | **leader 主会话**（oprun 驱动） |
| agents | 3（implementer/reviewer/evaluator） | **4**（+closer） |
| 内部 skill | 6（含 using-omni-powers、oparchive、oplead） | **5**（opspec/opred/optriage；删 using-omni-powers/oparchive，oplead 折进 oprun） |
| 归档执行 | oparchive skill 直接写 op_blueprint | **closer 产 blueprint_update.md → leader 审批 → 写入** |
| decisions.md | 写入者未明 | **closer 直接 append**（append-only） |
| 模型分配 | 硬编码 Opus/Sonnet/Haiku | **环境变量 OP_*_MODEL**（三档，未设继承主会话当前模型） |
| 执行期决策术语 | 信封规则 | **契约边界规则** |
| evaluator 介入 | Stage 2（验收先行）+ Stage 5（验收） | **仅 Stage 5**（评估→固化→破坏检查） |
| 判别力保证 | 先红后绿（实现前全 RED） | **破坏检查**（固化后故意破坏确认能红） |
| 锁清单 | spec_locks/{前缀}_locks.md | **删**，hook 全局拦 e2e/** |
| 测试缝 | 依赖 Stage 2 浮出 | **可测性契约**进 spec 模板（闸门 A） |
| spec 模板技术决策 | 两类（条件强制 + 设计探索） | **三类**（+可测性契约含预期失败模式） |
| task 目录结构 | tasks/{TID}/ + runs/（gitignore）+ 含 spec | **3 文件平铺**（brief/report/review），spec 在 op_execution/specs/ |
| 进度记录 | context.md（append）+ report.md（覆盖） | **report.md 顶部总报告 + 分轮**，删 context.md |
| evaluator 防放水 | 无 | **hard-pass gate + 预期失败模式 + 刻薄化调教循环** |
| evaluator 隔离 | 时序隔离 | **访问隔离**（文件系统+报告回流）+ **调教收敛标准** |
| 流程阶段 | 7 阶段（含 Stage 2） | **6 阶段**（删 Stage 2） |
| 关键术语 | 信封/oparchive/using-omni-powers/controller | 契约边界/closer 提案/leader 即 controller |
