# omni_powers

Claude Code 多 Agent 协作工作流系统。leader 编排（被 oprun 驱动）、op-implementer 开发、op-reviewer 双裁决审查、op-evaluator 验收、op-closer 一段式收口。规格是唯一契约，全线 Sub Agent。

支持两模式：**heavy**（全量，task 分支 + merge gate + worktree 隔离 + blueprint，hook 仅主会话 advisory）与 **lite**（低侵入，不加 hook / 无分支拓扑 / 仅写项目 `env.OP_DOCS_DIR`，不改已有文档）。设计见 `docs/omni_powers_design.md`（heavy+lite 一份，lite 部分在 §5）。

## 快速开始

**安装（heavy / lite 共用一个脚本，只装一次）**：

```bash
git clone <omni_powers_repo> && cd omni_powers
bash install.sh --set-ophome
# 效果：写 OP_HOME + 全局仅 /opinit 与 /oplinit；agents 只在 OP_HOME 作模板
```

装完后**按项目选模式**（同一项目只认一个 profile，不混跑）。**业务 skill（oprun 等）在 init 时绑到项目 `.claude/skills/`**，未 init 的项目没有 `/oprun`。

**heavy（全量）**：

```
/opinit      # 全局入口：bind 项目 skill + 三区骨架 + profile=heavy + hooks
/opintake    # 项目 skill：spec → 闸门 A → task 待开始
/oprun       # 项目 skill：task 循环
/opstatus    # 项目 skill：状态
```

**lite（低侵入）**：

```
/oplinit                    # 全局入口：bind 项目 skill + 骨架 + profile=lite
/oplintake "<需求>"         # 项目 skill
/oplrun                     # 项目 skill
```

lite 与 heavy 区别：不加 hook（leader 亲自跑测试代替机器校验）、无 task 分支与 merge gate（主分支直改）、无 closer（leader 收口）、无 blueprint 提炼、evaluator 裸评。脚本统一在 `$OP_HOME/scripts/`。

OP 项目根由项目 `.claude/settings.json.env.OP_DOCS_DIR` 配置。`/opinit`、`/oplinit` 首次询问一次；默认 `docs/omni_powers`，可选 `docs` 或安全项目相对路径。旧项目无配置继续使用默认根。下文 `$OP_DOCS_DIR` 指该配置值。

模型可由环境变量自定义：`OP_IMPLEMENTER_MODEL` / `OP_REVIEWER_MODEL` / `OP_EVALUATOR_MODEL` / `OP_CLOSER_MODEL`，值填 `haiku`/`sonnet`/`opus` 三档之一（对应 `settings.json` 的 `ANTHROPIC_DEFAULT_*_MODEL`）。未设则不传 model 参数，继承主会话当前模型。**spec 编写（含设计探索）归 leader 主会话**，不走 dispatch，闸门 A 前 `/model` 切 Opus。

## 目录结构

```
├── RULES.md        # 运行时操作手册（compact 恢复入口 + 全局状态视图 + profile 分叉）
│
├── install.sh               # 装 OP_HOME + 全局仅 opinit/oplinit
├── scripts/                  # 公用脚本（含 op_bind_project_skills.sh）
│
├── docs/                    # 项目文档
│   ├── op_decisions.md      #   决策记录
│   ├── omni_powers_design.md #  设计档案（heavy+lite 合并版）
│   ├── op_install.md        #   历史安装方案（已废弃，留作档案）
│   └── archive/             #   历史档案（含 op_findings.md、omni_powers_lite_design.md 等）
│
├── agents/                  # 角色提示词模板（只放 OP_HOME，永不注册 agents 发现路径）
│   ├── op-implementer.md       #   开发者（TDD、review 反馈处理）
│   ├── op-reviewer.md          #   双裁决：规格合规 + 测试可信
│   ├── op-evaluator.md         #   验收方：写 E2E + per-task 验收与对抗探索
│   └── op-closer.md            #   收口提案者（heavy 独有，lite 不派）
│                              #   派发：Read 模板 → general-purpose + prompt 注入
│
├── skills/                  # 均 disable-model-invocation（禁止模型自调）
│   ├── opinit/            #   heavy 初始化（**全局**安装）
│   ├── oplinit/           #   lite 初始化（**全局**安装）
│   ├── opintake/          #   heavy 需求入口（**项目** bind）
│   ├── oprun/             #   heavy 续跑（**项目** bind）
│   ├── opstatus/          #   状态（**项目** bind）
│   ├── oplintake/         #   lite 需求入口（**项目** bind）
│   ├── oplrun/            #   lite 续跑（**项目** bind）
│   ├── opspec/            #   内部（项目 bind，user-invocable:false）
│   ├── opred/             #   内部（项目 bind，user-invocable:false）
│   └── optriage/          #   分诊（项目 bind）
│
└── docs_template/omni_powers/ # 文档模板（三态模型）
    ├── op_readme.md        #   模板用法和命名约定
    ├── op_index.md         #   文档导航总图
    ├── op_blueprint/   #   稳定真相：prd / architecture / domain / conventions / spec / test
    ├── op_execution/   #   流动工作区：tasks_list / task 工作区 / issues / checkpoint
    └── op_record/      #   冻结历史：decisions / progress / tasks 归档
```

## 安装

heavy / lite 共用 `install.sh`（见「快速开始」）。`--set-ophome` 把 `OP_HOME` 写入 `~/.claude/settings.json` 的 env 段。

**安装边界**：

| 范围 | 装什么 |
|------|--------|
| 全局 | 仅 `opinit` + `oplinit` 软链；`env.OP_HOME` |
| 项目（`/opinit` 或 `/oplinit`） | `op_bind_project_skills.sh` 把业务 skill 软链到 `.claude/skills/` |
| 永不 | `~/.claude/agents/` 与项目 agents；业务 skill 不进全局 |

## 卸载

`bash uninstall.sh`：删全局 opinit/oplinit 及遗留业务 skill/agent，移除 `env.OP_HOME`。`--purge-project` 另删项目 OP 资产、hook、`.claude/skills/op*` bind 产物。

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
| 文档模板 | `docs_template/omni_powers/op_readme.md` |
| 文档导航（模板） | `docs_template/omni_powers/op_index.md`（部署后为 `$OP_DOCS_DIR/op_index.md`） |
| 厂商分析 | `docs/vendors_analyze/overview.md` |
| 历史安装方案（已废弃） | `docs/op_install.md` |
