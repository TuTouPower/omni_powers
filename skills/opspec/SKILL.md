---
name: opspec
disable-model-invocation: true
user-invocable: false
description: >
  工作 spec 生成（内部 skill，被 opintake 调用）。模板 + 假设先行 + 不变量强制 + 内联设计探索。
  产出 op_execution/specs/{TID}_{slug}.md（task:spec 1:1，每 task 一份），含 frontmatter status/type、不变量、验收标准、边界、技术决策。
  不直接对用户——opintake 负责和用户交互后调用本 skill 落盘。
---

# opspec：工作 spec 生成

> **路径前置**：进入 skill 后先执行：
> ```bash
> source "$OP_HOME/scripts/op_paths.sh"
> op_load_paths "" "$(git rev-parse --show-toplevel)"
> ```
> 后文 `$OP_DOCS_DIR` 使用解析后项目相对路径；旧项目无配置自动取 `docs/omni_powers`。


> **profile 感知**：`$OP_DOCS_DIR/profile` = `lite` 时——下文所有 `op_blueprint/`（domain.md/specs//architecture.md）对照步骤跳过（lite 下为空壳占位，不作契约源）；spec 须自足（必要的架构/命名约束内联进 spec 本体）。

把需求转成工作 spec。**内部 skill，由 opintake 在 Stage 1 调用**（澄清由 opintake 完成，Stage 2 拆 task 由 opintake 后续做）。opintake 已完成和用户澄清需求、确定方案——本 skill 把结论落盘成结构化 spec，供闸门 A 审批。

## 兜底：用户直接命中（无 opintake 上下文）

若被直接调用（无 opintake 传入的澄清结论），**不要拿不完整信息硬套模板**：
- 需求明确（一句话意图 + 不变量 + 验收标准 都能直接推导）→ 补齐必需输入后落盘（status: draft），返回时标"未经 opintake 澄清，建议人审补"
- 需求模糊 → 引导走 `/opintake "<需求>"`（澄清对话更系统），或当场补问必需项（≤3 问）

## 输入

opintake 传入（或兜底时本 skill 补齐）：
- 需求一句话意图
- change type（feat/refactor/perf/...）
- TID（见"TID 编码"）
- 澄清结论：不变量、验收标准、边界、不做的事
- 方案先行结论（若命中信号）：候选 2-3 个、推荐及理由、已知坑
- 跨 task 技术决策（若有）

## TID 编码

- TID 全局单调递增 `T0001/T0002/…`，固定四位数宽度，永不复用（e2e/baselines/归档按 TID 存）。
- 一次 intake 拆出的多个 task 连续编号；不同 intake 续编。spec 文件名 `{TID}_{slug}.md`，slug 为语义短横线名。
- **分配**：opintake 拆 task 时定 TID，写进 tasks_list.json 的 `spec` 字段（值为相对路径 `specs/{TID}_{slug}.md`，如 `"specs/T0001_user_auth.md"`）；TID 只放 `id` 字段。spec 文件名含 TID。分配前扫描现有 `op_execution/specs/`、`op_record/specs/`、`tasks_list.json`，取下一个未用 TID；并发 `/opintake` 未加锁时禁止同时运行，需先人工确认无另一个 intake 在写。

## 产出

`$OP_DOCS_DIR/op_execution/specs/{TID}_{slug}.md`（本文档路径统一带根 `$OP_DOCS_DIR/`）。

## spec 模板

> **行为段去坐标（design §290——人不审文件/函数清单，杠杆全在行为层）**：意图 / INV / AC / 边界 / 不做 五段只写行为与用户可观察结果。**禁**行号、文件名、函数名、变量名、CSS 类 / DOM selector、公式、API 字段——这些坐标收敛到「技术决策 → 实现锚点」子区。人是 spec 首要读者（闸门 A 人批），坐标随重构腐烂会让契约失效；AI 能从锚点区自取坐标。

