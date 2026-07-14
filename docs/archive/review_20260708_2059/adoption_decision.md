# 第二轮审阅决策（review_20260708_2059）

## 概览

- 审阅范围：6 主题（01 入口/模板 → 06 测试）× 4 模型（current/haiku/opus/sonnet）= 24 报告，07-11（archive/vendors）非 omni_powers 核心，略。
- 共识问题（≥2 模型）约 60 项 + 单模型独特若干。
- 统计：**采纳 ~48 项 / 不采纳 5 项 / 待决定 9 项**。

## 关键判断

本轮问题分两类：

1. **同步缺口（~40 项，占大头）**：上一轮审阅改了 design.md（状态机 ASCII、A18 闸门 C 事后报告、D6 lite 验收前置、D7 DOM 降 advisory、D9 eval 字段、D10 feature_key、D13 失败模式 best-effort、A17 去 SessionStart、A21 防线原则等），但执行时只改了 design + 部分 skill/agent/脚本，**模板全文、agent 内部指令、test fixture、脚本内部调用、RULES.md 状态表大量漏改**——代码与 design 脱节。这些方向已定（design 是真相），修复 = 把 design 改动同步到残留处。
2. **真 bug（~8 项）**：与上轮无关的新问题，CRITICAL/HIGH，必须修。

另有一组**设计取舍**（9 项待你定）。

---

## 待决定项（9 项，需你拍板）

### Q1. op_merge_gate.sh 实现优先级（写入硬底线未落地）

- 来源：05-H2（current/haiku/sonnet 共识）
- 现状：design §3.4 把 merge gate 列为"写入硬底线唯一生效点"（白名单 + review verdict + 受保护路径 REJECT），但 scripts/ 与 skills/oprun/scripts/ 均无此文件。§4.2 诚实标 P1 未落地，但 §3.4 正文写法像已存在。
- 选项：
  - A 现在实现 op_merge_gate.sh（白名单 diff + review verdict 读取 + REJECT 逻辑）—— heavy 写入硬底线真正生效
  - B design §3.4 正文统一加"（P1 交付，当前未落地）"与 §0.2 对齐，实现延后
- 推荐：**B**。当前 omni_powers 仍在文档/流程骨架阶段，merge gate 实现是 P1 专项，应等流程跑通后再补硬门；先诚实标注未落地。
- 理由：A 是真实现工作（白名单 diff 算法 + verdict 解析 + 测试），非同步缺口，应单独 P1 里程碑；B 消除"文档像已存在"的误导，零代码。

### Q2. Stop / SessionStart hook 补不补

- 来源：05-H3（current/sonnet 共识）
- 现状：settings.template.json 只注册 PreToolUse/PostToolUse/SubagentStop。design §4.1 要求 Stop（leader 收尾门禁）+ SessionStart（路由注入）+ PreToolUse[Task]（dispatch 留痕）。上轮 A17 已删 SessionStart（移到 /oprun 启动）。但 Stop hook（leader 收尾校验状态+新鲜证据）design §3.3 列了，未注册。
- 选项：
  - A 补 Stop hook（leader 收尾时校验 status + 测试证据新鲜度）+ design §4.1 对齐 settings.template 现状（去 SessionStart/PreToolUse[Task] 描述）
  - B design §4.1/§3.3 标"Stop hook P1 待落地"，settings.template 现状（三 hook）为真相
- 推荐：**A**。Stop hook 是 leader 收尾门禁（防 leader 忘改 status/漏证据），成本低（一个脚本），与 A17 删 SessionStart 不冲突（SessionStart 是注入，Stop 是校验，不同）。
- 理由：Stop 校验 leader 自身（信任根侧），是防线原则（A21"返回后验证"）的机械兜底，值得补。

### Q3. test_lock.sh 去留

- 来源：05-H6（haiku/sonnet 共识）
- 现状：scripts/test_lock.sh 提供 add/remove/check 锁定文件，但 hooks/pre_tool_use.sh 走硬编码 `e2e/*|*BUG-*`，不读 .test_locks。锁定与否对 hook 行为零影响。opinit_skeleton 建 .test_locks，opred skill 引用 test_lock——三方不一致。
- 选项：
  - A 删 test_lock.sh + 清理 opinit/opred 引用（行为层测试归 evaluator 全局管理，不需细粒度锁）
  - B pre_tool_use.sh 改读 .test_locks（实现锁定生效）
