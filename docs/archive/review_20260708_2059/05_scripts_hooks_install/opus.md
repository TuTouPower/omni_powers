# 审阅报告（05_scripts_hooks_install）

## 当前模型判断依据
- 当前主会话由 `default_opus` 驱动，根据说明及指令授权，此审阅由 Opus 视角进行独立只读审查。

## 审阅范围
本次审阅针对 `omni_powers` 的以下文件：
- `hooks/README.md`
- `hooks/git/commit-msg`
- `hooks/git/pre-commit`
- `hooks/post_tool_use.sh`
- `hooks/pre_tool_use.sh`
- `hooks/run-hook.cmd`
- `hooks/settings.template.json`
- `hooks/stop.sh`
- `install.sh`
- `uninstall.sh`
- `scripts/build_lite.sh`
- `scripts/op_check_env.sh`
- `scripts/op_closer_gate.sh`
- `scripts/op_jq.sh`
- `scripts/op_mutation_check.sh`
- `scripts/op_new_task.sh`
- `scripts/op_status.sh`
- `scripts/op_trailer_unlock.sh`
- `scripts/op_worktree_setup.sh`
- `scripts/op_worktree_teardown.sh`
- `scripts/test_lock.sh`

此外，对照了 `skills/oprun/scripts/op_close_pre.sh`、`skills/oprun/scripts/op_close_post.sh`、`skills/oplrun/scripts/op_close_post.sh`、`skills/oplrun/scripts/op_check_env.sh`、`skills/oplrun/scripts/op_check_p0.sh`、`skills/oplrun/scripts/op_assemble_eval_brief.sh` 以及 `agents/*.md` 等相关联动设计。

---

## 高优先级问题

### 1. `commit-msg` 与 `op_trailer_unlock.sh` 之间的 HMAC 数据输入格式不一致导致校验失败
- **位置**：`hooks/git/commit-msg` 第 49 行 与 `scripts/op_trailer_unlock.sh` 第 49 行。
- **现象**：
  - 在 `commit-msg` 中，计算 HMAC 的数据格式为：
    ```bash
    hmac_data="$(printf '%s' "$e2e_paths" | grep -c . >/dev/null; printf '%s' "$e2e_paths" | sort | tr '\n' ':')"
    ```
    注：`e2e_paths` 已经以换行符 `$'\n'` 拼接，例如：`e2e/a.js\ne2e/b.js\n`。`printf '%s'` 后，再通过 `tr '\n' ':'`，生成的 `$hmac_data` 会是 `e2e/a.js:e2e/b.js:`（末尾有冒号）。
  - 在 `op_trailer_unlock.sh` 中，计算 HMAC 的数据格式为：
    ```bash
    hmac_data="$(printf '%s\n' "$e2e_paths" | sort | tr '\n' ':')"
    ```
    注：这里的 `e2e_paths` 也是以换行符分隔的多行字符串，末尾本身带换行。如果使用 `printf '%s\n'`，会在末尾额外增加一个换行符。经过 `sort` 和 `tr '\n' ':'` 之后，生成的 `$hmac_data` 会多出一个前导或后随的空字段（冒号），或者在有空行时首部多出 `:`（即变成 `:e2e/a.js:e2e/b.js:`）。
  - 实测输出对比：
    - `commit-msg` 端的 `hmac_data` 输出为：`e2e/a.js:e2e/b.js:`
    - `op_trailer_unlock.sh` 端的 `hmac_data` 输出为：`:e2e/a.js:e2e/b.js:` (当输入为空行或多出尾随换行时首尾格式不匹配)。
- **影响**：由于输入 `hmac_data` 格式不一致，导致生成的 HMAC `Op-E2e-Unlock` 与 `commit-msg` 算出来的 expected 值无法匹配，造成合法的 `e2e` 提交被拒。
- **建议**：统一两处的 `hmac_data` 生成方式。推荐使用无副作用且幂等的生成方式，比如：
  ```bash
  hmac_data="$(echo "$e2e_paths" | grep -v '^$' | sort | tr '\n' ':')"
  ```
- **置信度**：100%
- **优先级**：P0 (阻断级别)

