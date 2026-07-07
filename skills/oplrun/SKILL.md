---
name: oplrun
description: >
  lite 续跑执行（零侵入版）：读 profile → task 循环（implementer → leader 自验 → reviewer 双裁决 → leader 收口）。
  触发：/oplrun、继续、下一步、干活。
  与 heavy 的 oprun 区别：无 hook（leader 亲自验证代替）、无 closer（leader 收口）、脚本自带、per-task 裸评。
---

# Op Lite Run Skill

> **运行前**：`bash "$SCRIPTS/op_check_env.sh"`（jq/git）。
> controller = leader 主会话。lite 无 hook——**leader 每 task 亲自跑测试 + 读 diff 验证**（代替 heavy 的机器校验）。

## 脚本根与 agent 派发（lite 核心）

lite 无 `$OP_HOME`。leader 定位本 skill 脚本目录并注入 agent：

```bash
SKILL_DIR="<本 skill 安装目录>"        # 如 ~/.claude/skills/oplrun
SCRIPTS="$SKILL_DIR/scripts"
OP_SCRIPT_ROOT="$SKILL_DIR"            # 注入 agent，agent 内 ${OP_SCRIPT_ROOT:-$OP_HOME} 走此
```

派 agent 用 `subagent_type`（agent 定义已装 `~/.claude/agents/op-*.md`）。**dispatch prompt 必须注入 `OP_SCRIPT_ROOT` + `OP_PROFILE=lite`**，agent 环境入口据此寻址脚本、走 lite 分支。

**不派 op-closer**——lite 收口由 leader 机械完成（子步骤 3.5）。

## 步骤一：读状态

```bash
cat docs/omni_powers/profile          # 必须 lite，否则停（heavy 项目用 /oprun）
cat docs/omni_powers/op_execution/leader_checkpoint.md
bash "$SCRIPTS/op_jq.sh" all
```

| 条件 | 动作 |
|---|---|
| profile≠lite | 停，提示用 heavy 的 /oprun |
| 全部 status=完成 | 循环结束，进收尾 |
| 存在 status=审阅中 | 先读 verdict 判断续点 |
| 存在 status=进行中 | 先读 report.md 顶部状态 |
| 存在可跑 task | 进循环 |
| 存在 status=待规划 | 提醒用 /oplintake 生成 spec |
| 全部阻塞/跳过/挂起 | 输出原因，等外部解除 |

## 循环

```
选 task（3.1）── 无 ──▶ 收尾
  │ 有
  ▼
派 op-implementer（3.2）→ leader 自验（3.3）→ 派 op-reviewer 双裁决（3.4）
  ├─ 双裁决 PASS ──▶ leader 收口 commit（3.5）─▶ per-task 裸评（3.6）
  │                                       ├─ FAIL(≤3轮) ──▶ 修复 task 回流重验
  │                                       └─ PASS ──▶ P0 检查 ─▶ 归档 ─▶ 回 3.1
  └─ 任一 FAIL
       ├─ 第1轮 ──▶ 回 3.2（fail 模式）
       └─ 第2轮 ──▶ 阻塞(quality)，写 issues，下游跳过 ──▶ 回 3.1
```

### 3.1 选 task

status=待开始、depends_on 全完成、不在阻塞范围、ID 最小。无符合 → 循环结束。

```bash
bash "$SCRIPTS/op_jq.sh" pending
bash "$SCRIPTS/op_jq.sh" deps {TID}      # 确认前置全完成
```

### 3.2 派 op-implementer

leader 先建 task 工作区（不写 brief）：

```bash
mkdir -p docs/omni_powers/op_execution/tasks/{TID}
# report.md/review.md 由 agent 产出；无 brief——dispatch 给指针
bash "$SCRIPTS/op_coder_check.sh" {TID}   # 输出 mode=normal|fail|blocked, round
bash "$SCRIPTS/op_status.sh" {TID} 进行中
sed -i "s/^current_task:.*/current_task: {TID}/" docs/omni_powers/op_execution/leader_checkpoint.md
```

dispatch 指针（不生成文件，prompt 直给）：

```
TID: {TID}
spec: docs/omni_powers/op_execution/specs/{TID}_{slug}.md
取元数据: jq 查 tasks_list.json 该 task（workset/depends_on）
```

派发（注入 lite 环境变量）：

