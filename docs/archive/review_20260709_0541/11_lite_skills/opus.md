## 当前模型判断依据

本报告基于 Opus 模型，根据用户授权进行只读代码和文档审阅。审阅参考了系统最高设计契约 `/home/karon/karson_ubuntu/omni_powers/docs/omni_powers_design.md`，特别是其中关于 lite 模式（零侵入、无分支隔离、无 hook 机制、裸评退化、leader 亲自承载校验及收口等）的设计规范，对 `11_lite_skills` 涉及的所有 15 个文件进行了全量静态走读和逻辑推理。

---

## 审阅范围

本次审阅覆盖以下文件（均相对项目根目录）：
1. `skills/oplinit/SKILL.md`
2. `skills/oplinit/scripts/op_check_env.sh`
3. `skills/oplinit/scripts/oplinit_skeleton.sh`
4. `skills/oplintake/SKILL.md`
5. `skills/oplintake/scripts/op_check_env.sh`
6. `skills/oplrun/SKILL.md`
7. `skills/oplrun/scripts/close_check.sh`
8. `skills/oplrun/scripts/op_assemble_eval_brief.sh`
9. `skills/oplrun/scripts/op_check_env.sh`
10. `skills/oplrun/scripts/op_close_post.sh`
11. `skills/oplrun/scripts/op_coder_check.sh`
12. `skills/oplrun/scripts/op_collect_open_issues.sh`
13. `skills/oplrun/scripts/op_jq.sh`
14. `skills/oplrun/scripts/op_read_verdict.sh`
15. `skills/oplrun/scripts/op_status.sh`

---

## 高优先级问题（CRITICAL / HIGH）

### 1. `DISPATCH_SHA` 临时环境变量丢失导致 spec 写保护失效
- **位置**：`skills/oplrun/SKILL.md` (步骤 3.2 与 3.6)。
- **现象**：
  - 步骤 3.2 中定义了临时 shell 变量 `DISPATCH_SHA=$(git rev-parse HEAD)` 用于记录派发时的锚点 SHA。
  - 步骤 3.6 依赖该变量执行写保护校验：`git diff --quiet "$DISPATCH_SHA" -- docs/omni_powers/op_execution/specs/`。
  - 由于 Claude Code 的子代理执行机制（Implementer/Reviewer/Evaluator）是在主会话中分步派发的，主会话会经历多次 Tool 调用和 Turn 交互。Claude Code 的 Shell 环境在不同 Turn/调用之间**不持久化环境变量和 Shell 状态**。
- **影响**：
  - 当工作流走到 3.6 收口阶段时，`$DISPATCH_SHA` 变量已在主会话环境中丢失并变为空值。
  - 执行 `git diff --quiet ""` 会导致 Git 报错退出（如 `fatal: bad revision`），或者若有容错则由于 SHA 为空而无法进行准确的 spec 修改对比，导致 spec 写保护形同虚设，无法拦截 Implementer 自行篡改规格迎合实现的行为（违反 design §5.9）。
- **建议**：
  - 将 `DISPATCH_SHA` 持久化。例如，在步骤 3.2 中，使用 `op_status.sh` 或 jq 脚本将派发时的 SHA 写入 `tasks_list.json` 中对应 task 记录的自定义元数据字段（如 `dispatch_sha`），或者写入 `leader_checkpoint.md`。步骤 3.6 收口时从中读取。
- **置信度**：High
- **优先级**：CRITICAL

### 2. 未追踪文件（Untracked Files）执行 `git mv` 导致收口中断及状态不一致
- **位置**：`skills/oplrun/scripts/op_close_post.sh` (第 54, 57, 62 行)。
- **现象**：
  - 脚本中直接对正在收口的目录和文件执行 `git mv`：
    - `git mv "$TASK_DIR" "$ARCHIVE_DIR"`
    - `git mv "$SPEC_SRC" "$ROOT/docs/omni_powers/op_record/specs/"`
    - `git mv "$ACCEPT_SRC" "$ACCEPT_DST"`
  - 在 lite 工作流中，工作 spec 文件（在 `op_execution/specs/` 下新建）和验收文件（由 Evaluator 在 `acceptance/{TID}/` 下生成，如 `eval.md`）都是新产生的文件，且在此之前**没有被执行过 `git add`**。
  - Git 对未追踪的文件/目录执行 `git mv` 时会直接报错并退出：`fatal: not under version control, source=...`。
