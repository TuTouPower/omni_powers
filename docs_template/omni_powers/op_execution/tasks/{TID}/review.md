# {TID} Review

## 裁决一：规格合规
### AC 覆盖
- {每条声明覆盖的 AC 是否真做到}

### 偏航检查
- {实际工作集 vs 预估偏差 / 自由发挥 / 范围偏航}

### INV 检查
- {触碰的 INV 是否守住}

## 裁决二：测试可信
### 测试质量
- {测的是 AC 还是 mock / 断言用户可观察 / 异步时序}

### 危险模式扫描
- {expect·assert 变更 / .skip·.only / timeout 增大 / 删测试块 / 加 eslint-disable}

## 问题清单
| # | 严重度 | 问题 | 暂存 |
|---|---|---|---|
| 1 | CRITICAL/HIGH/MEDIUM/LOW | {描述} | 是/否 |

<!--
verdict 规则：
- 文件最后一行必须 `verdict: PASS` 或 `verdict: FAIL`
- 首轮写一行；重审（FAIL 修复后）追加新 verdict 行，以最后一行为准
- PASS 门槛：所有未标【暂存】的问题必须修完
- review ≤ 2 轮（design §7.2 / RULES.md）；第 2 轮仍 FAIL → 阻塞
-->

verdict: PASS
