---
name: opstatus
disable-model-invocation: true
description: >
  读 tasks_list.json + leader_checkpoint.md，渲染人类可读状态报告。
  触发：/opstatus、看进度、现在啥情况。
  数据与视图分离：JSON 给机器和 hook，opstatus 给人。
---

# Op Status Skill

> **路径前置**：进入 skill 后先执行：
> ```bash
> source "$OP_HOME/scripts/op_paths.sh"
> op_load_paths "" "$(git rev-parse --show-toplevel)"
> ```
> 后文 `$OP_DOCS_DIR` 使用解析后项目相对路径；旧项目无配置自动取 `docs/omni_powers`。


> **运行前检查环境**：`bash "$OP_HOME/scripts/op_check_env.sh"`（jq/git/OP_HOME，缺失 die + 装法）
>
> **profile 感知**：先 `cat "$OP_DOCS_DIR/profile"`。`lite` 项目无「收口中」态、无闸门 C；异常提示中 `/opintake` 对应换 `/oplintake`。脚本统一在 `$OP_HOME/scripts/`（两版共用）。

`/opstatus` 渲染当前状态。只读，不改任何文件。

## 步骤

### 1. 读 checkpoint

```bash
cat "$OP_DOCS_DIR/op_execution/leader_checkpoint.md"
```

### 2. 查 tasks_list.json（严禁 Read 整文件，用 jq）

```bash
bash "$OP_HOME/scripts/op_jq.sh" all          # 全部概览
bash "$OP_HOME/scripts/op_jq.sh" pending      # 待开始
bash "$OP_HOME/scripts/op_jq.sh" awaiting     # 待闸门 A 审批
bash "$OP_HOME/scripts/op_jq.sh" blocked      # 阻塞
bash "$OP_HOME/scripts/op_jq.sh" obsolete     # 废弃
```

### 3. 渲染报告

输出格式：

```
== 当前 spec == {TID} {名称}
== 上次断点 == {checkpoint 摘要}
== task 进度 ==
  T0001 ✅完成  {title}
  T0002 🔄进行中 {title}
  T0003 ⏳待开始 (依赖 T0002) {title}
  T0004 ⏸待闸门 A 审批 {title}
  T04 🚫阻塞 (quality) {title}
  T05 ⚫废弃 {title}
== 下一步 == {下一个可跑 task 或阻塞原因}
== issues == {open issue 计数 + P0/P1 列表}
```

### 4. 异常提示

- 有 `待规划` task → 提示用 `/opintake`
- 有 `待闸门 A 审批` task → 提示批准（spec→approved + 转 ready）或 `/opintake` 调整
- 有 `阻塞` task → 列出 blocked_by 与所需外部条件
- 有 `废弃` task → 提示方案调整连带，确认下游是否也废弃
- 有 `tech-debt` 标签 issue → 列出计数

## 相关文件

| 文件 | 用途 |
|---|---|
| `$OP_DOCS_DIR/op_execution/tasks_list.json` | 唯一 task 真相源 |
| `$OP_DOCS_DIR/op_execution/leader_checkpoint.md` | 断点 |
| `scripts/op_jq.sh` | jq 查询 |