- **影响**：
  - `op_close_post.sh` 开启了 `set -e`，`git mv` 报错会导致收口脚本在中途直接崩溃退出。
  - 由于任务目录可能已经被移动（或部分移动），而 spec 和 acceptance 归档失败，导致工作区处于"半吊子"的损坏状态，tasks_list.json 状态也未更新到 `done`，状态极难自动恢复。
- **建议**：
  - 在执行 `git mv` 归档前，先对目标文件或目录显式执行 `git add -A` 或 `git add "$SPEC_SRC" "$ACCEPT_SRC"` 以确保其被 Git 追踪。
  - 或者在 `git mv` 时增加容错 fallback：
    `git mv "$SPEC_SRC" "$DST" 2>/dev/null || mv "$SPEC_SRC" "$DST"`，并在收口脚本最后的 `git add` 步骤中，把移动后的归档目录也显式加进 `git add` 中。
- **置信度**：High
- **优先级**：CRITICAL

### 3. `op_collect_open_issues.sh` 用 awk 简单提取 frontmatter 会因引号包裹漏报 P0/P1
- **位置**：`skills/oplrun/scripts/op_collect_open_issues.sh` (第 17-21 行)。
- **现象**：
  - 使用 `awk -F': *' '/^severity:/{print $2; exit}'` 和 `awk -F': *' '/^status:/{print $2; exit}'` 从 issue md 文件提取严重度和状态。
  - 如果 Agent 或用户在编写 issue 属性时使用了标准 YAML 格式的引号包裹（如 `severity: "P0"` 或 `status: 'open'`），awk 提取出来的值会保留引号（即 `s` 为 `"P0"`，`st` 为 `"open"`）。
  - 后续的 shell 条件判断 `[ "$s" = "$sev" ]`（即 `[ "\"P0\"" = "P0" ]`）会因为字符串不匹配而判定不成立。
- **影响**：
  - 凡是属性被单双引号包裹的 P0/P1 开启状态的 issues，都将无法被汇总工具搜集到，导致结束报告中漏报阻断性 P0/P1 缺陷，造成发布隐患。
- **建议**：
  - 提取后去除潜在的引号。可在 awk 命令的输出或 shell 变量赋值后用 `tr` 清理。例如：
    `tr -d ' \r"'\''`。
- **置信度**：High
- **优先级**：HIGH

---

## 中低优先级问题（MEDIUM / LOW）

### 4. `close_check.sh` 中的 `git status` 校验对已 stage 的收口文件产生误报警告
- **位置**：`skills/oplrun/scripts/close_check.sh` (第 43-50 行)。
- **现象**：
  - `others=$(git status --short 2>/dev/null | grep -v "^[MADRC? ]\+ ${arch}" || true)` 试图过滤掉当前 task 的归档改动，找出其他"越界"修改。
  - 在这之前，`op_close_post.sh` 会修改 `docs/omni_powers/op_record/progress.md` 和 `docs/omni_powers/op_execution/tasks_list.json` 并执行了 `git add`。
  - 此时 `git status --short` 必然输出这两个文件的 stage 修改信息（如 `M  docs/omni_powers/op_execution/tasks_list.json`）。
- **影响**：
  - 因为 `grep -v` 过滤条件只排除了归档目录 `${arch}`，没有排除 progress.md 和 tasks_list.json，导致 `close_check.sh` 在每次成功收口后必然发出 `[WARN] git status 有非 T0001 归档的改动`，产生无意义的警报噪音。
