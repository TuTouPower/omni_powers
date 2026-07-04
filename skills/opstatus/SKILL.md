---
name: opstatus
description: >
  读 tasks_list.json + leader_checkpoint.md，渲染人类可读状态报告。
  触发：/opstatus、看进度、现在啥情况。
  数据与视图分离：JSON 给机器和 hook，opstatus 给人。
---

# Op Status Skill

`/opstatus` 渲染当前状态。只读，不改任何文件。

## 步骤

### 1. 读 checkpoint

```bash
cat docs/omni_powers/op_execution/leader_checkpoint.md
```

### 2. 查 tasks_list.json（严禁 Read 整文件，用 jq）

```bash
bash "$OP_HOME/scripts/op_jq.sh all          # 全部概览
bash "$OP_HOME/scripts/op_jq.sh pending      # 待开始
bash "$OP_HOME/scripts/op_jq.sh blocked      # 阻塞
bash "$OP_HOME/scripts/op_jq.sh skipped      # 跳过
```

### 3. 渲染报告

输出格式：

```
== 当前 spec == {spec 前缀与名称}
== 上次断点 == {checkpoint 摘要}
== task 进度 ==
  T01 ✅完成  {title}
  T02 🔄进行中 {title}
  T03 ⏳待开始 (依赖 T02) {title}
  T04 🚫阻塞 (quality) {title}
== 下一步 == {下一个可跑 task 或阻塞原因}
== issues == {open issue 计数 + P0/P1 列表}
```

### 4. 异常提示

- 有 `待规划` task → 提示用 `/opintake`
- 有 `阻塞` task → 列出 blocked_by 与所需外部条件
- 有 `tech-debt` 标签 issue → 列出计数

## 相关文件

| 文件 | 用途 |
|---|---|
| `docs/omni_powers/op_execution/tasks_list.json` | 唯一 task 真相源 |
| `docs/omni_powers/op_execution/leader_checkpoint.md` | 断点 |
| `scripts/op_jq.sh` | jq 查询 |