```
Agent(subagent_type="op-implementer", prompt:
  "cd <项目根> && pwd
   环境：OP_PROFILE=lite OP_SCRIPT_ROOT=<oplrun skill 目录>
   {title}（{TID}）。先跑 op_coder_check.sh {TID} 定模式。
   读 spec（路径见 dispatch prompt）+ jq tasks_list 取 workset。TDD 实现（先写映射验收标准的结构层单测，不跑 e2e）。
   写 report.md：顶部总报告（状态 + evidence 命令/路径）+ 分 Round。
   lite 无 blueprint 定向包——spec 是唯一契约源。")
```

| mode | 动作 |
|---|---|
| normal | 正向 TDD |
| fail | 读 review.md 改 blocker |
| blocked | exit 1，直接阻塞不派 |

### 3.3 leader 自验（代 hook，lite 核心）

implementer 返回后 **leader 亲自验证**，不信 agent 自述：

```bash
head -20 docs/omni_powers/op_execution/tasks/{TID}/report.md   # 只读顶部总报告 + evidence 路径
# 按 report 的 evidence 段跑测试命令，读 verdict（不把全量输出纳入上下文）
git diff --stat                                                 # 先看改动面
# 定向读改动核心 hunk（不全量 git diff）
```

### 3.4 派 op-reviewer（双裁决）

```bash
bash "$SCRIPTS/op_status.sh" {TID} 审阅中
```

```
Agent(subagent_type="op-reviewer", prompt:
  "cd <项目根> && pwd
   环境：OP_PROFILE=lite OP_SCRIPT_ROOT=<oplrun skill 目录>
   review {TID}。读 spec（dispatch 给路径）。读 report.md。代码变更：git diff。
   输出 tasks/{TID}/review.md。
   双裁决：规格合规（覆盖验收标准/不偏航）+ 测试可信（测的是验收标准还是 mock/断言用户可观察/危险模式）。
   末行必须 verdict: PASS 或 FAIL。重审末尾追加新 verdict 行。
   lite 无 test.md——测试可信判定依据见 agent 内联 lite 分支。")
```

判定：

```bash
bash "$SCRIPTS/op_read_verdict.sh" {TID}   # exit 0=PASS, 1=FAIL
```

| 结果 | 轮次 | 动作 |
|---|---|---|
| PASS | 任意 | 收口 3.5 |
| FAIL | 第1轮 | 回 3.2 fail 模式 |
| FAIL | 第2轮 | `op_status {TID} 阻塞 quality`，写 issues/{TID}_quality.md，下游跳过，回 3.1 |

### 3.5 leader 收口（代 closer，lite 无「收口中」态）

双裁决 PASS 后 leader 机械收口（**不派 closer**）：

```bash
# ⚠️ lite 无 worktree——implementer 直改主工作树。先 stage 本 task 的代码改动，
#    否则 op_close_post 只 add 三文档路径，src/ 改动会漏出 commit（丢代码）。
git add {workset}          # tasks_list.json 里本 task 的 workset 路径（src/... 与新增测试）
bash "$SCRIPTS/op_close_post.sh" {TID} {feature}   # 校验 PASS + 归档 + progress + 标完成 + stage 文档
```

leader append `op_record/decisions.md`（若本 task 有架构决策），**来源标记 `leader-close`**：

```
## {date} - {TID}: {决策标题} [leader-close]
**决策**：... **理由**：...
```

commit + checkpoint + 验收：

```bash
git status --short         # 确认 src/ 改动已 stage、无遗漏
git commit -m "feat({TID}): {title}"
# leader 手动编辑 leader_checkpoint.md 追加 "- {TID} {title} ✅ {hash}" + 更新关键上下文
bash "$SCRIPTS/close_check.sh" {TID}   # 非 0 不许进下一个 task
```

回 3.1。

## per-task 裸评（task 收口后即验，3.6）

每 task leader 收口 commit 后即派 op-evaluator 做 per-task 裸评。

leader 先机械组装 brief（不参与内容，防污染）：

```bash
bash "$SCRIPTS/op_assemble_eval_brief.sh" {TID}
# 产出 docs/omni_powers/op_execution/acceptance/{TID}/eval_brief.md
```

派发（prompt 极简——内容全在 brief）：