- **建议**：
  - 在过滤正则中追加排除收口合法的公共更新文件：
    `grep -v -E "^[MADRC? ]+ (${arch}|docs/omni_powers/op_record/progress.md|docs/omni_powers/op_execution/tasks_list.json)"`。
- **置信度**：High
- **优先级**：MEDIUM

### 5. `op_read_verdict.sh` 对 review.md 的 verdict 行匹配规则过严导致解析失败
- **位置**：`skills/oplrun/scripts/op_read_verdict.sh` (第 21-22 行)。
- **现象**：
  - 使用 `grep -c '^verdict:'` 匹配行首为 `verdict:` 的行。
  - 在实际开发中，Reviewer 产出的 markdown 经常包含格式化样式，可能会将结论写为 `- verdict: PASS`、`* verdict: PASS` 或包含前导空格（如 `  verdict: PASS`）。
- **影响**：
  - 只要 verdict 前存在列表标记或空格，匹配就会失败，导致脚本返回 `verdict: NONE`，阻止正常的收口流程，降低了系统的易用性。
- **建议**：
  - 放宽匹配规则以增强容错性：
    `grep -oE '^[[:space:]]*([-*][[:space:]]+)?verdict:[[:space:]]*(PASS|FAIL)'`
- **置信度**：High
- **优先级**：MEDIUM

### 6. 无锁写 `tasks_list.json` 的潜在并发冲突风险
- **位置**：`skills/oplrun/scripts/op_status.sh` (第 52-56 行)。
- **现象**：
  - 在 macOS / Windows Git Bash 等无 `flock` 命令的系统上，脚本打印 `[WARN]` 并直接以"无锁写"运行。
- **影响**：
  - 虽然 lite 模式定位是单人串行，但若用户在外部终端使用 status 命令或工具并发处理状态时，可能会造成 tasks_list.json 数据覆写或损坏。
- **建议**：
  - 在无 `flock` 平台，可以退而使用简单的基于目录创建（`mkdir`）的原子锁机制来确保基本的写入互斥。但鉴于其为 lite 模式的单进程串行，保持现状的 WARN 提示作为中低优先级的取舍也可以接受。
- **置信度**：High
- **优先级**：LOW

---

## 改进建议

1. **解决 DISPATCH_SHA 丢失**：
   在 `leader_checkpoint.md` 中增加 `dispatch_sha` 元数据，在 `oplrun` 的步骤 3.2 写入它，并在 3.6 中通过读取该 checkpoint 字段来恢复 `DISPATCH_SHA`，以进行安全比对。
2. **重构 `op_close_post.sh` 归档操作**：
   将 `git mv` 替换为带有 fallback 的安全拷贝方式：
   ```bash
   safe_git_mv() {
       local src="$1"
       local dst="$2"
       if [ -e "$src" ]; then
           git mv "$src" "$dst" 2>/dev/null || { mv "$src" "$dst" && git add "$dst"; }
       fi
   }
   ```
3. **增强 `awk` 与 `grep` 解析**：
   在 `op_collect_open_issues.sh` 中：
   ```bash
   s="$(awk -F': *' '/^severity:/{print $2; exit}' "$f" 2>/dev/null | tr -d ' \r"'\''')"
   ```
   在 `op_read_verdict.sh` 中：
   ```bash
   verdict=$(grep -oE '^[[:space:]]*([-*][[:space:]]+)?verdict:[[:space:]]*(PASS|FAIL)' "$REVIEW_FILE" | tail -1 | sed -E 's/.*verdict:[[:space:]]*//' || echo "NONE")
   ```

---

## 不确定项 / 可能误报

- **关于 `op_status.sh` 批量更新状态的 jq 条件**：
  - `map(if .id as $id | $tids | index($id) then ...)`。在 jq 中，如果 `index($id)` 返回 `0`（匹配第一个元素），由于 `0` 在 jq 中代表真值，逻辑是正确的。但这种写法稍显晦涩，如果后续人员误改为类似 JavaScript 的非零判断，可能会引入 bug。此处代码逻辑无误，仅为可读性提醒。
