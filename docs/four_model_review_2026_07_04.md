# 四模型审阅问题汇总（2026-07-04）

> 来源：主会话 + Haiku + Sonnet + Opus。  
> 方式：只读审阅；本文只汇总四方已发现问题，不做修复，不改代码。

## CRITICAL

### 1. task 文件命名体系分裂，收口链路跑不通
来源：主 / Haiku / Opus

- v6 文档/agent 用：`brief.md / report.md / review.md`
- 旧脚本用：`spec.md / plan.md / context.md / review_spec.md / review_code.md / review_test.md`
- 相关位置：
    - `scripts/op_new_task.sh:17`
    - `scripts/op_close_pre.sh:8`
    - `scripts/op_close_post.sh:44-50`
    - `skills/oprun/scripts/op-coder-check.sh:16,31`
    - `skills/oprun/scripts/op-read-verdict.sh:19-24`
    - `skills/oprun/scripts/close_check.sh:33`
    - `agents/op-reviewer.md:11-12`
    - `agents/op-implementer.md:59-61`

### 2. `scripts/op_assemble_eval_brief.sh` 缺失
来源：主 / Haiku / Sonnet / Opus

- 确认不存在：`scripts/op_assemble_eval_brief.sh`
- 被引用：
    - `agents/op-evaluator.md:15,140`
    - `skills/oprun/SKILL.md:195`
    - `docs/omni_powers_design.md:388,490,537`
- 影响：evaluator brief 机械组装无法执行。

### 3. 安装入口缺失
来源：主 / Sonnet / Opus

- 缺失：
    - `install.sh`
    - `uninstall.sh`
- 引用：
    - `CLAUDE.md` 写 `./install.sh`
    - `docs/op_install.md` 描述安装流程
- 影响：用户照文档安装失败。

### 4. `scripts/op_new_task.sh` 模板路径错误
来源：主 / Haiku / Sonnet

- `scripts/op_new_task.sh:9`
- 当前：`TEMPLATE_DIR="$ROOT/template/op_execution/tasks/{TID}"`
- 实际：`docs_template/omni_powers/op_execution/tasks/{TID}/`
- 影响：创建 task 失败。

### 5. `tasks_list.json` schema 三套不一致
来源：Haiku / Opus

- 模板字段：`verification / created_at / updated_at / blockers`
- `opintake` 字段：`spec / type / covers_ac / touches_inv / risk_probe / workset`
- 脚本主要读写：`id / status / blocked_by / depends_on`
- 影响：模板、skill、脚本不能稳定互通。

### 6. reviewer 单文件 vs 三文件矛盾
来源：Opus

- agent 规定：`review.md` 单文件
- 脚本读取：`review_spec.md / review_code.md / review_test.md`
- 影响：review verdict 读取、轮次判断、收口检查全部不一致。

### 7. `op_close_pre.sh` / `op_close_post.sh` 仍要求 task 内 `spec.md`
来源：主 / Opus

- `scripts/op_close_pre.sh:8`
- `scripts/op_close_post.sh:44`
- v6 spec 位置：`docs/omni_powers/op_execution/specs/{前缀}.md`
- 影响：v6 task 目录没有 `spec.md` 时直接失败。

### 8. `close_check.sh` 检查清单与实际产物不一致
来源：Haiku / Sonnet

- `skills/oprun/scripts/close_check.sh:33`
- 要求：`brief.md / report.md / review.md`
- 但旧模板/脚本体系又是 `spec / plan / context / review_*`
- 影响：收口检查不可靠。

### 9. `opintake` spec 路径与脚本/hook/agent 矛盾
来源：Haiku

- `skills/opintake/SKILL.md:39`
- opintake 写：`op_execution/specs/{前缀}.md`
- 旧脚本读：`op_execution/tasks/{TID}/spec.md`
- 影响：spec 真相源混乱。

### 10. `skills/opintake/SKILL.md` 引用不存在的 spec 模板目录
来源：Sonnet

- `skills/opintake/SKILL.md:104`
- 引用：`docs_template/omni_powers/op_execution/specs/`
- 实际缺失。

### 11. `.claude-plugin/plugin.json` / `hooks/hooks.json` 缺失
来源：Sonnet

- `docs/op_install.md:133-162` 描述这些文件
- 实际不存在
- 影响：plugin 安装文档与仓库不一致。

## HIGH

### 12. review 轮次上限冲突
来源：主 / Haiku / Sonnet / Opus

- `skills/oprun/scripts/op-coder-check.sh:40`：`next_round > 3` 才 blocked
- `RULES.md` / design：review ≤ 2 轮
- 影响：协议与脚本调度冲突。

### 13. `blocked_by` 枚举冲突
来源：主 / Sonnet / Opus

- `RULES.md`：`resource / quality / spawn`
- `scripts/op_status.sh`：`key / domain / quality / spawn`
- 模板：`key`
- 影响：按 RULES 写 `resource` 会被脚本拒绝。

