# omni_powers

Claude Code 多 Agent 协作工作流系统。leader 编排（被 oprun 驱动）、op-implementer 开发、op-reviewer 双裁决审查、op-evaluator 验收、op-closer 两段节奏收口。规格是唯一契约，全线 Sub Agent。

支持两模式：**heavy**（全量，hook 强制 + worktree 隔离 + blueprint）与 **lite**（零侵入，不加 hook / 不改用户配置与已有文档）。设计见 `docs/omni_powers_design.md`（heavy+lite 一份，lite 部分在 §5）。

## 快速开始

**安装（heavy / lite 共用一个脚本，只装一次）**：

```bash
git clone <omni_powers_repo> && cd omni_powers
bash install.sh --set-ophome   # 全量装 skill+agent 进 ~/.claude/ + 写 OP_HOME（heavy 需要）
# 只用 lite 可省 --set-ophome；--link 开发模式（软链，改仓库即生效）
```

装完后**按项目选模式**（同一项目只认一个 profile，不混跑）：

**heavy（全量）**：

```
/opinit      # 一次性初始化：三区骨架 + profile=heavy + hooks 注册
/opintake    # 需求入口：分拣 → spec（含设计探索）→ 闸门 A → 自动拆 task → task 待开始
/oprun       # 从 checkpoint 续跑：task 循环 → spec 级验收 → 闸门 C → 归档
/opstatus    # 读 tasks_list.json + checkpoint，渲染人类可读状态
```

**lite（零侵入）**：

```
/oplinit                    # 一次性初始化：三区骨架 + profile=lite（不加 hook、不碰项目配置）
/oplintake "<需求>"         # 需求入口：spec + 拆 task + 闸门 A
/oplrun                     # task 循环（implementer → leader 自验 → reviewer 双裁决 → leader 收口）→ Stage 4 裸评
```

lite 与 heavy 区别：不加 hook（leader 亲自跑测试代替机器校验）、无 closer（leader 收口）、无 blueprint 提炼、evaluator 裸评、脚本自包含。

模型可由环境变量自定义：`OP_IMPLEMENTER_MODEL` / `OP_REVIEWER_MODEL` / `OP_EVALUATOR_MODEL` / `OP_CLOSER_MODEL`，值填 `haiku`/`sonnet`/`opus` 三档之一（对应 `settings.json` 的 `ANTHROPIC_DEFAULT_*_MODEL`）。未设则不传 model 参数，继承主会话当前模型。**spec 编写（含设计探索）归 leader 主会话**，不走 dispatch，闸门 A 前 `/model` 切 Opus。

## 目录结构

```
├── RULES.md        # 运行时操作手册（compact 恢复入口 + 全局状态视图 + profile 分叉）
│
├── install.sh               # 唯一安装脚本（heavy+lite 一次装齐 ~/.claude/）
├── scripts/build_lite.sh    # lite 副本漂移校验（开发用）
│
├── docs/                    # 项目文档
│   ├── op_decisions.md      #   决策记录
│   ├── omni_powers_design.md #  设计档案（heavy+lite 合并版）
│   ├── op_install.md        #   历史安装方案（已废弃，留作档案）
│   └── archive/             #   历史档案（含 op_findings.md、omni_powers_lite_design.md 等）
│
├── agents/                  # Agent 角色提示词（4，两版共用，环境入口 profile 化）
│   ├── op-implementer.md       #   开发者（TDD、review 反馈处理）
│   ├── op-reviewer.md          #   双裁决：规格合规 + 测试可信
│   ├── op-evaluator.md         #   验收方：写 E2E + spec 级验收与对抗探索
│   └── op-closer.md            #   收口提案者（heavy 独有，lite 不派）
│
├── skills/                  # Claude Code Skills
│   ├── opinit/            #   heavy 初始化（外部）
│   ├── opintake/          #   heavy 需求入口（外部）
│   ├── oprun/             #   heavy 续跑执行（外部）
│   ├── opstatus/          #   状态渲染（外部）
│   ├── oplinit/           #   lite 初始化（外部，零侵入）
│   ├── oplintake/         #   lite 需求入口（外部）
│   ├── oplrun/            #   lite 续跑执行（外部，脚本自包含）
│   ├── opspec/            #   spec 模板 + 设计探索（内部，opintake 调用）
│   ├── opred/             #   红灯归因协议（内部，implementer/reviewer 引用）
│   └── optriage/          #   issue 分级与转 task（内部，oprun 收尾时调用）
│
└── docs_template/omni_powers/ # 文档模板（三态模型）
    ├── README.md            #   模板用法和命名约定
    ├── index.md             #   文档导航总图
    ├── op_blueprint/   #   稳定真相：prd / architecture / domain / conventions / spec / test
    ├── op_execution/   #   流动工作区：tasks_list / task 工作区 / issues / checkpoint
    └── op_record/      #   冻结历史：decisions / progress / tasks 归档
```

## 安装

heavy / lite 共用 `install.sh`（见「快速开始」）。不再使用手动 `export OP_HOME` 方式——`--set-ophome` 会把 OP_HOME 写入 `~/.claude/settings.json` 的 env 段。

## 依赖

- `jq`（tasks_list.json 查询、opinit hooks 合并；Windows 需手装：`choco install jq` / `scoop install jq` / [官网下载](https://jqlang.github.io/jq/download/)）
- `git`（worktree 隔离，可选）
- **Windows 用户**：Git for Windows（提供 bash + cygpath；hook 走 polyglot wrapper，见 `hooks/README.md`）
- `bats`（开发测试，可选；`npm install -g bats`）

## 相关文档

| 要查什么 | 去哪看 |
|---|---|
| 运行时操作手册 + 状态机 | `RULES.md` |
| 设计档案（为什么这么设计，heavy+lite 合并版） | `docs/omni_powers_design.md` |
| lite 差异与两版共存架构 | `docs/omni_powers_design.md` §5 |
| 决策记录 | `docs/op_decisions.md` |
| 实验发现（归档） | `docs/archive/op_findings.md` |
| 文档模板 | `docs_template/omni_powers/README.md` |
| 文档导航（模板） | `docs_template/omni_powers/index.md`（部署后为 `docs/omni_powers/index.md`） |
| 厂商分析 | `docs/vendors_analyze/overview.md` |
| 历史安装方案（已废弃） | `docs/op_install.md` |
