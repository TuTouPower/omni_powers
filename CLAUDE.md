# omni_powers

Claude Code 多 Agent 协作工作流系统。leader 编排、op-coder 开发、op-code-reviewer 审查，标准化 task 生命周期。全线 Sub Agent（D15）。

## 快速开始

```
/op-start    # 统一入口：自动判断状态 → 选 task → 派 op-coder → review → 收口 → 下一个
/op-debt2tasks    # 功能 task 全完成后：扫技术债 → 归类 → 生成偿还 task
```

## 目录结构

```
├── RULES.md        # 核心协议（规则手册 + 操作细则）
│
├── docs/                    # 项目文档
│   ├── op_decisions.md      #   决策记录
│   ├── op_findings.md       #   实验发现
│   ├── experience.md        #   踩坑笔记
│   └── omni_powers_install.md # 通用化方案
│
├── agents/                  # Agent 角色提示词
│   ├── op-coder.md             #   开发者（TDD、review 反馈处理）
│   ├── op-code-reviewer.md     #   代码审查（安全/架构/错误处理）
│   ├── op-test-reviewer.md     #   测试审查（假测试/mock 风险/E2E 覆盖）
│   ├── op-spec-reviewer.md     #   spec 合规审查（逐条核对实现是否与 spec 一致）
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
└── docs_template/omni_powers/ # 文档模板（三态模型）
    ├── README.md            #   模板用法和命名约定
    ├── index.md             #   文档导航总图
    ├── op_blueprint/   #   稳定真相：prd / architecture / domain / conventions / spec / test
    ├── op_execution/   #   流动工作区：tasks_list / task 工作区 / tech_debt / checkpoint
    └── op_record/      #   冻结历史：decisions / progress
```

## 安装

```bash
git clone <omni_powers_repo>
cd omni_powers
./install.sh    # 写全局配置 → 建 symlink → 设 SessionStart hook
# 重启 Claude Code 生效
```

> 通用化方案详见 `docs/omni_powers_install.md`

## 依赖

- `jq`（tasks_list.json 查询）
- `git`（worktree 隔离，可选）

## 相关文档

| 要查什么 | 去哪看 |
|---|---|
| 完整协议规则 + 操作细则 | `RULES.md` |
| 决策记录 | `docs/omni_powers/op_decisions.md` |
| 实验发现 | `docs/omni_powers/op_findings.md` |
| 历史踩坑 | `docs/experience.md` |
| 文档模板 | `docs_template/omni_powers/README.md` |
| 文档导航 | `docs_template/omni_powers/index.md`（部署后为 `docs/index.md`） |
| DAG 依赖图 | `docs/omni_powers/op_execution/dag.md`（由 `dag_gen.sh` 生成） |
