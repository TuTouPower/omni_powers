# Haiku 审阅报告

## 当前模型判断依据

settings.json 顶层 `model` 为 `haiku`；`ANTHROPIC_DEFAULT_HAIKU_MODEL=default_haiku[1m]`；主会话可见标识 `default_model`。继承 `default_model`（settings 默认 haiku）执行审阅，无法确认实际底层模型 ID。

## 审阅范围

审阅两次 commit：`93aa4c2`（feat: 落地 op_merge_gate.sh 写入硬底线）+ `341af55`（fix: 修复既有脚本 bug + 过时测试，bats 全套 60/60 绿）。

14 个目标文件逐段审阅，不抽样。

---

## 高优先级问题（CRITICAL / HIGH）

### H1. op_merge_gate.sh 结构层测试判定遗漏 `__tests__/` 目录

**位置**：`scripts/op_merge_gate.sh:76-87`，`is_struct_test()` 函数

**现象**：函数对 `tests/` 目录下的文件放行（`*/tests/*|tests/*`），但未覆盖 `__tests__/` 命名约定。Jest/Vitest 等框架常用 `__tests__/` 目录存放实现侧单测，当前 glob 会将其判为白名单外文件，导致合法单测被 merge gate REJECT。

**影响**：使用 `__tests__/` 目录的项目在执行 merge gate 时，所有实现侧单测变更均被机械拒绝，task 分支无法合入主分支。白名单漏项导致硬底线过度拦截。

**建议**：在 `is_struct_test()` 的 `case` 分支追加 `__tests__/*)` 匹配。

**置信度**：高（可直接复现——在 `__tests__/foo.test.ts` 改动后跑 merge gate 即 REJECT）

**优先级**：HIGH

---

### H2. op_close_post.sh eval 豁免值与设计文档不一致

**位置**：`skills/oprun/scripts/op_close_post.sh:43-44`；`tests/scripts/helpers.bash:22`

**现象**：脚本用 `[ "$EVAL_SKIP" != "skip" ]` 判定是否豁免 acceptance_report.md 检查。字面值 `"skip"` 未被设计文档 §2.5（D9）记录为合法 eval 值——文档规定 eval 为 `"required"` 或免派理由文本（如 `"接口先行"`）。测试夹具直接使用 `"eval":"skip"` 配合此逻辑。

**影响**：若 leader 按设计文档填写 eval 字段为 `"接口先行"`（免派理由），当前逻辑仍会检查 acceptance_report.md（`"接口先行" != "skip"` 为 true），导致非行为型 task 收口时被误拦（缺少 acceptance_report.md 而 die）。脚本实际行为正确（只有显式 `"skip"` 才豁免），但字段语义与文档脱节。

**建议**：二选一：(a) 设计文档 §2.5 明确记录 `eval: "skip"` 为豁免哨兵值；(b) 改脚本逻辑为按 `"required"` 判定（`[ "$EVAL_SKIP" = "required" ]` 才检查），其余值一律豁免。

**置信度**：高

**优先级**：HIGH

---

### H3. op_merge_gate.sh 无 diff 时直接 exit 0 可能放行空 task

**位置**：`scripts/op_merge_gate.sh:49-52`

**现象**：当 task 分支相对主分支无改动时（空 diff），脚本直接 `exit 0` 并输出 `[WARN] ... 无东西可合`，跳过后继所有检查（包括 review verdict 校验）。若 implementer 的 task 分支被误重置或 squash 后才跑此脚本，merge gate 会静默 PASS。

**影响**：review verdict 未 PASS 的空 task 分支可被误合。虽然"无东西可合"这一现实使实际损害为零，但静默 PASS 绕过了 review verdict 检查这一设计意图。

**建议**：空 diff 场景仍跑 review verdict 校验（至少确认主分支 review.md 末行 PASS），或改为 exit 0 前显式输出"无改动，跳过 review 检查（无内容可合）"。

**置信度**：中

**优先级**：MEDIUM

---

### H4. op_closer_gate.sh `git status --porcelain` 对重命名文件可能漏判

**位置**：`scripts/op_closer_gate.sh:20`

**现象**：`git status --porcelain | awk '{print $2}'` 对重命名文件（`R  old -> new`）只会提取旧文件名（`old`），新文件名（`new`）落在 `$4` 及之后字段，不会进入 CHANGED 数组。若 closer 通过 `git mv` 操作重命名文件，越界的新文件路径不会被检测到。

**影响**：closer 通过重命名将文件移出白名单范围时，越界检查漏检新路径。实际操作中 closer 无权执行 `git mv`（权限清单 §2.6 不包含 git 操作），此风险主要来自 closer gate 自身实现假设变化后的防御缺口。

**建议**：追加 `git diff --name-only HEAD` 作二次校验（diff 不含重命名状态列的歧义），或改用 `git diff --name-status` 逐状态提取。

**置信度**：中（需 closer 越权 + 重命名双重条件同时发生）

**优先级**：MEDIUM

---

## 中低优先级问题（MEDIUM / LOW）

### M1. op_jq.sh deps 子命令 for 循环未加引号

