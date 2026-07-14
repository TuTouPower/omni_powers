# 审阅报告：11_lite_skills（haiku 视角）

## 当前模型判断依据

可观测来源：`/home/karon/.claude/settings.json` 顶层 `model=haiku`；`env.ANTHROPIC_MODEL=default_model`；`ANTHROPIC_DEFAULT_HAIKU_MODEL=default_haiku[1m]`；`ANTHROPIC_DEFAULT_SONNET_MODEL=default_sonnet[1m]`；`ANTHROPIC_DEFAULT_OPUS_MODEL=default_opus[1m]`；主会话环境提示由 `default_model` 驱动。无法读取运行时内部状态，当前路径继承主会话。

## 审阅范围

- `skills/oplinit/SKILL.md`
- `skills/oplinit/scripts/op_check_env.sh`
- `skills/oplinit/scripts/oplinit_skeleton.sh`
- `skills/oplintake/SKILL.md`
- `skills/oplintake/scripts/op_check_env.sh`
- `skills/oplrun/SKILL.md`
- `skills/oplrun/scripts/close_check.sh`
- `skills/oplrun/scripts/op_assemble_eval_brief.sh`
- `skills/oplrun/scripts/op_check_env.sh`
- `skills/oplrun/scripts/op_close_post.sh`
- `skills/oplrun/scripts/op_coder_check.sh`
- `skills/oplrun/scripts/op_collect_open_issues.sh`
- `skills/oplrun/scripts/op_jq.sh`
- `skills/oplrun/scripts/op_read_verdict.sh`
- `skills/oplrun/scripts/op_status.sh`

设计文档 `docs/omni_powers_design.md` 仅作上下文核对，不单独审阅。

---

## 高优先级问题（CRITICAL / HIGH）

### H1. oplrun SKILL.md dispatch prompt 与 implementer 脚本寻址自相矛盾，存在 FATAL 风险

**位置**：`skills/oplrun/SKILL.md` 步骤 3.2 派发段（L94-L100）；`skills/oplinit/SKILL.md` L12-L16 脚本根说明；`docs/omni_powers_design.md` §5.4

**现象**：
- oplrun SKILL.md 步骤 3.2 派 implementer 时，dispatch prompt 写 `"环境：OP_PROFILE=lite OP_SCRIPT_ROOT=<oplrun skill 目录>"`，并要求 implementer "先跑 op_coder_check.sh {TID} 定模式"。
- 但 oplinit SKILL.md L12-L16 声称 lite 脚本走 `${OP_SCRIPT_ROOT:-$OP_HOME}` fallback，指向 `~/.claude/scripts/omni_powers/`。
- design §5.5 明确：install.sh 已装共享 scripts 到 `~/.claude/scripts/omni_powers/`，lite 副本暂保留并同步内容，**完整归并（删 lite 副本 + oplrun SCRIPTS 寻址共享目录）待重构**。
- 当前 SKILL.md 注入的 `OP_SCRIPT_ROOT=<oplrun skill 目录>` 指向 `~/.claude/skills/oplrun`，其下的 `scripts/` 是 lite 副本；而 agent 内 `op_script()` resolver（design §5.4）按 `$root/scripts` 与 `$root/skills/oprun/scripts` 两路径查找——**oplr**（heavy 入口）路径在 lite 下不存在，resolver 只能命中第一路径。implementer 若按 resolver 写法，路径依赖 `$OP_SCRIPT_ROOT/scripts/op_coder_check.sh`；但 dispatch prompt 只说"先跑 op_coder_check.sh"，未给完整路径，agent 要么自己拼，要么靠 resolver。

**影响**：
1. 路径不明确会导致 implementer 首个脚本调用 FATAL（design §5.4 "前置探活"要求 agent 校验根目录存在），任务卡在启动。
2. `OP_SCRIPT_ROOT` 注入的是 skill 目录（`~/.claude/skills/oplrun`），其 `scripts/` 子目录才是脚本；而 design §5.4 的 resolver 假设根下直接有 `scripts/` 或 `skills/oprun/scripts/`——若 agent 把 `OP_SCRIPT_ROOT` 当根拼 `$OP_SCRIPT_ROOT/scripts/op_coder_check.sh`，路径正确；若 agent 拼错（如 `$OP_SCRIPT_ROOT/op_coder_check.sh`），FATAL。SKILL.md 没有给出明确的拼接约定，依赖 agent 自行推断。
3. 与 design §5.5 "完整归并待重构"的过渡期状态耦合——副本若漂移，两份 `op_coder_check.sh`（skill 副本 vs 共享目录）行为可能不一致。

