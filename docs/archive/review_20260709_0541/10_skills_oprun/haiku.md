# haiku 审阅报告：10_skills_oprun

## 当前模型判断依据

- `/home/karon/.claude/settings.json` 顶层 `model=haiku`；`env.ANTHROPIC_MODEL=default_model`；`env.ANTHROPIC_DEFAULT_HAIKU_MODEL=default_haiku[1m]`。
- 主会话环境提示当前由 `default_model` 驱动，本路 default_haiku[1m]。
- 不可读运行时内部状态；current 路继承主会话。用户显式授权调用 haiku 视角审阅。

## 审阅范围

逐文件全量审阅以下 8 个文件：

1. `skills/oprun/SKILL.md`（320 行）
2. `skills/oprun/scripts/close_check.sh`（54 行）
3. `skills/oprun/scripts/op_assemble_eval_brief.sh`（80 行）
4. `skills/oprun/scripts/op_checkpoint.sh`（61 行）
5. `skills/oprun/scripts/op_close_post.sh`（96 行）
6. `skills/oprun/scripts/op_close_pre.sh`（15 行）
7. `skills/oprun/scripts/op_coder_check.sh`（34 行）
8. `skills/oprun/scripts/op_read_verdict.sh`（37 行）

参考：`docs/omni_powers_design.md`（设计上下文）、`RULES.md`（状态机）、`scripts/op_status.sh`（交叉核对）。

---

## 高优先级问题（CRITICAL / HIGH）

### H1. SKILL.md 引用不存在的脚本 `op_merge_gate.sh` 与 `op_worktree_teardown.sh`

- **位置**：`skills/oprun/SKILL.md:285,286,319`
- **现象**：
  - 收尾段 `bash "$OP_HOME/scripts/op_worktree_teardown.sh .claude/worktrees/op-dev feat/op-dev"`，但 `find` 全仓只有 `scripts/op_worktree_teardown.sh`（603B，疑似占位）。
  - merge gate 段 `bash "$OP_HOME/scripts/op_merge_gate.sh" {TID}`，全仓无此文件。
- **影响**：`oprun` 收尾步骤会直接执行失败（worktree_teardown 脚本若只是 603B 占位则命令未必真实生效；merge_gate 脚本完全不存在则 `bash` 报 command not found）。SKILL.md 虽注明"P1 交付"，但 leader 按步骤照跑会在当前仓库状态报错。
- **置信度**：高（实际 find 确认）
- **优先级**：HIGH（脚本缺失影响执行链，但属已声明的 P1 待交付物，非逻辑 bug）

### H2. `op_close_post.sh` 幂等重跑时 `git add` 遗漏归档内容

- **位置**：`skills/oprun/scripts/op_close_post.sh:21-65, 90-93`
- **现象**：当 `ACTIVE_DIR=ARCHIVE_DIR`（第 26 行分支：工作区已不在、归档目录已存在）时，跳过整个归档 `if` 块（51-65 行），直接到 progress 追加 + `git add`。但 `git add` 段（90-93 行）固定 `git add docs/omni_powers/op_record/tasks/$TID ...`——若此前归档已提交过，此次 add 无新内容，progress 也已幂等跳过（70 行），结果空 commit 或 leader 后续 `git commit` 报 nothing to commit。
- **影响**：幂等重跑（中断恢复场景）时，`op_status.sh done` 已执行过但 tasks_list 未变，leader 紧接 `git commit -m "feat({TID}):..."` 会因 nothing staged 而失败。SKILL.md:267 未处理此异常分支。
- **建议**：幂等检测——若 task 已 done 且归档已提交，脚本应 echo "[SKIP] 已归档完成" 并 exit 0，而非继续走到 git add 段；或在 SKILL.md 的 commit 步骤前加 `git diff --cached --quiet || git commit`。
- **置信度**：中高（逻辑推演，未实跑）
- **优先级**：HIGH

### H3. `op_checkpoint.sh` awk 替换逻辑可能吞掉后续 `## ` 段

- **位置**：`skills/oprun/scripts/op_checkpoint.sh:51-55`
- **现象**：第二个 awk 块：
  ```awk
  /^## tasks_list 状态$/ { print repl; skip=1; next }
  /^## / && skip { skip=0 }
  !skip
  ```
  当匹配到 `## tasks_list 状态` 时打印 `repl` 并 `skip=1`，`next` 跳过本行。下一行若不是 `## ` 开头则被 `!skip` 过滤丢弃——设计意图是替换整个旧段直到下个 `## `。但**问题**：`repl` 内容以 `## tasks_list 状态` 开头（39 行 echo），而 awk 的 `print repl` 已打印该标题，随后 `skip=1` 会把原文件中该标题之后、直到下个 `## ` 之前的所有旧行丢弃——这部分是对的。**真正风险**：若 `repl` 末尾没有换行（`echo` 自带 `\n`，通常没问题），或 checkpoint 文件中 `## tasks_list 状态` 与下一个 `## ` 之间是空行，awk 的 `!skip` 会把空行也吞掉，导致替换后段间无空行，markdown 渲染可能粘连。