**位置**：`scripts/op_jq.sh:40`

**现象**：`for d in $DEPS; do` 使用未加引号的变量展开。`$DEPS` 含空格或特殊字符时会被 word splitting 拆碎。TID 格式限定为 `T0001` 等无空格标识符，当前不影响正确性。

**影响**：当前无实际影响；属 shell 最佳实践违规。

**建议**：改为 `while IFS= read -r d; do ... done <<< "$DEPS"`，或加注释声明 TID 格式不包含空格故不引号。

**置信度**：高

**优先级**：LOW

---

### M2. opinit_skeleton.sh e2e 目录探测逻辑可能误导用户

**位置**：`skills/opinit/scripts/opinit_skeleton.sh:32-39`

**现象**：当用户 project 已存在顶层 `e2e/` 时，脚本输出 WARN 但仍强制创建 `tests/e2e/`。WARN 消息称"已有 e2e/ 不会被纳入保护语义"，但未向用户确认是否迁移已有 e2e 到 `tests/e2e/`。

**影响**：用户可能有两个 e2e 目录（原有 + 新创建），且旧 e2e 不在保护范围内。轻度混乱。

**建议**：检测到顶层 `e2e/` 时用 `die` 提示用户先迁移再重跑，或提供 `--e2e-dir` 参数覆盖默认路径。

**置信度**：中

**优先级**：LOW

---

### M3. op_merge_gate.sh review verdict 提取假设 review.md 已在主分支提交

**位置**：`scripts/op_merge_gate.sh:131`

**现象**：`git show "$BASE:$REVIEW_PATH"` 读取主分支（base）tree 中的 review.md。若 leader 刚写入 review.md 到工作区但尚未 commit 到主分支，merge gate 读到的将是旧版本（或无文件），导致误判"verdict 缺失"。

**影响**：要求 merge gate 运行前 review.md 已提交到主分支。若工作流顺序出错（先跑 gate 再 commit review.md），合法 PASS 被拒。设计 §3.4 已明确"leader 落盘到主分支"，此要求是设计意图而非实现缺陷。

**建议**：在 merge gate 文档注释或 SKILL.md 中显式标注前置条件："merge gate 前必须 commit review.md 到主分支"，降低操作失误概率。

**置信度**：高

**优先级**：LOW

---

### M4. 测试覆盖 gap：op_close_post 缺少 acceptance_report 和 eval 豁免测试

**位置**：`tests/scripts/op_close_post.bats`（共 4 个 @test）

**现象**：当前测试只覆盖：缺参数 die / verdict PASS 归档 / verdict FAIL 拒绝 / verdict 缺失拒绝。缺少以下关键路径：
- acceptance_report.md 缺 verdict → die（D6 验收前置）
- eval:skip 豁免 acceptance_report 检查
- progress.md 幂等追加（重跑不重复写入同一 TID 行）

**影响**：D6 验收前置硬门禁缺测试覆盖，回归风险。

**建议**：补齐上述 3 个测试用例。

**置信度**：高

**优先级**：MEDIUM

---

### M5. 测试覆盖 gap：op_merge_gate 缺少 e2e 保护路径和空 diff 测试

**位置**：`tests/scripts/op_merge_gate.bats`（共 5 个 @test）

**现象**：缺少以下测试：
- e2e/ 路径变更（含 BUG-* 文件）→ REJECT
- tasks_list.json 变更 → REJECT
- 空 diff（无改动）→ exit 0 + WARN
- spec 文件变更 → REJECT

**影响**：e2e 保护路径（写入硬底线的核心受保护目标）缺直接测试覆盖。

**建议**：补齐上述 4 个测试用例。

**置信度**：高

**优先级**：MEDIUM

---

### M6. 设计文档 §5.1 与 §5.5 脚本寻址描述不一致

**位置**：`docs/omni_powers_design.md:752`（§5.1 差异面表） vs `docs/omni_powers_design.md:813`（§5.5）

**现象**：§5.1 表称 lite 脚本寻址为 `${OP_SCRIPT_ROOT:-$OP_HOME}` fallback；§5.5 称 lite 与 heavy 统一用 `$OP_HOME/scripts/`，`OP_SCRIPT_ROOT` 变量未被任何已落地脚本引用。两处描述矛盾，§5.5 是实际落地版本。

**影响**：文档读者按 §5.1 理解脚本寻址逻辑时会被误导。

**建议**：将 §5.1 差异面表的脚本寻址行更新为 §5.5 的统一方案（`$OP_HOME/scripts/`），删除 `OP_SCRIPT_ROOT` 引用。

**置信度**：高

**优先级**：LOW

---

### M7. tests/helpers.bash 固定 OP_HOME 路径与 bats 的 BATS_TEST_FILENAME 耦合

**位置**：`tests/scripts/helpers.bash:6`

**现象**：`OP_HOME="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"` 硬编码上溯两级。若 helpers.bash 被移动到其他目录（如 `tests/integration/helpers.bash`），路径解析会出错。但 helpers 本身有 `load helpers` 的 bats 加载机制约束位置，短期不会移动。