**建议**：
- 在 oplrun SKILL.md 派发段明确写出完整脚本调用路径，例如 `bash "$OP_SCRIPT_ROOT/scripts/op_coder_check.sh" {TID}`，而非裸 `op_coder_check.sh`。
- 或在 dispatch prompt 注入一个 `op_script()` resolver 函数定义，让 agent 直接 source 使用，消除路径歧义。
- 确认 `OP_SCRIPT_ROOT` 语义：是 skill 目录（含 `scripts/` 子目录）还是脚本平铺根？design §5.4 resolver 按"根下有 scripts/ 或 skills/oprun/scripts/"设计，暗示 `OP_SCRIPT_ROOT` 应为 skill 上一级（含 `scripts/` 或 `skills/` 的根）。当前 SKILL.md 注入 `OP_SCRIPT_ROOT=<oplrun skill 目录>` 与 resolver 假设不符。

**置信度**：中（design §5.4/§5.5 承认过渡期，路径约定确实存在歧义；但实际 agent 提示词可能内含 resolver 兜底，未读 agent 文件无法 100% 确认）

**优先级**：HIGH

---

### H2. op_close_post.sh spec 归档逻辑在"工作区无 spec"时会静默跳过，破坏 task:spec 1:1 归档完整性

**位置**：`skills/oplrun/scripts/op_close_post.sh` L55-L58

**现象**：
```bash
SPEC_SRC="$(ls "$ROOT"/docs/omni_powers/op_execution/specs/${TID}_*.md 2>/dev/null | head -1)"
if [ -n "$SPEC_SRC" ] && [ ! -e "$ROOT/docs/omni_powers/op_record/specs/$(basename "$SPEC_SRC")" ]; then
    git mv "$SPEC_SRC" "$ROOT/docs/omni_powers/op_record/specs/" || die "归档 spec 失败: $TID"
fi
```
当 `SPEC_SRC` 为空（工作 spec 不存在或已被前次归档移走）时，整个 if 块静默跳过，不报错。lite 下 spec 写保护是 advisory（§5.9），implementer 主分支直改风险存在；若 spec 在收口前被误移/误删，此处不拦。

**影响**：
1. task:spec 1:1 是核心契约（design §1.1），spec 未归档意味着 `op_record/specs/` 出现 TID 空洞，后续 task 无法引用历史 spec。
2. 与 close_check.sh L29-L40 的"归档二件齐全"检查不对齐——close_check 只查 report/review，不查 spec 是否归档，形成检查盲区。
3. lite 无 blueprint，工作 spec 是唯一契约源，归档失败等于契约丢失。

**建议**：
- `SPEC_SRC` 为空时 die，明确报"工作 spec 不存在: specs/${TID}_*.md，无法归档"。
- 或在幂等重跑场景（spec 已归档）下用更明确的判定：检查 `op_record/specs/` 是否已有该 TID 的 spec，有则视为已归档跳过，无则 die。

**置信度**：高（逻辑确实静默跳过；幂等性注释 L21"工作区优先，归档次之"只覆盖 task 目录，未覆盖 spec）

**优先级**：HIGH

---

### H3. op_close_post.sh acceptance 归档同样静默跳过，eval.md 可能未进归档

**位置**：`skills/oplrun/scripts/op_close_post.sh` L59-L63

