## 当前模型判断依据

可观测来源：`/home/karon/.claude/settings.json` 顶层 `model=haiku`；`env.ANTHROPIC_MODEL=default_model`；`ANTHROPIC_DEFAULT_HAIKU_MODEL=default_haiku[1m]`；`ANTHROPIC_DEFAULT_SONNET_MODEL=default_sonnet[1m]`；`ANTHROPIC_DEFAULT_OPUS_MODEL=default_opus[1m]`；主会话环境提示当前由 `default_model` 驱动。不能读取运行时内部状态；current 路继承主会话。

## 审阅范围

- 已完整阅读上下文：`/home/karon/karson_ubuntu/omni_powers/docs/omni_powers_design.md`。该文件仅作上下文，未作为审阅对象展开问题列表。
- 已逐段审阅：`/home/karon/karson_ubuntu/omni_powers/docs/vendors_analyze/vendors_repo/superpowers.md`
- 已逐段审阅：`/home/karon/karson_ubuntu/omni_powers/docs/vendors_analyze/vendors_repo/trellis.md`
- 遵守约束：未审阅 `vendors/` 与 `docs/archive/`；未联网；未跑构建；未跑测试；源文件只读；仅写本报告。

## 高优先级问题（CRITICAL / HIGH）

未发现 CRITICAL / HIGH 问题。

## 中低优先级问题（MEDIUM / LOW）

### 1. `superpowers.md`：状态管理章节与工具概览存在表述冲突

- 位置：`/home/karon/karson_ubuntu/omni_powers/docs/vendors_analyze/vendors_repo/superpowers.md:60`、`/home/karon/karson_ubuntu/omni_powers/docs/vendors_analyze/vendors_repo/superpowers.md:396-401`
- 现象：前文写 `executing-plans`「有 checkpoint」，后文「Memory / Checkpoint / 持久化」写「无 checkpoint 机制」。如果后文只限定 SDD 专用，则标题和措辞未说明限定范围。
- 影响：读者会误判 superpowers 是否具备 checkpoint/恢复能力；对比 omni_powers 的 checkpoint 设计时容易得出错误结论。
- 建议：将后文改成「SDD 无通用 checkpoint；仅依赖 progress ledger；executing-plans 另有 skill 内 checkpoint，非系统级持久化机制」，或拆分「SDD 状态」与「其他 skill 状态」。
- 置信度：高
- 优先级：MEDIUM

### 2. `superpowers.md`：核心 skill 标题拼写错误

- 位置：`/home/karon/karson_ubuntu/omni_powers/docs/vendors_analyze/vendors_repo/superpowers.md:177`
- 现象：标题写成 `sun_agent-driven-development`，应为 `subagent-driven-development`。
- 影响：降低文档可信度；影响搜索、目录跳转和后续引用一致性。
- 建议：修正标题拼写，并检查全文是否还有同类命名漂移。
- 置信度：高
- 优先级：LOW

### 3. `trellis.md`：Skills 数量统计与列表不一致

- 位置：`/home/karon/karson_ubuntu/omni_powers/docs/vendors_analyze/vendors_repo/trellis.md:52`、`/home/karon/karson_ubuntu/omni_powers/docs/vendors_analyze/vendors_repo/trellis.md:86-102`
- 现象：安装机制处写入 13 个 skill 目录；Skills 表中列出 12 个具名条目，再加 `gitnexus-* (6 个)`，按表面计数超过 13。若 `gitnexus-*` 属于子集或不全是 Claude Code skill，文档未解释。
- 影响：工具全景统计不可信；后续比较 superpowers/trellis/omni_powers 的 skill 规模时会误计。
- 建议：明确「13 个目录」对应哪 13 个；将 `gitnexus-*` 展开或注明它是否包含在 13 个内、是否为同类 skill。
- 置信度：高
- 优先级：MEDIUM

### 4. `trellis.md`：Task 状态机三处表述不一致

