## 当前模型判断依据

可观测来源：`/home/karon/.claude/settings.json` 顶层 `model` 为 `haiku`；同文件 `env.ANTHROPIC_MODEL` 为 `default_model`；`env.ANTHROPIC_DEFAULT_HAIKU_MODEL` 为 `default_haiku[1m]`；`env.ANTHROPIC_DEFAULT_SONNET_MODEL` 为 `default_sonnet[1m]`；`env.ANTHROPIC_DEFAULT_OPUS_MODEL` 为 `default_opus[1m]`；主会话环境提示显示当前由 `default_model` 驱动。不能读取运行时内部状态，只能判断 current 路继承主会话；主会话可见模型标识为 `default_model`，配置默认模型字段显示 `haiku`。

## 审阅范围

已完整阅读上下文：

- `/home/karon/karson_ubuntu/omni_powers/docs/omni_powers_design.md`

逐文件、逐段审阅：

- `/home/karon/karson_ubuntu/omni_powers/docs/op_decisions.md`
- `/home/karon/karson_ubuntu/omni_powers/docs/op_first_run.md`
- `/home/karon/karson_ubuntu/omni_powers/docs/op_install.md`

排除：`vendors/`、`docs/archive/`。

## 高优先级问题（CRITICAL / HIGH）

### HIGH-1：`op_first_run.md` 的 task 循环顺序与当前设计冲突

- 位置：`/home/karon/karson_ubuntu/omni_powers/docs/op_first_run.md:64-67`
- 现象：流程表写成 `/oprun task 循环 → implementer → reviewer → closer 收口 → commit`，随后另列 `per-task 验收`；当前设计要求 reviewer PASS 后先派 evaluator 在 task 分支 merge 前验收，验收 PASS 后才 merge，再进入 closer 收尾。
- 影响：首跑 runbook 若照此执行，会把未经验收的 task 进入 closer/commit 路径，破坏 “merge 前验收” 与 “验收 PASS 才收口” 的核心安全顺序。
- 建议：改为 `implementer → reviewer → evaluator merge 前验收 → merge gate + squash-merge → closer 收尾/归档`；若文档仅作历史首跑计划，顶部应标注“已过期，不可执行”。
- 置信度：高
- 优先级：HIGH

### HIGH-2：`op_first_run.md` 仍描述“闸门 C 人工批准”，与当前 autonomy-first 设计冲突

- 位置：`/home/karon/karson_ubuntu/omni_powers/docs/op_first_run.md:67`、`/home/karon/karson_ubuntu/omni_powers/docs/op_first_run.md:101`
- 现象：文档要求闸门 C 批 closer 收尾提案后写入 blueprint、baselines、归档；当前设计 §2.6 明确 closer 提案由 leader 自审并直接执行，用户不做 per-task 或事中审批，只看一次 oprun 结束事后报告。
- 影响：人工首跑会引入当前设计已取消的人审阻塞点，误导执行者把“事后报告”当成“事中 gate”。
- 建议：将“闸门 C”改为“leader 自审 closer 提案 + 结束报告”；如需保留人工首跑确认，应明确这是首跑调试额外观察点，不是正式流程。
- 置信度：高
- 优先级：HIGH

### HIGH-3：`op_first_run.md` 的安装/环境前置与当前安装模型不一致

- 位置：`/home/karon/karson_ubuntu/omni_powers/docs/op_first_run.md:14-16`、`/home/karon/karson_ubuntu/omni_powers/docs/op_first_run.md:62`
- 现象：文档把 `OP_HOME`、`op_check_env.sh`、`/opinit` 生成 hooks 与 `$OP_HOME` env 混在一起；当前设计/CLAUDE.md 为 `install.sh --set-ophome` 负责全局安装与 OP_HOME 写入，`/opinit` 只做项目 heavy 初始化。
- 影响：首跑操作者可能跳过 `install.sh`，误以为 `/opinit` 会完成全局安装和 OP_HOME 配置，导致后续脚本寻址失败。
- 建议：前置检查改为先运行仓库 `install.sh`（heavy 用 `--set-ophome`），再在靶子项目运行 `/opinit`；`op_check_env.sh` 路径按当前实际安装模型表述。
- 置信度：高
- 优先级：HIGH

## 中低优先级问题（MEDIUM / LOW）

