# 协议 Quick Reference（compact 恢复先读此文件）

> 多 Agent 协作工作流的最小恢复集。compact 后只加载本文件 + tasks_list.json + leader_checkpoint.md 即可重建编排。完整规则见 `agent_protocol.md`。

**角色**：leader(opus, 主会话, 收口改共享文档) / coder(haiku, TDD) / reviewer(sonnet, 写 review_code.md) / test-reviewer(sonnet, 写 review_test.md) / task-splitter(sonnet, 按需, 拆 task 不污染 leader)。无 doc-updater。

**状态机**：`待开始 → 进行中 → 审阅中 → 完成`；FAIL 回进行中（max 3 轮）；3 轮 FAIL → 阻塞。
英文/中文映射：pending=待开始 / coding=进行中 / reviewing=审阅中 / done=完成 / blocked=阻塞。

**单 task 10 步**：①确认 spec/plan 就位 ②拆 steps ③派 coder TDD ④调 task_review.js（或手工派双 review）⑤读 {passed,blockers}（PASS→⑥ / FAIL→发回 Teams coder 改再调 task_review.js，max 3 轮）⑥收口（progress/decisions/tech_debt/ref specs/tasks_list/归档）⑦commit ⑧回填 hash ⑨自检 compact ⑩下一个

**关键路径**：tasks_list.json=状态源 / docs/harness_execution/tasks/{TID}/=进行中 / docs/harness_record/tasks/{TID}/=归档 / docs/harness_blueprint/specs/{功能}.md=当前真相 / docs/harness_execution/leader_checkpoint.md=断点 / **docs/harness/template/=所有文件模板（新建文件拷这里）**

**新建文件规则（强制）**：协议中任何环节要新建文件（task 工作区的 spec/plan/steps/context/review_code/review_test、tasks_list.json、leader_checkpoint、tech_debt、issues/{TID}_*、harness_blueprint/* 等），一律先拷 `docs/harness/template/` 下对应模板再填内容，保证格式一致。无对应模板才自建。

**关键规则**：
- review 判定：脚本模式 task_review.js 返回 `{passed, blockers, techDebt}`；手工模式 review_*.md 首行 `verdict: PASS/FAIL`，leader 只取首行不读正文
- FAIL 默认发回**原 Teams coder**（有状态、跨轮复用），coder 改完写 review_*.md 修改记录，leader 再调 task_review.js，max 3 轮；小修可选 task_review_autofix.js（1 轮 scope 内 autofix，超限 escalate）
- commit 粒度=task，中间状态不 commit；step 不收口不单 commit；大到要多次收口 → 拆 task 派 task-splitter
- 并发=依赖分层+**leader 手动 git worktree 隔离**（不用 isolation:'worktree'，粒度不对），波次=DAG 层全部收口即结束；恢复后必须重算 DAG，不吃 checkpoint 惯性
- teammate idle = 可唤醒资源，FAIL 唤醒原 coder 实例不新 spawn
- spawn 失败重试2次→status=阻塞, blocked_by=spawn；回滚用 git revert 不用 reset

**恢复三件套**：`agent_protocol.md`（完整协议）+ `docs/harness_execution/tasks_list.json`（状态）+ `docs/harness_execution/leader_checkpoint.md`（断点）
