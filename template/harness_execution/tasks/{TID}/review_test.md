verdict: <PASS|FAIL>

> 首行 verdict: leader 读此行判定 PASS/FAIL，不 grep 正文。必须替换为 PASS 或 FAIL。
> **PASS 门槛**：所有未标【暂存】的问题必须 coder 修完才能 PASS。LOW 不是放过理由。
> **暂存判断标准**（满足任一才可标暂存）：跨 scope / 需环境变更 / 架构决策 / 依赖未来 task。
> 标【暂存】的问题不阻塞 PASS，但必须写原因。默认不暂存——能当场修的都标【当场修】。
> **轮次命名**：Review-N = test-reviewer 审阅（写意见 + verdict），Fix-N = coder 修改（FAIL 轮才有，逐项回应）。
> PASS 则止于 Review-N；FAIL 则进 Fix-N → Review-(N+1) 重读，循环 max 3 轮。
> 只追加不覆盖——后续轮次在文件末尾续写，不改前文。

---

## Review-1

### 1. 假测试 / 空洞断言
（文件、测试名、可疑断言、应改成什么具体断言）【当场修】

### 2. mock 风险
（哪些 mock 不够真实、漏掉了什么、应补哪些真实样本）【当场修】

### 3. skip / todo / only / 条件跳过
（文件、测试名、是否合理、是否导致关键路径没被测试）【当场修】

### 4. E2E 覆盖
（核心用户路径是否有 E2E、是否真实执行、是否有具体断言）【当场修】

### 5. 缺失的测试
（当前功能应该有但没写的测试，按严重度分级）

#### CRITICAL
#### HIGH
#### MEDIUM
#### LOW

### 6. bug 修复回归测试
（每个 bug 修复是否有回归测试、修复前是否失败、修复后是否通过）【当场修】

### 7. 测试与实现同步
（代码变了但测试没变、fixture/snapshot/schema 过时、文档不一致）【当场修】

### 8. 测试产物泄漏
（coverage/、playwright-report/、test-results/、test account 是否被 git 跟踪或打包进生产）【当场修】

### 9. 日志脱敏审查
（错误消息是否泄露变量值、API key、用户数据）【当场修】

---

## Fix-1

> 仅 FAIL 轮写。逐项回应 test-reviewer：已改 X / 此项不改因为 Y / review 此处判断有误因为 Z。
> 禁止写 context.md——FAIL 轮记录只进 review_*.md。

- 问题 X：已改，见 commit / 文件
- 问题 Y：此项不改，因为 Z

---

## Review-2

> 重读 coder 的 Fix-1 修改记录 + 新 git diff 后追加。承认误判则 PASS，维持原判则 FAIL 并追加理由。更新首行 verdict。

---

## Review-3

（第 3 轮仍 FAIL → 标"status=阻塞, blocked_by=quality"，写 issues/{TID}_quality.md）
