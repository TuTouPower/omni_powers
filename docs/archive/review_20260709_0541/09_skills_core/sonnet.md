## 当前模型判断依据

主会话可观测配置：`settings.json` 顶层 `model=haiku`；`ANTHROPIC_DEFAULT_HAIKU_MODEL=default_haiku`；`ANTHROPIC_DEFAULT_SONNET_MODEL=default_sonnet`；`ANTHROPIC_DEFAULT_OPUS_MODEL=default_opus`。本审阅以 sonnet 视角执行，独立判断，不参考其他路审阅。

## 审阅范围

模块 09_skills_core，8 个文件：

- `skills/opinit/SKILL.md`
- `skills/opinit/scripts/opinit_register_hooks.sh`
- `skills/opinit/scripts/opinit_skeleton.sh`
- `skills/opintake/SKILL.md`
- `skills/opred/SKILL.md`
- `skills/opspec/SKILL.md`
- `skills/opstatus/SKILL.md`
- `skills/optriage/SKILL.md`

设计文档 `docs/omni_powers_design.md` 作为上下文参考，不重复审阅。排除 `vendors/` 与 `docs/archive/`。

---

## 高优先级问题（CRITICAL / HIGH）

### H1. optriage/SKILL.md 无 profile 感知——lite 模式下不可用

- **位置**：`skills/optriage/SKILL.md` 全文
- **现象**：optriage SKILL.md 直接引用 `$OP_HOME/scripts/op_check_env.sh`、`$OP_HOME/scripts/op_new_task.sh`，且多次提及「闸门 C」。没有任何 profile 感知分支（无 lite fallback、无 `OP_PROFILE` 判断、无共享 scripts 目录寻址）。对比 opstatus/SKILL.md 顶部有明确的 profile 感知注释段，optriage 完全没有。
- **影响**：lite 模式下 leader 收尾调用 optriage 时，`$OP_HOME` 可能未设（lite 用户可不跑 `--set-ophome`），脚本寻址失败。lite 无 closer、无闸门 C，当前 optriage 流程引用的概念在 lite 下不适用。
- **建议**：参照 opstatus/SKILL.md 的 profile 感知模式，增加 lite 分支：用 `${OP_SCRIPT_ROOT:-$OP_HOME}` fallback 寻址脚本；闸门 C 段落标注 `heavy only`；leader 收尾段区分 heavy（oprun 驱动 closer 后调）与 lite（oplrun 驱动 leader 直接调）。
- **置信度**：高。design §2.6/§5.6 明确了 heavy/lite 收口差异，且 opstatus 已有 profile 感知实现。
- **优先级**：HIGH

### H2. opspec 可测性契约「必填，无 N/A 例外」与非行为型 task 矛盾

- **位置**：`skills/opspec/SKILL.md`，spec 模板「可测性契约」段
- **现象**：模板写明「可测性契约（必填，design §2.2——无 N/A 例外）」，要求每条 AC 配备验收信号、通道、测试缝。但 design §2.4 明确免除三类非行为型 task 的 evaluator 派发（接口先行/脚手架/纯内部重构），这些 task 的 AC 如「编译通过」「目录结构就位」不存在用户可观察运行时行为，「应用启动方式」「CDP/cua/直驱 通道」无从填写。
- **影响**：opintake/leader 在写非行为型 task 的 spec 时，被迫为不存在的 UI/运行时行为编造测试缝，产生噪音，降低 spec 可信度。或者 spec 编写者因填不出而卡住。
- **建议**：在模板「可测性契约」段增加条件判断：若 task 的 `type` 为接口先行/脚手架/纯内部重构（或 AC 全为编译期/结构性检查），可测性契约段可标注 `N/A（非行为型 task，验收由 reviewer + 编译器/类型检查承担，design §2.4）`。同时在 opspec 流程第 2 步「选模板」处根据 change type 判定是否要求完整可测性契约。
- **置信度**：高。design §2.4 明确有三类免派 evaluator 的 task。
- **优先级**：HIGH

