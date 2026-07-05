# 测试策略

> 职责（design §3.3）：测试宪章——分层/覆盖/lane/Mock 规则/调试入口（CDP 等）。
> 不在此：命名/架构。
> **命令勿臆造**：测试/运行命令必须从项目实际提取（CLAUDE.md / README / 旧 test.md / package.json scripts / scripts/ / Makefile 各处都可能），找不到标 NEEDS CLARIFICATION 问用户。

## 分层
| 层 | 工具 | 范围 | 覆盖目标 |
|---|---|---|---|
| 单元 | {项目实际命令/工具} | 函数/模块 | {项目目标；默认 80%+} |
| 集成 | {项目实际命令/工具} | 模块边界/API/存储 | 核心流程 |
| E2E | {项目实际命令/工具} | 用户流程 | 关键路径 |

## E2E 通道与 lane
| lane | 通道 | 判定 | 夜跑失败 |
|---|---|---|---|
| cdp | CDP（Playwright）/ 直驱（Bash/HTTP/SQL） | 结构化信号进机械硬门 | 阻断，自动开 issue |
| cua | CUA driver（OS 级真输入，`// channel: cua` 标注） | advisory（天然 flaky：焦点/DPI/时序） | 不阻断，开 issue |

通道判定见 opspec「通道判定」：Chromium 渲染的用 CDP，OS 原生壳层用 cua，无 UI 直驱。
<!-- 若有个人测试总方案（如 TESTING_PLAN.md），在此引用作上游宪章：用例矩阵/CI 分组/边界表不复写 -->

## 运行
- 单元: {从项目实际提取；找不到写 NEEDS CLARIFICATION}
- 集成: {从项目实际提取；找不到写 NEEDS CLARIFICATION}
- E2E: {从项目实际提取；找不到写 NEEDS CLARIFICATION}

## 约定
- 先测试后实现（TDD）
- 测试断言具体值，禁止 toBeTruthy/length>0 空洞断言
- mock 不掩盖真实问题
