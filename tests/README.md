# omni_powers 脚本测试

bats 覆盖关键 shell 脚本，锁住 P0/P1 修复 + 第二轮审阅同步，防回归。

## 安装 bats

```bash
npm install -g bats       # 装 ~/.npm-global/bin/bats
# 或 apt install bats / git submodule bats-core
```

## 跑测试

```bash
# 在 omni_powers 仓库根
bats tests/scripts/                    # 全部
bats tests/scripts/op_close_post.bats  # 单文件
```

若 bats 不在 PATH（npm 装在 `~/.npm-global/bin/`）：

```bash
export PATH="$HOME/.npm-global/bin:$PATH"
~/.npm-global/bin/bats tests/scripts/
```

## 测试范围（对应 design §0.2 能力矩阵已落地防线）

| 测试文件 | 覆盖 |
|---|---|
| op_close_post.bats | 校验 review+eval verdict PASS（D6）+ 归档 task/spec/acceptance（§1.2 三态）+ 标 done + 清 current_task |
| op_status.bats | blocked 强校验 blocked_by、状态流转（ASCII：blocked/done） |
| op_read_verdict.bats | 轮次判定、exit code |
| close_check.bats | 归档验收（tasks_list done + 归档二件齐全） |
| pre_tool_use.bats | 路径匹配（含 baselines）、spec 写保护 |
| op_check_env.bats | 环境检查（jq/git/OP_HOME） |
| opinit_register_hooks.bats | hooks 注册（PreToolUse/PostToolUse/SubagentStop/Stop）、OP_HOME 校验、Windows wrapper |
| opinit_skeleton.bats | 三区骨架、模板复制、幂等保留 |
| run-hook.bats | polyglot wrapper、hook name 自动补 `.sh` |
| op_trailer_unlock.bats | e2e trailer HMAC 生成 + commit-msg/pre-commit 端到端（含 staged 变 trailer 失效） |
| op_worktree_setup.bats | sparse-checkout 隔离（dev 无 e2e / eval 无 src+tasks+decisions，含 specs/acceptance 挂载断言） |
| op_closer_gate.bats | closer 越界机械校验（白名单通过 + 越界只报不撤销，Q5） |
| op_mutation_check.bats | 变异测试骨架（== ↔ != 自检） |

helpers.bash 建临时 git 仓库 + mock 三区结构（ASCII fixture + eval:skip），每个 @test 独立隔离。

## 未覆盖（随实现落地）

merge gate（op_merge_gate.sh，已落地，测试见 op_merge_gate.bats）、系统层夜跑（P2+/P3 未落地）—— 实现后补 bats。