### H3. opinit_register_hooks.sh：trap 注册晚于可能失败的操作，导致临时文件泄漏

- **位置**：`skills/opinit/scripts/opinit_register_hooks.sh`，第 31-52 行
- **现象**：脚本在 `case "$(uname -s)"` 分支内（第 33-50 行）执行 `mktemp` + `jq` 写入临时文件 `$TMP_TEMPLATE`。`set -euo pipefail` 下，若该分支内 `jq` 失败，脚本立即退出。但 `trap '[ -n "${TMP_TEMPLATE:-}" ] && rm -f "$TMP_TEMPLATE"' EXIT` 在第 52 行（case 语句之后）才注册。中间任何失败都会留下孤儿临时文件。
- **影响**：Windows Git Bash/MSYS2 环境下模板路径替换失败时，`/tmp/` 残留 `mktemp` 生成的临时文件。
- **建议**：将 trap 注册移到 case 语句之前（第 31 行 `TMP_TEMPLATE=""` 初始化之后即可），确保无论 case 分支内何处失败都能清理。
- **置信度**：高。`set -e` 与 trap 注册时序是确定性 bug。
- **优先级**：HIGH

### H4. opred/SKILL.md 引用已删除脚本 + 锁定机制描述与实际实现脱节

- **位置**：`skills/opred/SKILL.md`，第 55 行
- **现象**：「test_lock.sh 已删 Q3——锁定靠 pre_tool_use `e2e/*` 硬编码 hook，无细粒度锁；解锁 = leader 直接改实现/测试，记 decisions.md」。引用了已删除的脚本，且描述的实现路径（pre_tool_use hook）对 subagent 场景完全无效（design §0.1 明确声明 hook deny 对 subagent 失效）。implementer 和 reviewer 作为 subagent 读取此协议时，看到的锁机制描述与实际防护能力不符。
- **影响**：implementer 可能误以为存在机械锁而谨慎操作（过度约束），或反过来发现 hook 不生效后不信任整个协议。reviewer 审查时可能引用不存在的锁定流程。
- **建议**：重写「锁定文件解锁」段，诚实描述当前两层防护的实际情况：(1) merge gate 硬拦 task 分支 e2e 变更入主分支（design §3.4），这是对 implementer 的真正硬防线；(2) pre_tool_use 仅对 leader 主会话生效（advisory）。删除对 `test_lock.sh` 的引用。leader 审批→解锁→改测试→记 decisions 的流程保留，但注明「解锁 = leader 直接改文件，由 merge gate + commit trailer 配对提供事后审计（design §2.5）」。
- **置信度**：高。design §0.1/§0.2/§3.4 均声明了 hook 对 subagent 的失效。
- **优先级**：HIGH

---

## 中低优先级问题（MEDIUM / LOW）

### M1. opinit/SKILL.md 步骤三设计文档引用错误

- **位置**：`skills/opinit/SKILL.md`，第 73 行
- **现象**：Agent prompt 中引用 `$OP_HOME/docs/omni_powers_design.md §3.3` 作为「文档职责矩阵」的出处。但设计文档中职责矩阵位于 §1.3，§3.3 是「机械护栏」。
- **影响**：blueprint-generator Agent 如果按照 §3.3 去找文档职责矩阵，会找到完全不相关的内容（hook 防线层映射表），导致 blueprint 文档职责分工出错。
- **建议**：将 `§3.3` 改为 `§1.3`。
- **置信度**：高。直接比对 SKILL.md 文本与 design.md 实际位置。
- **优先级**：MEDIUM

### M2. opstatus/SKILL.md 步骤 2 的脚本路径在 lite 模式下不可用

