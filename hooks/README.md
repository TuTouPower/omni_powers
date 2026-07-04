# omni_powers hooks

## 跨平台（Windows / macOS / Linux）

hook command 走 **polyglot wrapper**（`run-hook.cmd`），借鉴 superpowers：

- **Windows**：CMD 路径——调 `C:\Program Files\Git\bin\bash.exe -l -c` 跑 .sh，`cygpath -u` 转 Unix 路径
- **macOS/Linux**：bash 路径——`: << 'CMDBLOCK'` heredoc 消费掉 CMD 段，直接 `exec .sh`

polyglot 关键：`: << 'CMDBLOCK'` 在 CMD 里 `:` 是 label（跳过），在 bash 里 `:` 是 no-op + `<<` 开 heredoc（消费 CMD 段）。

`settings.template.json` 的 command 形如：
```
bash "$OP_HOME/hooks/run-hook.cmd" pre_tool_use
```
参数**不带 `.sh`**（避免 Claude Code 2.1.x Windows 自动 bash 检测），wrapper 内部补 `.sh`。

## 前置要求

| 平台 | 必装 |
|---|---|
| Windows | Git for Windows（提供 `bash.exe` + `cygpath`）+ `jq`（手动装） |
| macOS / Linux | `bash` + `jq`（macOS：`brew install jq`） |

Windows 装在非默认路径时，设环境变量 `CLAUDE_CODE_GIT_BASH_PATH` 指向 `bash.exe`（Claude Code 也会用这个）。`run-hook.cmd` 的 bash.exe 检测顺序：`CLAUDE_CODE_GIT_BASH_PATH` → `C:\Program Files\Git\bin\bash.exe`（默认）→ `where bash`（PATH）。

## CRLF 防护

`.gitattributes` 强制 `*.sh` / `*.cmd` / `*.bats` LF 行尾——Windows clone 不会 CRLF 破坏 shebang 与 polyglot heredoc（CRLF 会令 `: << 'CMDBLOCK'` 失败）。

## hook 列表

| 事件 | matcher | 脚本 | 说明 |
|---|---|---|---|
| PreToolUse | Edit/Write/MultiEdit/Bash | pre_tool_use.sh | spec 写保护、e2e 拦截、--no-verify 拦截（advisory，subagent 失效见 design §8.1） |
| PostToolUse | Edit/Write/MultiEdit | post_tool_use.sh | 改 src/test 跑测试留证据 |
| SubagentStop | op-implementer | stop.sh | implementer 交工门禁（新鲜证据 + stop_hook_active 防递归） |
| SessionStart | — | session_start.sh | 路由注入 + approved spec 漂移校验 |

详细行为见 `docs/omni_powers_design.md` §11。
