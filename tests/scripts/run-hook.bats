#!/usr/bin/env bats

# 测 polyglot wrapper（run-hook.cmd）的 bash 路径
# CMD 路径在 Linux 无法测，基于 superpowers 验证写法信任

load helpers

@test "run-hook.cmd: polyglot bash 路径路由 pre_tool_use" {
  run bash "$OP_HOME/hooks/run-hook.cmd" pre_tool_use <<< '{"tool_name":"Bash","tool_input":{"command":"git commit --no-verify"}}'
  [ "$status" -eq 2 ]
  [[ "$output" == *"--no-verify"* ]]
}

@test "run-hook.cmd: 缺 hook 名 die" {
  run bash "$OP_HOME/hooks/run-hook.cmd"
  [ "$status" -ne 0 ]
  [[ "$output" == *"用法"* ]]
}

@test "run-hook.cmd: 参数自动补 .sh（无需传扩展名）" {
  run bash "$OP_HOME/hooks/run-hook.cmd" pre_tool_use <<< '{"tool_name":"Bash","tool_input":{"command":"git commit --no-verify"}}'
  # 路由到 pre_tool_use.sh 成功（exit 2 = 拦截 --no-verify），证明 .sh 自动补
  [ "$status" -eq 2 ]
}
