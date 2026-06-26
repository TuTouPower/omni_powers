# harness

Claude Code 多 Agent 协作工作流系统。leader 编排、op-op-coder 开发、op-code-reviewer 审查，标准化 task 生命周期。

## 快速开始

```
/op-start    # 统一入口：自动判断状态 → 选 task → 派 op-coder → review → 收口 → 下一个
/op-debt2tasks    # 功能 task 全完成后：扫技术债 → 归类 → 生成偿还 task
```

## 目录结构

```
├── RULES.md        # 核心协议（规则手册）
├── op_decisions.md     # 决策记录
├── op_findings.md              # 实验发现
├── experience.md            # 踩坑笔记
│
├── agents/                  # Agent 角色提示词
│   ├── op-coder.md             #   开发者（TDD、review 反馈处理）
│   ├── op-code-reviewer.md     #   代码审查（安全/架构/错误处理）
│   ├── op-test-reviewer.md     #   测试审查（假测试/mock 风险/E2E 覆盖）
│   └── op-closer.md            #   收口机械步骤（按需启用）
│
├── skills/                  # Claude Code Skills
│   ├── op-start/            #   统一工作流入口
│   │   └── scripts/         #     收口验收脚本
│   ├── op-task/           #   需求→task 前置
│   ├── op-generate-spec/    #   spec 生成
│   ├── op-generate-plan/    #   plan 生成
│   └── op-debt2tasks/       #   技术债偿还
│
└── template/                # 文档模板（三态模型）
    ├── README.md            #   模板用法和命名约定
    ├── index.md             #   文档导航总图
    ├── op_blueprint/   #   稳定真相：prd / architecture / domain / conventions / spec / test
    ├── op_execution/   #   流动工作区：tasks_list / task 工作区 / tech_debt / checkpoint
    └── op_record/      #   冻结历史：decisions / progress
```

## 核心概念

**状态机**：task 生命周期为 `待开始 → 进行中 → 审阅中 → 收口中 → 完成`（或 `阻塞`/`跳过`）。

**三态文档**：
| 层 | 含义 | 例子 |
|---|---|---|
| `op_blueprint/` | 稳定真相（很少变） | prd, architecture, conventions |
| `op_execution/` | 流动工作区（频繁变） | tasks_list.json, task/{TID}/, tech_debt |
| `op_record/` | 冻结历史（只追加） | decisions, progress |

**compact 恢复**：上下文窗口满了自动 compact，恢复时读 `RULES.md` + 用 jq 查询 `tasks_list.json`（⚠️ 严禁 Read 整文件）+ 读 `leader_checkpoint.md`。

## 工作流一览

```
/op-start
    │
    ├─ 全完成     → 提示 /op-debt2tasks
    ├─ 待开始     → 重算 DAG → 选 task → 派 op-coder
    ├─ 进行中     → op-coder 完成 → 派 review（Agent Team）
    ├─ 审阅中     → 读 review_*.md verdict → PASS 进收口 / FAIL 回 op-coder
    └─ 收口       → commit / 归档 / 更新 checkpoint → 自动选下一个
```

## 安装

```bash
git clone <harness_repo>
cd harness
./install.sh    # 写全局配置 → 建 symlink → 设 SessionStart hook
# 重启 Claude Code 生效
```

> 通用化方案详见 `omni_powers_install.md`

## 依赖

- Claude Code（Teams + SendMessage）
- `jq`（tasks_list.json 查询）
- `git`（worktree 隔离）

## 相关文档

| 要查什么 | 去哪看 |
|---|---|
| 完整协议规则 | `RULES.md` |
| 操作细则（jq/回滚/阻塞） | `RULES_DETAIL.md` |
| 决策记录 | `op_decisions.md` |
| 实验发现 | `op_findings.md` |
| 历史踩坑 | `experience.md` |
| 文档模板 | `template/README.md` |
| 文档导航 | `template/index.md`（部署后为 `docs/index.md`） |
| DAG 依赖图 | `docs/op_execution/dag.md`（由 `dag_gen.sh` 生成） |