**现象**：
```bash
ACCEPT_SRC="$ROOT/docs/omni_powers/op_execution/acceptance/$TID"
ACCEPT_DST="$ROOT/docs/omni_powers/op_record/acceptance/$TID"
if [ -d "$ACCEPT_SRC" ] && [ ! -e "$ACCEPT_DST" ]; then
    git mv "$ACCEPT_SRC" "$ACCEPT_DST" || die "归档 acceptance 失败: $TID"
fi
```
ACCEPT_SRC 不存在时静默跳过。但 L42-L49 刚校验过 `$EVAL_MD`（= `$ACCEPT_SRC/eval.md`）存在且 PASS——若 eval.md 确实存在，ACCEPT_SRC 必然存在，逻辑上不会跳过。但 `eval: skip` 的 task（L43-L44 `EVAL_SKIP=skip` 分支）跳过 eval.md 校验，此时 ACCEPT_SRC 可能不存在（evaluator 未派发，无 acceptance 产出），此处静默跳过合理。

**影响**：非行为型 task（eval:skip）不产 acceptance，跳过归档正确；行为型 task 若 acceptance 目录因外部原因缺失，L46 的 `[ -s "$EVAL_MD" ]` 会先 die，不会走到这里。实际风险低。

**建议**：保持现状即可，但建议加注释说明"eval:skip 场景 acceptance 不存在属正常"。

**置信度**：高（逻辑自洽，风险低）

**优先级**：LOW（降级，原列 HIGH 但复核后风险可控）

---

### H4. oplrun SKILL.md 步骤 3.6 `git add -u` 后 `op_close_post.sh` 再 `git add`，stage 范围重复且可能遗漏新文件

**位置**：`skills/oplrun/SKILL.md` L186-L188

**现象**：
SKILL.md 3.6 收口流程：
```bash
git add -u                                          # 已跟踪改动
git status --short | grep -E '^\?\? ' | grep -v 'docs/omni_powers/' && echo "[WARN] ..." || true
bash "$SCRIPTS/op_close_post.sh" {TID} {feature}    # 内部再 git add 归档+progress+tasks_list
```
问题：
1. `git add -u` 只 stage 已跟踪文件的改动（含 implementer 改的 src + op_close_post 之前 leader 手动改的 checkpoint），**不包含未跟踪新文件**（如 implementer 新建的 src 文件、新建的 e2e 文件）。SKILL.md 注释 L185 说"未跟踪文件 leader 确认"，但 WARN 后没有实际的 `git add` 动作——只 echo 警告，未跟踪文件最终没被 stage。
2. `op_close_post.sh` L88-L91 内部 `git add` 只 add 归档目录 + progress + tasks_list，不 add src 改动。两者相加：implementer 新建的 src 文件（未跟踪）**不会被 commit**。
3. 顺序问题：`git add -u` 在 `op_close_post.sh`（内含 `git mv`）之前跑。`git mv` 本身会 stage 移动，但若 `git add -u` 已 stage 了 task 工作区的改动，随后 `git mv` 把目录移走，stage 状态可能混乱。

**影响**：
1. **新文件丢失**：implementer 新建 src 文件（feat 常见），收口 commit 不含它，下个 task 跑时文件还在工作树但不在 git 历史里，compact 恢复或 `git revert` 时出错。
2. 违反 design §5.9"按实际 diff add"原则——`git add -u` 只覆盖已跟踪，未跟踪新文件被遗漏。

**建议**：
1. WARN 检测到未跟踪的 omni_powers 文件后，应实际 `git add docs/omni_powers/` 补纳（或 leader 显式确认后 add）。
2. 对 src 等非 omni_powers 未跟踪文件，leader 确认后 `git add <具体文件>`，而非只 echo。
3. 考虑调整顺序：先跑 `op_close_post.sh`（归档 + stage 流程文件），再 `git add -u` + 处理未跟踪，最后统一 commit。当前顺序 `git add -u` → `op_close_post.sh`（git mv）→ commit 可能产生 stage 冲突。

**置信度**：高（`git add -u` 确实不纳未跟踪文件，逻辑明确）

**优先级**：HIGH

---

### H5. oplintake SKILL.md 步骤四 task schema 与 heavy design 的 `eval` 字段语义不匹配

**位置**：`skills/oplintake/SKILL.md` L79-L90；`docs/omni_powers_design.md` §2.4（D9 task schema `eval: "required"|"skip"`）

