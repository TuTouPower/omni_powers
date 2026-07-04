---
name: opspec
description: >
  工作 spec 生成（内部 skill，被 opintake 调用）。模板 + 假设先行 + 不变量强制 + 内联设计探索。
  产出 op_execution/specs/{前缀}.md（叶子或总述），含 frontmatter status/type/feature、不变量、AC、边界、技术决策。
  不直接对用户——opintake 负责和用户交互后调用本 skill 落盘。
---

# opspec：工作 spec 生成

把需求转成工作 spec。**内部 skill，由 opintake 在 Stage 1 调用**（Stage 0 分拣 + 澄清由 opintake 完成，Stage 2 拆 task 由 opintake 后续做）。opintake 已完成入口分拣、和用户澄清需求、确定方案——本 skill 把结论落盘成结构化 spec，供闸门 A 审批。

## 兜底：用户直接命中（无 opintake 上下文）

若被直接调用（无 opintake 传入的澄清结论），**不要拿不完整信息硬套模板**：
- 需求明确（一句话意图 + INV + AC 都能直接推导）→ 补齐必需输入后落盘（status: draft），返回时标"未经 opintake 澄清，建议人审补"
- 需求模糊 → 引导走 `/opintake "<需求>"`（澄清对话更系统），或当场补问必需项（≤3 问）

## 输入

opintake 传入（或兜底时本 skill 补齐）：
- 需求一句话意图
- change type（feat/refactor/perf/...）
- 前缀编号（见"编号规则"）+ spec 类型（叶子/总述）
- 澄清结论：不变量、AC、边界、不做的事
- 方案先行结论（若命中信号）：候选 2-3 个、推荐及理由、已知坑
- 跨 task 技术决策（若有）

## 编号规则

| 类型 | 前缀 | 示例 | 说明 |
|---|---|---|---|
| 单需求（不拆） | `a_<功能>` | `a_export_stats.md` | 一文件一叶子 |
| 多 task 总述 | `b_<主题>` | `b_website.md` | 总述（意图 + 子叶子清单），不挂 AC |
| 叶子 | `<总述前缀><NN>` | `b01_pages.md`、`b02_contact.md` | NN 两位数从 01；前缀永不复用 |

**分配**：opintake Stage 0 分拣时定前缀（跨需求单调递增），写进 spec frontmatter + tasks_list.json 的 `spec` 字段。撞号靠 opintake 入口全局视野（同时只一个 /opintake）。

## 产出

`docs/omni_powers/op_execution/specs/{前缀}.md`（本文档路径统一带根前缀 `docs/omni_powers/`）。

## 叶子 spec 模板

```markdown
---
status: draft        # draft（本 skill 写）→ approved（闸门 A 人批）→ in_progress（oprun 起）→ done / cancelled。本 skill 只写 draft，后续流转归 leader/oprun
type: feat           # feat | refactor | perf | ...（决定测试规则与 AC 侧重）
feature: <功能名>    # 对应 op_blueprint/specs/{功能名}.md；closer 合入 baseline 时按此映射
---
# {名称}
## 一句话意图
{opintake 传入的需求意图}

## 不变量（INV）
{填不出 = 没理解需求。与 docs/omni_powers/op_blueprint/domain.md / 生效规格冲突必须显式标注}
- INV-1: {不变量} —— {为什么}
<!-- refactor 型此区最长：列出所有必须保持的行为契约 -->

## 验收场景（AC）
{Then 必须用户可观察。每条须可直接翻译为可执行断言}
- AC-1: Given {前置} When {操作} Then {可观察结果}
<!-- feat: 用户能做什么新事 | refactor: 等价性验证 | perf: 量化指标 -->

## 边界与反例
{竞态、并发、空状态、失败路径、刷新/重启、多显示器/多窗口}
- {边界场景}: {期望行为}

## 不做的事
- {明确排除的范围}

## 技术决策
{三类内容，均随闸门 A 过人审}
### 条件强制（被 2+ task 依赖的决策）
- {数据模型/模块通信/状态存储/接口形状} —— {理由}

### 设计探索结论（命中方案先行信号时）
- 候选：{A / B / C}
- 推荐：{选哪个} —— {复杂度与边界行为权衡 + 理由}
- 已知坑：{坑}
<!-- 完整探索过程存 docs/omni_powers/op_record/decisions.md，此处只留结论。未命中信号则此区空 -->

### 可测性契约（必填，纯文档/配置类可 N/A）
{写 spec 时顺手推导——AC 的验收方式自然延伸}
- 应用启动方式: {一条命令启动，如 npm start / ./app；纯文档/配置类无则写"N/A + 理由"}
- AC-1 验收信号: {结构化优先——DOM 文本/a11y tree/CLI stdout/API 响应/DB 查询/进程健康检查；视觉对照——截图，advisory}，关键入口: {URL / 菜单路径 / API 端点}
- AC-1 通道: {CDP | cua | 直驱}（判定见本 skill「通道判定」；能用 CDP 的一律 CDP）
- AC-N 测试缝: {如"需测试收件箱 → 需 Mailpit + seed 账号"}
- 预期失败模式（每 AC 至少 1 条反例——如果 xxx 没做好，AC 应该 FAIL）:
  - AC-1 若未正确实现则 {行为表现}，评估时专门试这个
<!-- implementer 把测试缝当成和 AC 同级的交付义务。evaluator Stage 4 对照此表逐条试反例 -->

## 待澄清 [NEEDS CLARIFICATION]
{≤3 条。无则写"无"。
有则：本 skill 仍落盘（status: draft）+ 返回路径时**显式报告待澄清项**给 opintake → opintake 带回用户补澄清 → 补完后才走闸门 A。即"阻断闸门 A"，不阻断落盘。}
```

