## 当前模型判断依据

可观测来源：`/home/karon/.claude/settings.json` 顶层 `model=haiku`；`env.ANTHROPIC_MODEL=default_model`；`ANTHROPIC_DEFAULT_HAIKU_MODEL=default_haiku[1m]`；`ANTHROPIC_DEFAULT_SONNET_MODEL=default_sonnet[1m]`；`ANTHROPIC_DEFAULT_OPUS_MODEL=default_opus[1m]`；主会话环境提示当前由 `default_model` 驱动。不能读取运行时内部状态；current 路继承主会话。

## 审阅范围

本轮完整阅读上下文设计档：

- `/home/karon/karson_ubuntu/omni_powers/docs/omni_powers_design.md`

本轮逐文件、逐段、逐脚本函数审阅以下文件，排除 `vendors/` 与 `docs/archive/`：

- `/home/karon/karson_ubuntu/omni_powers/skills/oprun/SKILL.md`
- `/home/karon/karson_ubuntu/omni_powers/skills/oprun/scripts/close_check.sh`
- `/home/karon/karson_ubuntu/omni_powers/skills/oprun/scripts/op_assemble_eval_brief.sh`
- `/home/karon/karson_ubuntu/omni_powers/skills/oprun/scripts/op_checkpoint.sh`
- `/home/karon/karson_ubuntu/omni_powers/skills/oprun/scripts/op_close_post.sh`
- `/home/karon/karson_ubuntu/omni_powers/skills/oprun/scripts/op_close_pre.sh`
- `/home/karon/karson_ubuntu/omni_powers/skills/oprun/scripts/op_coder_check.sh`
- `/home/karon/karson_ubuntu/omni_powers/skills/oprun/scripts/op_read_verdict.sh`

限制遵守：只读源文件；未跑构建；未跑测试；未联网；未使用 TaskCreate/TaskUpdate/TaskList/TaskGet；仅写入本报告文件。

## 高优先级问题（CRITICAL / HIGH）

### 1. `SKILL.md` 主流程图仍把 merge 放在 evaluator 验收之前

- 位置：`/home/karon/karson_ubuntu/omni_powers/skills/oprun/SKILL.md:100-107`、`/home/karon/karson_ubuntu/omni_powers/skills/oprun/SKILL.md:183-188`
- 现象：循环图写成「双裁决 PASS → merge gate + squash-merge → per-task 验收」，且判定表中 PASS 动作写「收口（3.5）」。后文 `3.5` 与设计档要求又写「双裁决 PASS 后、squash-merge 前派 op-evaluator」。同一文档内执行顺序自相矛盾。
- 影响：leader 按流程图执行时，可能把未经 evaluator hard-pass gate 验收的 task 先合入主分支。该风险直接破坏设计档 §2.4/§2.5 的「merge 前验」安全边界。
- 建议：统一主流程图、判定表、章节编号：`review PASS → evaluator 验收 → merge gate → squash-merge → closer → leader 自审归档`。删除所有「merge 后验收」残留表达。
- 置信度：高
- 优先级：HIGH

### 2. `SKILL.md` 仍要求 implementer/reviewer 自行读取或写入本应由 leader 单写/注入的流程文件

- 位置：`/home/karon/karson_ubuntu/omni_powers/skills/oprun/SKILL.md:127-140`、`/home/karon/karson_ubuntu/omni_powers/skills/oprun/SKILL.md:168-172`
- 现象：implementer prompt 写「jq 查 tasks_list.json 取 workset/depends_on」；reviewer prompt 写「输出：tasks/{TID}/review.md」。设计档 §2.4/§3.4 明确：`tasks_list.json` 不挂给 subagent，workset/depends_on 由 dispatch 脚本提取注入；`review.md` 单写者是 leader，reviewer 只在返回文本末行给 verdict。
- 影响：破坏单写者与流程文件单副本模型。implementer 可直接读全局 tasks_list，reviewer 可直接写 review.md，merge gate 关于「task 分支不许碰 review.md」与「主分支 review.md 末行 verdict」的信任前提被削弱。
- 建议：改为 leader/脚本先生成 review-package 与 dispatch metadata；implementer prompt 只接收已提取字段，不指示 jq 读 tasks_list；reviewer prompt 改为「返回文本末行 `verdict: PASS|FAIL`，leader 落盘 review.md」。
- 置信度：高
- 优先级：HIGH

### 3. `op_assemble_eval_brief.sh` 未真正剥离 spec 模板中的「设计探索结论」段