- 推荐：**A**。锁定机制当前是死代码（hook 不读），维护负担（三方不一致）；design §3.1 行为层测试归 evaluator，细粒度锁定是过度设计。
- 理由：B 增复杂度（hook 读文件 + 维护 .test_locks），收益不明（e2e 硬编码已工作）。

### Q4. op_check_p0.sh 去留（lite P0 检查）

- 来源：04-P1-1（current/haiku/sonnet/opus 全共识）
- 现状：脚本实现"open P0 → exit 1 阻断归档"，但 oplrun SKILL.md 从不调用（上轮 A18 改事后，3.6 不跑它）；design §5.8 要求"P0 不事中阻断，进结束报告"。死代码 + 语义反转。
- 选项：
  - A 删 op_check_p0.sh（lite + heavy 副本），结束报告段用 jq 直接扫 issues 汇总
  - B 改名 op_collect_open_issues.sh——去 exit 1，只汇总返回 0，供结束报告用
- 推荐：**B**。结束报告要扫 P0 汇总（A18），封装成脚本（jq 扫 issues/ open P0/P1）比 SKILL 内联好；改名消除"阻断"语义误导。
- 理由：A 删后结束报告要内联 jq（散）；B 保留机械汇总能力，语义对齐 A18。

### Q5. op_closer_gate.sh 自动撤销 vs 只报

- 来源：05-H7（current 独报但风险高）
- 现状：我上轮写的 op_closer_gate.sh 用 `git status --porcelain` 扫全工作区，不区分"closer 本次触碰"与"closer 前已存在的合法未提交变更"（review.md/checkpoint/临时验证）；`git checkout --` 对未跟踪文件无效。可能误撤销致数据丢失。
- 选项：
  - A 派发前记 baseline（git status -z），gate 只比 baseline 之后新增；撤销区分 tracked/untracked
  - B gate 只 fail（越界即告警 + exit 1），不自动撤销，交 leader 决策
- 推荐：**B**。自动撤销风险高（误删 leader 合法改动）；gate 职责是"拦截提案进自审"，越界时 fail + 报清单，leader 看 grant 或 revert 更安全。
- 理由：A 实现 baseline diff 复杂 + 仍可能误判；B 简单安全，符合"机械校验只报告，破坏性操作归 leader"。

### Q6. git add -A 收紧策略（lite 收口）

- 来源：04-P1-4（sonnet/opus 共识）
- 现状：oplrun 3.6 收口用 `git add -A`（我上轮 D6 改的，为防漏新增文件）。lite 无 worktree/hook，git add -A 是写入唯一收集点，会把 docs/omni_powers/ 外的临时文件/调试输出/.env 一并入库。
- 选项：
  - A 收紧为 `git add -u`（已跟踪改动）+ 显式 add 新增列表（从 dispatch 锚点 sha diff-filter=A 取）
  - B git add -A 前跑 git status --short 让 leader 确认范围
- 推荐：**A**。-u + 锚点 sha 派生的新增列表，机械且精确（只 add 本 task 实际产出）。
- 理由：B 每次确认打断（违反 autonomy）；A 复用 dispatch 锚点 sha（A19 已有），diff-filter=A 取新增文件，与 workset 比对越界即 warn。

### Q7. opspec spec 字段 schema 定型（路径 vs TID）

- 来源：03-2（current/haiku/sonnet/opus 共识）
- 现状：tasks_list.json 的 spec 字段，design §2.3 用路径 `specs/{TID}_{slug}.md`，opspec/opintake 示例用 TID `{TID}`。三处冲突，dispatch 脚本无法稳定定位 spec。
- 选项：
  - A 统一为路径（`specs/{TID}_{slug}.md`），dispatch 直接用
  - B 统一为 TID（`{TID}`），dispatch 拼 slug 路径
- 推荐：**A**。路径自描述（含 slug），dispatch 免拼接；TID 在 id 字段已有，spec 字段冗余 TID 无增益。
- 理由：路径是文件系统真相，dispatch 用路径最稳；slug 在路径里也便人读。

### Q8. flock 跨平台降级

- 来源：04-P2-3（sonnet/opus 共识）
- 现状：op_status.sh 用 flock（Linux 特有），macOS/Git Bash 无 → die，状态更新全失效。
- 选项：
  - A `command -v flock` 检测，不可用降级 WARN + 无锁写（lite 串行，并发风险低）
  - B 强制要求 flock（macOS brew install flock / Git Bash 装 util-linux）
