# tests 分块审阅报告（haiku 视角）

> 模型：default_haiku[1m]（用户授权多模型审阅）
> 核心参考：docs/omni_powers_design.md
> 审阅范围：tests/README.md + tests/scripts/ 下 16 个文件 + helpers.bash
> 方法：全量通读 + 实跑 bats 验证（`bats tests/scripts/` 全量）+ 对照被测脚本源码
> 实跑结果：55 测试中 10 FAIL（op_status 4、op_close_post 1、op_ci_local 3、opinit_register_hooks 1、close_check 1）

---

## 摘要

测试套件整体结构与 design 能力矩阵的对应关系清晰，覆盖了 P0/P1 修复点（verdict 校验、TID 精确匹配、幂等、blocked_by 强校验、spec 写保护、worktree 隔离、trailer 自锁、mutation 骨架）。但存在一类贯穿性问题：**测试 fixture（helpers.bash）与多个测试用例仍使用中文状态枚举与已废弃的 task schema 字段，而脚本已迁移到 design §1.1 规定的 ASCII 机读值**，导致实测大面积红。另有 1 个测试测了不存在的脚本（op_ci_local.sh）、1 个测试断言了已移除的 hook 事件（SessionStart，A17/D8 去除）。这两类属"测试与实现/design 同步失败"，意味着套件目前无法作为可信回归门。

---

## 问题清单

### P1-TEST-01 helpers.bash fixture 与 op_status.bash 全面使用中文状态值，与脚本 ASCII 契约冲突（套件大面积红）

- 位置：tests/scripts/helpers.bash:23（tasks_list.json fixture）、tests/scripts/op_status.bats:7-44、tests/scripts/op_close_post.bats:15（经 op_status.sh 间接）、tests/scripts/close_check.bats:7
- 现象：
  - helpers.bash:23 写 `"status":"收口中"`，fixture 里 task 状态用中文
  - op_status.bats 全部用例传中文：`op_status.sh T01 阻塞`、`op_status.sh T01 完成`、`op_status.sh T01 无效状态`
  - op_close_post.sh 内部调 `op_status.sh "$TID" 完成`（skills/oprun/scripts/op_close_post.sh 倒数第 3 段），中文"完成"传入
  - 对照 scripts/op_status.sh:8-9 注释明确：「status 有效值（ASCII 机读）: pending ready in_progress reviewing closing done suspended blocked obsolete」；case 分支只接受这 9 个 ASCII 值，其余一律 `die "无效 status"`
- 实测：op_status.bats 5 测试中 4 FAIL；op_close_post.bats「verdict PASS 归档」FAIL（错误链：`op_close_post` → `op_status.sh T01 完成` → die「无效 status: 完成」）；close_check.bats「归档后通过」FAIL（同链路）
- 影响：
  1. design §1.1 明确要求「status（机读 ASCII）」「脚本/agent 不得自创状态串；脚本内 jq/grep 比较一律用左列 ASCII 值」，理由是跨平台 locale 无关、Windows Git Bash/PowerShell 下稳定。测试与 helpers 恰恰违反这一硬约束。
  2. 套件无法通过 CI，丧失回归门价值——任何改动都无法靠这套测试判红绿。
  3. op_close_post.sh 本身也用中文"完成"调 op_status.sh，说明脚本侧也存在中英混用遗留，不只是测试问题。
