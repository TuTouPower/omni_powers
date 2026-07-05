# omni_powers 脚本测试

bats 覆盖关键 shell 脚本，锁住 P0/P1 修复，防回归。

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
# 或直接全路径
~/.npm-global/bin/bats tests/scripts/
```

## 测试范围（对应审阅 P0/P1 修复）

| 测试文件 | 覆盖 |
|---|---|
| op_close_post.bats | P0-1 缺 feature die、verdict 校验、归档、P0-4 清 current_task |
| op_status.bats | P1-5 阻塞强校验 blocked_by、状态流转 |
| op-checkpoint.bats | P1-7 幂等 + TID 锚定 |
| op-read-verdict.bats | 轮次判定、exit code |
| close_check.bats | P2-6 TID 精确匹配（不误配 T010） |
| pre_tool_use.bats | P2-4 路径匹配（含 baselines）、spec 写保护 |
| op_check_env.bats | 环境检查脚本（jq/git/OP_HOME） |
| opinit_register_hooks.bats | hooks 注册、OP_HOME 校验、Windows wrapper 改写 |
| opinit_skeleton.bats | 三区骨架、模板复制、幂等保留 |
| run-hook.bats | polyglot wrapper、hook name 自动补 `.sh` |

helpers.bash 建临时 git 仓库 + mock 三区结构，每个 @test 独立隔离。