**现象**：
oplintake 给出的 task schema：
```json
{
  "eval": "required",
  "eval_reason": null
}
```
与 design §2.4 D9 字段定义一致（`eval: "required"|"skip"`）。但 op_close_post.sh L43 读取字段写法：
```bash
EVAL_SKIP="$(jq -r --arg tid "$TID" '.tasks[] | select(.id==$tid) | .eval // "required"' ...)"
if [ "$EVAL_SKIP" != "skip" ]; then ...
```
变量名 `EVAL_SKIP` 语义反转（值为 required 时表示"不 skip"），可读性差但逻辑正确。问题在 oplintake SKILL.md 未说明何时填 `skip`——design §2.4 明确"接口先行/脚手架/纯内部重构 task 免派"，但 oplintake 步骤四完全没提这个判定，leader 写 tasks_list 时可能漏标 `eval: skip`，导致非行为型 task 也被强制派 evaluator（裸评无行为可验，evaluator 困惑）。

**影响**：
1. 非行为型 task 未标 `eval: skip` → op_close_post.sh 强制校验 eval.md（L46 die），evaluator 被派但无 AC 可验，卡在收口。
2. oplintake 是 task 创建入口，漏指导等于源头缺失。

**建议**：
1. oplintake SKILL.md 步骤四补充判定说明：接口先行/脚手架/纯内部重构 task 标 `eval: skip` + 填 `eval_reason`，引用 design §2.4。
2. 变量名 `EVAL_SKIP` 改为 `EVAL_MODE` 更清晰（非必须）。

**置信度**：中（oplintake 确实未提 eval 字段判定；但 leader 可能从 design 自行推断）

**优先级**：HIGH

---

## 中低优先级问题（MEDIUM / LOW）

### M1. op_check_env.sh 三份副本完全相同，未利用共享目录机制

**位置**：`skills/oplinit/scripts/op_check_env.sh`、`skills/oplintake/scripts/op_check_env.sh`、`skills/oplrun/scripts/op_check_env.sh`（三份逐字节相同）

**现象**：三个 skill 各带一份内容完全一致的 `op_check_env.sh`。design §5.5 明确"install.sh 已统一装共享 scripts 到 `~/.claude/scripts/omni_powers/`"，lite 副本暂保留并同步——但 SKILL.md 调用时用的是 `$SCRIPTS/op_check_env.sh`（本 skill 的 scripts/），而非共享目录。

**影响**：
1. 三份副本需手动保持同步，任一修改漏改另两份会产生行为漂移（design §5.5 承认"副本同步淘汰待重构"）。
2. 当前内容一致，无即时风险，但维护负担存在。

**建议**：
- 按设计方向，逐步改为调用共享目录 `$OP_SCRIPT_ROOT/op_check_env.sh`（`OP_SCRIPT_ROOT=~/.claude/scripts/omni_powers/`），删 skill 内副本。
- 过渡期加 `build_lite.sh` 校验三份一致（design §5.5 提到该脚本暂留维护副本同步）。

**置信度**：高（三份逐字节相同，直接观察）

**优先级**：MEDIUM

---

### M2. oplinit_skeleton.sh profile 互斥判定对"无三区但已有 docs/omni_powers/"场景未覆盖

**位置**：`skills/oplinit/scripts/oplinit_skeleton.sh` L17-L27

**现象**：
```bash
if [ -f "$PROFILE_FILE" ]; then
    # 读 profile 判定
elif [ -d docs/omni_powers/op_execution ] && [ -f docs/omni_powers/op_execution/tasks_list.json ]; then
    die "疑似 heavy 残留..."
fi
```
elif 条件要求同时有 `op_execution/` 目录和 `tasks_list.json`。但若用户手动建了 `docs/omni_powers/`（如只建了 README 或只建了 op_blueprint 空目录），既无 profile 也无 tasks_list.json，elif 不命中，脚本继续往下 `mkdir -p` 补建——此时若该目录其实是 heavy 的不完整残留，会静默补成 lite 骨架，污染 heavy 状态。

**影响**：边缘场景（用户半初始化或手动建目录）下 profile 探测失效。design §5.2 判定表要求"已有 docs/omni_powers/ 但无 profile → 默认 die"。

