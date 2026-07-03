---
name: opred
description: >
  红灯归因协议。测试变红时，提供 implementer 和 reviewer 共同遵守的改动依据判定。
  被 op-implementer / op-reviewer 引用，不对外。
---

# opred：红灯归因协议

测试红 → 默认实现错。复现 → 读断言 → 读实现 → 归因 → 才能动手。

## 归因三选一

### (a) 实现 bug

- 断言保护的 AC/INV 没问题，实现没满足
- **动作**：只改实现，不碰测试

### (b) 测试写错

- 断言本身错了（写错期望值、mock 过度、断言内部状态而非行为）
- **动作**：改测试，**必须写明错因**
  - 锁定文件（`e2e/**` 全锁；`BUG-*` 新增统一 `BUG-{id}_*.spec` 命名 + 解锁审批 + fix 归因、修改既有解锁）归因记 `decisions.md`
  - `fix` 场景"原测试供奉了 bug"须给依据（用户报告/INV-x）

### (c) 规格变了

- AC/INV 本身要变（需求改了/发现原规格不对）
- **动作**：走 spec 变更子流程（agent 提 delta → 人批 → 重新 commit → 受影响 task 失效重拆）
- 不直接改测试

## 没有归因不准碰测试

implementer 改测试前必须在 `review.md` 的 Fix-N 段或 `report.md` 的分轮里写明归因（a/b/c + 依据）。reviewer 审查时核对归因是否成立。

## 危险模式（reviewer 扫这些 = 自动怀疑归因缺失）

- 删除/反转 expect
- `toBe` → `toContain`/正则/`>=`（放宽断言）
- timeout/阈值增大
- `.skip`/`.only`
- 删测试文件或 it 块
- test 文件加 eslint-disable
- 恒假断言、纯存在性断言

命中 → reviewer 要求 implementer 给归因。给不出 → `verdict: FAIL`。

## 锁定文件解锁

`e2e/**` 归 op-evaluator 所有，implementer 永久无写权限；`BUG-*` implementer 可新增（fix 回归带归因+解锁审批）、修改既有禁止。归因 (b) 需改锁定测试时：

1. implementer 在 `review.md` 写明归因 + 依据
2. leader 审批
3. evaluator 解锁（`scripts/test_lock.sh remove <file>`）
4. 改测试，记 `decisions.md`
5. 重新锁定

## refactor 型特殊规则

refactor 行为层**完全冻结**（等价性法官）。断言期望值不许变——变了 = 行为变了 = 自动重归类为 `feat`/`fix`，回走 spec 流程。免费的偷改行为检测器。

结构层单测可机械适配（import/调用/mock 挂载点跟改），但断言期望值同样不许变。
