---
name: oplinit
disable-model-invocation: true
description: >
  lite 项目初始化（低侵入版）：绑定项目 skill + 三区骨架 + profile=lite。
  触发：/oplinit（全局常驻入口之一；业务 skill 由本 skill 绑到项目 .claude/skills/）。
  与 heavy 的 opinit 区别：不注册 hook、不归档旧文档、不重构 CLAUDE.md、不提炼 blueprint。
  前置：已跑 install.sh --set-ophome（全局仅装 opinit+oplinit + OP_HOME）。
---

# Op Lite Init Skill

> **脚本根**：lite 与 heavy 共用 `$OP_HOME/scripts/`。先运行 `bash "$OP_HOME/scripts/op_check_env.sh"`。

`/oplinit` 在目标项目初始化 lite 工作流骨架。**一次性**。低项目侵入——只建 `$OP_DOCS_DIR/`（含 `$OP_DOCS_DIR/e2e/` 验收资产），不碰宿主任何已有文件（design §5.3）。**lite 验收 E2E 默认写 `$OP_DOCS_DIR/e2e/`**（不进用户测试 runner 自动发现）；用户显式同意才写顶层 `e2e/`（heavy 路径）。

## 与 heavy /opinit 的区别

| | opinit（heavy） | oplinit（lite） |
|---|---|---|
| 绑定项目 skill | heavy 集 | lite 集 |
| 三区骨架 | ✓ | ✓ |
| 注册 hook 到项目 .claude | ✓ | **✗** |
| 归档旧文档 | ✓ | **✗** |
| 重构 CLAUDE.md | ✓ | **✗** |
| 提炼 blueprint | ✓ | **✗**（op_blueprint 空壳占位） |
| profile | heavy | lite |

## 步骤 0：绑定项目 skill（业务 skill 不进全局）

```bash
bash "$OP_HOME/scripts/op_bind_project_skills.sh" --profile lite
```

绑定后本项目可 `/oplintake` `/oplrun` `/opstatus` `/optriage`。未 bind 前这些命令在本项目不存在。

## 步骤：一次询问 OP 根并建骨架

一次询问 OP 根：默认 `docs/omni_powers`，可选 `docs`，也可填安全项目相对路径。若已有根变化，同时取得迁移确认。

```bash
bash "$OP_HOME/scripts/op_configure_project.sh" --target "<确认的 OP 根>" --yes
source "$OP_HOME/scripts/op_paths.sh"
op_load_paths "" "$(git rev-parse --show-toplevel)"
bash "$OP_HOME/skills/oplinit/scripts/oplinit_skeleton.sh"
```

lite 不注册 hook；项目 settings 仅持久化 `env.OP_DOCS_DIR`。

脚本做：

- 建 `$OP_DOCS_DIR/` 三区（op_blueprint 空壳 / op_execution / op_record）+ `$OP_DOCS_DIR/e2e/`（lite 验收 E2E 默认落点，低侵入；§5.3）
- 写 `$OP_DOCS_DIR/profile` = `lite`
- 内联生成 tasks_list.json / leader_checkpoint.md / progress.md / decisions.md / op_blueprint/README.md（占位说明）
- **幂等**：已存在文件保留不覆盖，只补缺
- **profile 互斥**：已有 `profile=heavy` 或疑似 heavy 残留 → die，不混跑

## 终点

骨架就绪，profile=lite。提示用户：

- `/oplintake "<需求>"` 开始新需求
- `git add -- "$OP_DOCS_DIR" .claude/settings.json .claude/skills && git commit -m "oplinit"` 提交骨架（oplinit 不自动 commit；含 skill 软链）
- skill 断链时重跑：`bash "$OP_HOME/scripts/op_bind_project_skills.sh" --profile lite`

## 相关文件

| 文件 | 用途 |
|---|---|
| `$OP_HOME/scripts/op_bind_project_skills.sh` | 项目 skill 绑定 |
| `$OP_HOME/skills/oplinit/scripts/oplinit_skeleton.sh` | 三区骨架 + profile=lite |
| `$OP_HOME/skills/oplintake/SKILL.md` | 需求入口 |
| `$OP_HOME/skills/oplrun/SKILL.md` | 续跑执行 |
