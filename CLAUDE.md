# omni_powers

Claude Code 多 Agent 协作工作流系统（v5 对齐）。leader 编排（被 oplead 驱动）、op-implementer 开发、op-reviewer 双裁决审查、op-evaluator 验收、op-closer 产收口提案。规格是唯一契约，全线 Sub Agent。

## 快速开始

```
/opinit      # 一次性安装：生成 omni_powers 三区骨架 + hooks 注册
/opintake    # 需求入口：分拣 → spec（含设计探索）→ 闸门 A → 自动拆 task → 就绪
/oprun       # 从 checkpoint 续跑：task 循环 → spec 级验收 → 闸门 C → 归档
/opstatus    # 读 tasks_list.json + checkpoint，渲染人类可读状态
```

模型可由环境变量自定义：`OP_IMPLEMENTER_MODEL` / `OP_REVIEWER_MODEL` / `OP_EVALUATOR_MODEL` / `OP_CLOSER_MODEL`，值填 `haiku`/`sonnet`/`opus` 三档之一（对应 `settings.json` 的 `ANTHROPIC_DEFAULT_*_MODEL`）。未设则不传 model 参数，继承主会话当前模型。

## 目录结构

```
├── RULES.md        # 核心协议（规则手册 + 操作细则，v5 对齐）
│
├── docs/                    # 项目文档
│   ├── op_decisions.md      #   决策记录
│   ├── op_findings.md       #   实验发现
│   ├── experience.md        #   踩坑笔记
│   └── op_install.md          # 通用化方案
│
├── agents/                  # Agent 角色提示词（4）
│   ├── op-implementer.md       #   开发者（TDD、review 反馈处理）
│   ├── op-reviewer.md          #   双裁决：规格合规 + 测试可信
│   ├── op-evaluator.md         #   验收方：写 E2E + spec 级验收与对抗探索
│   └── op-closer.md            #   收口提案者（只产提案不落笔）
│
├── skills/                  # Claude Code Skills
│   ├── opinit/            #   一次性安装（外部）
│   ├── opintake/          #   需求入口（外部）
│   ├── oprun/             #   续跑执行（外部）
│   ├── opstatus/          #   状态渲染（外部）
│   ├── opspec/            #   spec 模板 + 设计探索（内部，opintake 调用）
│   ├── opred/             #   红灯归因协议（内部，implementer/reviewer 引用）
│   └── optriage/          #   issue 分级与转 task（内部，oplead 收尾调用）
│
└── docs_template/omni_powers/ # 文档模板（三态模型）
    ├── README.md            #   模板用法和命名约定
    ├── index.md             #   文档导航总图
    ├── op_blueprint/   #   稳定真相：prd / architecture / domain / conventions / spec / test
    ├── op_execution/   #   流动工作区：tasks_list / task 工作区 / issues / checkpoint
    └── op_record/      #   冻结历史：decisions / progress / tasks 归档
```

## 安装

```bash
git clone <omni_powers_repo>
cd omni_powers
./install.sh    # 写全局配置 → 建 symlink → 设 SessionStart hook
# 重启 Claude Code 生效
```

> 通用化方案详见 `docs/op_install.md`

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
| v5 重构方案 | `docs/vendors/reconstruction-proposal.md` |
| v5 修订意见 | `docs/vendors/v5-revision-notes.md` |