```markdown
---
status: draft        # draft（本 skill 写）→ approved（闸门 A 人批）。本 skill 只写 draft，approved 后冻结（design §1.2，执行期 spec-delta 走变更子流程不改 status）
type: feat           # feat | refactor | perf | ...（决定测试规则与 验收标准侧重）
eval: required       # "required"（派 evaluator，默认）| <免派理由文本>（免派——接口先行/脚手架/纯内部重构，design §2.4/D9）。值非 "required" 即免派，值即理由
---
# {名称}
## 一句话意图
{opintake 传入的需求意图}

## 不变量（INV）
{填不出 = 没理解需求。与 $OP_DOCS_DIR/op_blueprint/domain.md / 生效规格冲突必须显式标注}
- INV-1: {不变量} —— {为什么}
<!-- refactor 型此区最长：列出所有必须保持的行为契约 -->
<!-- 只写行为契约，禁坐标（行号/文件/函数/变量/selector/公式）→ 坐标入「实现锚点」 -->

## 验收场景（验收标准 AC）
{Then 必须用户可观察。每条须可直接翻译为可执行断言}
- AC-1: Given {前置} When {操作} Then {可观察结果}
<!-- feat: 用户能做什么新事 | refactor: 等价性验证 | perf: 量化指标 -->
<!-- 可观察=用户视角（看见/能做/状态变化），非 DOM 度量或 selector 存在性 -->

## 边界与反例
{竞态、并发、空状态、失败路径、刷新/重启、多显示器/多窗口}
- {边界场景}: {期望行为}
<!-- 同样禁坐标，场景与期望用白话行为描述 -->

## 不做的事
- {明确排除的范围}

## 技术决策
{四类内容，均随闸门 A 过人审}
### 条件强制（被 2+ task 依赖的决策）
- {数据模型/模块通信/状态存储/接口形状} —— {理由}

### 设计探索结论（命中方案先行信号时）
- 候选：{A / B / C}
- 推荐：{选哪个} —— {复杂度与边界行为权衡 + 理由}
- 已知坑：{坑}
<!-- 完整探索过程存 $OP_DOCS_DIR/op_record/decisions.md，此处只留结论。未命中信号则此区空 -->

### 实现锚点（坐标集中地——给 implementer/reviewer，可选）
- 文件/函数/行号: {如 dashboard_detail.ts:207 mark 定位逻辑}
- DOM/CSS 锚点: {如 #tlZoom 滑块 / .tl-mm-window 窗口}
- 状态/变量: {如 _dt_zoom 模块级状态}
<!-- 行为段禁出现的坐标全收敛到此。无坐标则省此区；evaluator 测试 selector 归「可测性契约」不在此 -->

### 可测性契约（必填，design §2.2——无 N/A 例外）
{写 spec 时顺手推导——验收标准的验收方式自然延伸}
- 应用启动方式: {一条命令启动，如 npm start / ./app}
- AC-1 验收信号: {结构化优先——CLI stdout/API 响应/DB 查询/进程健康检查（**DOM/a11y 降 advisory，D7**）；视觉对照——截图/DOM，advisory}，关键入口: {URL / 菜单路径 / API 端点}
- AC-1 通道: {CDP | cua | 直驱}（判定见本 skill「通道判定」；能用 CDP 的一律 CDP）
- AC-N 测试缝: {如"需测试收件箱 → 需 Mailpit + seed 账号"}
- 预期失败模式（**best effort——建议每条 AC 1 条反例，非硬门槛，D13**；如果 xxx 没做好，验收标准应该 FAIL）:
  - AC-1 若未正确实现则 {行为表现}，评估时专门试这个
<!-- implementer 把测试缝当成和验收标准同级的交付义务。evaluator 验收时对照此表逐条试反例 -->

## 待澄清 [NEEDS CLARIFICATION]
{≤3 条。无则写"无"。
有则：本 skill 仍落盘（status: draft）+ 返回路径时**显式报告待澄清项**给 opintake → opintake 带回用户补澄清 → 补完后才走闸门 A。即"阻断闸门 A"，不阻断落盘。}
```

> 顺序依赖（task 依赖、接口 task 位置）**不进 spec 本体**——在 tasks_list.json（depends_on，机读）+ leader_checkpoint（人扫）。避免闸门 A 写保护后 Stage 2 追加冲突。

## 流程

```
1. 接收 opintake 传入的澄清结论（或兜底补齐）
2. 选模板（spec 模板）
3. 落盘 $OP_DOCS_DIR/op_execution/specs/{TID}_{slug}.md（status: draft）
4. 方案先行判定（见下）——命中则补设计探索结论区
5. spec 自审（**结构合规扫描先行**——段齐/编号/可测性契约必填/行为段无坐标，再查占位符/一致性/范围/歧义）
6. 返回 spec 路径给 opintake；有待澄清项则显式报告（阻断闸门 A，不阻断落盘）
```

## 通道判定（可测性契约的「通道」字段）

**核心原则：能用 CDP 测的，一律用 CDP。CDP 做不到的，才上 cua 真实鼠标键盘。** CDP 更快、更稳、可并行、可断言 DOM；cua OS 级真输入慢、脆、依赖显示器与权限。

```
被测行为
  ├─ 普通网页 / Electron 渲染层 / 扩展自有页 DOM 内？
  │   （UI、表单、preload API、IPC、storage、网络拦截）      ─► CDP（Playwright）
  ├─ Electron 原生壳层？
  │   （应用菜单、托盘、原生对话框、shell.openExternal、
  │     globalShortcut、窗口 OS 级控制、系统通知、
  │     安装/卸载/更新、深度链接）                            ─► cua
  ├─ 浏览器 chrome / 扩展安装 / OS 对话框？
  │   （chrome://extensions、工具栏图标、权限弹窗、
  │     文件对话框、HTTP 认证、打印）                          ─► cua
  ├─ 其他桌面原生 app（非 Chromium）？                        ─► cua
  └─ CLI / DB / API / 进程（无 UI）？                          ─► 直驱（Bash/HTTP/SQL）
```

