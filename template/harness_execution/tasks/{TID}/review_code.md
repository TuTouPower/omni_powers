verdict: <PASS|FAIL>

> 首行 verdict: leader 读此行判定 PASS/FAIL，不 grep 正文。必须替换为 PASS 或 FAIL。
> **PASS 门槛**：所有未标【暂存】的问题必须 coder 修完才能 PASS。LOW 不是放过理由。
> **暂存判断标准**（满足任一才可标暂存）：跨 scope / 需环境变更 / 架构决策 / 依赖未来 task。
> 标【暂存】的问题不阻塞 PASS，但必须写原因。默认不暂存——能当场修的都标【当场修】。
> **轮次命名**：每轮拆两段——N-1 = reviewer 审阅（写意见 + verdict），N-2 = coder 修改（FAIL 轮才有，逐项回应）。
> PASS 则止于该轮 N-1；FAIL 则进 N-2 修改 → (N+1)-1 重读，循环 max 3 轮。
> 只追加不覆盖——后续轮次在文件末尾续写，不改前文。

---

## Round 1-1 Reviewer 审阅

### CRITICAL
（安全漏洞、数据丢失风险、硬编码 secret——必须修复才能继续）

#### 1. ...【当场修】

### HIGH
（功能性 bug、重大质量问题——应修复）

#### 1. ...【当场修】

### MEDIUM
（代码质量、可维护性问题——建议修复）

#### 1. ...【当场修】

### LOW
（风格、命名、小改进建议——应修复，LOW 不是放过理由）

#### 1. ...【当场修】

> 任何级别满足暂存条件时标【暂存:原因】，如：【暂存:跨 scope，需 T05 先完成】
> 暂存条件：跨 scope / 需环境变更 / 架构决策 / 依赖未来 task

---

## Round 1-2 Coder 修改

> 仅 FAIL 轮写。逐项回应 reviewer：已改 X / 此项不改因为 Y / review 此处判断有误因为 Z。
> 禁止写 context.md——FAIL 轮记录只进 review_*.md。

- CRITICAL X：已改，见 commit / 文件
- HIGH Y：此项不改，因为 Z
- MEDIUM 此处判断有误，因为 W

---

## Round 2-1 Reviewer 重读

> 重读 coder 的 Round 1-2 修改记录 + 新 git diff 后追加。承认误判则 PASS，维持原判则 FAIL 并追加理由。更新首行 verdict。

---

## Round 3-1 Reviewer 重读

（第 3 轮仍 FAIL → 标"status=阻塞, blocked_by=quality"，写 issues/{TID}_quality.md）
