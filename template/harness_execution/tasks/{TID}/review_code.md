verdict: <PASS|FAIL>

> 首行 verdict: 为人工阅读参考。实际判定：leader 读 review_*.md 首行 verdict，不 grep 正文。
> **PASS 门槛**：能当场修的问题（含所有 LOW）必须 coder 修完才能 PASS，LOW 不是放过理由。
> 每条问题明确标【当场修】或【暂存:原因】（跨 scope/环境/架构决策/需未来 task）。标【当场修】没修完 = FAIL。
> **轮次命名**：每轮拆两段——N-1 = reviewer 审阅（写意见 + verdict），N-2 = coder 修改（FAIL 轮才有，逐项回应）。
> PASS 则止于该轮 N-1；FAIL 则进 N-2 修改 → (N+1)-1 重读，循环 max 3 轮。
> 只追加不覆盖——后续轮次在文件末尾续写，不改前文。

---

## Round 1-1 Reviewer 审阅

### blockers
（必须修复才能继续）【当场修】

### risks
（可能出问题）【当场修 / 暂存:原因】

### suggestions
（改进建议，非阻塞）【当场修 / 暂存:原因】

### 逐项详细审查

#### 1. ...【当场修 / 暂存:原因】

---

## Round 1-2 Coder 修改

> 仅 FAIL 轮写。逐项回应 reviewer：已改 X / 此项不改因为 Y / review 此处判断有误因为 Z。
> 禁止写 context.md——FAIL 轮记录只进 review_*.md。

- blocker X：已改，见 commit / 文件
- risk Y：此项不改，因为 Z
- suggestion 此处判断有误，因为 W

---

## Round 2-1 Reviewer 重读

> 重读 coder 的 Round 1-2 修改记录 + 新 git diff 后追加。承认误判则 PASS，维持原判则 FAIL 并追加理由。更新首行 verdict。

- 承认误判：X 项改 PASS，因为...
- 维持原判：Y 项仍 FAIL，因为...

---

## Round 2-2 Coder 修改

（同 Round 1-2 格式）

---

## Round 3-1 Reviewer 重读

（第 3 轮仍 FAIL → 标"status=阻塞, blocked_by=quality"，写 issues/{TID}_quality.md）