- 推荐：**A**。lite 零侵入哲学（不强制装额外包），串行执行下无锁可接受（并发风险低）；WARN 提示用户。
- 理由：B 违反零侵入；A 降级合理（锁是防并发，lite 单 leader 串行无并发）。

### Q9. 补 merge gate / closer gate / SubagentStop 测试优先级

- 来源：06-T7（current/haiku/opus/sonnet 全共识）
- 现状：这三个 P1 防线零 bats 覆盖。closer gate 已落地（D3），merge gate 未落地（Q1），SubagentStop hook 在。
- 选项：
  - A 现在补 closer_gate + SubagentStop 测试（merge gate 等落地）
  - B 全部等 P1 防线落地后统一补测
- 推荐：**A**。closer_gate 已落地应即测（防回归）；SubagentStop hook 在也应测；merge gate 等实现。
- 理由：已落地的就该测（closer_gate 我上轮写完没测，是欠债）；merge gate 随 Q1。

---

## 采纳项（~48 项，详细）

### A. 真 bug（CRITICAL/HIGH，必须修，方向明确）

**A1. implementer 写 review.md 违反单写者（02-1，CRITICAL）** — `agents/op-implementer.md:3,4,50-57,65-69`：多处指示 FAIL 轮在 review.md 追加 Fix-N。design §1.1/§2.4/§3.4 明确 review.md 单写者=leader。**修复**：删所有写 review.md 指示，FAIL 轮修复记录统一追加 report.md Round-N 段。

**A2. implementer/reviewer 自行 jq 读 tasks_list 违反隔离（02-2，CRITICAL）** — `op-implementer.md:40`、`op-reviewer.md:63`：design §1.1/§2.4/§3.4 明确 tasks_list.json 不挂 subagent worktree，应由 dispatch 注入。**修复**：删 jq 步骤，改"从 dispatch prompt / review-package 读注入的 workset"。

**A3. op_close_post 传中文"完成"致状态机死锁（04-P0-1 + 05-H_h1，CRITICAL）** — `skills/oplrun/scripts/op_close_post.sh:55` + heavy 副本 `oprun/scripts/op_close_post.sh:54` + `op_close_pre.sh:18`（传"收口中"）：`op_status "$TID" 完成`，枚举只认 ASCII `done`，die 触发，归档中断，task 永卡 reviewing。**修复**：所有脚本内 op_status 调用改 ASCII（done/closing），全仓 grep 中文状态串。

**A4. oplintake 示例写中文 status（04-P0-2，CRITICAL）** — `skills/oplintake/SKILL.md:83-88`：`"status": "待开始"`，op_jq pending 查 ready 永不命中，循环空转。**修复**：示例改 ready，顶部补"机读 ready"。

**A5. commit-msg 与 op_trailer_unlock HMAC 输入不一致（05-H1，CRITICAL）** — `hooks/git/commit-msg:49` vs `scripts/op_trailer_unlock.sh:49`：e2e_paths 末尾换行不同（printf '%s' vs '%s\n'），HMAC 必不匹配，合法 e2e 提交永远被阻。**修复**：两侧统一 `printf '%s\n' "$e2e_paths" | sort | tr '\n' ':'`；删 commit-msg 死代码 grep；提取共享函数防漂移；加 bats 端到端自测。

**A6. uninstall 漏 ~/.claude/scripts/omni_powers/（05-H5）** — `uninstall.sh:68-93`：install 装共享 scripts（D5），uninstall 没反向删，11 个脚本残留。**修复**：remove_global 追加 `del "$CLAUDE_HOME/scripts/omni_powers"`。

**A7. op_closer_gate 全工作区扫描（05-H7）** — 见 Q5（按你选 A/B 实现）。

### B. 状态机 ASCII 全链路同步（上轮 D1/A16/A20 漏改处）

design 状态枚举已 ASCII（pending/ready/in_progress/reviewing/closing/done/suspended/blocked/obsolete，删 skipped）。漏改处：

**B1. RULES.md 状态表中文 + 跳过态（01-P5/P15）** — `RULES.md:18-39,49-54,90-99`：状态图/表用中文机读值，含已删的"跳过"，缺 obsolete，blocked_by 多 resource/spawn（design 仅 quality）。**修复**：RULES 状态图/表统一 ASCII，删跳过，加 obsolete，blocked_by 收敛 quality。

**B2. heavy skill 内部中文状态调用（03-1）** — `op_checkpoint.sh:31-36`、`op_close_pre.sh:12`、`op_close_post.sh:54`、`opstatus/SKILL.md` 渲染段、`optriage/SKILL.md:76`、`opintake/SKILL.md` 示例：脚本 jq 比较/op_status 调用/intake 示例全用中文。**修复**：全改 ASCII，opstatus 作唯一中文渲染层。

