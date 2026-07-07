---
name: oplinit
description: >
  lite 项目初始化（零侵入版）：在目标项目建 omni_powers 三区骨架 + 写 profile=lite。
  触发：/oplinit。一次性。
  与 heavy 的 opinit 区别：不注册 hook、不归档旧文档、不重构 CLAUDE.md、不提炼 blueprint。
  前置：已全量安装到 ~/.claude（见仓库 install.sh）。
---

# Op Lite Init Skill

> **脚本根**：leader 先定位本 skill 安装目录（如 `~/.claude/skills/oplinit`），后续脚本用它：
> ```bash
> SKILL_DIR="<本 skill 安装目录>"   # 如 ~/.claude/skills/oplinit
> SCRIPTS="$SKILL_DIR/scripts"
> bash "$SCRIPTS/op_check_env.sh"   # jq/git
> ```

`/oplinit` 在目标项目初始化 lite 工作流骨架。**一次性**。零项目侵入——只建 `docs/omni_powers/` 自己的子目录（含 `docs/omni_powers/e2e/` 验收资产），不碰宿主任何已有文件（design §5.3）。**lite 验收 E2E 默认写 `docs/omni_powers/e2e/`**（零侵入，不进用户测试 runner 自动发现）；用户显式同意才写顶层 `e2e/`（heavy 路径）。

## 与 heavy /opinit 的区别

| | opinit（heavy） | oplinit（lite） |
|---|---|---|
| 三区骨架 | ✓ | ✓ |
| 注册 hook 到项目 .claude | ✓ | **✗** |
| 归档旧文档 | ✓ | **✗** |
| 重构 CLAUDE.md | ✓ | **✗** |
| 提炼 blueprint | ✓ | **✗**（op_blueprint 空壳占位） |
| profile | heavy | lite |

## 步骤：建骨架

```bash
bash "$SCRIPTS/oplinit_skeleton.sh"
```

脚本做：

- 建 `docs/omni_powers/` 三区（op_blueprint 空壳 / op_execution / op_record）+ `docs/omni_powers/e2e/`（lite 验收 E2E 默认落点，零侵入；§5.3）
- 写 `docs/omni_powers/profile` = `lite`
- 内联生成 tasks_list.json / leader_checkpoint.md / progress.md / decisions.md / op_blueprint/README.md（占位说明）
- **幂等**：已存在文件保留不覆盖，只补缺
- **profile 互斥**：已有 `profile=heavy` 或疑似 heavy 残留 → die，不混跑

## 终点

骨架就绪，profile=lite。提示用户：

- `/oplintake "<需求>"` 开始新需求
- `git add docs/omni_powers && git commit -m "oplinit"` 提交骨架（oplinit 不自动 commit）

## 相关文件

| 文件 | 用途 |
|---|---|
| `scripts/oplinit_skeleton.sh` | 三区骨架 + profile=lite |
| `../oplintake/SKILL.md` | 需求入口 |
| `../oplrun/SKILL.md` | 续跑执行 |
