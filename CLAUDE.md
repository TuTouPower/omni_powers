# harness

Claude Code 多 Agent 协作工作流系统。leader 编排、coder 开发、reviewer 审查，标准化 task 生命周期。

## 快速开始

```
/harness-start    # 统一入口：自动判断状态 → 选 task → 派 coder → review → 收口 → 下一个
/debt-to-tasks    # 功能 task 全完成后：扫技术债 → 归类 → 生成偿还 task
```

## 目录结构

```
├── agent_protocol.md        # 核心协议（规则手册 + compact 恢复最小集）
├── workflow_design.md       # Workflow 脚本设计决策（why）
├── experience.md            # 踩坑笔记
│
├── agents/                  # Agent 角色提示词
│   ├── coder.md             #   开发者（TDD、review 反馈处理）
│   └── test-reviewer.md     #   测试审查（假测试/mock 风险/E2E 覆盖）
│
├── workflows/               # Workflow 脚本（可执行 JS）
│   ├── README.md            #   接口手册（调用方式、args、返回结构）
│   ├── task_review.js       #   单 task review gate（主用，含可选 autofix）
│   └── task_full.js         #   单 task 全流程（可选，默认不用）
│
├── skills/                  # Claude Code Skills
│   ├── harness-start/       #   统一工作流入口
│   │   └── scripts/         #     收口验收脚本
│   ├── intake/              #   需求→task 前置
│   ├── spec-generator/      #   spec 生成
│   ├── plan-generator/      #   plan 生成
│   └── debt-to-tasks/       #   技术债偿还
│
└── template/                # 文档模板（三态模型）
    ├── README.md            #   模板用法和命名约定
    ├── index.md             #   文档导航总图
    ├── harness_blueprint/   #   稳定真相：prd / architecture / domain / conventions / spec / test
    ├── harness_execution/   #   流动工作区：tasks_list / task 工作区 / tech_debt / checkpoint
    └── harness_record/      #   冻结历史：decisions / progress
```

## 核心概念

**状态机**：task 生命周期为 `待开始 → 进行中 → 审阅中 → 完成`（或 `阻塞`）。

**三态文档**：
| 层 | 含义 | 例子 |
|---|---|---|
| `harness_blueprint/` | 稳定真相（很少变） | prd, architecture, conventions |
| `harness_execution/` | 流动工作区（频繁变） | tasks_list.json, task/{TID}/, tech_debt |
| `harness_record/` | 冻结历史（只追加） | decisions, progress |

**compact 恢复**：上下文窗口满了自动 compact，恢复时读 `agent_protocol.md` + `tasks_list.json` + `leader_checkpoint.md`。

## 工作流一览

```
/harness-start
    │
    ├─ ALL_DONE   → 提示 /debt-to-tasks
    ├─ READY      → 重算 DAG → 选 task → 派 coder
    ├─ CODING     → 检查 coder 进度 → 完成则调 task_review.js
    ├─ REVIEW     → 读 workflow 返回值 → PASS 进收口 / FAIL 回 coder
    └─ 收口       → commit / 归档 / 更新 checkpoint → 自动选下一个
```

## 依赖

- Claude Code（Teams + Workflow tool + SendMessage）
- `jq`（tasks_list.json 查询）
- `git`（worktree 并发隔离）

## 相关文档

| 要查什么 | 去哪看 |
|---|---|
| 完整协议规则 | `agent_protocol.md` |
| 实验发现 | `findings.md` |
| 决策记录 | `decisions.md` |
| Workflow 脚本接口 | `workflows/README.md` |
| Workflow 设计决策 | `workflow_design.md` |
| 历史踩坑 | `experience.md` |
| 文档模板 | `template/README.md` |