### MEDIUM-1：`op_first_run.md` 对“预期失败模式”的硬度描述过强

- 位置：`/home/karon/karson_ubuntu/omni_powers/docs/op_first_run.md:64`
- 现象：闸门 A 检查项写“预期失败模式每条验收标准 ≥1 条”；当前设计 §2.2/§2.5 将预期失败模式定义为 best effort，建议每条 AC 1 条，非硬门槛。
- 影响：首跑时可能把建议项当成硬门，造成无意义补齐或阻塞，与设计中“避免凑数”的取舍相反。
- 建议：改为“优先检查关键 AC 是否有预期失败模式；无则说明原因，不作为硬阻断”。
- 置信度：高
- 优先级：MEDIUM

### MEDIUM-2：`op_first_run.md` 仍引用已删除/弱化的“调教循环”表述

- 位置：`/home/karon/karson_ubuntu/omni_powers/docs/op_first_run.md:118`
- 现象：文档写“写首条偏差指令进 evaluator few-shot（design §8.1 调教循环启动）”；当前设计已无 §8.1 编号，且 D25 已删除“钓鱼审计 + 刻薄化调教循环”相关机制。
- 影响：读者会寻找不存在的章节或机制，误以为存在持续调教/审计闭环。
- 建议：改为“若发现 evaluator 放水，记录偏差指令素材，后续人工评估是否纳入 op-evaluator prompt”；删除旧章节引用。
- 置信度：高
- 优先级：MEDIUM

### MEDIUM-3：`op_first_run.md` 声称完成后归档并沉淀到 D20，但当前仍留在项目 docs 根目录

- 位置：`/home/karon/karson_ubuntu/omni_powers/docs/op_first_run.md:6`、`/home/karon/karson_ubuntu/omni_powers/docs/op_first_run.md:119`
- 现象：文档自称完成后移入 `docs/archive/`，结论并入 `op_decisions.md`（D20）；但该文档仍在当前审阅范围根目录，且 D20/D21/D27 等后续决策已存在。
- 影响：无法判断它是仍可执行计划、历史计划还是已完成残留；作为根目录文档会被误读为当前首跑权威 runbook。
- 建议：若已完成或过期，移入 archive 或顶部加“历史计划，当前不可直接执行”；若仍有效，按当前 design 全面更新。
- 置信度：中
- 优先级：MEDIUM

### MEDIUM-4：`op_install.md` 顶部废弃说明仍给出错误当前迁移路径

- 位置：`/home/karon/karson_ubuntu/omni_powers/docs/op_install.md:3-5`
- 现象：废弃说明写“用户 git clone 仓库 → `/opinit` skill 安装 → opinit 写 `$OP_HOME` 到 settings.json env”；当前安装模型是 `install.sh` 负责安装 skill/agent/scripts，`--set-ophome` 写 OP_HOME，`/opinit` 是项目初始化。
- 影响：即使主体标为旧文档，读者仍可能相信顶部“当前模型”说明，按错误步骤安装。
- 建议：改为“当前安装见 CLAUDE.md 与 `install.sh`；heavy 需 `bash install.sh --set-ophome`，再在项目内 `/opinit`”。
- 置信度：高
- 优先级：MEDIUM

### MEDIUM-5：`op_install.md` 指向当前设计章节编号已失效

- 位置：`/home/karon/karson_ubuntu/omni_powers/docs/op_install.md:4-5`
- 现象：文档指向 `docs/omni_powers_design.md §11`；当前设计的安装/插件结构在 §4.1，lite 相关在 §5。
- 影响：读者按链接定位会找不到对应内容，降低废弃文档的导航价值。
- 建议：更新为 `docs/omni_powers_design.md §4.1`，或只指向 `CLAUDE.md` “安装”段，避免章节漂移。
- 置信度：高
- 优先级：MEDIUM

### MEDIUM-6：`op_decisions.md` 最新决策与当前设计存在未标注的时序冲突