**建议**：
- elif 放宽为 `[ -d docs/omni_powers ]`（目录存在即触发"无 profile"判定），与 design §5.2 判定表对齐。
- 当前条件过严，漏判风险。

**置信度**：中（design §5.2 判定表"已有 docs/omni_powers/ 但无 profile → 默认 die"确实比脚本宽松）

**优先级**：MEDIUM

---

### M3. op_status.sh `--batch` 分支未处理 `blocked_by`，与单条模式语义不对称

**位置**：`skills/oplrun/scripts/op_status.sh` L58-L63

**现象**：
```bash
if $batch; then
    tids_json=$(echo "$tids" | jq -R 'split(",")')
    jq ... '.blocked_by = null' ...   # 批量恒置 null
```
批量模式恒置 `blocked_by = null`。若用 `--batch` 批量置 blocked 状态，blocked_by 信息丢失。虽然批量 blocked 场景罕见，但语义上单条模式支持 blocked_by（L65-L69），批量不支持，行为不对称。

**影响**：低，批量 blocked 非典型用例。但若有人误用 `--batch T1,T2 blocked quality`，blocked_by 被吞，状态机依赖 blocked_by 分类的下游逻辑（如 optriage）会失真。

**建议**：
- 批量模式若 `status=blocked`，要么 die 提示"批量不支持 blocked_by，请单条"，要么接受第 4 参数统一赋值。

**置信度**：高（逻辑明确）

**优先级**：MEDIUM

---

### M4. op_jq.sh `deps` 子命令用空格分词遍历依赖，依赖 ID 含空格会出错

**位置**：`skills/oplrun/scripts/op_jq.sh` L22-L34

**现象**：
```bash
DEPS=$(jq --arg tid "$TID" -r '.tasks[] | select(.id==$tid) | .depends_on[]?' ...)
for d in $DEPS; do  # 未引号包裹，按 IFS 分词
```
`for d in $DEPS` 依赖默认 IFS（空格/制表符/换行）分词。TID 约定为 `T0001` 格式（design §1），不含空格，实际安全。但写法不规范，若未来 TID 格式变化或 jq 输出含额外空白，行为异常。

**影响**：低（TID 格式约束保证安全），但属于脆弱写法。

**建议**：改用 `while IFS= read -r d; do ... done <<< "$DEPS"` 更健壮。

**置信度**：高

**优先级**：LOW

---

### M5. op_coder_check.sh 与 op_read_verdict.sh 对 review.md verdict 行的 grep 模式不一致

**位置**：
- `skills/oplrun/scripts/op_coder_check.sh` L14 `grep -q '^verdict:'`
- `skills/oplrun/scripts/op_coder_check.sh` L21 `grep -c '^verdict:'`
- `skills/oplrun/scripts/op_read_verdict.sh` L21 `grep -c '^verdict:'`
- `skills/oplrun/scripts/op_read_verdict.sh` L22 `grep -oE '^verdict:[[:space:]]*(PASS|FAIL)'`
- `skills/oplrun/scripts/op_close_post.sh` L38 `grep -oE '^verdict:[[:space:]]*(PASS|FAIL)'`

**现象**：
- 计数用 `grep -c '^verdict:'`（宽松，匹配任意 verdict 行）。
- 取值用 `grep -oE '^verdict:[[:space:]]*(PASS|FAIL)'`（严格，只认 PASS/FAIL）。
- 若 review.md 出现 `verdict: INSUFFICIENT_EVIDENCE`（design §2.5 evaluator hard-pass gate 三态之一，reviewer 理论上也可能用），计数会把它算作一轮，但取值时 `tail -1` 取不到 PASS/FAIL，verdict 变量可能为空。

**影响**：
1. op_read_verdict.sh L22 verdict 为空时，L27-L35 走 else 分支输出 `result: NONE, exit 0`——把"非 PASS/FAIL 的 verdict"当 NONE 处理，leader 可能误判为"未裁决"继续派 reviewer，轮次计数已增加但 verdict 未识别。
2. op_coder_check.sh 计数含非 PASS/FAIL 行，round 判定可能偏大。