- 位置：`/home/karon/karson_ubuntu/omni_powers/docs/vendors_analyze/vendors_repo/trellis.md:279-285`、`/home/karon/karson_ubuntu/omni_powers/docs/vendors_analyze/vendors_repo/trellis.md:358-364`、`/home/karon/karson_ubuntu/omni_powers/docs/vendors_analyze/vendors_repo/trellis.md:436-440`
- 现象：一处写 `no_task → planning → in_progress → (archive 时直接 completed)` 且 `completed` 标签 dead；schema 写 `planning|in_progress|completed|archived`；后文又写状态机为 `planning → in_progress → archived（直接 archive，中间无 completed 阶段）`。
- 影响：读者无法确定 `completed` 是否真实状态、dead code、还是 archive 流程中的过渡态。对比 omni_powers 的状态枚举时容易形成错误映射。
- 建议：统一成一个权威状态表。例如：`task.json.status` 实际允许值为 X；workflow breadcrumb 另有 dead/legacy `completed` 标签；archive 行为如何落盘。若 `completed` 已废弃，从 schema 示例移除或标注 deprecated。
- 置信度：高
- 优先级：MEDIUM

### 5. `trellis.md`：配置写入范围表缺少全局路径说明

- 位置：`/home/karon/karson_ubuntu/omni_powers/docs/vendors_analyze/vendors_repo/trellis.md:47-53`、`/home/karon/karson_ubuntu/omni_powers/docs/vendors_analyze/vendors_repo/trellis.md:61-72`
- 现象：前文说明可能写入 `~/.claude/settings.json` 或项目 `.claude/settings.json`，汇总表只写 `.claude/settings.json`。Agents、Skills、Commands 同样未明确是项目 `.claude/`、全局 `~/.claude/`，还是按平台配置决定。
- 影响：安装侵入性评估不够精确；与 omni_powers heavy/lite「是否改全局配置/项目配置」对比时，读者可能误判写入边界。
- 建议：在汇总表增加「作用域」列：global / project / per-platform，并分别列出 `~/.claude/...` 与 `<repo>/.claude/...` 的触发条件。
- 置信度：中
- 优先级：LOW

### 6. `superpowers.md`：对重复注入影响的结论偏绝对

- 位置：`/home/karon/karson_ubuntu/omni_powers/docs/vendors_analyze/vendors_repo/superpowers.md:374-378`
- 现象：文档写 compact 后重复注入同一内容「不影响 agent 推理能力」。该结论偏绝对；即使内容相同，仍会占用上下文并可能引入重复指令权重。
- 影响：低估 SessionStart 注入在长会话中的上下文成本和指令重复风险；与 omni_powers 的 compact/恢复设计对比时不够谨慎。
- 建议：改成更稳妥表述：「重复内容较短，预期影响有限；主要成本是上下文占用与重复指令权重，需通过 eval/实测确认」。
- 置信度：中
- 优先级：LOW

## 改进建议

1. 为 vendor 分析文档增加统一「可验证来源」字段：repo 路径、版本/tag、commit SHA、分析日期、是否联网核验。当前仅 `superpowers.md` 末尾有较完整 source，`trellis.md` 缺少同等格式来源。
2. 增加统一「与 omni_powers 设计对照」小节，集中比较：安装侵入性、hook 是否作为安全边界、subagent 上下文注入、状态持久化、测试/验收防线、worktree/隔离策略。当前两篇更多是 vendor 自身拆解，横向比较信息需读者自行拼接。
3. 对所有数量型结论（版本、commit 数、skill 数、平台数、周下载量）增加「截至日期」与「来源」。无法离线复核时标注为「采样观察」而非事实定论。
4. 对「hook 注入」类机制统一加安全边界注释：可用于上下文补齐/行为引导，不可视为访问控制或硬权限隔离。这一点与 `omni_powers_design.md` 的 subagent hook 失效/防线定位高度相关。
5. 建议把状态机单独整理成机读/表格形式，避免正文多处自然语言描述漂移。

## 不确定项 / 可能误报

1. 本次按用户要求不联网、不读取 vendor 源仓库，仅基于两份目标文档内部一致性与 `omni_powers_design.md` 上下文审阅；涉及版本号、commit 数、平台支持数量、npm 下载量等外部事实未核验。
2. `trellis.md` 中 Skills 数量问题可能源于作者将 `gitnexus-*` 视为一个聚合项，或其中部分不是 Claude Code skill；但当前文本未说明，故仍作为文档一致性问题记录。
3. `superpowers.md` 中 checkpoint 问题可能源于「系统级 checkpoint」与「executing-plans skill 内 checkpoint」概念差异；当前文本未显式分层，故作为歧义问题记录。