- 位置：`/home/karon/karson_ubuntu/omni_powers/skills/oprun/scripts/op_assemble_eval_brief.sh:33-37`
- 现象：脚本只匹配 `^## 设计探索结论`，但设计档 spec 模板中该段是 `### 设计探索结论：命中方案先行信号时`，位于 `## 技术决策` 下。当前 awk 不会剥掉该段。
- 影响：evaluator brief 会泄露方案探索结论、候选方案、已知坑等过程信息，违背设计档 §2.5「剥探索结论，防 evaluator 被过程带偏」的隔离目标，增加验收放水或按实现思路验收的风险。
- 建议：按实际模板处理三级标题。可在 `## 技术决策` 内仅保留「条件强制」与「可测性契约」，剔除 `### 设计探索结论` 直到下一个 `###` 或 `##`。同时增加覆盖 `### 设计探索结论：...` 变体。
- 置信度：高
- 优先级：HIGH

### 4. `op_assemble_eval_brief.sh` 未包含实际生效规格正文，只输出 `spec_index.md`

- 位置：`/home/karon/karson_ubuntu/omni_powers/skills/oprun/scripts/op_assemble_eval_brief.sh:39-46`
- 现象：脚本在「生效规格（开工前基线）」段只 `cat op_blueprint/spec_index.md`，没有解析 task 对应 feature，也没有读取 `op_blueprint/specs/{feature}.md` 正文。
- 影响：evaluator 缺少历史生效规格与开工前基线，只能基于工作 spec 和索引验收。跨功能不变量、既有行为约束、功能级规格可能被漏验，削弱设计档 §2.5 的访问隔离 brief 价值。
- 建议：从 task spec frontmatter 或 tasks_list 中读取 `feature_key`/feature，定位并追加对应 `op_blueprint/specs/{feature}.md`。若无法定位，应明确 FAIL 或输出 `INSUFFICIENT_EVIDENCE` 级别警告，而不是把索引当生效规格。
- 置信度：高
- 优先级：HIGH

### 5. `op_close_post.sh` 收口校验缺少 design 声明的关键前置条件

- 位置：`/home/karon/karson_ubuntu/omni_powers/skills/oprun/scripts/op_close_post.sh:31-48`、`/home/karon/karson_ubuntu/omni_powers/skills/oprun/SKILL.md:261-265`
- 现象：`SKILL.md` 注释宣称 `op_close_post.sh` 会检查「merge gate PASS + decisions.md 存在本 TID closer append 块且已 commit」，但脚本实际只检查 report/review 非空、review PASS、eval PASS 或 eval skip。
- 影响：即使 closer 没有追加 decisions、没有生成 `blueprint_update.md`、merge gate 没跑或没通过，脚本仍可能归档并把 task 标 done。Stage 4 的 closer 收尾与 leader 自审写入无法被机械保证。
- 建议：补齐检查：存在 `acceptance/{TID}/blueprint_update.md`；`op_record/decisions.md` 有本 TID closer/red-attribution 块或明确无归因标记；merge gate PASS 证据文件或 trailer 存在；必要的 op_blueprint/baselines 变更已应用或显式记录「无变更」。脚本文档与实际行为保持一致。
- 置信度：高
- 优先级：HIGH

### 6. `op_close_post.sh` 修改 checkpoint 但不 stage，随后 `op_checkpoint.sh` 又在 commit 后修改 checkpoint

- 位置：`/home/karon/karson_ubuntu/omni_powers/skills/oprun/scripts/op_close_post.sh:76-93`、`/home/karon/karson_ubuntu/omni_powers/skills/oprun/SKILL.md:261-270`、`/home/karon/karson_ubuntu/omni_powers/skills/oprun/scripts/op_checkpoint.sh:1-5`
- 现象：`op_close_post.sh` 清空 `leader_checkpoint.md` 的 `current_task`，但 `git add` 只包含 task 归档、progress、tasks_list，不包含 checkpoint。`SKILL.md` 又要求先 `git commit`，再跑 `op_checkpoint.sh` 写完成 task 与状态段，最后 `close_check.sh`。这会把 checkpoint 更新留在 commit 之后的未提交状态。
- 影响：checkpoint 作为 compact 恢复入口可能不随 task commit 入库。下次恢复时 current_task、已完成 task、tasks_list 状态段可能落后，导致重复执行、状态误判或 close_check 只 WARN 不阻断未提交 checkpoint。
- 建议：重新定义 checkpoint 提交流程。推荐：`op_close_post.sh` 不修改 checkpoint，或修改后必须 stage；`op_checkpoint.sh` 在 commit 前生成可提交内容；需要 commit hash 时可先用预期提交信息或拆成「归档 commit」与「checkpoint commit」两个明确提交。无论采用哪种，close_check 应确保 checkpoint 已提交或被纳入当前 commit。
- 置信度：高
- 优先级：HIGH

### 7. `op_close_post.sh` stage 边界过窄，可能遗漏 closer/leader 自审核心产物