- 建议：
  1. helpers.bash fixture 的 task status 改 ASCII（`"status":"closing"` 或 `"status":"reviewing"`——收口前态）
  2. op_status.bats 全部用例改 ASCII：`blocked`、`done`、以及"无效 status"用例用一个既非 ASCII 也非中文的串（如 `garbage`）
  3. op_close_post.sh 内部 `op_status.sh "$TID" 完成` 改为 `op_status.sh "$TID" done`；同时复查所有脚本内对状态的中文引用（grep `完成\|阻塞\|挂起\|待开始\|待规划\|收口中\|跳过` scripts/ skills/*/scripts/）
  4. op_checkpoint.sh 内的 jq 查询也用中文（`select(.status == "完成")` 等），与 op_status.sh 的 ASCII 契约矛盾，需一并迁移到 ASCII
- 置信度：高（实跑复现 + 源码直证）
- 优先级：P1（阻断 CI，design 硬约束违反）

---

### P1-TEST-02 op_ci_local.bats 测了不存在的脚本（exit 127）

- 位置：tests/scripts/op_ci_local.bats:6（`SCRIPT="$REPO/scripts/op_ci_local.sh"`）、:22-49 三个用例
- 现象：`scripts/op_ci_local.sh` 在仓库中不存在（`ls scripts/op_ci_local.sh` → No such file）。bats 实跑 BW01 警告：`exited with code 127, indicating 'Command not found'`，三用例全 FAIL。
- 设计依据：测试注释引用「design §3.3.1 三接口」，但 design §3.3 第 6 层「定期体检」标注为 **P3 交付，当前不可用**；design §0.2 能力矩阵里「系统层夜跑回归」是 P2+/P3。即该脚本属规划中未落地工件，测试却当成已存在来测。
- 影响：测试套件包含无法通过的用例，误导维护者以为脚本应存在；若 CI 跑 bats，永远红。
- 建议：二选一——
  1. 若 op_ci_local.sh 是计划内 P3 工件：移除该 .bats 文件或 `skip "P3 未落地"`，待脚本落地再启用
  2. 若脚本已被废弃/改名：删除测试，更新 tests/README.md 的测试范围表（当前表未列 op_ci_local，但文件在）
- 置信度：高（文件系统直证）
- 优先级：P1（死测试污染套件）

---

### P1-TEST-03 opinit_register_hooks.bats 断言 SessionStart 事件，但该 hook 已移除（A17/D8）

- 位置：tests/scripts/opinit_register_hooks.bats:33（`jq -e '.hooks.SessionStart'`）
- 现象：hooks/settings.template.json 只含 PreToolUse / PostToolUse / SubagentStop 三个事件，无 SessionStart。design §5.3 D8 明确「lite 无自动发现：新会话/compact 后无 SessionStart 注入（A17 已去）」；oprun/SKILL.md:84「原 SessionStart hook 已移除，此复查是其职责落点」（挪入 /oprun 启动按需触发）。实跑该用例 FAIL。
- 影响：测试断言与当前架构（SessionStart 职责挪入 /oprun 启动流）相反；永远红。
- 建议：删除该断言行，或改为断言 PreToolUse/PostToolUse/SubagentStop 三者存在（对齐 settings.template.json 实际内容）。
- 置信度：高
- 优先级：P1

---

### P2-TEST-04 helpers.bash fixture 的 task schema 用了 design 已废弃的字段

- 位置：tests/scripts/helpers.bash:23
- 现象：fixture JSON 含 `"spec":"b01"`（design §2.3 规定 spec 指向 `specs/{TID}_{slug}.md`）、`"type":"实现"`、`"covers_ac":["AC-1"]`、`"touches_inv":[]`、`"risk_probe":false`。对照 design §2.3「task 元数据」明确：
  - 「无 covers_ac/touches_inv——task:spec 1:1，spec 的验收标准/不变量全是这 task 的，不另引用编号」
  - 「无'完成定义'——即 spec 的验收场景，不重复」
  - 字段集应为 `id/title/status/spec/depends_on/workset` + `eval`/`eval_reason`（D9）
- 影响：
  1. fixture 不符合 design schema，测试通过不代表真实 tasks_list.json 能被脚本正确处理
  2. 新脚本若依赖 `eval`/`eval_reason` 字段做免派判定（design §2.4），现有 fixture 无法覆盖
  3. 误导后续维护者以为 covers_ac/type/risk_probe 是合法字段
- 建议：fixture 对齐 design §2.3 schema，最小有效形态：`{"id":"T01","title":"test task","status":"reviewing","spec":"specs/T01_test.md","depends_on":null,"workset":["src/x.ts"],"eval":"required","eval_reason":""}`
- 置信度：高
- 优先级：P2（不阻断当前用例，但 fixture 失真）

---

### P2-TEST-05 op_status.bats 缺少 design §1.1 完整状态枚举的覆盖

- 位置：tests/scripts/op_status.bats（全文）
- 现象：design §1.1 定义 9 个 ASCII 状态（pending/ready/in_progress/reviewing/closing/done/suspended/blocked/obsolete），测试只覆盖 blocked 的强校验 + done 的清 blocked_by + "无效 status"。未覆盖：
  - `obsolete`（废弃态，design §1.2 有独立处置：spec 移 obsolete/，tasks_list 保留）
  - `suspended`（挂起）
  - `--batch` 批量模式（op_status.sh 实现了，测试零覆盖）
  - 非 blocked 态传 blocked_by 是否被忽略/拒绝（脚本逻辑：非 blocked 态强制 blocked_by=null）
- 影响：状态机是全系统枢纽，枚举覆盖不足→状态流转回归风险。
- 建议：补用例覆盖每个合法状态流转 + --batch + obsolete 的 spec 归档联动（若归档逻辑在脚本侧）。
- 置信度：中（覆盖度判断）
- 优先级：P2

---

### P2-TEST-06 worktree 测试未覆盖 design §2.5 evaluator 隔离的 decisions.md 排除声明

- 位置：tests/scripts/op_worktree_setup.bats:36-43（eval worktree 用例）
- 现象：测试断言 `[ ! -d ".claude/wt/src" ]`、`[ -d ".claude/wt/e2e" ]`、`[ ! -d ".claude/wt/docs/omni_powers/op_execution/tasks" ]`、`[ ! -f ".claude/wt/docs/omni_powers/op_record/decisions.md" ]`。对照 design §0.2 能力矩阵「evaluator src 排除：sparse-checkout 无 src/**+task 目录+decisions.md」，测试覆盖了 src/tasks/decisions 三项排除——这部分是对的。
  但 design §2.5 还要求 evaluator 排除 `op_execution/tasks/**`（活跃 task）+ `op_record/tasks/**`（归档 task），测试只验了 `op_execution/tasks`（活跃），未验 `op_record/tasks`（归档 task 目录）。setup 里建了 `docs/omni_powers/op_record` 但只放了 decisions.md，没放归档 task。
- 影响：若 op_worktree_setup.sh eval 模式漏排归档 task 目录，evaluator 仍能读到历史 task 的 report/review（含实现细节），削弱隔离。advisory 级，但 design 明确要求。
- 建议：setup 里补建 `docs/omni_powers/op_record/tasks/T00_old/report.md`，eval 用例加断言 `[ ! -d ".claude/wt/docs/omni_powers/op_record/tasks" ]`。
- 置信度：中
- 优先级：P2

---

### P2-TEST-07 trailer_unlock 测试未覆盖 design §2.5 的 trailer 绑定 commit-sha 防重放

- 位置：tests/scripts/op_trailer_unlock.bats:63-73（staged 变了 trailer 失效用例）
- 现象：design §2.5「trailer 由解锁脚本一次性生成、绑定 commit-sha 防重放；解锁脚本输出不进 agent 可读文件；校验不依赖 agent 可写状态」。测试覆盖了"staged 清单变化致 trailer 失效"，但未覆盖：
  - 同一 trailer 被重放（第二次 commit 复用）是否被拒
  - trailer 是否真的绑定 sha（而非仅绑定 staged 清单 hash）
- 影响：防重放是 design 明示的安全属性，测试只验了"清单变化"，未验"sha 绑定"。若实现改为纯清单 hash（无 sha），测试照过但安全模型弱化。
- 建议：读 op_trailer_unlock.sh 源码确认 trailer 构造含 sha，补用例：生成 trailer → commit A 成功 → 新 e2e 文件 + 重用旧 trailer commit B 应被拒。
- 置信度：中（需看脚本实现确认构造方式）
- 优先级：P2

---

### P3-TEST-08 tests/README.md 测试范围表与实际文件不同步

- 位置：tests/README.md:31-41（测试范围表）
- 现象：表列 10 个测试文件，但 tests/scripts/ 实际有 16 个 .bats（缺 op_check_p0 / op_ci_local / op_mutation_check / op_trailer_unlock / op_worktree_setup / op_read_verdict 的部分条目）。op_ci_local 在表里完全没列，op_trailer_unlock / op_worktree_setup / op_mutation_check 也未列。
- 影响：维护者按 README 理解覆盖范围会漏判。
- 建议：补全表格，每行对应一个 .bats，覆盖说明对齐 design 章节。
- 置信度：高
- 优先级：P3

---

### P3-TEST-09 op_mutation_check 测试 KILLED 判定基于 stdout 含 "pass"，与真实断言强度不符

- 位置：tests/scripts/op_mutation_check.bats:16-32（KILLED 用例）
- 现象：test.sh 里 `if eq a a; then echo pass; else echo fail; exit 1; fi`——"覆盖"判定靠 test.sh 退出码 + 输出含 pass。但变异（== ↔ !=）后 `eq a a` 变 `[ "a" != "a" ]` 返回假，走 else 分支 exit 1，测试脚本判 KILLED。逻辑成立。
  但 ESCAPE 用例（:34-51）的 test.sh 只调 `unused` 从不调 `eq`，变异后 test.sh 行为不变（仍 exit 0），判 ESCAPE——这也成立。
  风险点：design §3.3 第 6 层称「骨架 op_mutation_check.sh 做 == ↔ != 变异自检」，测试验证了基本机制，但未覆盖：
  - 多个 == 运算符部分覆盖（只 kill 一个）
  - 变异后测试仍 pass 的误判（如测试本身有 .skip 或恒真断言）
- 影响：骨架可信度边界未探，但 design 已声明这是骨架、专业工具用 mutmut/stryker，属已知限制。
- 置信度：中
- 优先级：P3（design 已声明骨架定位）

---

### P3-TEST-10 close_check.bats 用例 1 间接依赖 op_close_post（经 op_status 中文问题），独立可测性差

- 位置：tests/scripts/close_check.bats:5-12
- 现象：用例 1 先跑 op_close_post.sh（归档 + 调 op_status）再跑 close_check，归档步骤因 P1-TEST-01 中文状态问题失败，close_check 本身逻辑未被独立验证。用例 2（未归档不通过）独立可过。
- 影响：close_check 的"归档后通过"路径无法独立测试，耦合了 op_close_post 的状态。
- 建议：用例 1 改为手动构造归档态（mkdir op_record/tasks/T01 + 放 report/review + checkpoint 写 T01 行），不依赖 op_close_post，解耦验证 close_check 自身逻辑。
- 置信度：高
- 优先级：P3（待 P1-TEST-01 修复后此问题部分缓解，但耦合本身是设计缺陷）

---

## 覆盖度评估（对照 design 能力矩阵）

| design 防线/能力 | 测试覆盖 | 评价 |
|---|---|---|
| implementer e2e 排除（worktree dev） | op_worktree_setup.bats:29-34 | 充分 |
| evaluator src/tasks/decisions 排除 | op_worktree_setup.bats:36-43 | 基本充分（归档 task 目录未验，P2-TEST-06） |
| merge gate（白名单零 diff） | **未覆盖** | op_merge_gate.sh 无对应 .bats，P1 级防线无测试 |
| e2e/BUG-* 合法写入通道（trailer 自锁） | op_trailer_unlock.bats | 基本充分（sha 防重放未验，P2-TEST-07） |
| spec 写保护 | pre_tool_use.bats:13-22 + op_trailer_unlock.bats:55-61 | 充分（主会话 + git pre-commit 双路径） |
| reviewer 双裁决 | op_read_verdict.bats + op_close_post.bats verdict 校验 | 充分（轮次 + 末行 + exit code） |
| SubagentStop 完成门禁 | **未覆盖** | hooks/stop.sh 无对应 .bats |
| closer gate（机械校验） | **未覆盖** | op_closer_gate.sh 无对应 .bats（design §0.2 标注已落地 D3） |
| lite P0 处置 | op_check_p0.bats | 充分 |
| 变异测试骨架 | op_mutation_check.bats | 基本充分（骨架定位） |
| checkpoint 幂等 + TID 锚定 | op_checkpoint.bats | 充分 |
| opinit 骨架 + hook 注册 + profile 互斥 | opinit_*.bats | 充分（除 SessionStart 断言过时） |

**关键缺口**：merge gate（design §3.4 写入硬底线）、closer gate（D3 已落地）、SubagentStop——三项 P1 级防线零测试覆盖。merge gate 是「写入硬底线所在」（design §3.4 原文），无测试意味着白名单逻辑回归无任何门禁。

---

## 总结

测试套件方向正确（锁 P0/P1 修复、覆盖关键脚本），但当前状态**不可作为可信回归门**：10/55 实测红，根因是测试侧（中文状态）与脚本侧（ASCII 迁移）的同步断裂，外加测了不存在的脚本和已移除的 hook。修复优先级：
1. P1-TEST-01/02/03 三项（状态枚举同步 + 删死测试 + 删过时断言）→ 让套件全绿
2. 补 merge gate / closer gate / SubagentStop 三项 P1 防线测试
3. P2 fixture 对齐 design schema + 状态枚举全覆盖

修完后套件方能承担 design §0.2 能力矩阵的回归守护职责。
