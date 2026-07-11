# 测试策略

> 职责（design §3.3）：测试宪章——分层/覆盖/Mock 规则/调试入口。
> 不在此：命名/架构。
> **命令勿臆造**：测试/运行命令必须从项目实际提取（CLAUDE.md / README / 旧 test.md / package.json scripts / scripts/ / Makefile 各处都可能），找不到标 NEEDS CLARIFICATION 问用户。

## 分层
| 层 | 工具 | 范围 | 覆盖目标 |
|---|---|---|---|
| 单元 | {项目实际命令/工具} | 函数/模块 | {项目目标；默认 80%+} |
| 集成 | {项目实际命令/工具} | 模块边界/API/存储 | 核心流程 |
| E2E | {项目实际命令/工具} | 用户流程 | 关键路径 |

<!-- 若有个人测试总方案（如 TESTING_PLAN.md），在此引用作上游宪章：用例矩阵/CI 分组/边界表不复写 -->
<!-- E2E 验收通道（CDP/cua/直驱）与 lane 严格度是 omni_powers 框架机制，见 design「验收信号」与 opspec「通道判定」，不在项目 test.md 复写 -->

## 运行
- 单元: {从项目实际提取；找不到写 NEEDS CLARIFICATION}
- 集成: {从项目实际提取；找不到写 NEEDS CLARIFICATION}
- E2E: {从项目实际提取；找不到写 NEEDS CLARIFICATION}

## 约定
- 先测试后实现（TDD）
- 测试断言具体值，禁止 toBeTruthy/length>0 空洞断言
- mock 不掩盖真实问题