### 14. `$OP_HOME` / `$CLAUDE_PROJECT_DIR` / `$CLAUDE_PLUGIN_ROOT` 混用
来源：Sonnet / Haiku / Opus

- `RULES.md` 用 `$OP_HOME`
- hook settings 用 `$CLAUDE_PROJECT_DIR`
- `docs/op_install.md` 用 `$CLAUDE_PLUGIN_ROOT`
- 脚本用 `git rev-parse --show-toplevel`
- 影响：路径模型不统一。

### 15. checkpoint 被当 JSON 读
来源：主 / Haiku

- `hooks/pre_tool_use.sh:67`
- 用：`jq -r '.current_task // empty' leader_checkpoint.md`
- 但 checkpoint 是 markdown/yaml 风格。
- 影响：e2e/BUG 锁当前 task 读取失败。

### 16. `op-checkpoint.sh` 依赖模板锚点，但 opinit 生成格式不同
来源：Haiku / Opus

- `skills/oprun/scripts/op-checkpoint.sh`
- 依赖：`## tasks_list 状态`、`## 已完成 task`
- `skills/opinit/SKILL.md` heredoc 生成的 checkpoint 没这些锚点。
- 影响：checkpoint 更新可能假成功。

### 17. evaluator 写权限/身份机制不可执行
来源：主 / Opus

- hook 用 `OP_AGENT_ROLE=evaluator`
- `oprun` dispatch 没设置该环境变量
- 影响：evaluator 可能被拦；implementer 也可能绕过隔离。

### 18. e2e / BUG 测试锁机制与 design 矛盾
来源：Opus

- design 说 e2e 全局硬阻断
- hook 实际只有命中 `.test_locks` 才拦
- 未登记路径会放行
- 影响：implementer 可改 e2e。

### 19. Stop hook 证据门禁误伤非 src task
来源：主 / Opus

- `hooks/stop.sh` 要 5 分钟内测试证据
- `hooks/post_tool_use.sh` 只对 `src/*` 生成证据
- 影响：文档、e2e、closer、evaluator task 可能被拒收工。

### 20. `post_tool_use.sh` 只管 `src/*`，漏 `tests/` 和 `e2e/`
来源：Haiku

- `hooks/post_tool_use.sh:18-21`
- 影响：多数测试修改不产证据。

### 21. `op_jq.sh` jq 拼接注入风险
来源：主 / Sonnet / Opus

- `scripts/op_jq.sh`
- 模式：`select(.id=="'"$TID"'")`
- 应用 `--arg`
- 影响：TID 含引号会破坏 jq。

### 22. `op_jq.sh deps` 条件退化
来源：主 / Sonnet / Opus

- 表达式等价于：`st != "完成"`
- 影响：细分状态判断失效。

### 23. evaluator 验收报告路径冲突
来源：Haiku / Opus

- `agents/op-evaluator.md:100`：`op_execution/specs/{spec}_acceptance.md`
- design：`op_execution/acceptance/{前缀}/`
- baseline 又写：`op_execution/acceptance/{前缀}/baselines/`
- 影响：closer/evaluator/归档路径不统一。

### 24. leader 写 `op_blueprint/` 会被 hook 拦，但流程没说明如何放行
来源：Opus

- `hooks/pre_tool_use.sh` 需要 `OP_LEADER_WRITE=1`
- `skills/oprun/SKILL.md` / `agents/op-closer.md` 未给 leader 执行步骤
- 影响：closer 提案批准后可能写不进去。

### 25. `op_close_post.sh` `git add` 范围可能误 stage
来源：Haiku

- `scripts/op_close_post.sh:65-68`
- 可能把控制文件或未审 blueprint 改动一起 stage。
- 影响：提交边界不干净。

### 26. `docs/op_install.md` 是未落地 plugin 模式
来源：Haiku / Sonnet

- 提到：`CLAUDE_PLUGIN_ROOT`、`claude plugins install .`、`plugin.json`、`hooks.json`、config yaml
- 实际未实现。
- 影响：文档误导。

### 27. `docs/omni_powers_design.md` 超前实现
来源：Haiku / Sonnet

- 引用不存在脚本
- 设计已 v6，运行脚本仍 v5
- 影响：设计与现实脱节。

### 28. `op_status.sh` lock / batch 健壮性问题
来源：Haiku / Opus

- lock 文件父目录/失败处理不足
- batch 模式 blocked_by 行为与单 task 不一致
- batch jq 解析可能不稳
- 影响：批量状态更新不可靠。

## MEDIUM

### 29. `docs_template/` 是 v5 残留
来源：Opus / Sonnet

- `dag.md`
- `spec.md` 单数
- `tech_debt.md`
- `review_code.md/review_test.md`
- 旧 agent 名称
- 影响：opinit 会把旧结构带入新项目。

