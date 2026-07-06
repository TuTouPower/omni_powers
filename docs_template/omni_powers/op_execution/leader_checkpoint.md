# Leader Checkpoint

> 每 task 闭环后由 `op_checkpoint.sh {TID}` 自动生成机械部分，leader 补填"关键上下文"段。
> 写完应跑 `bash "$OP_HOME/skills/oprun/scripts/close_check.sh" {TID}` 验收，非 0 不许进下一个 task。

current_task:
last_completed:
next_step:

## 已完成 task

<!-- AUTO: op_checkpoint.sh 自动追加 -->

## tasks_list 状态

<!-- AUTO: op_checkpoint.sh 自动生成 -->

## 关键上下文（leader 手动填）

- 当前目标：...
- 下一步：...
- 卡点 / 待决策：...
- 易踩的坑 / 背景须知：...