**建议**：
1. 统一 grep 模式，计数也用 `grep -cE '^verdict:[[:space:]]*(PASS|FAIL)'`，只数有效裁决。
2. op_read_verdict.sh 对"有 verdict 行但无 PASS/FAIL"的情况单独输出 `result: UNKNOWN` 并 exit 非 0，让 leader 显式处理。

**置信度**：中（reviewer 实际是否输出 INSUFFICIENT_EVIDENCE 取决于 agent 提示词，未读 agents/ 无法确认；但 design §2.5 明确这是合法三态之一）

**优先级**：MEDIUM

---

### M6. close_check.sh git status 检查的正则可能误匹配归档路径

**位置**：`skills/oplrun/scripts/close_check.sh` L43

**现象**：
```bash
others=$(git status --short 2>/dev/null | grep -v "^[MADRC? ]\+ ${arch}" || true)
```
`$arch` = `docs/omni_powers/op_record/tasks/${TID}`，正则中 `/` 未转义（grep BRE/ERE 下 `/` 是字面量，实际安全）。但 `grep -v` 排除"以归档路径开头"的行，若工作树有其他 `op_record/tasks/` 下的改动（如另一 TID 的残留），不会被排除，正确触发 WARN。逻辑基本正确。

**潜在问题**：`[MADRC? ]+` 中的 `?` 在字符类内是字面量（非量词），` `（空格）也在类内——覆盖 `git status --short` 的 XY 状态码组合基本够用，但未覆盖 `??`（未跟踪）的两个 `?`，因为类内只有一个 `?` 且 `+` 修饰整个类。实际 `??` 会匹配（两个字符都在类内），没问题。

**影响**：低，逻辑可用。

**建议**：可读性可提升，加注释说明状态码覆盖意图。非必须。

**置信度**：高

**优先级**：LOW

---

### M7. op_assemble_eval_brief.sh 未校验 spec 是否 approved，可能给 evaluator 喂 draft spec

**位置**：`skills/oplrun/scripts/op_assemble_eval_brief.sh` L16-L17

**现象**：
```bash
WORK_SPEC=$(ls "$ROOT"/docs/omni_powers/op_execution/specs/${TID}_*.md 2>/dev/null | head -1 || true)
[ -n "$WORK_SPEC" ] || die "工作 spec 不存在..."
```
只校验文件存在，不读 frontmatter `status`。若 spec 还是 `draft`（闸门 A 未批），brief 照样组装，evaluator 按 draft spec 裸评——契约未冻结，验收无意义。

**影响**：
1. oplrun SKILL.md 流程上 reviewer 在裸评前，理论上 spec 此时应该已 approved。但 lite 无写保护 hook，draft 状态残留风险存在。
2. 若 leader 忘记把 spec 改 approved（oplintake 步骤三），整个验收链基于未冻结契约。

**建议**：
- 加 frontmatter 校验：`grep -q '^status: approved' "$WORK_SPEC" || die "spec 未 approved，拒绝组装 brief"`。

**置信度**：中（流程约束理论上保证 approved，但机械校验缺失）

**优先级**：MEDIUM

---

### M8. op_collect_open_issues.sh 标题解析 awk 对带空格/特殊字符的 title 截断不准

**位置**：`skills/oplrun/scripts/op_collect_open_issues.sh` L20

**现象**：
```bash
title="$(awk -F': *' '/^title:/{gsub(/^title: */, ""); print; exit}' "$f" ...)"
```
`awk -F': *'` 设分隔符为冒号+空格，随后 `gsub` 又去剥离 `title: ` 前缀——两套逻辑叠加。若 title 含 `: `（如 "修复：登录失败"），`-F': *'` 会把 title 切断在第一个冒号处，`gsub` 后取到的可能只是冒号前的部分。实际上 `gsub` 是对整行操作，`-F` 对 `print`（无字段号）不生效（print 等价 print $0），所以实际取到完整行再 gsub 去前缀——**逻辑可用但 `-F` 冗余，易误读**。

**影响**：低，实际输出正确（print 默认整行）。但 `-F': *'` 是死代码，误导维护者。

**建议**：删掉 `-F': *'`，只保留 `gsub` 逻辑。

**置信度**：高

**优先级**：LOW

---