- 位置：`/home/karon/karson_ubuntu/omni_powers/docs/op_decisions.md:285-297`、`/home/karon/karson_ubuntu/omni_powers/docs/op_decisions.md:414-427`
- 现象：D20 写 lite “P0 阻断检查，归档前停下问用户”；D27 写“闸门 C 批量化，per-task 中断压到 1 次”。当前设计已改为 heavy/lite 都事后报告，P0 不事中阻断归档，closer 提案 leader 自审不事中问用户。
- 影响：`op_decisions.md` 是决策记录，历史冲突可接受；但这些条目不是很早期旧机制，且未标“已被 A18/后续决策取代”，读者可能把它们当成最新有效决策。
- 建议：在 D20/D27 对应条目前增加“已被后续 A18/current design 改写”的状态标记，或新增一条后续决策说明取消事中 P0 阻断与闸门 C 人审。
- 置信度：中
- 优先级：MEDIUM

### MEDIUM-7：`op_decisions.md` 存在“待改/待澄清”残留，未反映当前 design 状态

- 位置：`/home/karon/karson_ubuntu/omni_powers/docs/op_decisions.md:333-345`、`/home/karon/karson_ubuntu/omni_powers/docs/op_decisions.md:346-361`
- 现象：D22 仍写“与现状关系待澄清”；D23 仍写“影响（待改，本条仅记决策）”。当前 design 已采用强制 spec 定位，且 spec 模板中未见原 D23 所述 `feature` frontmatter 注释。
- 影响：读者无法区分“待办未做”与“已被后续修改吸收”，增加维护噪音。
- 建议：在 D22/D23 下补一行“处置状态：已吸收/已改写/不再适用”，或追加 D28 类清账决策。
- 置信度：中
- 优先级：MEDIUM

### LOW-1：`op_decisions.md` 决策编号顺序混乱且 D11 缺失无说明

- 位置：`/home/karon/karson_ubuntu/omni_powers/docs/op_decisions.md:103-140`
- 现象：D10 后直接 D13、D14，然后 D12；D11 缺失且无“编号保留/废弃”说明。
- 影响：作为审计记录可读性差，引用 D 编号时容易误判时间顺序。
- 建议：保留原文不重排历史，但在顶部术语演变区加“编号历史存在空洞和乱序，按日期/标题阅读；D11 未使用或遗失”。
- 置信度：高
- 优先级：LOW

### LOW-2：`op_install.md` 主体旧内容很长，废弃警告不足以防误用

- 位置：`/home/karon/karson_ubuntu/omni_powers/docs/op_install.md:9-381`
- 现象：主体保留大量可复制命令和 JSON/bash 示例，且包含 `claude plugins install`、`$CLAUDE_PLUGIN_ROOT`、旧 agent 名称等不可用路径。
- 影响：虽然顶部警告明确，但长文档在搜索命中时仍可能被片段引用误用。
- 建议：若必须留在 docs 根目录，可在每个大节标题前加“历史原文”边界，或缩短为摘要并将完整原文移入 archive。
- 置信度：中
- 优先级：LOW

## 改进建议

1. 将 `/home/karon/karson_ubuntu/omni_powers/docs/op_first_run.md` 定性为“当前可执行 runbook”或“历史首跑计划”二选一；若前者，按 current design 重写执行顺序、安装模型、闸门语义；若后者，移入 archive 或加醒目标记。
2. 给 `/home/karon/karson_ubuntu/omni_powers/docs/op_decisions.md` 增加“状态标记”惯例：`active` / `superseded by Dxx` / `absorbed into design` / `historical`，避免历史决策与当前契约混读。
3. 更新 `/home/karon/karson_ubuntu/omni_powers/docs/op_install.md` 顶部的“当前安装方式”说明；主体保持历史原文可以接受，但不要让顶部导航指错当前流程。
4. 对项目根 `docs/` 做一次“当前文档 vs 历史文档”分层：当前可执行文档留根目录；历史设计/安装/首跑计划进 `docs/archive/`，根目录只留索引链接。

## 不确定项 / 可能误报

1. `op_first_run.md` 可能有意作为“人工首跑额外观测计划”，因此包含比正式流程更多人工确认点；若如此，问题不在人工确认本身，而在没有明确标注“调试观察点，不是正式流程”。
2. `op_decisions.md` 是 append-only 决策史，历史冲突本身不应视为错误；本报告只标出未标注 superseded/absorbed 状态、容易误导读者的近期开口项。
3. `op_install.md` 顶部已明确废弃，主体旧机制不是问题；本报告关注的是顶部“当前替代路径”本身已过期，以及根目录保留长篇旧命令的误用风险。