- **位置**：`skills/opstatus/SKILL.md`，第 28-31 行
- **现象**：步骤 2 的命令全部硬编码 `bash "$OP_HOME/scripts/op_jq.sh"`。顶部虽声明 lite 项目「脚本寻址用共享 scripts 目录（`$SCRIPTS` = `~/.claude/scripts/omni_powers/`）」，但实际命令中没有应用此 fallback。而且 `$SCRIPTS` 变量名与 design §5.4 定义的 `${OP_SCRIPT_ROOT:-$OP_HOME}` 不一致。
- **影响**：lite 用户执行 `/opstatus` 时，步骤 2 的 jq 查询命令因 `$OP_HOME` 未设而失败。
- **建议**：统一使用 design §5.4 的 fallback 机制。在步骤 2 前加一个变量赋值：`SCRIPTS="${OP_SCRIPT_ROOT:-$OP_HOME}/scripts"`，后续命令用 `bash "$SCRIPTS/op_jq.sh"`。同时顶部 profile 感知段将 `$SCRIPTS = ~/.claude/scripts/omni_powers/` 改为引用 `${OP_SCRIPT_ROOT:-$OP_HOME}`。
- **置信度**：高。lite 用户不跑 `--set-ophome` 是明确的设计决策。
- **优先级**：MEDIUM

### M3. opinit_register_hooks.sh：grep "omni_powers" 判断已有 hook 归属，可能误覆盖用户 hook

- **位置**：`skills/opinit/scripts/opinit_register_hooks.sh`，第 79 行
- **现象**：`grep -q "omni_powers" "$hooks_dir/$name"` 用于判断 `.git/hooks/` 下的已有 hook 是否为 omni_powers 生成。若用户自己的 pre-commit hook 恰好包含 "omni_powers" 字符串（如注释 `# 与 omni_powers 配合使用`），会被误判为 omni_powers 生成然后被覆盖。
- **影响**：用户自定义 git hook 被静默覆盖。发生概率低但后果严重。
- **建议**：在 omni_powers 生成的 git hook 文件头部加入唯一标识行（如 `# omni_powers-generated hook v1`），grep 匹配该精确标识而非泛泛的 "omni_powers" 字符串。或改用更可靠的检测方式：记录已安装 hook 的 checksum 到专用标记文件。
- **置信度**：中。取决于用户的 hook 是否恰好包含该字符串。
- **优先级**：MEDIUM

### M4. opinit_register_hooks.sh：jq `walk` 需 jq 1.6+，未做版本检查

- **位置**：`skills/opinit/scripts/opinit_register_hooks.sh`，第 40-48 行
- **现象**：Windows 路径替换使用 `jq 'walk(...)'`，`walk` 内置于 jq 1.6（2018 年发布）。虽然 jq 1.6 已发布多年，但部分老旧环境（尤其是通过系统包管理器安装的长期支持发行版）可能仍用 jq 1.5。脚本在前面只检查了 `command -v jq`，没有检查版本。
- **影响**：旧版 jq 上 `walk` 未定义，脚本在 Windows 环境下失败且错误信息不友好（`jq: error: walk/1 is not defined`）。
- **建议**：增加 jq 最低版本检查：`jq --version` 解析版本号，≥1.6 才继续，否则提示升级。或在 MINGW 分支用不依赖 `walk` 的替换逻辑（手动递归）。
- **置信度**：中。取决于目标环境的 jq 版本。
- **优先级**：MEDIUM

### M5. opinit_skeleton.sh：非 git 仓库时 `pwd` fallback 不可靠

- **位置**：`skills/opinit/scripts/opinit_skeleton.sh`，第 7 行
- **现象**：`ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"`。若用户当前目录不是项目根（如在子目录中运行 `/opinit`），且 git 命令失败，`pwd` 返回的是子目录而非项目根，三区骨架会建在错误位置。
- **影响**：`docs/omni_powers/` 建在子目录下，后续 oprun/opstatus 找不到。需要手动移动或重跑。
- **建议**：增加检测：若 git 失败，向上遍历目录树查找包含 `CLAUDE.md` 或 `package.json` 等标志文件的目录作为项目根。若找不到，显式提示用户切换到项目根再跑。
- **置信度**：中。设计要求 opinit 在项目根执行，但未机械强制。
- **优先级**：MEDIUM