- 位置：`/home/karon/karson_ubuntu/omni_powers/skills/oprun/scripts/op_close_post.sh:89-93`、`/home/karon/karson_ubuntu/omni_powers/skills/oprun/SKILL.md:253-270`
- 现象：脚本只 `git add op_record/tasks/{TID}`、`progress.md`、`tasks_list.json`。closer 追加的 `op_record/decisions.md`、转出的 `op_execution/issues/`、leader 采纳写入的 `op_blueprint/**`、baselines、checkpoint 等都不在 stage 清单中。
- 影响：leader 直接按 `SKILL.md` 执行 `git commit` 时，可能只提交归档和状态，不提交规格沉淀、决策记录、issue、baseline 等 Stage 4 核心成果。任务显示 done，但蓝图/决策资产缺失。
- 建议：`op_close_post.sh` 应要么只做归档不负责 stage，并让 `SKILL.md` 明确 leader 需审查后手动 stage 完整收口集；要么扩展 stage 白名单，覆盖本 task 允许的收口产物：`op_record/decisions.md`、`op_execution/issues/`、`op_record/acceptance/{TID}`、`op_record/specs/{TID}_*.md`、`op_blueprint/**`、`leader_checkpoint.md` 等，并配合 closer gate 防越界。
- 置信度：高
- 优先级：HIGH

### 8. `op_close_post.sh` 用 `git mv` 归档 acceptance，遇到 evaluator 新产出未跟踪文件时可能失败

- 位置：`/home/karon/karson_ubuntu/omni_powers/skills/oprun/scripts/op_close_post.sh:59-64`
- 现象：acceptance 工作区由 evaluator/brief 生成，包含 `eval_brief.md`、`eval.md`、baselines、issue 草稿等新文件。脚本直接 `git mv "$ACCEPT_SRC" "$ACCEPT_DST"`，但该目录内文件未必已被 git 跟踪。
- 影响：在常见路径中，未跟踪 acceptance 目录会导致 `git mv` 失败，收口归档中断；若部分文件已跟踪、部分未跟踪，也可能遗漏未跟踪验收证据。
- 建议：归档前显式处理未跟踪目录：使用普通 `mv` 后 `git add -A` 指定源/目标路径，或先 `git add -A "$ACCEPT_SRC"` 再 `git mv`。task/spec/acceptance 三类归档都应对「新文件未跟踪」有一致策略。
- 置信度：中高
- 优先级：HIGH

## 中低优先级问题（MEDIUM / LOW）

### 9. `close_check.sh` 未校验 tasks_list、progress、spec/acceptance 归档与活区清理

- 位置：`/home/karon/karson_ubuntu/omni_powers/skills/oprun/scripts/close_check.sh:21-50`
- 现象：close_check 只检查 checkpoint 是否含 TID、`op_record/tasks/{TID}/report.md`/`review.md` 是否非空、git status 是否有其它改动。未检查 tasks_list 中该 TID 是否为 `done`，未检查 `progress.md` 行，未检查 spec 是否从 execution 归档到 record，未检查 acceptance 是否归档，未检查活区 `op_execution/tasks/{TID}` 是否已清理。
- 影响：收口验收可能通过一个不完整归档。后续 task 继续执行时，状态与资产可能不一致。
- 建议：增加硬检查：tasks_list status=done；`progress.md` 有 TID；`op_record/specs/{TID}_*.md` 存在；如非 eval skip 则 `op_record/acceptance/{TID}` 存在；`op_execution/tasks/{TID}`、`op_execution/acceptance/{TID}`、`op_execution/specs/{TID}_*.md` 不再存在。
- 置信度：高
- 优先级：MEDIUM

### 10. `op_checkpoint.sh` 使用不存在于 schema 的 `blocked_by` 字段

- 位置：`/home/karon/karson_ubuntu/omni_powers/skills/oprun/scripts/op_checkpoint.sh:29-35`
- 现象：脚本生成状态 JSON 时选择 `{id, status, blocked_by}`，但设计档 task schema 使用 `depends_on`，状态机也说明下游阻塞依赖 `depends_on` 判定，不另设 blocked_by。
- 影响：checkpoint 中阻塞信息可能显示为 `T000X(null)` 或空，无法表达真实依赖/阻塞原因，降低 compact 恢复可读性。
- 建议：改为读取 `depends_on`；若需要质量阻塞原因，应读取 issue 或 tasks_list 中真实存在的 reason 字段，不要引用未定义字段。
- 置信度：高
- 优先级：MEDIUM

### 11. `op_read_verdict.sh` 只支持 `op_execution/tasks/{TID}/review.md`，归档后或恢复场景不兼容

