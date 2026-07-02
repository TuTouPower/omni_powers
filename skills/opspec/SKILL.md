---
name: opspec
description: >
  工作 spec 生成（内部 skill，被 opintake 调用）。模板 + 假设先行 + 不变量强制 + 内联设计探索。
  产出 op_execution/specs/{前缀}.md，含 frontmatter status/type、不变量、AC、边界、技术决策。
  不直接对用户——opintake 负责和用户交互后调用本 skill 落盘。
---

# opspec：工作 spec 生成

把需求转成 v5 格式的工作 spec。**内部 skill，由 opintake 在 Stage 1-3 调用**。opintake 已完成入口分拣（§1 三判据命中）、和用户澄清了需求、确定了方案——本 skill 把结论落盘成结构化 spec，供闸门 A 审批。

## 何时被调用

opintake 在以下情况调本 skill：
- 入口分拣判定需写 spec（跨范围/改契约/高代价）
- 已和用户完成澄清对话，需求明确
- 已确定方案（若命中方案先行信号，设计探索已完成）

本 skill **不重新和用户对话**——opintake 把对话结论作为输入传入。本 skill 只负责结构化落盘 + 自审。

## 输入

opintake 传入：
- 需求一句话意图
- change type（feat/refactor/perf/...）
- 前缀编号（a_ 单需求 / b_ 总述 + b01/b02 叶子，封顶两层）
- 澄清结论：不变量、AC、边界、不做的事
- 方案先行结论（若命中信号）：候选 2-3 个、推荐及理由、已知坑
- 跨 task 技术决策（若有）

## 产出

`docs/omni_powers/op_execution/specs/{前缀}.md`，严格按模板。叶子 spec 用前缀编号，总述 spec 同前缀无编号后缀。

## spec 模板（v5）

```markdown
---
status: draft        # draft → approved → in_progress → done / cancelled
type: feat           # feat | refactor | perf | ...（决定测试规则与 AC 侧重）
---
# {名称}
## 一句话意图
{opintake 传入的需求意图}

## 不变量（INV）
{填不出 = 没理解需求。与 domain.md / 生效规格冲突必须显式标注}
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
{两类内容，均随闸门 A 过人审}
### 条件强制（被 2+ task 依赖的决策）
- {数据模型/模块通信/状态存储/接口形状} —— {理由}

### 设计探索结论（命中方案先行信号时）
- 候选：{A / B / C}
- 推荐：{选哪个} —— {复杂度与边界行为权衡 + 理由}
- 已知坑：{坑}
<!-- 完整探索过程存 decisions.md，此处只留结论。未命中信号则此区空 -->

### 可测性契约（必填）
{写 spec 时顺手推导——AC 的验收方式自然延伸}
- 应用启动方式: {一条命令启动，如 npm start / ./app / ...}
- AC-1 测试方式: {computer use / CLI / 截图断言}，关键入口: {URL / 菜单路径 / API 端点}
- AC-N 测试缝: {如"需测试收件箱 → 需 Mailpit + seed 账号"; "需验证导出 → 需 stats export 命令"}
- 预期失败模式（每 AC 至少 1 条反例——如果 xxx 没做好，AC 应该 FAIL）:
  - AC-1 若未正确实现则 {行为表现}，评估时专门试这个
  - AC-N 若未正确实现则 {行为表现}
<!-- implementer 把测试缝当成和 AC 同级的交付义务。evaluator Stage 5 对照此表逐条试反例 -->

## 待澄清 [NEEDS CLARIFICATION]
{≤3 条，有则阻断。无则写"无"}

## 执行图
{opintake 在 Stage 3 拆完 task 后追加：task 依赖概览 + 接口 task 位置，≤10 行}
```

## 流程

```
1. 接收 opintake 传入的澄清结论
2. 按模板落盘 op_execution/specs/{前缀}.md（status: draft）
3. 方案先行判定（见下）——命中则补设计探索结论区
4. spec 自审（占位符/一致性/范围/歧义）
5. 返回 spec 路径给 opintake
```

## 方案先行（内联设计探索）

**触发信号（机械判定）**：
- ① 某 INV/AC 涉及"正确性需论证而非目测"的计算（核算、对账、并发一致性、时间切分）
- ② 验收标准含"高效/准确/一致"等需算法保证的词

命中 → 技术决策区写设计探索结论：候选 2-3 个、复杂度与边界行为、推荐及理由、已知坑。**完整探索过程存 `decisions.md`，spec 只留结论**。

未命中 → 设计探索结论区留空。

> 信号③（implementer BLOCKED 或两轮 review 不过）属执行期兜底，不在此 skill 范围。由 oplead 现场插设计 task。

## 不变量优先

填不出 INV = 没理解需求。INV 与 `op_blueprint/domain.md` 或既有生效规格冲突必须显式标注（写 `⚠️ 与 domain.md X 冲突，待闸门 A 裁定`）。

## spec 自审

写完后全新眼光审视：

1. **占位符扫描**：TODO/TBD/不完整段/模糊需求 → 修复
2. **内部一致性**：各段矛盾？架构和功能对得上？
3. **INV 完整性**：沉默失败区（数据隔离/持久化/权限）覆盖到？
4. **AC 可翻译**：每条 Then 都能翻译为可执行断言？用户可观察？
5. **边界完整**：竞态、失败路径、空状态都在？
6. **技术决策无遗漏**：拆 task 时若发现某 task 产出约束他人而 spec 未写 → 打回补 spec

发现问题直接内联修复。修完返回路径，不重审。

## 闸门 A（opintake 负责，非本 skill）

本 skill 落盘后返回路径。**闸门 A 审批由 opintake 呈报用户**：人批 → `status: approved` + commit + 写保护。本 skill 不参与审批环节。

## 相关文件

| 文件 | 用途 |
|---|---|
| `op_blueprint/domain.md` | 全局不变量，INV 须对照不冲突 |
| `op_blueprint/specs/` | 生效规格，AC 须对照不重复 |
| `op_blueprint/architecture.md` | 架构地图，技术决策须对照 |
| `op_record/decisions.md` | 设计探索完整过程存此处 |