### M6. opintake/SKILL.md 相关文件表 opspec 路径重复

- **位置**：`skills/opintake/SKILL.md`，第 96-103 行
- **现象**：表格中 `skills/opspec/SKILL.md` 出现了两次：一次「spec 模板与设计探索（内部 skill，被本 skill 调用）」，一次「spec 模板来源（`op_execution/specs/{TID}_{slug}.md` 由 opspec 生成）」。
- **影响**：可读性差，无功能影响。
- **建议**：合并为一条。
- **置信度**：高。
- **优先级**：LOW

### M7. optriage/SKILL.md 调用者声明自相矛盾

- **位置**：`skills/optriage/SKILL.md`，第 14-15 行 vs 第 131 行
- **现象**：第 14-15 行触发条件包括「用户显式 `/optriage`、分诊、处理 issue」；第 131 行注意段写「leader 是本 skill 的唯一调用者」。两处矛盾。
- **影响**：用户看到第 14 行会认为自己可以直接调 `/optriage`，但第 131 行说只有 leader 能调。行为不明确。
- **建议**：统一表述。若用户可直调，第 131 行改为「leader 是主要调用者，用户也可显式调用」。若不可，去掉第 14-15 行的用户显式触发描述。
- **置信度**：高。
- **优先级**：LOW

### M8. opspec/SKILL.md 模板「不变量与 domain.md 冲突」在 lite 模式无意义

- **位置**：`skills/opspec/SKILL.md`，spec 模板第 53 行
- **现象**：模板中不变量段写「与 `docs/omni_powers/op_blueprint/domain.md` / 生效规格冲突必须显式标注」。顶部虽有 profile 感知声明（lite 跳过 `op_blueprint/`），但 spec 模板正文没有条件分支。lite 模式下 spec 编写者看到此提示会尝试找不存在的 domain.md。
- **影响**：lite 用户困惑或浪费时间查找不存在的文件。
- **建议**：在模板中增加 lite 条件注释：`<!-- lite: op_blueprint 为空壳，domain.md 不存在，跳过此检查 -->`。或 profile 感知段明确说明「lite 下模板中的 op_blueprint 引用条款自动不适用」。
- **置信度**：中。顶部 profile 感知声明已有提示，但模板正文容易被独立复制/引用而丢失上下文。
- **优先级**：LOW

### M9. opinit_register_hooks.sh 备份文件重名风险

- **位置**：`skills/opinit/scripts/opinit_register_hooks.sh`，第 55 行
- **现象**：`.claude/settings.json.bak.$(date +%s)` 使用 Unix 时间戳做备份后缀。若同一秒内两次运行脚本，第二次备份覆盖第一次。虽然概率极低（需手动跑两次且在同一秒内），但备份被覆盖意味着丢失了第一次备份的状态。
- **影响**：极低概率的数据丢失。
- **建议**：加纳秒精度或随机后缀：`$(date +%s%N 2>/dev/null || date +%s)_$RANDOM`。
- **置信度**：中。概率极低但修复成本也为零。
- **优先级**：LOW

### M10. opinit/SKILL.md 步骤零浏览脚本对空目录静默失败

- **位置**：`skills/opinit/SKILL.md`，第 21-29 行
- **现象**：浏览命令 `ls *.md 2>/dev/null` 在没有 .md 文件时静默失败（无输出），leader 可能误以为「根目录无 .md 文件需要关注」。但实际上可能有 `.txt`/`.rst`/`.adoc` 等其他格式的文档。类似地，`grep -rilE 'task|plan|todo' docs *.md 2>/dev/null` 中 `*.md` 在无匹配时 bash 传递字面字符串给 grep。
- **影响**：步骤零未发现所有文档/计划文件，导致归档不完整或错过未执行计划。
- **建议**：用 `find` 替代 `ls` + glob 组合，覆盖更多文档格式。`grep -rilE 'task|plan|todo' docs/ *.md 2>/dev/null` 改为 `find docs/ . -maxdepth 1 -type f | xargs grep -rilE 'task|plan|todo' 2>/dev/null`。
- **置信度**：低。多数项目有 .md 文件。
- **优先级**：LOW