- **影响**：markdown 格式退化（段间缺空行），非功能 bug。但在某些 checkpoint 模板结构下可能导致段标题粘连。
- **建议**：`repl` 末尾确保有空行（当前 `{ ... } > tmp` 的最后 echo "" 已保证），或 awk 逻辑显式在 repl 后补 `\n`。
- **置信度**：中（需 checkpoint 实际模板验证）
- **优先级**：HIGH（若粘连则 checkpoint 可读性受损，影响 compact 恢复）

### H4. `op_close_post.sh` `eval.md` 校验路径与 evaluator 实际产物路径不一致风险

- **位置**：`skills/oprun/scripts/op_close_post.sh:44-48`
- **现象**：脚本校验 `docs/omni_powers/op_execution/acceptance/$TID/eval.md` 的 `verdict: PASS`。但 SKILL.md:205 显示 evaluator brief 产在 `acceptance/{TID}/eval_brief.md`，而 evaluator 实际验收报告（含 verdict）的文件名 design §2.5 未显式约定为 `eval.md`——evaluator 可能写 `acceptance_report.md` 或其他名。脚本用固定名 `eval.md` 硬编码。
- **影响**：若 evaluator agent 提示词未强制产出文件名 `eval.md`，收口脚本会 die "eval.md 缺或空"，阻断收口。SKILL.md:209 dispatch prompt 只说"按 brief 执行验收"，未约束产出文件名。
- **建议**：在 evaluator agent 提示词或 SKILL.md dispatch 段显式约束 `verdict` 必须写入 `acceptance/{TID}/eval.md`；或脚本 glob `acceptance/$TID/*.md` 找含 verdict 的文件。
- **置信度**：中高（design 未显式定义 eval.md 文件名约定）
- **优先级**：HIGH

---

## 中低优先级问题（MEDIUM / LOW）

### M1. `op_coder_check.sh` 与 `op_read_verdict.sh` 的 `verdict` 格式解析不统一

- **位置**：
  - `op_coder_check.sh:14`：`grep -q '^verdict:'`（匹配行首）
  - `op_coder_check.sh:21`：`grep -c '^verdict:'`
  - `op_read_verdict.sh:21-22`：`grep -c '^verdict:'` + `grep -oE '^verdict:[[:space:]]*(PASS|FAIL)'`
- **现象**：两脚本都假设 verdict 行严格顶格 `^verdict:`。但 reviewer 提示词（SKILL.md:171）要求"文件最后一行必须写 verdict: PASS 或 FAIL"。若 reviewer 在 markdown 表格或列表中写了 `verdict:`（如 `- verdict: PASS`），则 `^verdict:` 不匹配，`op_coder_check` 误判为首轮（round:1, mode:normal）。
- **影响**：reviewer 格式不规范时轮次计数错乱，可能突破 2 轮上限或永远首轮。
- **建议**：要么 dispatch prompt 更强约束"行首顶格 `verdict: PASS|FAIL`"，要么 grep 放宽为 `[[:space:]]*verdict:`。
- **置信度**：中（依赖 reviewer 遵守格式）
- **优先级**：MEDIUM

### M2. `close_check.sh` 第 3 项 git status 过滤正则不严谨

- **位置**：`skills/oprun/scripts/close_check.sh:43`
- **现象**：`grep -v "^[MADRC? ]\+ ${arch}"` 过滤掉归档路径的改动。但 `arch` 含 TID，如 `docs/omni_powers/op_record/tasks/T0001`——正则中 `.` 未转义（这里是路径分隔符无影响），但 `+` 在 BRE 下需 `\+`，脚本用的是 `grep -v`（BRE），`\+` 正确。问题是 `${arch}` 若含正则元字符（如 TID 里的字母无碍），基本安全。**真正问题**：只过滤了工作区路径前缀，若归档已 commit（`git status` 不显示），过滤多余；若归档 staged 但未 commit，`git status --short` 显示 `A  docs/.../T0001/report.md`，过滤掉归档路径后剩其他改动——逻辑成立。但当 worktree 模式下 `.claude/worktrees/` 残留文件会全部报为"非本 task 改动"，噪声大。
- **影响**：worktree 模式收尾时 WARN 噪声。
- **建议**：可额外过滤已知 worktree 路径或 `.claude/`。
- **置信度**：中
- **优先级**：MEDIUM

