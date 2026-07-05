# {TID} 质量阻塞

> review 满 2 轮仍 FAIL 时写（第 2 轮 FAIL → 阻塞，下游跳过）。

issue_id: {TID}_quality
source: reviewer FAIL（{TID}）
spec: {前缀}
task: {TID}
severity: P0 | P1
status: open
tags: [quality, blocker]
created_at: {YYYY-MM-DD HH:mm UTC+8}

## 未解决的问题
（从 review.md 摘要残留的 CRITICAL/HIGH）

## 已尝试轮数
2 轮（review 上限）

## 影响
- 该 task 标"status=阻塞, blocked_by=quality"
- 后续依赖该 task 的 task 也受影响

## 恢复条件
（需用户提供什么 / 哪天重试）