### 2. `git commit-msg` 误判无改动的非 e2e 提交
- **位置**：`hooks/git/commit-msg` 第 23-30 行。
- **现象**：
  ```bash
  while IFS= read -r path; do
      case "$path" in
          e2e/*) has_e2e=1; e2e_paths="${e2e_paths}${path}"$'\n' ;;
      esac
  done < <(git diff-index --cached --name-only "$against")
  ```
  如果本次 commit 是通过 `git commit --allow-empty` 创建的空提交，或者被某些重置机制导致 `git diff-index --cached` 没有任何输出，`while` 循环不会读取任何内容，`has_e2e` 保持 `0`，可安全放行。
  但是，如果修改的文件名恰好包含 `e2e`（例如 `docs/omni_powers/e2e/` 的文档、或者 `skills/oprun/scripts/op_assemble_eval_brief.sh`），且由于通配符模式 `e2e/*` 过于宽泛（没有严格限定在顶层 `e2e/` 目录），可能会错误拦截这些非真正的 `e2e/` 运行代码提交。
  更严重的是，`against` 变量在全新仓库（没有 HEAD 提交）时：
  ```bash
  against="$(git rev-parse --verify HEAD >/dev/null 2>&1 && echo HEAD || echo "$(git hash-object -t tree /dev/null)")"
  ```
  在全新仓库（无 commits）下，`git diff-index --cached` 可能会失效或返回未追踪文件。
- **影响**：非 `e2e` 的常规文档或配置文件修改如果被误判为 e2e，会导致不需要解锁码的提交被拦截，增加操作摩擦。
- **建议**：匹配模式由 `e2e/*` 细化为 `e2e/**/*`（若为 monorepo）或严格的顶层 `e2e/*`。并确保空行或特殊空提交不会引起误判。
- **置信度**：90%
- **优先级**：P1

---

## 中低优先级问题

### 1. `install.sh` 中的 `OP_HOME` 环境变量配置覆盖问题
- **位置**：`install.sh` 第 69 行。
- **现象**：
  ```bash
  jq --arg oh "$REPO_ROOT" '.env = (.env // {}) | .env.OP_HOME = $oh' "$SETTINGS" > "$tmp"
  ```
  这段代码只考虑了 `.env.OP_HOME` 的写入。但是，如果用户的 `.claude/settings.json` 中已经配置了其它的环境变量，或者用户手动为 `OP_HOME` 设定了特定路径，直接重新覆盖可能不符合预期，并且没有在终端清晰警示用户原有的 `OP_HOME` 被修改。
- **影响**：若多次在一个环境以不同的目录跑 `install.sh`，可能会在不给警告的情况下静默改写 `settings.json` 中的 `OP_HOME` 指向。
- **建议**：在改写 `.env.OP_HOME` 前，先检查是否已存在不同的值。如果有，提示用户并确认是否覆盖。
- **置信度**：80%
- **优先级**：P2

### 2. `uninstall.sh` 中项目级清理（`--purge-project`）未彻底移除 `docs/omni_powers/`
- **位置**：`uninstall.sh` 第 100 行。
- **现象**：
  ```bash
  local docs_op="docs/omni_powers"
  del "$docs_op"
  ```
  函数 `del` 的定义：
  ```bash
  del() {
      local dst="$1"
      if [ -e "$dst" ] || [ -L "$dst" ]; then
          if [ "$DRY_RUN" -eq 1 ]; then echo "  [DRY] del $dst"
          else rm -rf "$dst"; echo "  [DEL] $dst"; fi
      fi
  }
  ```
  在 monorepo 或不同子目录下执行 `uninstall.sh --purge-project` 时，`docs/omni_powers` 的相对路径依赖于当前工作目录 `pwd`。如果用户不是在项目根目录下执行，或者项目结构中 `docs/omni_powers` 不在当前 `pwd` 的直属下方，删除将失效。
- **影响**：项目 omni_powers 工作区和残留配置文件清理不干净。
- **建议**：通过 `git rev-parse --show-toplevel` 定位项目根，并从项目根绝对路径删除 `docs/omni_powers`。
- **置信度**：90%
- **优先级**：P2

### 3. `op_worktree_setup.sh` 在 non-cone 模式下的 pattern 可能导致在某些 Git 版本上排除失效
- **位置**：`scripts/op_worktree_setup.sh` 第 38-60 行。
- **现象**：
  ```bash
  git sparse-checkout init --no-cone
  ```
  并在 `info/sparse-checkout` 中写入否定匹配：
  ```
  /*
  !/e2e/
  ```
  在部分较旧的 Git 版本（如 2.25 ~ 2.28 早期）中，否定匹配模式（`!/e2e/`）在 non-cone 模式下可能需要配合明确的子目录通配（如 `!/e2e/**`）才能在 `git read-tree` 时完全将工作目录清空。脚本虽有验证段进行 `WARN`，但如果排除失效，会导致 implementer 的工作区暴露 `e2e/` 代码。