**B3. op_jq pending 命名误导（04-P3-1）** — `op_jq.sh:14-18`：pending 查 status=ready，与 status=pending（待规划）撞名。**修复**：改 runnable/ready 或保留别名强注释。

### C. A18 事后报告同步（漏改处）

design A18 已改（闸门 C 从事中批量审 → leader 自审 + 事后报告，P0 不事中阻断）。漏改：

**C1. optriage P0 阻断闸门 C（03-3）** — `optriage/SKILL.md:54-61,109-112`：仍写"P0 默认阻断闸门 C，本 spec 收尾前必修"。**修复**：改 P0/P1 复核标注 + 进结束报告 blocks_merge 语义 + 处置选项，不事中阻断。

**C2. op_check_p0 语义反转（04-P1-1）** — 见 Q4。

**C3. reviewer 写 review.md + 直写 issues 赋 P（02-5）** — `op-reviewer.md:3,19-21,61-68,24`：仍列写 review.md，line 24"写 issue 直接赋 P 级"。design §2.4 reviewer 无 checkout 不直写，verdict 末行由 leader 落盘；§3.2 issue 由 leader/optriage 赋 P。**修复**：reviewer 只返回末行 verdict 文本；范围外发现写返回文本暂存段，leader 收口落盘赋 P。

**C4. opred spec 变更仍写"人批"（03-10）** — `opred/SKILL.md:28-36,50-58`：归因(c)写"agent 提 delta → 人批 → 重新 commit → 受影响 task 失效重拆"。design §2.4 执行期 spec-delta 由 leader 自主记录改 spec + 更新 tasks_list + 同 TID 重跑。**修复**：改"发现者提 delta → leader 记录 + 改 spec + 更新 tasks_list → 同 TID 重跑；事后报告呈现"。

**C5. test op_check_p0.bats 固化事中阻断（06-T4）** — `tests/scripts/op_check_p0.bats:30-38`：断言 open P0 时 exit 1（A18 反向）。**修复**：改 exit 0 + 输出 P0 清单汇总语义；补"open P0 + 仍允许归档"用例（依 Q4 定）。

**C6. test opinit_register_hooks.bats 断言 SessionStart（06-T3）** — `tests/scripts/opinit_register_hooks.bats:33`：A17 已删 SessionStart，测试仍 jq .hooks.SessionStart。**修复**：删断言，改验 PreToolUse/PostToolUse/SubagentStop 三者。

### D. D6 lite 验收前置同步（漏改处）

design D6 已改（oplrun 3.5 裸评前置 / 3.6 commit 后置）。漏改：

**D1. op_close_post 未校验 evaluator PASS（04-P2-2）** — `oplrun/scripts/op_close_post.sh:32-40`：只校验 review verdict，不校验 acceptance/{TID}/eval.md 末行 PASS。leader 误跳 evaluator 仍归档。**修复**：close_post 校验 eval.md 最新 verdict PASS；非行为型 task 用 eval:skip 显式豁免。

**D2. op_close_post 不归档 spec/acceptance（03-4 + 04-P1-3）** — `oprun/scripts/op_close_post.sh:70-73` + lite 副本：design §2.6 要求三类归档（task 目录 + spec 原文 + acceptance），脚本只 git mv task 目录。**修复**：补 `git mv specs/{TID}_*.md op_record/specs/` + `git mv acceptance/{TID} op_record/acceptance/{TID}`；close_check 扩查归档完整性 + tasks_list .status=="done"。

**D3. 缺 dispatch 锚点 sha + spec 写保护机械校验（04-P1-2）** — `oplrun/SKILL.md:70-118,125-134,176-184`：dispatch reviewer 用裸 git diff（对 HEAD），implementer 自行 commit → diff 空。design §5.9/A19 要求锚点 sha。**修复**：3.2 记 DISPATCH_SHA=$(git rev-parse HEAD)；3.4 用 git diff $DISPATCH_SHA（新增文件先 git add -N）；3.6 收口前 git diff --quiet $DISPATCH_SHA -- specs/ 非零走变更子流程。

### E. 模板字段同步（上轮 D9/D10/D13/D7/A16 漏改处）