### M3. `op_assemble_eval_brief.sh` 的 `cua do status` 调用未做超时控制

- **位置**：`skills/oprun/scripts/op_assemble_eval_brief.sh:68-69`
- **现象**：`$(cua do status 2>/dev/null | head -3 | tr '\n' ' ')` 若 `cua` 命令挂起（等待连接设备），脚本会阻塞。`set -euo pipefail` 下子命令失败不致命（`|| echo '未知'`），但**挂起**（非失败）无法被 `set -e` 捕获。
- **影响**：brief 组装阶段挂起，leader 无法推进。
- **建议**：`timeout 5 cua do status` 或在组装前 `cua --version` 探活即可，status 调用放到 evaluator 侧。
- **置信度**：中
- **优先级**：MEDIUM

### M4. `op_assemble_eval_brief.sh` spec 剥离逻辑只匹配 `## 设计探索结论`，遗漏其他探索段

- **位置**：`skills/oprun/scripts/op_assemble_eval_brief.sh:36`
- **现象**：`awk '/^## 设计探索结论/{skip=1; next} /^## /{skip=0} !skip'` 只剥「设计探索结论」段。但 design §2.2 spec 模板还有「条件强制」「可测性契约」等子段——这些是 `###` 三级标题，不受 `^## ` 影响，保留正确。**但** spec 若含 `## 已知坑` 或 `## 候选方案` 等 `##` 级探索段（design 模板未显式列出但 decisions.md 探索过程可能内联），则不会被剥。
- **影响**：evaluator 可能读到探索过程内容，违反 design §2.5「剥探索结论」原则。
- **建议**：明确 spec 模板中哪些 `##` 段属探索类，脚本统一剥离；或文档约束探索内容只能放 decisions.md，spec 只留结论。
- **置信度**：中（依赖 spec 模板实际形态）
- **优先级**：MEDIUM

### M5. `op_checkpoint.sh` 临时文件 PID 后缀在 trap 外可能残留

- **位置**：`skills/oprun/scripts/op_checkpoint.sh:9, 49, 57`
- **现象**：trap 清理 `/tmp/op_checkpoint_status_$$.md` 和 `/tmp/op_checkpoint_$$.md`。`$$` 是当前 shell PID。脚本内 `status_json` 等变量用 heredoc 未落盘，安全。但第 49 行写 status 临时文件、57 行显式 `rm -f`——若 51-55 行 awk 执行失败（如 checkpoint 文件不存在导致 awk 报错），`set -euo pipefail` 触发 exit，trap 清理 status 文件，但 `$$.md`（主临时文件）已由 `mv` 处理或未生成。整体 trap 覆盖足够。
- **影响**：低，trap 已兜底。
- **建议**：无强需改，仅记录。
- **置信度**：高
- **优先级**：LOW

### M6. `op_close_post.sh` spec 归档 glob 在多 spec 匹配时静默取首个

- **位置**：`skills/oprun/scripts/op_close_post.sh:55`
- **现象**：`SPEC_SRC="$(ls .../specs/${TID}_*.md | head -1)"`。TID 全局单调递增不复用（design §1），理论唯一匹配。但若用户误建多份（如 `T0001_a.md` + `T0001_b.md`），静默归档首个，第二个遗留工作区。
- **影响**：边缘场景，低概率。
- **建议**：多匹配时 WARN。
- **置信度**：高
- **优先级**：LOW

### M7. SKILL.md 状态判定表与实际脚本 status 枚举不完全对齐

- **位置**：`skills/oprun/SKILL.md:58-67`
- **现象**：判定表用中文渲染值（"全部 status=done"），而 `op_status.sh` 与 RULES.md 用 ASCII 机读值（`done`/`ready` 等）。SKILL.md 此处是给人读的判定指引，中文渲染可接受，但"存在 status=closing"（62 行）等表述混用——设计文档明确机读 ASCII、渲染层映射中文（design §1.1）。SKILL.md 作为 leader 执行手册，混用可能致 leader 误读 jq 输出。
- **影响**：低，leader 通常能映射。
- **建议**：判定表补 ASCII 值注释。
- **置信度**：中
- **优先级**：LOW

### M8. `op_close_pre.sh` 过于简单，仅一行实质操作