```
Agent(subagent_type="op-evaluator", prompt:
  "cd <项目根> && pwd
   环境：OP_PROFILE=lite OP_SCRIPT_ROOT=<oplrun skill 目录>
   读 docs/omni_powers/op_execution/acceptance/{TID}/eval_brief.md，按 brief 执行 per-task 裸评 {TID}。
   逐条验收标准评估 → PASS 的验收标准 固化成 docs/omni_powers/e2e/{TID}/（lite 零侵入，不进用户测试 runner，§5.3） → 破坏检查 → 对抗探索。
   输出 acceptance/{TID}/eval.md，末行 verdict: PASS 或 FAIL。")
```

> **lite 裸评退化**（§5.7）：无 worktree 隔离、无 baseline 对照、无跨迭代回归，每 task 裸评一次。evaluator 能读到 src/——防"抄实现"底线失效，属 lite 已接受代价。

判定：

- 验收范围内 **FAIL** → 转修复 task 回流（走 task 循环）重验，**≤3 轮**。到顶处置（design §2.5：验收标准 binary gate，不存在降级落 issue）：人裁三选一——继续追加修复轮（显式授权）/ 显式豁免带 FAIL 验收标准归档（记 decisions + 验收标准标 KNOWN-FAIL + 开 P1 issue）/ 转设计 task。范围外发现 → issues。
- 验收 **PASS** → **P0 阻断检查**（代闸门 C 的 P0 阻断语义，design §5.8）：

  ```bash
  bash "$SCRIPTS/op_check_p0.sh"   # exit 0=无 open P0 可归档；exit 1=有 open P0 停下问用户
  ```

  - 有 open P0 → 停下呈报用户三选一：转修复 task 回流 / 显式豁免（leader append decisions.md，来源 `leader-close`，记豁免理由）/ 中止归档
  - 无 open P0 → leader 归档 task：spec 原文移 `op_record/specs/`、task 目录入 `op_record/tasks/{TID}/`、acceptance 工作区移 `op_record/acceptance/{TID}/`，TID 标完成（永不复用）。回 3.1 下一个 task；全部 task 闭环 → 完结报告。

> lite 无闸门 C、无 closer——leader 直接归档（无 blueprint 合入，因 lite 无 blueprint 真相源）。

## 看进度（lite 内联状态渲染，代 opstatus）

lite 不单装 opstatus——用户说"看进度/现在啥情况"时，leader 内联渲染（只读，不改文件）：

```bash
cat docs/omni_powers/profile
cat docs/omni_powers/op_execution/leader_checkpoint.md
bash "$SCRIPTS/op_jq.sh" all
bash "$SCRIPTS/op_jq.sh" blocked
```

渲染格式：

```
== profile == lite
== 上次断点 == {checkpoint 摘要}
== task 进度 ==
  T01 ✅完成  {title}
  T02 🔄进行中 {title}
  T03 ⏳待开始 (依赖 T02) {title}
  T04 🚫阻塞 (quality) {title}
== 下一步 == {下一个可跑 task 或阻塞原因}
```

## 收尾

- 全部完成：检查 issues/ 有无 tech-debt，提示处理
- 有待规划：提示用 /oplintake
- 全部阻塞/挂起：输出原因

## compact 恢复

1. 读本 SKILL + `docs/omni_powers/profile`（确认 lite）
2. `bash "$SCRIPTS/op_jq.sh" all`
3. 有未归档 tasks/{TID}/ 则从 report.md + review.md 重建状态
4. 重选 task 进循环

## 相关文件

| 文件 | 用途 |
|---|---|
| `scripts/op_jq.sh` | tasks_list 查询 |
| `scripts/op_status.sh` | 状态流转（lite 枚举，无收口中） |
| `scripts/op_coder_check.sh` | implementer 模式判定 |
| `scripts/op_read_verdict.sh` | verdict 读取 |
| `scripts/op_close_post.sh` | 收口机械步骤（无收口中，自探测同目录 op_status） |
| `scripts/op_assemble_eval_brief.sh` | per-task 裸评 evaluator brief 组装（lite 裸评版） |
| `scripts/close_check.sh` | 收口验收 |
| `scripts/op_check_p0.sh` | P0 阻断检查（per-task 裸评 PASS 后归档前扫 open P0） |
| `scripts/op_check_env.sh` | 环境检查（jq/git） |
