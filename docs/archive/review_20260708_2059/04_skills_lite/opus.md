# Opus Multi-Model Review Report - Skills Lite Mode

## 当前模型判断依据
- 观测来源：主会话由 `default_opus[1m]` 驱动。
- 审阅模式：`/multi-model-review` 只读审阅，独立评估，不输出 `verdict:` 格式，不碰 git 状态，输出写入指定报告文件。

## 审阅范围
本审阅覆盖了以下 lite 模式核心初始化、intake、run 关联脚本与配置：
- `skills/oplinit/SKILL.md`
- `skills/oplinit/scripts/op_check_env.sh`
- `skills/oplinit/scripts/oplinit_skeleton.sh`
- `skills/oplintake/SKILL.md`
- `skills/oplintake/scripts/op_check_env.sh`
- `skills/oplrun/SKILL.md`
- `skills/oplrun/scripts/close_check.sh`
- `skills/oplrun/scripts/op_assemble_eval_brief.sh`
- `skills/oplrun/scripts/op_check_env.sh`
- `skills/oplrun/scripts/op_check_p0.sh`
- `skills/oplrun/scripts/op_close_post.sh`
- `skills/oplrun/scripts/op_coder_check.sh`
- `skills/oplrun/scripts/op_jq.sh`
- `skills/oplrun/scripts/op_read_verdict.sh`
- `skills/oplrun/scripts/op_status.sh`

---

## 高优先级问题

### 1. 状态映射中文污染导致收尾崩溃
- **位置**: `skills/oplrun/scripts/op_close_post.sh` 第 55 行
- **现象**: 脚本调用了 `bash "$SCRIPT_DIR/op_status.sh" "$TID" 完成`。而 `op_status.sh` 脚本中硬编码限制了合法状态集只能为 ASCII 状态（`pending|ready|in_progress|reviewing|done|blocked|obsolete|suspended`），传入中文 `完成` 会触发 `die`。
- **影响**: 正常开发流程在 per-task 裸评 PASS 后执行收尾时，`op_close_post.sh` 必然在状态更新阶段报错中断，导致 status 无法推进到 `done`、Checkpoint 无法清理，流程被强行阻断。
- **建议**: 将 `完成` 改为 ASCII 状态 `done`：
  ```bash
  bash "$SCRIPT_DIR/op_status.sh" "$TID" done
  ```
- **置信度**: 100%
- **优先级**: High

### 2. `flock` 文件锁对 macOS / Windows Git Bash 的兼容性阻断
- **位置**: `skills/oplrun/scripts/op_status.sh` 第 50-52 行
- **现象**: 脚本在更新 `tasks_list.json` 时直接使用 Linux 特有的 `flock` 命令进行加锁。
- **影响**: 在 macOS (默认未安装 `flock` 命令行工具) 以及 Windows Git Bash 环境下运行时，会因为 `flock: command not found` 抛出 127 错误，直接触发 `die "获取文件锁失败"`，导致状态更新功能在非 Linux 平台上彻底失效。
- **建议**: 加锁前使用 `command -v flock` 检查可用性。若不存在，由于 Lite 模式下 Task 执行本身是单线程串行，可以安全降级为输出 WARN 提示并直接操作，或使用简易的文件夹/临时文件锁。
  ```bash
  if command -v flock >/dev/null 2>&1; then
      flock 3 || die "获取文件锁失败"
  else
      echo "[WARN] flock not found, proceeding without file lock" >&2
  fi
  ```
- **置信度**: 100%
- **优先级**: High

---

## 中低优先级问题

### 3. 未按设计要求剥离 spec 中的 "设计探索结论"
- **位置**: `skills/oplrun/scripts/op_assemble_eval_brief.sh`
- **现象**: 脚本在组装 evaluator brief 时，直接 `cat "$WORK_SPEC"` 输出了工作 spec 的全量内容。
- **影响**: 违反了设计规范 §2.5 和 §5.5 关于 "组装 eval_brief 时剥离'设计探索结论/已知坑'段" 的安全性设计。在 Lite 模式无文件系统强隔离的情况下，若不剥离这些实现设计方案，将导致 evaluator 产生确认偏误（Confirmation Bias），损害了评估的独立性和黑盒可信度。
- **建议**: 增加过滤逻辑，使用 `sed` 或 `awk` 提取工作 spec 时排除 `### 设计探索结论` 等纯实现侧的小章节。
- **置信度**: 95%
- **优先级**: Medium

