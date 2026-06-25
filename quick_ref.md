# 协议 Quick Reference（compact 恢复先读此文件）

> 最小恢复集。compact 后只加载本文件 + tasks_list.json + leader_checkpoint.md。完整规则见 `agent_protocol.md`。

**角色**：leader(opus, 收口改共享文档) / coder(haiku, TDD) / reviewer(sonnet, 写 review_code.md) / test-reviewer(sonnet, 写 review_test.md) / task-splitter(sonnet, 按需, 拆 task 不污染 leader)。

**状态机**：`待开始 → 进行中 → 审阅中 → 完成`；FAIL 回进行中（max 3 轮）；3 轮 FAIL → 阻塞。

**执行入口**：`/harness-start` 统一驱动（选 task → 派 coder → 调 task_review.js → 收口 → 自动下一个）。需求入轨走 `/intake`，还债走 `/debt-to-tasks`。

**关键路径**：tasks_list.json=状态源 / docs/harness_execution/tasks/{TID}/=进行中 / docs/harness_record/tasks/{TID}/=归档 / docs/harness_blueprint/specs/{feature}.md=当前真相 / leader_checkpoint.md=断点 / docs/harness/template/=所有文件模板。

**新建文件规则**：一律先拷 `docs/harness/template/` 下对应模板再填内容。无对应模板才自建。

**关键规则**：
- review：task_review.js workflow 返回 `{passed, blockers, techDebt}`，leader 读返回值不 grep
- FAIL：发回原 Teams coder（有状态跨轮复用），coder 在 review_*.md 追加修改记录（禁碰 context.md），重调 task_review.js，max 3 轮
- commit 粒度=task，step 不收口不单 commit；大到需多次收口 → 拆 task
- 并发=依赖分层 + leader 手动 git worktree 隔离，上限 3，波次=同层全部收口
- 恢复后必须重算 DAG，不吃 checkpoint 惯性
- idle = 可唤醒资源，FAIL 唤醒原实例不新 spawn
- spawn 失败重试 2 次→阻塞(blocked_by=spawn)；回滚用 git revert

**恢复三件套**：本文件 + tasks_list.json + leader_checkpoint.md。遇细节分歧再查 agent_protocol.md。