**E1. tasks_list 模板 spec 字段（01-P1）+ type 字段（01-P2）+ eval 补齐（01-P3）** — `docs_template/.../tasks_list.json`：spec 填 TID 非路径（依 Q7 定）；type:"实现" 未定义（删）；T0002/T0003 缺 eval/eval_reason（补）。**修复**：依 Q7 改 spec；删 type；所有示例 task 补 eval/eval_reason。

**E2. README 模板 TID 两位（01-P4）** — `docs_template/.../README.md:38-39`：T05→T0001（四位强制）。

**E3. report.md 模板"hook 自动跑测试"（01-P6）** — `docs_template/.../tasks/{TID}/report.md:17-18`：subagent 不触发 hook（A21），自动测试结果不存在。**修复**：改"贴实现者自跑测试命令与关键输出"。

**E4. index/README"已归档含 brief"（01-P10）** — `docs_template/.../index.md:44-46`：design §1.1 无 brief。**修复**：改"report/review"。

**E5. baselines_index/test 模板 DOM 列硬门（01-P11）** — `docs_template/.../baselines/baselines_index.md:13-21` + `test.md:14-20`：design D7 DOM 降 advisory。**修复**：模板注释移 DOM/a11y 到 advisory 行。

**E6. decisions.md 模板缺幂等标识（01-P12）** — `docs_template/.../op_record/decisions.md:5`：design §2.6 要求 `[来源|TID|Round-N|日期]`。**修复**：补来源标记前缀占位。

**E7. 模板未标 lite blueprint 空壳（01-P14）** — index/README/baselines_index：lite 不读 blueprint。**修复**：blueprint 章节加"heavy only；lite 空壳不读"。

**E8. RULES 完成态缺验收前置（01-P16）** — `RULES.md:34`：design §2.4/§2.6 验收 PASS 是完成前置。**修复**：补"+ evaluator 验收 PASS"。

### F. agent 措辞同步（漏改处）

**F1. closer 自判 feature_key（02-3）** — `op-closer.md:57,118-123`：design D10 feature_key 闸门 A 定入 frontmatter，closer 只引用。**修复**：改"从 task spec frontmatter feature_key 读；缺失回报 leader 不自判"。

**F2. evaluator DOM 列硬门（02-4）** — `op-evaluator.md:124-127`：design D7 降 advisory。**修复**：DOM/a11y 移出硬门主体，归 advisory。

**F3. evaluator"落 issues"措辞（02-6）** — `op-evaluator.md:116-118,172-174,200`：可能诱导直写 issues/。**修复**：改"写入 acceptance_report.md 范围外段（草稿），leader 收口落盘赋 P"。

**F4. closer decisions 缺 Round-N（02-7）** — `op-closer.md:44-46`：design §2.6 要求 [来源|TID|Round-N|日期]。**修复**：补 Round-N。

**F5. closer 硬编码 $OP_HOME 缺 heavy-only（02-8）** — `op-closer.md:7-8`：closer heavy 独有。**修复**：顶部加"heavy 独有，lite 不派；OP_PROFILE=lite 立即 FATAL"。

### G. skill 内部同步（漏改处）

**G1. opspec frontmatter 超定义 + 失败模式过严 + DOM（03-6）** — `opspec/SKILL.md:41-93`：status 写 draft→approved→in_progress→done/cancelled（design §1.2 仅 draft|approved）；预期失败模式强制（D13 改 best-effort）；DOM 列结构化优先（D7 降 advisory）；缺 feature/eval 锚点。**修复**：frontmatter 仅 draft→approved；反例改 best-effort；DOM 改 advisory；补 feature/eval。

**G2. op_assemble_eval_brief 未剥探索结论（03-5 + 04-P2-1）** — `oprun/scripts/op_assemble_eval_brief.sh:33-36` + lite 副本：直接 cat 全 spec，违反 design §2.5"剥探索结论"。**修复**：cat 前 sed/awk 删"### 设计探索结论"子段；按 feature 锚点纳入生效规格；无法定位输出 INSUFFICIENT_BASELINE。

**G3. opinit_skeleton 固定建 e2e/ 未探测（03-7）** — `opinit/scripts/opinit_skeleton.sh:25-32`：design §1 规定探测既有 e2e/。**修复**：建前 [ -d e2e ] 探测，存在 die 让 leader 问；建空 config 占位（依 Q1/D4-B）。

**G4. opstatus lite 寻址不一致（03-8）** — `opstatus/SKILL.md:13,28-57`：声明用 $SCRIPTS，步骤 2 仍写 $OP_HOME（lite 无）。**修复**：命令改 [ "$OP_PROFILE" = "lite" ] 选 SCRIPTS；补 suspended 渲染、issues 扫描、TID 四位。

