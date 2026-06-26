# 用户记录的经验 不作为参考 未经用户允许绝不准修改

- [obra/superpowers: An agentic skills framework & software development methodology that works.](https://github.com/obra/superpowers)
  - /superpowers:brainstorming 生成 spec
  - /superpowers:writing-plans 生成 plan
- [Fission-AI/OpenSpec: Spec-driven development (SDD) for AI coding assistants.](https://github.com/Fission-AI/OpenSpec)
- [mattpocock/skills: Skills for Real Engineers. Straight from my .claude directory.](https://github.com/mattpocock/skills)
  - /grill-me 生成 prd

上面三个项目的介绍在这里，/home/karon/karson_ubuntu/user_config_backup/overview


没有生成 dag.md
coder 发消息 leader 收不到
test_reviewer 文档应该放在 worktree 但是卸载了主 repo
coder context.md 写到了主 repo 而非 worktree。修复
closer  没有subagent

两个 FAIL：tech_debt 无 T43 段，归档缺 spec.md/plan.md。修复。

● Bash(echo "" >> docs/harness_execution/tech_debt.md && echo "## T43" >>
      docs/harness_execution/tech_debt.md && echo "无新增。" >>
      docs/harness_execution/tech_debt.md)
  ⎿  (No output)

● Bash(cp docs/harness_execution/tasks/T43/spec.md
      docs/harness_record/tasks/T43/spec.md && cp
      docs/harness_execution/tasks/T43/plan.md docs/harness_record/tasks/T43/p…)
  ⎿  Error: Exit code 1
     cp: cannot stat 'docs/harness_execution/tasks/T43/spec.md': No such file or
     directory

● spec.md/plan.md 已被 git mv 移走了，在 worktree 的 record 里。从那里拷。


closer 删了 spec.md/plan.md 但没归档到 record。从 git 恢复并归档。