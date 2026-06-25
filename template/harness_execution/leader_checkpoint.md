# Leader Checkpoint

> 每 task 闭环后写。compact 后从此文件恢复。也作会话交接——人读"关键上下文"段即可接手。
> 写完必须跑 `bash docs/harness/skills/harness-start/scripts/close_check.sh {TID}` 验收，非 0 不许进下一个 task。

## 已完成 task
- {TID} ... ✅ {hash}

## tasks_list.json 状态
- 完成：...
- 下一个：{TID}
- 阻塞跳过：...

## team 状态
- team: {name}
- team config 路径: `~/.claude/teams/{team-name}/config.json`（compact 恢复时查 team 还在不在、paneId 在哪）
- coder: {复用/重 spawn 决策}
- reviewer / test-reviewer: 常驻

## compact 计数
- 已完成 N task

## 依赖 DAG
（拓扑分层，波次编排用。⚠️ 恢复后必须重算 DAG 层宽，不吃 checkpoint 惯性）

## 关键上下文（给人读）
- 当前目标：...
- 下一步：...
- 卡点 / 待决策：...
- 易踩的坑 / 背景须知：...
