# Leader Checkpoint

> 续跑断点。**current_task 只填领用的 TID（如 `T0001`）或空**（awaiting_gate/未领时留空，状态信息归 next_step/关键上下文）——hook P0-4 awk 读它校验新鲜证据，格式须 `^current_task: <TID>`，不可加粗/列表化/填描述。
> task 状态看 tasks_list.json（唯一真相），/opstatus 渲染人类可读视图，不在此复写。

## 断点

### current_task:
### last_completed:
### next_step:

## 关键上下文

- 当前目标：...
- 卡点 / 待决策：...
- 易踩的坑 / 背景须知：...
