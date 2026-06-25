verdict: PASS

> 首行必须是 `verdict: PASS` 或 `verdict: FAIL`，leader 用 head -1 取此行判断。
> **PASS 门槛**：能当场修的问题（含所有 LOW）必须 coder 修完才能 PASS，LOW 不是放过理由。
> 每条问题明确标【当场修】或【暂存:原因】（跨 scope/环境/架构决策/需未来 task）。标【当场修】没修完 = FAIL。
> FAIL 轮：coder 追加修改记录段，reviewer 重读后更新首行 verdict + 追加本轮意见。

## {TID} 代码审查报告

### blockers
（必须修复才能继续）【当场修】

### risks
（可能出问题）【当场修 / 暂存:原因】

### suggestions
（改进建议，非阻塞）【当场修 / 暂存:原因】

### 逐项详细审查

#### 1. ...【当场修 / 暂存:原因】

---

## coder 修改记录（FAIL 轮追加，只追加不覆盖）

### Round 2 修改
- blocker X：已改，见 commit / 文件
- risk Y：此项不改，因为 Z
- suggestion 此处判断有误，因为 W

---

## reviewer 回读（FAIL 轮，重读 coder 反驳 + 新 diff 后追加）

### Round 2 回读
- 承认误判：X 项改 PASS，因为...
- 维持原判：Y 项仍 FAIL，因为...
（更新首行 verdict）
