verdict: PASS

> 首行必须是 `verdict: PASS` 或 `verdict: FAIL`，leader 用 head -1 取此行判断。
> **PASS 门槛**：能当场修的问题（含所有 LOW）必须 coder 修完才能 PASS，LOW 不是放过理由。
> 每条问题明确标【当场修】或【暂存:原因】（跨 scope/环境/架构决策/需未来 task）。标【当场修】没修完 = FAIL。
> **轮次命名**：每轮拆两段——N-1 = test-reviewer 审阅（写意见 + verdict），N-2 = coder 修改（FAIL 轮才有，逐项回应）。
> PASS 则止于该轮 N-1；FAIL 则进 N-2 修改 → (N+1)-1 重读，循环 max 3 轮。
> 只追加不覆盖——后续轮次在文件末尾续写，不改前文。

---

## Round 1-1 Test-Reviewer 审阅

### 假测试/空洞断言
（文件、测试名、可疑断言、应改成什么）【当场修】

### mock 风险
（哪些 mock 不够真实）【当场修 / 暂存:原因】

### 缺失的测试
### CRITICAL
### HIGH
### MEDIUM
### LOW

### 日志脱敏审查
（错误消息是否泄露变量值）【当场修 / 暂存:原因】

---

## Round 1-2 Coder 修改

> 仅 FAIL 轮写。逐项回应 test-reviewer：已改 X / 此项不改因为 Y / review 此处判断有误因为 Z。
> 禁止写 context.md——FAIL 轮记录只进 review_*.md。

- CRITICAL X：已补测试
- HIGH Y：此项不改，因为 Z

---

## Round 2-1 Test-Reviewer 重读

> 重读 coder 的 Round 1-2 修改记录 + 新 git diff 后追加。承认误判则 PASS，维持原判则 FAIL 并追加理由。更新首行 verdict。

- 承认误判：X 项改 PASS，因为...
- 维持原判：Y 项仍 FAIL，因为...

---

## Round 2-2 Coder 修改

（同 Round 1-2 格式）

---

## Round 3-1 Test-Reviewer 重读

（第 3 轮仍 FAIL → 标"status=阻塞, blocked_by=quality"，写 issues/{TID}_quality.md）
