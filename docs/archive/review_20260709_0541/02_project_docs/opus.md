## 当前模型判断依据
根据可观测来源 `/home/karon/.claude/settings.json`：
- 顶层配置 `"model": "haiku"`
- 环境变量 `"env.ANTHROPIC_MODEL": "default_model"`
- 环境变量 `"env.ANTHROPIC_DEFAULT_HAIKU_MODEL": "default_haiku[1m]"`
- 环境变量 `"env.ANTHROPIC_DEFAULT_SONNET_MODEL": "default_sonnet[1m]"`
- 环境变量 `"env.ANTHROPIC_DEFAULT_OPUS_MODEL": "default_opus[1m]"`
- 主会话环境提示显示当前由 `default_model` 驱动

## 审阅范围
本次审阅排除了 `vendors/` 与 `docs/archive/`，对以下文件进行了逐段审阅：
- `/home/karon/karson_ubuntu/omni_powers/docs/op_decisions.md`
- `/home/karon/karson_ubuntu/omni_powers/docs/op_first_run.md`
- `/home/karon/karson_ubuntu/omni_powers/docs/op_install.md`

## 高优先级问题（CRITICAL / HIGH）

### 1. `op_first_run.md` 闸门 C 人工审查时序与核心设计冲突
- **位置**：`docs/op_first_run.md` 第 3 行、第 67 行表格、第 101 行成功标准。
- **现象**：将“闸门 C”列为 task 循环内部的同步人工确认步骤（“批 closer 收尾提案”），并作为 task 闭环的前置条件。
- **影响**：与 `omni_powers_design.md` §2.6 和 D27 决策（D-3=A：闸门 C 批量化与 leader 自审）严重矛盾。最新架构规定 closer 提案由 leader 自审并直接自动写入，无需用户事中审批；闸门 C 已调整为在一次 oprun 结束或中断时呈报的批量化“事后报告”。首跑计划在此处保留了同步人工阻断，会导致测试流程与真实设计偏离，无法正确验证 leader 的自主决策能力。
- **建议**：修正首跑计划中的时序描述，将 task 循环内的 closer 提案写入改为“leader 自动读取提案并自审执行写入”；将闸门 C 移至 task 循环外，作为事后批量呈报步骤。
- **置信度**：High
- **优先级**：HIGH

### 2. `op_first_run.md` 推荐的模型配置违背“强审弱错”的质量底线
- **位置**：`docs/op_first_run.md` 第 26-30 行。
- **现象**：首跑计划推荐的 `OP_REVIEWER_MODEL` 配置为 `sonnet`。
- **影响**：根据 `omni_powers_design.md` §2 中的角色模型分配表，`op-reviewer` 的推荐配置应为 `opus`。因为 implementer 已经使用了 `sonnet`，如果 reviewer 也使用 `sonnet`，就会与设计原则中的“强审弱错开同档盲区”相违背，导致首跑中 reviewer 的双裁决能力大打折扣，无法完全暴露实现侧的隐藏缺陷。
- **建议**：将 `OP_REVIEWER_MODEL` 的推荐值修改为 `opus`，或加注说明以保证审阅阶段的拦截可信度。
- **置信度**：High
- **优先级**：HIGH

## 中低优先级问题（MEDIUM / LOW）

### 3. `op_install.md` 指向不存在的章节，导致引用失效
- **位置**：`docs/op_install.md` 第 4 行。
- **现象**：文档前言中写道“详见 docs/omni_powers_design.md §11”。
- **影响**：在合并后的 `omni_powers_design.md` 中，章节经过了重构重编，最大二级章节号仅为 `5. lite 模式`，并不存在 `§11`。此失效引用会导致需要了解安装和环境变量细节的开发者在设计文档中迷失。
- **建议**：将引用修改为指向正确的章节，如 `## 4. 工程部署` 或 `### 4.1 插件结构与安装`。
- **置信度**：High
- **优先级**：MEDIUM

### 4. 已废弃和执行完毕的计划文档未移入归档目录
- **位置**：`docs/op_install.md`、`docs/op_first_run.md`。
- **现象**：`op_install.md` 属于“已废弃”的通用化方案说明，`op_first_run.md` 前言也写明了“完成后：本文档移 docs/archive/”，但两份文档目前仍滞留在 `docs/` 根目录。
- **影响**：违反了 `CLAUDE.md` 对 `docs/archive/` 目录的存放约定，混淆了当前的活跃项目文档，增加了开发者或 Agent 的信息噪音。
- **建议**：将两份文件物理移动到 `docs/archive/` 下。
- **置信度**：High
- **优先级**：MEDIUM

### 5. `op_decisions.md` 编号缺失、断层及废弃决策标记不完整
- **位置**：`docs/op_decisions.md` 全文。
- **现象**：
  - 缺失 `D11` 决策编号；
  - `D12`（代码平面 vs 控制平面分离）已被 `D16`（取消平面分离）及 `D17` 事实上取代并推翻，但其标题未像 `D1`/`D4`/`D5`/`D10` 等标题那样加上 `⚠️ 已被 D16 取代` 的警告后缀；
  - “baseline 形态裁定”决策块（第 221 行）未获得以 `Dxx` 开头的统一决策编号；
  - `D21` 的表格中引用了大量旧章节号（如 §10, §15 等），这在重构合并后的 design.md 中已不匹配。
- **影响**：损害了决策历史记录作为“架构演进真相源”的一致性，容易使阅读历史依据的后续开发者产生困惑。
- **建议**：
  - 为 `baseline 形态裁定` 补上统一决策编号（如 `D17a` 或在 `D18` 中并合）；
  - 在 `D12` 标题加上 `⚠️ 已被 D16 取代` 标记；
  - 在 `D21` 涉及章节引用的旧决策中，补充注释说明“章节号对应合并前旧版设计”。
- **置信度**：High
- **优先级**：LOW

## 改进建议
1. **重整 docs 根目录文件**：
   - 将已废弃的旧安装方案 `docs/op_install.md` 剪切移动至 `docs/archive/op_install.md`。
   - 若首跑已经完成，将 `docs/op_first_run.md` 剪切移动至 `docs/archive/op_first_run.md`；若首跑未执行或需保留作为演练，应将文档内的同步审批时序和推荐模型修改正确后再予保留。
2. **修正决策记录的废弃标记**：
   - 全量检索 `op_decisions.md`，凡是被后续决策（如 D15、D16）直接废弃或重大修改的历史决策（如 D12），统一加上 `⚠️ 已被 Dxx 取代` 的醒目标记。

## 不确定项 / 可能误报
- **关于 `op_first_run.md` 的定位**：首跑计划设计为“半自动人工确认”可能包含为了调试目的有意保留的暂停点（即使最新流程规定此处是自动的）。如果是为了调试目的，建议在文档中显式说明“此人工确认仅为首跑调试时人肉观察 leader 自审决策使用，不代表真实 heavy 流程的闸门设置”。
