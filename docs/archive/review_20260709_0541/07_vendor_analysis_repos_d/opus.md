## 当前模型判断依据
根据系统配置与运行时提示，当前由 default_opus 模型驱动。

## 审阅范围
本审阅针对 omni_powers 项目中的第三方供应商分析模块（07_vendor_analysis_repos_d）进行全量只读审阅，涉及以下文件：
- /home/karon/karson_ubuntu/omni_powers/docs/vendors_analyze/vendors_repo/superpowers.md
- /home/karon/karson_ubuntu/omni_powers/docs/vendors_analyze/vendors_repo/trellis.md

## 高优先级问题（CRITICAL / HIGH）
### 1. trellis.md 状态机与任务状态描述冲突
- **位置**：`trellis.md` 第 280-283 行、第 363 行 及 第 440 行。
- **现象**：
  - 第 280-283 行的状态迁移图为：`no_task → planning → in_progress → (archive 时直接 completed)`，并标注 `completed 标签目前 DEAD`。
  - 第 440 行的状态迁移描述为：`planning → in_progress → archived（直接 archive，中间无 completed 阶段）`。
  - 第 363 行的 `task.json` 模式中，`status` 字段定义了四个可选值 `"planning|in_progress|completed|archived"`。
- **影响**：状态机的流转和终态定义混乱。若 `completed` 确实属于已废弃（DEAD）状态，则 schema 描述中应将其清除；若其仍然存在，则前后文关于 "无 completed 阶段" 和 "DEAD" 的逆差描述是矛盾的，会导致在此基础上开发 omni_powers 兼容层时产生状态路由误判。
- **建议**：统一状态机的文字描述与 schema 定义。澄清 `completed` 与 `archived` 在 Trellis 状态树中的真实位置及相互关系。
- **置信度**：High
- **优先级**：HIGH

## 中低优先级问题（MEDIUM / LOW）
### 1. superpowers.md 注入通道术语定义不严谨
- **位置**：`superpowers.md` 第 8 行 及 第 46 行、第 150-160 行。
- **现象**：文档前文提到 "核心机制是在 SessionStart 时将 `using-superpowers` 技能全文注入 system context"，而后面具体描述时明确指出是通过 `additionalContext` 字段进行注入。
- **影响**：在 Claude Code 等平台中，`additionalContext` 的注入级别并不等同于 `system context`（系统提示词），它在上下文优先级上通常比 system context 低。若对此不加区分，可能会导致 implementer 误认为注入具有系统级别的绝对遵从约束，从而在长上下文环境中忽视其可能被压缩或淡化的风险。
- **建议**：明确区分 `system context` 和 `additionalContext` 的概念，指出其在不同 harness 平台上的具体实现限制。
- **置信度**：High
- **优先级**：MEDIUM

### 2. superpowers.md 标题拼写错误
- **位置**：`superpowers.md` 第 177 行。
- **现象**：三级标题写作 `### 4.2 sun_agent-driven-development（SDD，核心执行引擎）`。
- **影响**：`sun_agent` 为拼写错误，正确写法应为 `sub_agent` 或 `subagent`（与前文一致），影响文档的规范性。
- **建议**：修正为 `### 4.2 subagent-driven-development（SDD，核心执行引擎）`。
- **置信度**：High
- **优先级**：LOW

### 3. trellis.md Windows 环境 Python 检测路径描述模糊
- **位置**：`trellis.md` 第 33 行。
- **现象**：文档描述 "在 Windows 上优先 venv/Scoop"。
- **影响**：`venv`（Python 虚拟环境）与 `Scoop`（Windows 命令行包管理器）不是同类概念，并列描述容易造成理解混淆。
- **建议**：修正为 "在 Windows 上优先使用 Scoop 安装的系统级 Python，或检测当前激活的 venv 虚拟环境"。
- **置信度**：High
- **优先级**：LOW

### 4. superpowers.md 跨平台符号链接的兼容性隐患
- **位置**：`superpowers.md` 第 129 行。
- **现象**：文档提到 `AGENTS.md -> CLAUDE.md` 贡献指南采用了 symlink 方式。
- **影响**：在 Windows 开发环境（若未开启系统开发者模式或 Git 的 symlink 支持），符号链接克隆后会退化为普通文本文件，导致 `CLAUDE.md` 无法正常打开或被损坏。
- **建议**：建议考虑以文档引用或构建时复制的形式代替 symlink，增强跨平台兼容性。
- **置信度**：High
- **优先级**：LOW

## 改进建议
1. **状态状态机制统一标准化**：鉴于 `superpowers` 和 `trellis` 都涉及状态管理（如 superpowers 的 Progress Ledger、trellis 的 3-Phase 状态机），建议在 `omni_powers_design.md` 或对比说明中，专门增加一张对比矩阵，澄清二者的生命周期转换差异，这有助于在 omni_powers 执行层进行适配。
2. **术语与概念对齐**：superpowers 中用到了 `subagent-driven-development`，而 trellis 中用到了 `trellis-implement` 和 `trellis-check`。建议文档中明确标注这些特定厂商的概念与 `omni_powers` 自有概念（如 implementer、reviewer）的映射关系。

## 不确定项 / 可能误报
- **关于 superpowers 零外部依赖声明**：`superpowers.md` 第 10 行称 "所有功能纯用 shell / JS / SKILL.md 实现，不依赖 npm 包..."，但第 100 行列出了 `skills/brainstorming/scripts/server.cjs`（零依赖 WebSocket 服务器）。Node.js 的原生 `http` 或 `net` 模块实现 WebSocket 握手和数据帧解析虽然可行，但在无外部依赖（如 `ws` 包）的情况下代码量很大且易出错。此处不排除该服务器实际上依赖了极简的第三方依赖，或者其只是一个轻量占位脚本。建议在后续源码对比中予以核实。