- 位置：`/home/karon/karson_ubuntu/omni_powers/skills/oprun/scripts/op_read_verdict.sh:12-19`
- 现象：脚本只读活区 review.md。若 task 已进入归档但流程恢复或 close_post 幂等重跑需要确认 verdict，脚本返回 NONE。
- 影响：对已归档 task 的幂等检查能力弱；与 `op_close_post.sh` 支持活区/归档两种 ACTIVE_DIR 的设计不一致。
- 建议：增加归档路径 fallback：活区不存在时读 `op_record/tasks/{TID}/review.md`，输出中标注来源。
- 置信度：中
- 优先级：LOW

### 12. `op_coder_check.sh` 对已有 PASS verdict 的异常重入会返回 fail 模式

- 位置：`/home/karon/karson_ubuntu/omni_powers/skills/oprun/scripts/op_coder_check.sh:20-33`
- 现象：只要 review.md 有 1 条 verdict，无论最后 verdict 是 PASS 还是 FAIL，脚本都会计算 next_round=2 并输出 `mode: fail`。正常流程 PASS 后不会再派 implementer，但异常恢复/误调用时会把已 PASS 任务当成 FAIL 修复轮。
- 影响：降低恢复鲁棒性，可能诱导 leader 对已 PASS task 重新派 implementer。
- 建议：读取最后 verdict；若 PASS，输出 `mode: passed` 或直接非 0 提示「不应再派 implementer，进入 evaluator/merge」。
- 置信度：中
- 优先级：LOW

### 13. `SKILL.md` 收尾命令片段存在引号缺失

- 位置：`/home/karon/karson_ubuntu/omni_powers/skills/oprun/SKILL.md:268`
- 现象：命令写成 `bash "$OP_HOME/skills/oprun/scripts/op_checkpoint.sh {TID}`，缺少闭合引号。
- 影响：复制执行会直接 shell 语法错误，打断收口。
- 建议：修为 `bash "$OP_HOME/skills/oprun/scripts/op_checkpoint.sh" {TID}`。
- 置信度：高
- 优先级：LOW

### 14. `close_check.sh` 的 git status 过滤对 rename/路径格式较脆弱

- 位置：`/home/karon/karson_ubuntu/omni_powers/skills/oprun/scripts/close_check.sh:42-50`
- 现象：过滤正则只排除以 `${arch}` 开头的状态行。`git status --short` 对 rename 会显示 `R  old -> new`，归档移动可能不会被该模式识别。
- 影响：可能产生误报 WARN；虽然不阻断，但会降低信号质量。
- 建议：用 `git status --porcelain=v1 -z` + 路径解析，或改为白名单检查目标路径集合，而非 grep 文本过滤。
- 置信度：中
- 优先级：LOW

## 改进建议

1. 给 heavy oprun 建一个机械状态转移表，作为 `SKILL.md` 与脚本共同依据：`ready → in_progress → reviewing → eval_pending/evaluating(不入 tasks_list 可作为内部阶段) → closing → done`，并标清每步谁写哪些文件。
2. 把 dispatch metadata/review-package/eval brief 全部脚本化，避免 `SKILL.md` prompt 继续承担「临时口头协议」。尤其是 tasks_list 提取、workset 对照、review verdict 落盘。
3. `op_close_post.sh` 拆为两个阶段更安全：`validate_close_artifacts`（只校验）与 `archive_close_artifacts`（归档+stage）。当前脚本同时校验、移动、改状态、清 checkpoint、stage，职责偏多，容易遗漏边界。
4. 收口 commit 清单建议由脚本打印「必须纳入 commit 的路径」并和 `git diff --cached --name-only` 对比，防 Stage 4 核心资产未提交。
5. `op_assemble_eval_brief.sh` 建议加入 schema 化输出：明确列出「工作 spec」「保留的条件强制决策」「剥离的探索段」「生效规格文件」「baseline index」「启动方式」。缺任一关键来源时给 FAIL/WARN 分级。
6. 所有脚本建议统一 profile 校验与 root 定位策略。当前部分脚本用 `$OP_HOME` fallback，部分直接依赖路径，和设计档 §5.5 的 profile 入口约定不完全一致。

## 不确定项 / 可能误报

1. `op_close_post.sh` 中 `git mv` 对未跟踪 acceptance 目录的风险，取决于 evaluator 产物在实际流程中是否会被提前 `git add`。从当前 `SKILL.md` 与脚本看不到该前置，因此按高风险报告。
2. `op_close_post.sh` 未 stage decisions/op_blueprint/issues 可能被人工 `git add` 补救；但 `SKILL.md` 当前示例没有明确该步骤，脚本注释又暗示机械归档负责收口，因此按流程缺陷报告。
3. `op_read_verdict.sh` 只读活区在正常 merge gate 前足够；归档 fallback 属幂等/恢复增强，因此降为 LOW。
4. `op_coder_check.sh` 的 PASS 异常重入问题不影响严格按主流程执行的 happy path，因此降为 LOW。