### M9. oplrun SKILL.md compact 恢复步骤未提示读 dispatch 锚点 sha

**位置**：`skills/oplrun/SKILL.md` L242-L247

**现象**：
compact 恢复 4 步：读 SKILL + profile → op_jq all → 读未归档 task 的 report/review 重建 → 重选 task。未提恢复 `DISPATCH_SHA`（步骤 3.2 定义的关键变量，reviewer diff 锚点）。

**影响**：
1. compact 后 leader 丢失 `DISPATCH_SHA`，reviewer 派发时 `git diff ${DISPATCH_SHA}` 锚点空，diff 异常。
2. 无机械持久化——DISPATCH_SHA 只存在 leader 主会话内存，compact 即丢。

**建议**：
1. compact 恢复步骤补一条：从 checkpoint 或 task 目录重建 DISPATCH_SHA（如收口时把 DISPATCH_SHA 写入 task 目录 `.dispatch_sha` 文件）。
2. 或在 leader_checkpoint.md 增加 `dispatch_sha_{TID}` 字段持久化。

**置信度**：高（DISPATCH_SHA 未持久化，compact 必丢）

**优先级**：MEDIUM

---

### M10. oplrun SKILL.md 3.4 reviewer diff 指令与 lite 实际环境（无 worktree）的 `git add -N` 前置缺失

**位置**：`skills/oplrun/SKILL.md` L130

**现象**：
dispatch reviewer prompt 写："`git diff ${DISPATCH_SHA}（leader 注入锚点 sha... 新增文件先 git add -N 纳入）`"。`git add -N`（intent-to-add）是让未跟踪新文件出现在 `git diff` 里的标准做法。但这个指令是写给 reviewer agent 的——reviewer 是只读 subagent（design §3.4 "无 checkout"），它跑 `git add -N` 会修改 index，若 reviewer worktree 与主 worktree 共享 index（lite 无 worktree 隔离，reviewer 在主工作树跑），**reviewer 的 `git add -N` 会污染主分支 index 状态**，后续 leader `git add -u` / `git status` 判定受影响。

**影响**：
1. reviewer 跑 `git add -N` 后，这些文件在 index 里标记为 intent-to-add，leader 收口时 `git add -u` 可能行为异常（`-u` 不处理 intent-to-add 的未跟踪文件，但 index 状态已脏）。
2. `git status` 输出含 `A`（added）状态，close_check.sh L43 的 WARN 检测可能误报。

**建议**：
1. reviewer prompt 改为：让 leader 在派 reviewer 前**先**跑 `git add -N <未跟踪新文件>` 纳入 diff，reviewer 只读 diff 不改 index。职责分离。
2. 或 reviewer 用 `git diff ${DISPATCH_SHA} -- . ':!docs/omni_powers'`（不对，这会排除流程文件）——更稳妥是 leader 预处理 index。

**置信度**：中（lite 确实无 worktree 隔离，reviewer 与主会话共享工作树；`git add -N` 副作用真实存在）

**优先级**：MEDIUM

---

### M11. op_status.sh flock 锁文件残留未清理

**位置**：`skills/oplrun/scripts/op_status.sh` L50-L56, L81-L82

**现象**：
```bash
LOCK_FILE="$TASKS_FILE.lock"
exec 3>"$LOCK_FILE"
flock 3 ...
...
mv "$TASKS_FILE.tmp" "$TASKS_FILE"
exec 3>&-   # 关闭 fd 3，释放锁，但 lock 文件残留
```
锁文件 `tasks_list.json.lock` 创建后不删除。oplinit_skeleton.sh L39-L40 的 `.gitignore` 已忽略 `*.lock`（L40 `printf '*.lock\n'`），所以不会进 git。但文件残留依赖 `.gitignore` 生效——若用户未跑 oplinit（手动建目录）或 `.gitignore` 被删，lock 文件会进 git。

**影响**：低（oplinit 保证 .gitignore 存在；flock 释放后残留空文件无害）。

**建议**：`exec 3>&-` 后加 `rm -f "$LOCK_FILE"` 清理（`flock` 释放后删除安全）。

**置信度**：高

**优先级**：LOW

---

