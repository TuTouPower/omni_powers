---
name: op-generate-plan
description: >
  从 spec.md 生成 plan.md。默认深度模式（逐 step 确认 + 可选 visual companion），
  用户说"快速模式/快速决定/直接生成"才走快速。intake/op-debt2tasks 调本 skill 生成 plan。
  触发：/op-generate-plan、生成 plan、写实施计划。
---

# 写实施计划

> 本 skill 参考 [superpowers:writing-plans](https://github.com/obra/superpowers)（Copyright (c) 2025 Prime Radiant, Inc.），本土化适配 harness 工作流。
> `plan-document-reviewer-prompt.md` 直接取自 superpowers，原作者保留版权。

## 概述

写全面的实施计划，假设工程师对我们的代码库零上下文、品味存疑。记录他们需要知道的一切：每个 task 涉及哪些文件、代码、测试、可能需要查的文档、怎么测试。把所有内容拆成小口 task。DRY。YAGNI。TDD。频繁提交。

假设他们是熟练的开发者，但几乎不了解我们的工具集和问题领域。假设他们不太懂好的测试设计。

**开始时声明：** "我用 op-generate-plan 来创建实施计划。"

**上下文：** 如果在隔离的 worktree 中工作，应由 leader 在执行时通过 `git worktree` 创建。

**保存 plan 到：** `docs/harness_execution/tasks/{TID}/plan.md`

## 模式选择

**默认：深度模式**——逐 step 确认，可选 visual companion。

**快速模式**：仅当用户**明确说**以下关键词时才走快速：
- "快速模式"、"快速决定"、"直接生成"、"快速生成"、"不用讨论了"
- 或 intake/op-debt2tasks 调用时指定快速模式

进入 skill 后先确认：

```
为 {TID} "{title}" 生成 plan。

默认逐 step 确认。说"快速"则我直接出完整 plan 供你审阅。
开始？
```

## 范围检查

如果 spec 覆盖了多个独立子系统，应该在 brainstorming/op-generate-specerator 阶段就拆成子项目 spec。如果没有，建议先拆成多个 plan——每个子系统一个。每个 plan 应该产出可独立运行、可测试的软件。

## 文件结构

在定义 task 前，先画出要创建或修改哪些文件，每个文件负责什么。这是把拆解决策锁定的地方。

- 设计有清晰边界和明确定义接口的单元。每个文件应有单一清晰职责。
- 你在上下文中能一次性把握的代码推理最可靠，文件聚焦时代码编辑更准确。优先选择更小、聚焦的文件，而不是做太多事的大文件。
- 经常一起改的文件应该放在一起。按职责拆分，不按技术层拆分。
- 在已有代码库中，遵循已有模式。如果代码库用大文件，不要单方面重组——但如果正在修改的文件已经长得笨重，把拆分纳入 plan 是合理的。

文件结构为 task 拆解提供信息。每个 task 应产出自成体系、可独立理解的变更。

## Task 粒度

task 是携带自己测试周期、值得一个新审查者审视的最小单元。画 task 边界时：把设置、配置、脚手架和文档步骤折叠进需要它们的 task 中；只在审查者可以有意义地批准一个 task 而拒绝其邻居时才拆分。每个 task 以独立可测试的交付物结束。

## 小口 Task 粒度

**每个步骤是一个动作（2-5 分钟）：**
- "写失败的测试"——一步
- "跑测试确认失败"——一步
- "写最小实现让测试通过"——一步
- "跑测试确认通过"——一步
- "提交"——一步

## Plan 文档头部

**每个 plan 必须以这个头部开始：**

```markdown
# {TID} {title} Implementation Plan

> **给 coder：** 按 step 顺序执行，每 step 勾选完成。step 使用 `- [ ]` checkbox 语法跟踪进度。

**目标：** {一句话描述要做什么}

**方案：** {2-3 句话描述方案}

**技术栈：** {关键技术和库}

## 全局约束

{spec 中跨 task 的要求——版本下限、依赖限制、命名规则——每行一条，精确值从 spec 逐字复制。每个 task 的要求隐式包含本节。}

---
```

## Task 结构

```markdown
### Step N: {子步骤标题}

**文件：**
- 创建: `exact/path/to/file.py`
- 修改: `exact/path/to/existing.py:123-145`
- 测试: `tests/exact/path/to/test.py`

**接口：**
- 消费: {这个 step 使用前面 step 的什么——精确签名}
- 产出: {后面 step 依赖什么——精确函数名、参数和返回类型。step 的实现者只看自己的 task；这个块告诉他们邻居 task 使用的名字和类型。}

- [ ] **Step 1: 写失败的测试**

```python
def test_specific_behavior():
    result = function(input)
    assert result == expected
```

- [ ] **Step 2: 跑测试验证失败**

运行: `pytest tests/path/test.py::test_name -v`
期望: FAIL with "function not defined"

- [ ] **Step 3: 写最小实现**

```python
def function(input):
    return expected
```

- [ ] **Step 4: 跑测试验证通过**

运行: `pytest tests/path/test.py::test_name -v`
期望: PASS

- [ ] **Step 5: 提交**

```bash
git add tests/path/test.py src/path/file.py
git commit -m "feat: add specific feature"
```

## 禁止 Placeholder

每一步必须包含工程师需要的实际内容。以下是 **plan 失败**——永远不要写这些：

- "TODO"、"TBD"、"稍后实现"、"填细节"
- "添加适当的错误处理" / "添加验证" / "处理边界情况"
- "写以上测试"（没有实际测试代码）
- "类似 Step N"（重复代码——工程师可能乱序读 step）
- 描述做什么但不展示怎么做的步骤（代码步骤需要代码块）
- 引用任何 task 中未定义的类型、函数或方法

## 记住

- 始终精确文件路径
- 每步完整代码——如果步骤改代码，展示代码
- 精确命令和期望输出
- DRY、YAGNI、TDD、频繁提交

## 自审

写完完整 plan 后，用全新眼光对照 spec 检查 plan。这是你自己跑的 checklist——不是派 subagent。

**1. Spec 覆盖：** 浏览 spec 中的每个段/需求。能指向实现它的 task 吗？列出任何缺口。

**2. Placeholder 扫描：** 搜索 plan 中的红旗——上述"禁止 Placeholder"段的任何模式。修复。

**3. 类型一致性：** 后面 task 中使用的类型、方法签名和属性名与前面 task 定义的一致吗？Step 3 叫 `clearLayers()` 的函数在 Step 7 叫 `clearFullLayers()` 是 bug。

如果发现问题，直接内联修复。不需要再审——修完继续。如果发现 spec 需求没有对应 task，加 task。

## 快速模式

仅当用户明确说"快速"时走此模式。**不跳过设计过程**——而是 skill 自己完成上述全部步骤，不等用户逐项确认：

1. 自己读 spec 全文
2. 自己画文件结构
3. 自己拆 step，定粒度
4. 自己写完整 plan（每 step 含代码骨架 + 精确命令 + 期望输出）
5. 自己跑自审（spec coverage / placeholder scan / 类型一致性）
6. 输出 plan 全文 + step 概览，请用户审阅

用户只需在最后审阅。说"改"才改，否则通过进入 op-start。

**关键**：不把 step 拆分丢回给用户。拆几个 step、每 step 做什么、文件路径是什么——skill 自己做决定。但必须汇报 step 概览。

## 执行交接

保存 plan 后，指向下一步：

**"Plan 已写入 `docs/harness_execution/tasks/{TID}/plan.md`。task 就位，调 /op-start 开始开发循环。"**

op-start 会接管后续：选 task → 派 coder → review → 收口。

## 相关文件

| 文件 | 用途 |
|---|---|
| `template/harness_execution/tasks/{TID}/plan.md` | plan 模板 |
| `template/harness_execution/tasks/{TID}/spec.md` | spec 模板（输入） |
| `skills/op-generate-spec/SKILL.md` | 上一步：op-generate-spec |
| `skills/op-start/SKILL.md` | 下一步：op-start |
| `skills/op-generate-plan/plan-document-reviewer-prompt.md` | Plan 审阅提示词模板 |
