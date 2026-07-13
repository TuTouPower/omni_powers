# Karate 统一 API 与网站 E2E 决策

## D26：Karate 作为唯一 E2E 引擎（2026-07-13）

### 决策

omni_powers 中，所有 API 与网站端到端测试统一使用 Karate。不再以 Playwright（`.spec.ts`）或 Cypress 等为 E2E 生成目标。Karate `.feature` 是唯一 E2E 测试格式，Karate CLI 是唯一 E2E 执行引擎。

### 职责归属

| 内容 | implementer | reviewer | evaluator |
|---|---:|---:|:---:|
| 单元测试 | 写 | 审 | 不写 |
| 集成测试 | 写 | 审 | 按需观察 |
| Karate API E2E | 禁写 | 审测试可信性 | 写、运行、固化 |
| Karate Web E2E | 禁写 | 审测试可信性 | 写、运行、固化 |
| `karate-config.js` / `karate-pom.json` | 禁改 | 审 | 维护 |
| `e2e/support/**` | 禁改 | 审 | 维护 |
| BUG 回归 feature | 禁写 | 审 | 写、运行、固化 |
| acceptance_report.md | 不写 | 不写 | 写 |

### 目录约定

```text
e2e/
├── karate-config.js     # evaluator 维护，implementer 禁改
├── karate-pom.json      # evaluator 维护，implementer 禁改
├── support/             # 共享 setup、auth、data
├── {TID}/               # per-task E2E
└── regression/          # BUG-* 回归测试
```

lite 默认 `docs/omni_powers/e2e/{TID}/`。

### evaluator 流程

1. 从 spec 推导验收场景
2. 写候选 feature → `acceptance/{TID}/karate_work/`
3. 运行候选 → exit 0 + 报告一致
4. 破坏检查（破坏核心断言 → 必红 → 恢复 → 必绿）
5. 固化到 `e2e/{TID}/`
6. 全量回归（所有 feature，不追加 tag 过滤）
7. 存入 `acceptance/{TID}/`，产出 acceptance_report.md

### 防假绿规则

- 零 Scenario / 零 Feature → FAIL
- exit 0 但 JUnit/Cucumber 报告显示失败 → FAIL
- 固化后变异仍绿 → 测试不可固化
- 全量回归必须验证新 task 未破坏既有测试
- 禁止静默跳过已知 flaky 测试（spec 明确允许 quarantine 除外）

### 本地 Karate 版本

固定 commit `576e09e`（v2.1.1.RC1），维护 fat JAR 于 omni_powers 内。不自动下载最新版，不自动安装 Java 21。evaluator 通过 `OP_KARATE_JAR` 发现引擎入口，不可用时报基础设施失败。

### API 与 Web 统一

API 和 Web 可在同一 `.feature` 中组合（API setup → 浏览器验证，或反之），不按技术栈拆为两套框架。将 Spec → AC → Feature → Scenario 作为一条链保持完整溯源。场景必须标注 `@TID` 和 `@AC-N`，tag 作为选择过滤器，不能替代断言。

### 需接受的约束

1. Java 21 成为行为验收的前提依赖
2. 项目不得自行添加 Playwright/Cypress/Selenium E2E
3. 桌面原生应用（非 Web）不承诺 Karate 覆盖
4. OS 原生行为（文件选择器等）优先从 DOM/CDP 入口验证；无法验证时归入 `@channel=cua`，不作为 Karate 阻断
5. accessibility 通过 Karate 调用 axe 完成，不另建测试 runner 或框架
6. 视觉回归通过 `karate-image` 完成
7. 下载/上传/浏览器会话隔离等 Karate v2 当前缺失能力，通过固定版本补丁和 `op_karate.sh` 适配层补齐
8. Karate v2 尚未 GA，omni_powers 采用受控固定发行物，不依赖上游最新版

### 与既有设计的对应

- merge gate（`scripts/op_merge_gate.sh`）：`e2e/**`、`docs/omni_powers/e2e/**` 仍为受保护路径，task 分支变更一律 REJECT
- close gate（`scripts/op_close_post.sh`）：检查 `e2e/{TID}/*.feature` 已 git 跟踪、非零 Scenario、mutation check 全部 KILLED
- opred（`skills/opred/SKILL.md`）：锁定文件从泛化 `e2e/**` 精确化为 `e2e/**/*.feature`、`e2e/karate-config.js`、`e2e/karate-pom.json`、`e2e/support/**`、`e2e/baselines/**`
- 验收信号分层（`docs/omni_powers_design.md`）：结构化断言为硬门，视觉 diff 为视觉 AC 的硬门，截图不可替代行为断言
- eval brief（`scripts/op_assemble_eval_brief.sh`）：移除 Playwright 固化和 `npx playwright test --list`，改为 Karate 命令、JAR 路径、Java 版本和全量回归命令

### 新增文件

- `scripts/op_karate.sh`：依赖检查、feature 发现、task/全量执行、报告归一化、空跑防护
- `tools/karate/`：固定 fat JAR + VERSION + SHA256SUMS