**影响**：低——当前目录结构稳定。

**建议**：改为从仓库根探测（`git rev-parse --show-toplevel`），与生产脚本对齐。

**置信度**：中

**优先级**：LOW

---

## 改进建议

### S1. op_merge_gate.sh 增加 `tests/` 外测试文件模式支持

当前 `is_struct_test()` 识别的模式集为 `*.test.*|*.spec.*|*_test.*|*_test|*/tests/*|tests/*`。可考虑追加：
- `__tests__/*`（Jest/Vitest 约定）
- `*Test.*`（JUnit/Kotlin 约定）
- `*_spec.rb`（RSpec 约定）

是否添加取决于项目技术栈，建议将模式列表外置为可配置项或至少在设计文档中声明"当前仅覆盖特定框架模式，新框架需补模式"。

### S2. op_closer_gate.sh 增加防御性 `git diff` 双重校验

在当前 `git status --porcelain` 基础上增加 `git diff --name-only HEAD` 二次确认，两个来源的结果取并集，降低状态列解析遗漏风险（对齐 op_merge_gate.sh 已采用的 diff 方式）。

### S3. 统一 eval 字段的哨兵值语义

当前 `op_close_post.sh` 使用 `"skip"` 作为豁免哨兵，但 `tasks_list.json` schema（design §2.3）定义 eval 为 `"required"` 或原因文本。建议明确记录两种哨兵值：`"required"`（需要 evaluator）和 `"skip"`（显式豁免），其余值视为原因文本且默认不豁免 acceptance_report 检查（即当前脚本行为）。

### S4. opinit_skeleton.sh e2e 目录探测改为交互式

检测到冲突（已有顶层 `e2e/`）时不是仅 WARN 而是要求用户通过参数确认：`--e2e-dir tests/e2e` 或 `--e2e-dir e2e`，避免自动决策造成之后 merge gate 保护范围与用户预期不符。

### S5. 补齐测试缺口（M4 + M5）

`op_close_post.bats` 补 3 个用例（acceptance_report verdict / eval:skip / progress 幂等），`op_merge_gate.bats` 补 4 个用例（e2e 保护 / tasks_list 保护 / 空 diff / spec 保护）。优先补 e2e 保护路径测试——那是硬底线的核心受保护目标。

---

## 不确定项 / 可能误报

### U1. op_merge_gate.sh `*_test` 无扩展名匹配的意图

`*_test` 模式（不带 `.*` 后缀）可匹配 `foo_test`（无扩展名），但也匹配 `foo_test_extra`（`*` 吞掉 `_extra`）。若存在文件 `foo_test_helper.py`，`*_test.*` 匹配（`foo_test_helper` + `.py`），但也可能误匹配非测试文件 `my_test_data.json`（`my_test` + `_data.json`）。这可能是有意为之（宁可多放行少阻拦），也可能引入白名单过宽。标记为**不确定**——取决于实际项目文件命名约定。

### U2. op_closer_gate.sh 白名单路径前缀匹配的边界

`ALLOWED` 路径使用 `case "$f" in "$a"*)` 前缀匹配。`docs/omni_powers/op_execution/issues/` 作为前缀匹配 `/issues/` 下的所有文件，符合意图。但如果 closer 创建文件 `docs/omni_powers/op_execution/issues_README.md`（issues 目录的兄弟文件以 `issues` 为前缀），路径 `docs/omni_powers/op_execution/issues` 作为前缀也会匹配到它。当前脚本中 `ALLOWED` 的 `issues/` 条目以 `/` 结尾，避免此问题。但 `decisions.md` 条目无尾 `/`——若存在 `decisions.md.backup` 同级文件也会被放行。实际风险极低（closer 权限清单不涉及文件创建模式），标记为**不确定**。

### U3. 设计文档 §5.7 evaluator 裸评退化中 A11 提示词级隔离的实际强度

文档称 lite 下 evaluator 独立性"靠提示词级隔离维持"，设计承认"无文件系统隔离（evaluator 物理能读 src/，提示词约束是 lite 唯一防线，弱于 heavy 结构隔离）"。此退化是 lite 模式的设计取舍（用零侵入换安全性下降），不属于实现缺陷。标记为**不确定**——作为审阅意见记录：若 lite 模式未来要求更高的 evaluator 独立性，需要在提示词之外增加文件系统层隔离。

---

## 总体评价

两次 commit 的核心交付（`op_merge_gate.sh` 写入硬底线 + 既有脚本 bug 修复 + bats 60/60 绿）质量扎实。merge gate 的白名单/黑名单逻辑正确，closer gate 的越界检查务实，测试覆盖了主要路径。

主要关注点：
1. **H1**（`__tests__/` 目录白名单遗漏）是实际可触发的 REJECT，应优先修复。
2. **H2**（eval 字段语义不一致）是文档与代码的契约偏差，不改会导致 leader 填写 eval 字段时出错。
3. 测试缺口（M4/M5）虽不阻塞当前功能，但核心路径缺测试覆盖是长期维护风险。