一句话：**Chromium 渲染出来的东西用 CDP，OS 原生窗口/对话框/菜单用 cua，无 UI 的直驱。**

CDP 接入方式（写进可测性契约的"应用启动方式"旁）：
- Web：Playwright `chromium.launch`
- Electron：Playwright `_electron.launch({ executablePath })`（生产包通常关 CDP，需 dev/test 构建开 `--remote-debugging-port`）
- 扩展：`chromium.launchPersistentContext` + `--load-extension`（仅 Chromium，headed）；popup/options 直接 `goto chrome-extension://<id>/xxx.html`

> 详细边界表与用例矩阵见用户测试总方案（TESTING_PLAN.md，若目标项目 test.md 有引用）。cua 用法见 op-evaluator.md「执行后端」。

## 方案先行（内联设计探索）

**触发信号（机械判定）**：
- 某 不变量/验收标准 涉及"正确性需论证而非目测"的计算（核算、对账、并发一致性、时间切分）
- 验收标准含"高效/准确/一致"等词——**仅当该词修饰需算法/数据保证的行为**（排除"UI 风格保持一致""命名一致"等非算法语义）

命中 → 技术决策区写设计探索结论：候选 2-3 个、复杂度与边界行为、推荐及理由、已知坑。**完整探索过程存 `$OP_DOCS_DIR/op_record/decisions.md`，spec 只留结论**。

> 第三信号（implementer BLOCKED 或两轮 review 不过）属执行期兜底，不在此 skill。由 leader 现场插设计 task（oprun 驱动）。

## 不变量优先

填不出 不变量 = 没理解需求。不变量与 `$OP_DOCS_DIR/op_blueprint/domain.md` 或既有生效规格冲突必须显式标注（写 `⚠️ 与 domain.md X 冲突，待闸门 A 裁定`）。不变量陈述行为契约，不夹坐标（行号/文件/selector/公式）——坐标入「技术决策 → 实现锚点」，避免随重构腐烂（design §290）。

## spec 自审

写完后全新眼光审视：

0. **结构合规扫描（先于内容审——缺段比内容烂更基础，可测性契约「必填无 N/A 例外」在此强制）**：逐一核对模板必需段在场——
   - [ ] 一句话意图
   - [ ] 不变量（每条 `INV-N` 编号）
   - [ ] 验收标准（每条 `AC-N` 编号，非裸复选框）
   - [ ] 边界与反例
   - [ ] 不做的事
   - [ ] 技术决策（条件强制 / 设计探索结论 / 实现锚点 / 可测性契约 四子区）
   - [ ] **可测性契约**（启动方式 + 每条 AC 的验收信号/通道 + 测试缝 + 预期失败模式）——缺 = 不合格，必补
   - [ ] 待澄清 [NEEDS CLARIFICATION]（无则写"无"，不能整段缺）
   缺任一段 = 结构不合格，补齐再进内容审。**行为段（意图/INV/AC/边界/不做）扫坐标**：出现行号/文件/函数/变量/selector/公式 → 下沉到「实现锚点」。
1. **占位符扫描**：TODO/TBD/不完整段/模糊需求 → 修复
2. **内部一致性**：各段矛盾？架构和功能对得上？数字/公式跨段一致？
3. **不变量完整性**：沉默失败区（数据隔离/持久化/权限）覆盖到？
4. **验收标准可翻译**：每条 Then 都能翻译为可执行断言？用户可观察（非 grep/DOM 度量等实现手段）？
5. **边界完整**：竞态、失败路径、空状态都在？

发现问题直接内联修复。修完返回路径，不重审。

> 拆 task 时"某 task 产出约束他人而 spec 未写"的检查**不在此 skill**（自审时还没拆 task）——归 opintake Stage 2 拆 task 时检查（打回 opspec 补写）。

## 闸门 A（opintake 负责，非本 skill）

本 skill 落盘后返回路径。**闸门 A 审批由 opintake 呈报用户**：人批 → `status: approved` + commit + 写保护。本 skill 不参与审批环节。

## 相关文件

| 文件 | 用途 |
|---|---|
| `$OP_DOCS_DIR/op_blueprint/domain.md` | 全局不变量，不变量须对照不冲突 |
| `$OP_DOCS_DIR/op_blueprint/specs/` | 生效规格，验收标准须对照不重复 |
| `$OP_DOCS_DIR/op_blueprint/architecture.md` | 架构地图，技术决策须对照 |
| `$OP_DOCS_DIR/op_record/decisions.md` | 设计探索完整过程存此处 |
