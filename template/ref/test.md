# 测试策略

> 测试分层、覆盖要求、运行方式。

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
