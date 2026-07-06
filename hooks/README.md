# omni_powers hooks

## 跨平台（Windows / macOS / Linux）

hook command 走 **polyglot wrapper**（`run-hook.cmd`），借鉴 superpowers：

- **Windows**：CMD 路径——调 `C:\Program Files\Git\bin\bash.exe -l -c` 跑 .sh，`cygpath -u` 转 Unix 路径
- **macOS/Linux**：bash 路径——`: << 'CMDBLOCK'` heredoc 消费掉 CMD 段，直接 `exec .sh`

polyglot 关键：`: << 'CMDBLOCK'` 在 CMD 里 `:` 是 label（跳过），在 bash 里 `:` 是 no-op + `<<` 开 heredoc（消费 CMD 段）。

hook command 按平台生成：

```bash
# macOS / Linux
bash "$OP_HOME/hooks/run-hook.cmd" pre_tool_use
```

```bat
:: Windows（opinit 在 Git Bash 下生成绝对 .cmd 路径）
"C:\path\to\omni_powers\hooks\run-hook.cmd" pre_tool_use
```

参数**不带 `.sh`**；CMD 分支与 bash 分支都会自动补 `.sh`。Windows 必须让 `.cmd` wrapper 直接启动，才能使用 `CLAUDE_CODE_GIT_BASH_PATH` 查找非默认 Git Bash；若外层先写 `bash ...`，则 `bash` 必须已在 PATH 中。

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

## git 层 hooks（heavy 专属，绕过 subagent deny 失效）

`hooks/git/` 下的 git hook 由 opinit 注册到项目 `.git/hooks/`（不覆盖用户已有非 omni_powers hook）：

| hook | 作用 |
|---|---|
| pre-commit | spec 写保护——`docs/omni_powers/op_blueprint/` 下 approved/in_progress 状态的生效规格不允许直接 commit（走 design §2.2 spec 变更子流程） |
| commit-msg | e2e 提交校验——含 `e2e/**` 的 commit 必须带合法 `Op-E2e-Unlock:` trailer（HMAC-SHA256(leader secret, e2e 文件清单)）；leader 用 `scripts/op_trailer_unlock.sh` 生成 |

secret 存 `~/.claude/omni_powers/e2e_secret`（mode 600，首次自动生成，不进项目仓库）。强隔离需 OS keyring（P3 增强），当前靠 mode 600 + 纪律禁止 agent 读 `~/.claude/omni_powers/`。

详细行为见 `docs/omni_powers_design.md` §2.5（e2e 写入通道）+ §3.3（防线映射）+ §4.1（hook 清单）。
