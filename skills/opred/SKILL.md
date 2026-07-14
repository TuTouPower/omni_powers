---
name: opred
disable-model-invocation: true
user-invocable: false
description: >
  红灯归因协议。测试变红时，提供 implementer 和 reviewer 共同遵守的改动依据判定。
  被 op-implementer / op-reviewer 引用，不对外。
---

# opred：红灯归因协议

> **运行前检查环境**：`bash "$OP_HOME/scripts/op_check_env.sh"`（jq/git/OP_HOME，缺失 die + 装法）。若仅作为被 agent prompt 引用的纯文本协议片段，不单独执行 shell，则此检查由调用入口负责。

测试红 → 默认实现错。复现 → 读断言 → 读实现 → 归因 → 才能动手。

## 归因三选一

### (a) 实现 bug

- 断言保护的 验收标准/不变量 没问题，实现没满足
- **动作**：只改实现，不碰测试

### (b) 测试写错

- 断言本身错了（写错期望值、mock 过度、断言内部状态而非行为）
- **动作**：改测试，**必须写明错因**
  - 锁定文件（`e2e/**` 全锁；`BUG-*` 新增统一 `BUG-{id}_*.spec` 命名 + 解锁审批 + fix 归因、修改既有解锁）归因记 `decisions.md`
  - `fix` 场景"原测试供奉了 bug"须给依据（用户报告/INV-x）

### (c) 规格变了

- 验收标准/不变量 本身要变（需求改了/发现原规格不对）
- **动作**：走 spec 变更子流程（发现者提 delta → **leader 自主记录改 spec + 更新 tasks_list + 同 TID 重跑**，不重拆、不等用户事批；事后报告呈现，design §2.4/A18）
- 不直接改测试

## 没有归因不准碰测试

implementer 改测试前必须在 `report.md` 的归因段/Fix-N 段写明归因（a/b/c + 依据）——**implementer 对 decisions.md 无写权（design §2.4），归因经 closer per-task 收口提取 append 到 decisions.md（来源标记 red-attribution）**。reviewer 审查时核对归因是否成立。

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

`e2e/**`（含 BUG-*）归 op-evaluator 所有——implementer worktree 不挂 `e2e/`（已落地 advisory 防无意耦合，design §0.1/§0.2）+ task 分支 e2e 变更被 merge gate 硬拦入主分支（design §3.4）；`BUG-*` 新增由 evaluator 写或 implementer 产 patch 附 report 经 leader 落盘（§2.1 fix 流程）、修改既有禁止。归因 (b) 需改锁定测试时：

1. implementer 在 `report.md` 归因段写明归因 + 依据（对 decisions.md 无写权——design §2.4，归因经 closer per-task 收口提取 append）
2. leader 审批
3. leader 解锁（**test_lock.sh 已删 Q3——锁定靠 pre_tool_use `e2e/*` 硬编码 hook，无细粒度锁**；解锁 = leader 直接改实现/测试，记 decisions.md）
4. 改测试，leader 记 `decisions.md`（来源标记 red-attribution）
5. 重新锁定

## refactor 型特殊规则

refactor 行为层**完全冻结**（等价性法官）。断言期望值不许变——变了 = 行为变了 = 自动重归类为 `feat`/`fix`，回走 spec 流程。免费的偷改行为检测器。

结构层单测可机械适配（import/调用/mock 挂载点跟改），但断言期望值同样不许变。
