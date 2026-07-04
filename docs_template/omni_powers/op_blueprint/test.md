# 测试策略

> 职责（design §3.3）：测试宪章——分层/覆盖/lane/Mock 规则/调试入口（CDP 等）。
> 不在此：命名/架构。

## 分层
| 层 | 工具 | 范围 | 覆盖目标 |
|---|---|---|---|
| 单元 | pytest / vitest | 函数/模块 | 80%+ |
| 集成 | pytest + TEST_DATABASE_URL | API+DB | 核心流程 |
| E2E | Playwright | 用户流程 | 关键路径 |

## 运行
- API: `cd src/api && .venv/bin/pytest`
- Web: `cd src/web && npx vitest run`

## 约定
- 先测试后实现（TDD）
- 测试断言具体值，禁止 toBeTruthy/length>0 空洞断言
- mock 不掩盖真实问题
