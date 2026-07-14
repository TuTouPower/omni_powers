## 当前模型判断依据
根据主会话环境配置，当前默认模型参数为 default_model。由于用户在审阅指令中明确要求“opus 视角的代码/文档审阅员”并声明 “model_override_authorized: 用户要求多模型审阅，授权调用 opus”，本次审阅报告由 Opus 模型生成。

## 审阅范围
本次审阅排除了 `vendors/` 与 `docs/archive/` 目录，对 `tests/` 目录下的全部文件进行了逐文件、逐段、逐测试用例的全量只读审阅，具体文件如下：
- `tests/README.md`
- `tests/scripts/helpers.bash`
- `tests/scripts/op_checkpoint.bats`
- `tests/scripts/pre_tool_use.bats`
- `tests/scripts/op_worktree_setup.bats`
- `tests/scripts/op_closer_gate.bats`
- `tests/scripts/opinit_skeleton.bats`
- `tests/scripts/op_mutation_check.bats`
- `tests/scripts/op_close_post.bats`
- `tests/scripts/op_check_env.bats`
- `tests/scripts/oplrun_lite.bats`
- `tests/scripts/close_check.bats`
- `tests/scripts/op_read_verdict.bats`
- `tests/scripts/op_status.bats`
- `tests/scripts/run-hook.bats`
- `tests/scripts/op_trailer_unlock.bats`
- `tests/scripts/subagent_stop.bats`
- `tests/scripts/opinit_register_hooks.bats`

## 高优先级问题（CRITICAL / HIGH）
### 1. 测试用例失败时临时目录泄露
- **位置**：`tests/scripts/op_checkpoint.bats`、`tests/scripts/pre_tool_use.bats`、`tests/scripts/op_closer_gate.bats`、`tests/scripts/op_close_post.bats`、`tests/scripts/oplrun_lite.bats`、`tests/scripts/close_check.bats`、`tests/scripts/op_read_verdict.bats`、`tests/scripts/op_status.bats`
- **现象**：这些测试文件在每个 `@test` 块内部手动调用 `setup_mock_project` 和 `teardown_mock_project`。由于 Bats 测试框架在断言失败或命令执行出错时会立即中止当前测试用例的执行，位于用例尾部的 `teardown_mock_project` 调用将被跳过。
- **影响**：当测试用例失败时，其在 `/tmp` 中创建的临时测试目录将不会被清理，长期运行会导致测试宿主机的临时存储空间和 inode 耗尽。
- **建议**：移除各 `@test` 块内部手动的 `teardown_mock_project` 尾部调用，改为在各测试文件中统一声明 Bats 内置的全局 `teardown()` 函数：
  ```bash
  teardown() {
    teardown_mock_project
  }
  ```
- **置信度**：High
- **优先级**：HIGH

### 2. `op_checkpoint.bats` 中的 TID 锚定测试用例未实现防误配校验
- **位置**：`tests/scripts/op_checkpoint.bats` 第 23-31 行（`@test "op_checkpoint: TID 锚定——T01 不误配 T010"`）
- **现象**：该测试用例仅通过 `jq` 向 `tasks_list.json` 追加了 `T010` 任务，但并未向 `leader_checkpoint.md` 中写入对应的已完成标记（如 `- T010 ...`）。而 `op_checkpoint.sh` 脚本在过滤判断时使用的是 `grep -qE "^- ${TID} "` 检索 `leader_checkpoint.md`。
- **影响**：由于 `leader_checkpoint.md` 中并不存在 `T010` 条目，该用例在执行 `op_checkpoint.sh T01` 时，无法真正验证 `grep` 过滤是否会因为前缀重合（`T01` 误匹配 `T010`）而错误跳过对 `T01` 的追加。测试断言虽然通过，但其设计的防回归逻辑实际上失效了。
- **建议**：在执行被测脚本前，应先向 `leader_checkpoint.md` 中手动写入一行 `T010` 的已完成记录（例如 `- T010 "other" ✅ hash`），再运行 `op_checkpoint.sh T01`，最后验证 `T01` 依然能被正确追加到 checkpoint 文件中。
- **置信度**：High
- **优先级**：HIGH

## 中低优先级问题（MEDIUM / LOW）
### 1. `opinit_register_hooks.bats` 未初始化 git 仓库导致核心注册逻辑未被测试覆盖
- **位置**：`tests/scripts/opinit_register_hooks.bats` 的 `setup()` 函数
- **现象**：测试脚本的 `setup()` 仅使用 `mktemp -d` 创建了空目录并进入，并未执行 `git init` 初始化本地 git 仓库。
- **影响**：被测脚本 `opinit_register_hooks.sh` 在执行时会调用 `git rev-parse --git-dir`，由于测试环境不是 git 仓库，脚本会直接走入 `else` 分支，打印 `[WARN] 非 git 仓库，跳过 git hooks 注册`。这导致脚本中复制 `pre-commit` 和 `commit-msg` git hooks、校验权限以及防止覆盖用户已有 hooks 的核心逻辑在测试中从未被真正执行和断言。
- **建议**：在 `tests/scripts/opinit_register_hooks.bats` 的 `setup()` 中加入 `git init -q`，并在测试用例中增加对 `.git/hooks/pre-commit` 和 `.git/hooks/commit-msg` 文件是否成功生成且内容符合预期的断言。
- **置信度**：High
- **优先级**：MEDIUM