---

## 改进建议

### S1. 建立 opintake/optriage 的 profile 感知一致性

当前 profile 感知在各 skill 中分布不均：opstatus 有完整的 profile 感知头，opspec 有顶部声明，optriage 完全没有，opintake 仅有互斥检查但无 lite 脚本寻址。建议：

- 为所有 skill 建立统一的 profile 感知模板段（类似 opstatus 的顶部注释），包含：profile 互斥检查、脚本寻址 fallback、lite 分支行为差异。
- 这将减少 lite 用户遇到 `$OP_HOME` 未设错误的频率，也与 design §5.4 的「两版共用一份文件」目标一致。

### S2. opred 增加 lite 分支说明

opred 多处引用 closer（归因提取、decisions.md append），但 closer 是 heavy 独有。建议在文件顶部增加 lite 分支说明：

```
> **profile 感知**：lite 模式下无 closer；归因提取由 leader 在收口时直接从 report.md 提取 append 到 decisions.md（design §5.6）。锁定机制在 lite 下退化为 leader 纪律 + git diff 审计。
```

### S3. opinit_skeleton.sh 的 leader_checkpoint.md 模板增加初始有效值

当前模板 `current_task:` 后无值，`last_completed:` 后无值。opstatus 等读取 checkpoint 的工具若做字符串比较或非空检测，空值可能导致未定义行为。建议模板中填充明确的占位值：`current_task: none`、`last_completed: none`。

### S4. 考虑将 hook 注册与 git hook 注册解耦

`opinit_register_hooks.sh` 同时注册 Claude Code hooks（settings.json）和 git hooks（.git/hooks/）。两者失败模式不同：前者影响 heavy 全流程，后者只影响 spec 写保护。当前脚本在前者成功后继续执行后者，但后者失败不阻塞。建议将两者拆为独立步骤，各有独立错误处理与报告，便于调试。

---

## 不确定项 / 可能误报

### U1. opinit_register_hooks.sh 中 `chmod +x` 在 Windows 上的行为

第 66 行 `chmod +x "$OP_HOME/hooks/"*.sh "$OP_HOME/hooks/run-hook.cmd" 2>/dev/null` 在 Windows Git Bash 环境下的实际行为不确定。Git Bash 的 chmod 通常 no-op，脚本可能依赖 hook 文件已有执行权限。`2>/dev/null` 抑制了所有错误，若 chmod 失败且 hook 确需执行权限，问题会被掩盖。但 design 中提到 polyglot wrapper 机制，可能 `.cmd` 文件不依赖 POSIX 权限。由于无法实测 Windows 环境，标为不确定。

### U2. optriage 的 「闸门 C」段落是否应完全删除

当前 optriage 步骤 5 为「闸门 C 呈报」。按 design §5.1，lite 无闸门 C。但 heavy 确实需要此步骤。问题是 optriage 是否会从 lite 上下文被调用——若 lite leader 收尾时跳过 optriage，则保留闸门 C 段落无问题。若 lite 也调 optriage，则需分支。当前 H1 已标记 profile 感知缺失，若 H1 修复，此问题一并解决。

### U3. opspec 通道判定中 CDP 对 Electron 的约束

第 131 行写「生产包通常关 CDP，需 dev/test 构建开 `--remote-debugging-port`」。此为正确的技术说明，但 spec 编写者可能不知道如何构建 dev/test 版本。建议在 conventions.md 或项目 test.md 中收录 dev/test 构建命令，spec 的可测性契约引用之。不过这不属于本模块审阅范围。