> 顺序依赖（task 依赖、接口 task 位置）**不进 spec 本体**——在 tasks_list.json（depends_on，机读）+ leader_checkpoint（人扫）。避免闸门 A 写保护后 Stage 2 追加冲突。

## 总述 spec 模板（b_ 前缀，精简）

总述**不挂 AC/可测性契约**（那是叶子粒度）。只串意图 + 子叶子清单 + 跨叶子不变量 + 跨 task 决策：

```markdown
---
status: draft
type: feat
feature: <主题功能名>
---
# {主题名称}
## 一句话意图
{总需求意图}

## 子叶子清单
- b01_pages.md — {叶子范围一句话}
- b02_contact.md — {叶子范围一句话}
<!-- 每叶子各自的 AC/可测性在叶子 spec，不在此 -->

## 跨叶子共同不变量
- INV-1: {跨多个叶子都成立的不变量} —— {为什么}

## 跨 task 技术决策
### 条件强制
- {被 2+ 叶子的 task 依赖的决策} —— {理由}

## 不做的事
- {主题级排除}

## 待澄清 [NEEDS CLARIFICATION]
{同叶子模板}
```

## 流程

```
1. 接收 opintake 传入的澄清结论（或兜底补齐）
2. 判定叶子/总述 → 选模板
3. 落盘 docs/omni_powers/op_execution/specs/{前缀}.md（status: draft）
4. 方案先行判定（见下）——命中则补设计探索结论区
5. spec 自审（占位符/一致性/范围/歧义）
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
- ① 某 INV/AC 涉及"正确性需论证而非目测"的计算（核算、对账、并发一致性、时间切分）
- ② 验收标准含"高效/准确/一致"等词——**仅当该词修饰需算法/数据保证的行为**（排除"UI 风格保持一致""命名一致"等非算法语义）

命中 → 技术决策区写设计探索结论：候选 2-3 个、复杂度与边界行为、推荐及理由、已知坑。**完整探索过程存 `docs/omni_powers/op_record/decisions.md`，spec 只留结论**。

> 信号③（implementer BLOCKED 或两轮 review 不过）属执行期兜底，不在此 skill。由 leader 现场插设计 task（oprun 驱动）。

## 不变量优先

填不出 INV = 没理解需求。INV 与 `docs/omni_powers/op_blueprint/domain.md` 或既有生效规格冲突必须显式标注（写 `⚠️ 与 domain.md X 冲突，待闸门 A 裁定`）。

## spec 自审

写完后全新眼光审视：

1. **占位符扫描**：TODO/TBD/不完整段/模糊需求 → 修复
2. **内部一致性**：各段矛盾？架构和功能对得上？
3. **INV 完整性**：沉默失败区（数据隔离/持久化/权限）覆盖到？
4. **AC 可翻译**（叶子）：每条 Then 都能翻译为可执行断言？用户可观察？
5. **边界完整**：竞态、失败路径、空状态都在？

发现问题直接内联修复。修完返回路径，不重审。

> 拆 task 时"某 task 产出约束他人而 spec 未写"的检查**不在此 skill**（自审时还没拆 task）——归 opintake Stage 2 拆 task 时检查（打回 opspec 补写）。

## 闸门 A（opintake 负责，非本 skill）

本 skill 落盘后返回路径。**闸门 A 审批由 opintake 呈报用户**：人批 → `status: approved` + commit + 写保护。本 skill 不参与审批环节。

## 相关文件

| 文件 | 用途 |
|---|---|
| `docs/omni_powers/op_blueprint/domain.md` | 全局不变量，INV 须对照不冲突 |
| `docs/omni_powers/op_blueprint/specs/` | 生效规格，AC 须对照不重复 |
| `docs/omni_powers/op_blueprint/architecture.md` | 架构地图，技术决策须对照 |
| `docs/omni_powers/op_record/decisions.md` | 设计探索完整过程存此处 |