- **位置**：`skills/oprun/scripts/op_close_pre.sh:12`
- **现象**：整个脚本只调 `op_status.sh {TID} closing`。独立的脚本开销（文件、维护成本）相对其功能偏高。
- **影响**：无功能问题，仅工程整洁度。
- **建议**：可内联进 SKILL.md 或合并进 `op_close_post.sh` 前置段。但 design §5.5 明确 lite 不调用此脚本（删"收口中"态的因果链），保留独立文件便于 heavy/lite 分叉——属设计取舍。
- **置信度**：高
- **优先级**：LOW

### M9. SKILL.md 3.3 段 reviewer spawn 失败处理引用 `op_status.sh ... blocked spawn` 但未校验 blocked_by 枚举

- **位置**：`skills/oprun/SKILL.md:174,187`
- **现象**：SKILL.md 写 `op_status.sh {TID} blocked spawn`。核对 `op_status.sh`（第 56 行）确认 `spawn` 是合法 `blocked_by` 枚举（resource/quality/spawn）。**无问题**，但第 187 行 `blocked quality` 同样合法。此条实际是确认通过，记录供参考。
- **置信度**：高
- **优先级**：LOW（ informational）

### M10. `op_read_verdict.sh` exit code 与 SKILL.md 3.4 判定表语义重叠

- **位置**：`skills/oprun/scripts/op_read_verdict.sh:6` vs `skills/oprun/SKILL.md:178-181`
- **现象**：脚本注释"exit 0 = PASS 或 NONE, exit 1 = FAIL"。SKILL.md 3.4 用 `bash op_read_verdict.sh` 后按输出 `result:` 判定，未依赖 exit code（SKILL.md 示例只读 stdout）。脚本同时提供 exit code 和 stdout result，双通道信息冗余但无害。
- **影响**：无。
- **建议**：无需改。
- **置信度**：高
- **优先级**：LOW

---

## 改进建议

1. **补齐 P1 脚本或在 SKILL.md 加前置检查**（H1）：`op_merge_gate.sh`、`op_worktree_teardown.sh` 完整实现前，SKILL.md 收尾段应加 `[ -f ... ] || echo "[SKIP] P1 未交付"` 守卫，避免 leader 照跑报错。

2. **`op_close_post.sh` 幂等短路**（H2）：脚本开头检测 `jq '.tasks[] | select(.id==$tid) | .status' == "done"` 则 echo SKIP exit 0，杜绝重复执行副作用。

3. **统一 verdict 文件名约定**（H4）：在 `agents/op-evaluator.md` 与 SKILL.md dispatch prompt 中强制 evaluator 产出 `acceptance/{TID}/eval.md` 且末行 `verdict: PASS|FAIL`，与 `op_close_post.sh:44` 校验对齐。

4. **verdict 行格式强约束**（M1）：reviewer/evaluator dispatch prompt 显式要求"文件末行顶格 `verdict: PASS` 或 `verdict: FAIL`，禁止列表/表格包裹"，脚本侧 grep 保持严格。

5. **checkpoint awk 测试用例**（H3）：补一个 bats 测试覆盖 checkpoint 替换后段间空行完整性。

6. **eval brief 探索段剥离清单化**（M4）：spec 模板明确"探索类 `##` 段清单"，脚本按清单循环剥离，而非只剥单一段名。

7. **cua 调用超时**（M3）：所有 `cua do` 外包 `timeout` 命令。

---

## 不确定项 / 可能误报

1. **H3 checkpoint awk 粘连**：未实跑，依赖 checkpoint 模板实际结构。若模板在 `## tasks_list 状态` 段前后已有空行规范，可能无问题。建议实测验证。

2. **M4 spec 探索段**：未读 `skills/opspec/` 模板实际内容，不确定 spec 是否存在 `## 已知坑` 等其他探索段。若模板严格控制只有「设计探索结论」一个探索段，则 M4 误报。

3. **H2 幂等重跑**：逻辑推演，未实跑复现。若 `op_close_post.sh` 在 SKILL.md 流程中保证只跑一次（leader commit 后不重入），则幂等问题不触发。但中断恢复场景下 leader 可能重跑此脚本。

4. **M2 git status 过滤**：worktree 模式噪声判断基于推演，实际 worktree 残留文件是否进 `git status` 取决于 `.gitignore` 配置。

5. **H1 脚本缺失**：`op_worktree_teardown.sh` 实际有 603B 文件，未读其内容，可能功能完整只是体积小；`op_merge_gate.sh` 则 find 确认全仓不存在，此项确凿。建议进一步读 teardown 脚本确认。