**G5. opinit 章节引用错误 + hook 注册不全（03-11）** — `opinit/SKILL.md:73,101-109`：引 §3.3 应 §1.3；步骤五漏 git hooks 注册（pre-commit + commit-msg）。**修复**：改 §1.3；补 git hooks 注册 + "更新 hook 后重跑 /opinit 同步"。

**G6. RULES compact 硬编码 $OP_HOME（01-P8）** — `RULES.md:88-99,120-140`：lite 无 $OP_HOME。**修复**：改 ${OP_SCRIPT_ROOT:-$OP_HOME} fallback；compact 恢复先读 profile。

**G7. leader_checkpoint 模板 heavy 专用路径（01-P9）** — `docs_template/.../leader_checkpoint.md:3-4`：lite 无 $OP_HOME。**修复**：profile 分叉或 fallback。

### H. 测试同步（fixture/断言过时）

**H1. fixture 中文状态（06-T1，P0）** — `tests/scripts/helpers.bash:21-24` + 各 bats：脚本已 ASCII，fixture 仍中文，55 用例 10 FAIL。**修复**：helpers fixture 改 ASCII；bats 用例全 ASCII；复查脚本内残留中文调用。

**H2. op_ci_local.bats 测已删脚本（06-T2）** — `tests/scripts/op_ci_local.bats:6`：op_ci_local.sh 709afb3 已删。**修复**：删测试文件或 skip "P3 未落地"。

**H3. helpers fixture 含废弃字段（06-T5）** — `helpers.bash:22-24`：type/covers_ac/touches_inv/risk_probe（§2.3 已删），缺 eval/eval_reason。**修复**：对齐 schema。

**H4. lite profile 测试缺失（06-T6）** — close_check/op_check_env/op_close_post/op_status/op_worktree_setup 缺 lite 分支测试。**修复**：每 profile-aware 脚本加 heavy/lite/unknown 三组；新增 oplinit_skeleton.bats。

**H5. worktree 测试未覆盖关键路径（06-T9）** — `op_worktree_setup.bats:17-43`：未测 specs/acceptance/tasks_list/review.md 挂载。**修复**：扩展 fixture。

**H6. trailer 测试未覆盖 sha 重放（06-T10）** — `op_trailer_unlock.bats:63-73`：未测同 trailer 不同 commit 被拒。**修复**：构造两 HEAD sha 验证。

**H7. tests/README 覆盖表不同步（06-T11）** — `tests/README.md:28-43`：列 10 项实际 16 bats。**修复**：按能力矩阵重组。

---

## 不采纳项（5 项，简列）

- **N1. evaluator 输出示例 emoji（02-current LOW-9）** — 上轮 N2 已决定保留 emoji（状态标记视觉辨识），一致适用。
- **N2. 部分 design 节号漂移（01-P13）** — LOW，节号在合并后重排是正常的文档演进，逐处刷新成本高于收益；design 自身是真相源，引用失效时读者自查。可选 LOW 顺手改。
- **N3. hook 测试断言 subagent deny（06-T8）** — 测试验证 advisory 行为（hook 对 subagent 场景的预期），非 bug；加"主会话/advisory"边界注释即可（并入 H 系列顺手），不改测试逻辑。
- **N4. op_first_run.md 归档（01-P7）** — 可采纳归档（移 docs/archive/ + 加废弃头），但这是文档整理非功能，优先级 LOW，可顺手或留。
- **N5. 单模型独特 LOW（命名/注释偏好）** — 如 op_coder_check 注释轮次歧义、PLUGIN_ROOT vs OP_HOME_DIR 命名、progress.md 字段扩展等，属风格/改进建议，无对错，收益低于改动成本。

---

## 执行建议

- **CRITICAL（A1-A5）+ 状态机同步（B1-B3）** 是阻断性 bug + 状态机地基，应首批修（lite 当前闭环必崩——A3/A4 中文状态致死锁）。
- **A18/D6 同步（C/D 系列）** 是上轮架构改动的代码落地欠债，第二批。
- **模板/agent/skill 同步（E/F/G）** 第三批（文档级，量大但风险低）。
- **测试同步（H）** 第四批（随代码改同步更新 fixture/断言）。
- **待决定项（Q1-Q9）** 定了再并入相应批次。

注：本轮审阅在 docs/review_*/（.gitignore 已忽略，不入库）。决策文档同样不入库，作为执行依据。
