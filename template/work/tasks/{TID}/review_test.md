verdict: PASS

> 首行必须是 `verdict: PASS` 或 `verdict: FAIL`，leader 用 head -1 取此行判断。
> **PASS 门槛**：能当场修的问题（含所有 LOW）必须 coder 修完才能 PASS，LOW 不是放过理由。
> 每条问题明确标【当场修】或【暂存:原因】（跨 scope/环境/架构决策/需未来 task）。标【当场修】没修完 = FAIL。
> FAIL 轮：coder 追加修改记录段，test-reviewer 重读后更新首行 verdict + 追加本轮意见。

## {TID} 测试审查报告

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

## coder 修改记录（FAIL 轮追加，只追加不覆盖）

### Round 2 修改
- CRITICAL X：已补测试
- HIGH Y：此项不改，因为 Z

---

## test-reviewer 回读（FAIL 轮，重读 coder 反驳 + 新 diff 后追加）

### Round 2 回读
- 承认误判：X 项改 PASS，因为...
- 维持原判：Y 项仍 FAIL，因为...
（更新首行 verdict）