- **影响**：在某些 OS/Git 环境中，隔离防线退化，导致 implementer 能够直接读写行为层测试代码而不报阻断错误（只能靠 merge gate 在最后一关拦截）。
- **建议**：优化否定匹配模式，确保对子文件和目录都匹配：
  ```
  /*
  !/e2e/
  !/e2e/**
  ```
- **置信度**：85%
- **优先级**：P2

### 4. `test_lock.sh` 缺少对 lockfile 并发操作时的完整清理机制
- **位置**：`scripts/test_lock.sh` 第 40 行。
- **现象**：
  ```bash
  grep -vxF "$r" "$lockfile" > "$lockfile.tmp" 2>/dev/null || true
  mv "$lockfile.tmp" "$lockfile"
  ```
  如果在执行 `mv` 的瞬间有其他进程在等待读取 `$lockfile`，或者发生中断，会导致 `$lockfile` 临时消失或损坏。虽然有 `flock 9` 进行排它锁保护，但在并发操作频繁时，使用覆盖重命名（`mv`）可能会导致打开原文件描述符的文件句柄失效。
- **影响**：可能导致其它依赖该锁文件的读取或写入流程读取到空内容，或引起偶发性文件丢失。
- **建议**：使用临时文件写入并直接重定向写回，而不是直接 `mv` 覆盖被锁定的文件本身：
  ```bash
  grep -vxF "$r" "$lockfile" > "$lockfile.tmp" && cat "$lockfile.tmp" > "$lockfile" && rm -f "$lockfile.tmp"
  ```
  这样可以确保 `$lockfile` 文件的 inode 节点不发生改变，保持并发读取文件句柄的安全。
- **置信度**：75%
- **优先级**：P2

### 5. `post_tool_use.sh` 证据清理命令中 `find` 参数对某些平台（如 BSD/macOS）不兼容
- **位置**：`hooks/post_tool_use.sh` 第 62 行。
- **现象**：
  ```bash
  find "$tasks_dir" -name 'test_evidence_*.log' -mmin +60 -delete 2>/dev/null
  ```
  部分 macOS/BSD 系统自带的 `find` 工具不支持 `-mmin` 语法，或者 `-delete` 参数的位置有严格要求。例如在 macOS 默认 `find` 中，不带参数的 `-delete` 可能会报错或失效。
- **影响**：在 macOS 环境下，旧的测试证据文件可能无法被自动删除，导致 `docs/omni_powers/op_execution/tasks/{TID}/` 目录下堆积大量 log 文件，污染工作区。
- **建议**：使用兼容性更好的时间过滤方式，或者使用 `find ... -mtime +0` 并配合 `xargs rm -f`，或先判断系统平台。
- **置信度**：85%
- **优先级**：P2

---

## 改进建议

### 1. `pre_tool_use.sh` 中的 approved 状态检查效率优化
- **位置**：`hooks/pre_tool_use.sh` 第 48 行。
- **说明**：在 `PreToolUse` 的 `Edit/Write` 拦截中，频繁使用 `awk` 对文件内容进行解析获取 `status`：
  ```bash
  status="$(awk -F': *' '/^status:/{print $2; exit}' "$file_path" 2>/dev/null | tr -d ' ')"
  ```
  对每次写操作都调用 `awk` 在性能上是可以接受的，但如果文件过大或者并发写较多，可以先用快速的 `grep` 过滤或者做路径快速排除，避免频繁启动外部进程。

### 2. `run-hook.cmd` 的平台探测增强
- **位置**：`hooks/run-hook.cmd` 第 15-23 行。
- **说明**：Windows 平台下寻找 `bash.exe` 时，若 `CLAUDE_CODE_GIT_BASH_PATH` 为空，脚本会 fallback 到 `C:\Program Files\Git\bin\bash.exe`。可以加上对 `C:\Program Files (x86)\Git\bin\bash.exe` 和 `C:\tools\git\bin\bash.exe`（scoop 常见路径）的快速检测，以提升 Windows 环境下的开箱即用体验。

---

## 不确定项

### 1. `op_mutation_check.sh` 对非 JS/Python 项目的通用测试指令支持
- **问题**：`op_mutation_check.sh` 将变异后的源文件直接覆盖，然后跑传入的 `$@` 测试命令。对于编译型语言（如 Rust, Go），直接替换源文件可能会由于语法不合规、未导出等原因导致编译期直接报错，而非测试框架的 "KILLED"。脚本直接通过退出码判断，可能无法区分编译错误与测试失败的边界。目前该变异工具在 heavy/lite 流程中并未被自动调度，其定位偏向辅助性体检。
- **置信度**：70%