### 4. `op_check_p0.sh` 的调用缺失与语义矛盾
- **位置**: `skills/oplrun/SKILL.md` & `skills/oplrun/scripts/op_check_p0.sh`
- **现象**: 项目中实现了 `op_check_p0.sh`，但在 `oplrun/SKILL.md` 的 per-task 循环各步骤中均未提及或调用该脚本。同时，该脚本设计为 "发现 open P0 则 exit 1 阻断"，这与设计规范 §5.8 强调的 "lite P0 处置：oplrun 结束报告汇总 open P0，不事中阻断" 存在语义冲突。
- **影响**: 导致 P0 阻断检查在运行期被静默忽略；或者一旦集成，将违背 "不事中阻断" 的设计原则，导致任务无法正常归档。
- **建议**: 明确 P0 检查的定位。应将 `op_check_p0.sh` 定位为 "只收集不阻断"，去掉 exit 1，并集成到 `oplrun/SKILL.md` 的最终收尾收口（Stage 5 / 收尾）中，作为汇总报告的一部分呈报给用户。
- **置信度**: 90%
- **优先级**: Medium

### 5. Agent 缺乏运行前路径探活，易导致迟滞报错
- **位置**: `agents/op-implementer.md` (第 7-13 行) & `agents/op-reviewer.md` (第 7-12 行)
- **现象**: 环境检查入口中，定义 `op_script` 路径解析后直接调用 `bash "$(op_script op_check_env.sh)"`。
- **影响**: 违反了设计规范 §5.4 的硬性要求："三执行 agent 在 resolver 后立即校验根目录存在——`${OP_SCRIPT_ROOT:-$OP_HOME}` 解析结果为空或目录不存在 → agent 输出明确 FATAL 并停在首个脚本调用前"。若变量解析为空，会导致执行空路径产生晦涩错误，且延迟到后续具体脚本调用才失败，增加调试定位成本。
- **建议**: 在 `op_script` 解析之后，直接加入路径存在性及非空的前置判定，失败则输出明确的 FATAL 错误并退出。
- **置信度**: 100%
- **优先级**: Medium

### 6. Windows CRLF 换行符对 P0 提取的潜在失效风险
- **位置**: `skills/oplrun/scripts/op_check_p0.sh` 第 24-25 行
- **现象**: 提取 `severity` 和 `status` 字段时，脚本使用了 `tr -d ' '` 仅剔除空格。
- **影响**: 若在 Windows 环境下编辑或拉取了 issues md 文件（换行符为 `\r\n`），`tr -d ' '` 无法过滤回车符 `\r`。这会导致提取出的 `sev` 值为 `P0\r`，与 `P0` 的字符串比对 `[ "$sev" = "P0" ]` 失败，导致阻断性问题被静默漏过。
- **建议**: 使用更安全的 `tr -d '[:space:]'` 或 `tr -d '\r'` 对解析出来的 frontmatter 值进行净化。
- **置信度**: 95%
- **优先级**: Medium

---

## 改进建议
- **优化收口阶段的 `git add -A` 行为**：`skills/oplrun/SKILL.md` 步骤 3.6 在收口归档时，要求 leader 运行 `git add -A`。这属于强侵入操作，极易将用户在工作区中未暂存的、与当前 Task 完全无关的临时改动一并 staged 并 commit 进历史。建议收窄 `git add` 范围为实际 Task 工作集及其衍生测试文件，或者先通过 `git status` 提醒用户确认是否有越界脏文件。

## 不确定项
- **关于 lite 模式下 `decisions.md` 的幂等性防重标记**：设计规范 §2.6 要求 decisions.md 应该具有多写者幂等 append 协议（`[来源标记 | TID | Round-N | 日期]`）。但目前 `oplrun/SKILL.md` 步骤 3.6 中的 leader append 示例中未体现此结构。考虑到 Lite 模式无 closer agent，改动完全由 leader 进行，且任务串行，不确定是否必须严格执行机器可读的幂等标识，抑或人工去重即可。