### M12. oplrun SKILL.md 结束报告缺少 spec 变更决策表的机械汇总

**位置**：`skills/oplrun/SKILL.md` L207, L238

**现象**：
结束报告 L207 提"spec 变更记录（leader-close decisions）"，L238 提"spec 变更"。但设计要求（design §2.6 事后报告）报告内容含"spec 变更决策表（decisions.md spec-delta）"。lite 下 leader-close 是 decisions.md 的来源标记之一，但 SKILL.md 未给出机械汇总方法（如 `grep '\[leader-close\]' docs/omni_powers/op_record/decisions.md`），依赖 leader 手动扫。

**影响**：低，leader 能读 decisions.md；但缺机械辅助易漏。

**建议**：结束报告步骤补一个 grep 命令汇总本批次 leader-close 条目。

**置信度**：中

**优先级**：LOW

---

## 改进建议

### 全局性建议

1. **路径寻址统一化**（对应 H1）：oplrun SKILL.md 所有 dispatch prompt 中的脚本调用都应给出完整路径或注入 resolver，当前"裸脚本名 + 环境变量"的写法依赖 agent 自行推断，是 FATAL 高发点。建议定义一个标准 dispatch header 模板，所有 subagent 派发复用。

2. **收口 stage 顺序重构**（对应 H4）：当前 `git add -u` → `op_close_post.sh`（git mv）→ commit 的顺序有 stage 冲突和新文件遗漏风险。建议改为：`op_close_post.sh`（归档 + stage 流程文件）→ leader 处理 src 改动（`git add -u` + 确认未跟踪）→ 统一 commit。

3. **verdict 解析标准化**（对应 M5）：定义一个共享的 verdict 解析函数（或在 op_read_verdict.sh 基础上统一），所有脚本（op_coder_check / op_close_post / op_read_verdict）复用，消除 grep 模式漂移。

4. **DISPATCH_SHA 持久化**（对应 M9）：把 DISPATCH_SHA 写入 task 目录或 checkpoint，compact 恢复可重建。

5. **副本归并推进**（对应 M1）：按 design §5.5 方向，逐步删 skill 内 scripts 副本，改调共享目录，降低同步维护成本。

### 文档一致性

6. oplintake SKILL.md 步骤四应补 `eval` 字段判定指导（对应 H5），与 design §2.4 D9 对齐。

7. oplinit_skeleton.sh profile 互斥判定应与 design §5.2 判定表一致（对应 M2）。

---

## 不确定项 / 可能误报

1. **H1 路径寻址**：未读 `agents/op-implementer.md` 等 agent 定义文件，agent 内可能已有 `op_script()` resolver 兜底，实际 FATAL 概率可能低于判断。需交叉验证 agent 文件。

2. **H3 acceptance 归档静默跳过**：复核后逻辑自洽（eval:skip 场景合理跳过），已降级为 LOW，可能不算问题。

3. **M5 verdict INSUFFICIENT_EVIDENCE**：reviewer 实际是否输出该三态取决于 agent 提示词约束，未读 agents/ 确认。若 reviewer 提示词强制只输出 PASS/FAIL，则此问题不存在。

4. **M10 reviewer `git add -N` 副作用**：reviewer 若被明确指示"只读不改 index"，实际不会跑 `git add -N`——但 SKILL.md L130 的 prompt 文本确实包含该指令，存在被 agent 执行的可能。需结合 agent 提示词判断。

5. **oplintake SKILL.md L25 `grep -qx lite`**：`-x` 要求整行匹配，若 profile 文件末尾有换行符（`echo "lite"` 默认带 `\n`），`grep -qx` 匹配整行内容（不含换行），正常工作。但若文件有尾部空格或 BOM，可能失配——未实测，列为观察项。

6. **oplinit_skeleton.sh L36 `echo "lite" > "$PROFILE_FILE"`**：`echo` 在不同 shell 对转义符处理不一（dash 不解析 `\n`，bash 默认不解析），此处无转义符，安全。但跨 shell（若用户用 sh 而非 bash 跑）行为依赖 `echo` 实现——脚本 shebang 是 `#!/usr/bin/env bash`，正常场景安全。