### 2. 使用固定路径的全局临时文件，存在并行测试时的冲突隐患
- **位置**：
  - `tests/scripts/op_checkpoint.bats` 第 25 行（使用了 `/tmp/tasks.json`）
  - `tests/scripts/oplrun_lite.bats` 第 10 行（使用了 `/tmp/t`）
- **现象**：测试脚本在通过 `jq` 修改任务列表 JSON 并重写时，将临时输出重定向到了 `/tmp/tasks.json` 和 `/tmp/t` 这种全局固定的路径中。
- **影响**：如果开启了 Bats 的并行测试模式（例如 `bats -j`）或者有多个 CI 任务同时在宿主机上运行，不同的测试用例可能会由于同时读写该共享文件而产生竞争条件（Race Condition），引发随机的测试失败或数据异常。
- **建议**：将临时文件重定向到测试用例专属的临时目录下，如使用 `$TEST_ROOT/tasks.json.tmp` 或通过 `mktemp` 获取安全唯一的临时文件路径。
- **置信度**：High
- **优先级**：MEDIUM

### 3. `op_close_post.bats` 缺少对非 `skip` 类型 `eval` 强校验逻辑的测试
- **位置**：`tests/scripts/op_close_post.bats`
- **现象**：`op_close_post.sh` 包含对 `eval.md` 是否存在以及状态是否为 `PASS` 的强校验（除非 `eval` 属性为 `skip`）。然而，`op_close_post.bats` 中的所有测试用例都只使用了 `helpers.bash` 预设的 `eval: skip`，未编写任何针对非 `skip`（即 `eval: required`）场景的用例。
- **影响**：无法验证 `op_close_post.sh` 在处理非 `skip` 类型的 task 时，读取并强校验 `eval.md` 状态的逻辑是否正确，存在逻辑漏洞不被发现的风险。
- **建议**：在 `op_close_post.bats` 中新增两个用例：
  1. 测试在 `eval` 属性不为 `skip` 时，如果 `eval.md` 缺失或非 `PASS`，收口脚本是否会正常被阻断并报错返回非0状态；
  2. 测试在 `eval` 属性不为 `skip` 且 `eval.md` 校验通过时，脚本能够顺利完成归档。
- **置信度**：High
- **优先级**：MEDIUM

### 4. `op_status.bats` 缺少对 `--batch` 批量更新状态选项的测试
- **位置**：`tests/scripts/op_status.bats`
- **现象**：`op_status.sh` 支持通过 `--batch` 参数批量修改一组 TID 的状态，但 `op_status.bats` 中只对单 TID 场景进行了断言，未编写任何针对 `--batch` 逻辑分支的用例。
- **影响**：批量模式在 jq 拼接、输入参数切分（如 `split(",")`）等方面的代码复杂度高于普通模式，缺少对应的自动化测试可能使得此处在代码变更时引入 Bug 而不受察觉。
- **建议**：在 `op_status.bats` 中增加对 `--batch` 用法的测试，验证传递多个 TID 时，`tasks_list.json` 中相应的多个任务状态均被正确修改。
- **置信度**：High
- **优先级**：MEDIUM

### 5. `op_trailer_unlock.bats` 中的测试标题存在输入法错别字
- **位置**：`tests/scripts/op_trailer_unlock.bats` 第 63 行
- **现象**：测试用例标题声明为 `@test "commit-msg: staged 变了中国旧 trailer 失效"`。
- **影响**：标题中的“中国旧”显然为拼写错误（应为“之后，旧”或“中，旧”），降低了代码和报告的规范性。
- **建议**：将“中国旧”纠正为“之后，旧”。
- **置信度**：High
- **优先级**：LOW

## 改进建议
1. **统一 Bats 测试套件的 Setup 和 Teardown 模式**：目前测试套件中，一部分测试（如 `op_worktree_setup.bats`、`op_mutation_check.bats`、`opinit_register_hooks.bats`、`op_trailer_unlock.bats`）使用了内置的全局 `setup()`/`teardown()` 函数，而另一部分则在用例内手动调用 `setup_mock_project`。建议全部统一为在全局 `setup` / `teardown` 中执行初始化和垃圾回收，防止任何临时文件的遗留。
2. **规范化 `helpers.bash` 提供的 Mock 结构**：可以为 `helpers.bash` 的 `setup_mock_project` 增加可选参数，允许在用例调用时灵活指定默认生成的 `eval` 类型或任务列表内容，以更好地支撑不同状态校验的边界测试。
3. **增加 Bash 版本的检测模拟测试**：`op_check_env.sh` 中虽然对 `BASH_VERSION` 进行了非 Bash 运行的警告，但 `op_check_env.bats` 并未对该警告分支编写模拟环境的测试。可以通过修改环境变量或利用 subshell 模拟非 bash 环境下的行为进行断言补充。

## 不确定项 / 可能误报
无。本次审阅指出的测试逻辑缺失、清理逻辑遗漏和拼写错误均具有确凿的代码依据。