### 30. `docs_template/omni_powers/op_blueprint/baselines/baselines_index.md` 缺失
来源：主

- design 已要求：`baselines/baselines_index.md`
- 实际缺失。

### 31. `docs_template/omni_powers/index.md` 引用已删除 `dag.md`
来源：Sonnet / Opus

- `op_execution/dag.md`
- design 已删除 DAG 文件。

### 32. `scripts/test_lock.sh` 缺 `set -e`
来源：Sonnet

- 只有：`set -uo pipefail`
- 影响：部分错误可能继续执行。

### 33. `scripts/test_lock.sh` 无锁
来源：Haiku / Opus

- add/remove 都无 flock
- 并发可能重复或丢记录。

### 34. `scripts/op_new_task.sh` 不拷贝 review 模板
来源：Sonnet

- 只拷：`spec.md / plan.md / context.md`
- 不拷：`review_spec.md / review_code.md / review_test.md`

### 35. `op-read-verdict.sh` round 计算基于 `review_spec.md`
来源：Haiku

- 但 v6 reviewer 输出 `review.md`
- 影响：round 永远不准。

### 36. `op_close_pre.sh` 盖戳逻辑不适合 v6
来源：Opus

- v6 spec 在 `op_execution/specs/`
- task 目录无 `spec.md`
- 影响：per-task 收口启动失败。

### 37. `opinit` 会迁移顶层 docs，可能误移合法文档
来源：Opus

- `skills/opinit/SKILL.md:43`
- 相关 docs 迁移逻辑可能误归档项目已有设计文档。

### 38. `op-evaluator.md` “不存在 Stage 2”措辞不准
来源：Opus

- v6 有 Stage 2：task 拆分
- 删除的是 v5 Stage 2 验收先行
- 影响：术语误导。

### 39. `op-closer.md` / decisions 写入可能并发冲突
来源：Haiku

- `op_record/decisions.md` append-only
- 多写者无锁
- 影响：并发截断/覆盖风险。

### 40. `agents/op-evaluator.md` 工具权限与隔离目标冲突
来源：Haiku

- tools 里有 `Read/Grep/Bash`
- 规则又禁止读 `src/**`
- 依赖 hook，但 hook 拦不住所有读取路径
- 影响：隔离不硬。

### 41. `hooks/settings.template.json` SessionStart matcher 不确认
来源：Sonnet

- SessionStart hook 没 matcher
- 不确定是否按预期触发。

### 42. `hooks/settings.template.json` 合并可能覆盖用户 hooks
来源：Haiku

- `jq -s '.[0] * .[1]'`
- 影响：已有 hooks 可能被覆盖。

### 43. `docs/op_decisions.md` 混旧 agent 名称
来源：Sonnet

- 旧名：`op-coder / op-code-reviewer / op-test-reviewer`
- D17 已更新体系
- 影响：历史记录未标“已取代”。

### 44. `CLAUDE.md` 引用不存在文档路径
来源：Haiku / Opus

- `docs/vendors/reconstruction-proposal.md`
- `docs/vendors/v5-revision-notes.md`
- `docs/omni_powers/op_findings.md`
- 实际路径不匹配。

### 45. `optriage` issue 命名/流转不统一
来源：Haiku

- `I-{YYYYMMDD}-{NN}.md`
- `{TID}_quality.md`
- `issues/{TID}_quality.md`
- 多套命名共存。

### 46. `opstatus` / 状态恢复语义不完整
来源：Haiku

- `收口中` 在状态枚举中
- 但恢复路径描述不完整。

## LOW

### 47. `hooks/stop.sh` 注释与代码不一致
来源：Opus

- 注释：5 分钟
- 代码清理：`-mmin +60`

### 48. `op-checkpoint.sh` 临时文件无 trap
来源：Opus

- `/tmp/op_checkpoint_status_$$.md`
- 异常路径可能残留。

### 49. `op_jq.sh:19` 静默吞 `shift` 错误
来源：Sonnet

- `shift 2>/dev/null || true`

### 50. 零测试覆盖
来源：Sonnet

- 没有 shell/hook 测试
- 脚本逻辑错误无法自动发现。

### 51. `hooks/pre_tool_use.sh` frontmatter 解析脆弱
来源：Sonnet

- awk 查 `^status:`
- 对缩进/格式敏感。

### 52. `skills/opred` / reviewer / implementer 危险模式清单重复
来源：Opus

- 多处重复维护
- 后续易漂移。

### 53. `agents/op-reviewer.md` refactor 加审无输出格式落点
来源：Opus

- 有规则，无模板对应字段。

### 54. `progress.md` 追加格式未文档化
来源：Opus

- `scripts/op_close_post.sh` 写：`- {TID} | {feature} | {date} | 完成`
- 模板未说明格式。

### 55. archive 旧协议可能被误读
来源：Sonnet

- `docs/archive/*` 仍保留旧路径/旧协议
- 如果 agent grep 到，可能混淆。
