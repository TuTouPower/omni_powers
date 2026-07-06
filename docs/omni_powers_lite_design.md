# Omni Powers Lite: 零侵入轻量版设计方案

> **定位**：本项目同时支持 **heavy**（现状全量）与 **lite**（零侵入）两种模式。
> lite 与 heavy 的唯一区别是**不侵入宿主环境**——不加 hook、不改 Claude Code 配置、不改用户已有文件。
> **Agent 协作是本质**：leader / op-implementer / op-reviewer / op-evaluator 四角色**职责模型两版共享**（agent 定义需 profile 化后方可共用，见 §8；lite 减 op-closer）。
>
> 本文档只写 lite 相关设计与两版共存架构。heavy 现状见 `omni_powers_design.md` / `RULES.md`。
>
> **本版据三份审阅意见 + 亲核代码现状修订**（脚本清单、角色数、状态文件名、agent 硬编码均已核对）。

---

> ## ✅ 文档定位：lite 已实现（2026-07-06）
>
> 全量安装器 + lite 三入口 + agent profile 化 + Stage 4 裸评 + RULES 分叉全部落地并验证。详见 §14 落地状态。
>
> **lite 是 degraded mode，不是 heavy 同等安全版**：无 hook 强制、无 worktree 隔离、无 baseline 对照、evaluator 裸评。用它换零侵入（不侵入用户项目）。
>
> 全文标注约定：
> - 措辞「共享」指「职责模型共享，agent/脚本经 `${OP_SCRIPT_ROOT:-$OP_HOME}` fallback 两版共用一份」。
> - 「零侵入」= 不侵入用户**项目**（不装项目 hook、不改项目已有文档）；全局 `~/.claude` 全量安装是用户主动配置。

## 1. 核心原则

### 1.1 角色：职责共享，环境入口 profile 化

- **四角色职责模型两版共享**——但 **agent 定义文件当前是纯 heavy【现状】**，需 profile 化改造【待实现】才能共用（§8.3）。
- **共享的是「职责逻辑」，不是「文件字节不变」**：agent 定义里的环境检查入口（`$OP_HOME` 引用）、heavy 专属路径（worktree/op_blueprint/baselines）需 **profile 化**才能两版共用。详见 §8。
- **lite 减 op-closer**：closer heavy 独有，lite 不安装、不派发。收口（git commit + 归档 + append decisions）由 leader 机械操作完成（§7.3）。理由：closer 原职责主要产 blueprint 更新提案；lite 无 blueprint 真相源，closer 职责缩水到不值一个独立 Agent。

> 修订说明：初版写"四角色完全共享、绝不变"与"减 closer"自相矛盾，且与 agent 硬编码 `$OP_HOME` 冲突。现更正为「三个执行 agent + leader 职责共享，环境入口 profile 化，lite 不派 closer」。

### 1.2 零侵入的精确边界

lite「零侵入」= **不加 hook + 不改 Claude Code 配置 + 不改用户已有文件**。允许的写入：

| 允许写入 | 说明 |
|---|---|
| `~/.claude/skills/opl*/` | lite 入口 skill（新增，不覆盖用户已有） |
| `~/.claude/agents/op-*.md` | 四角色 agent 定义（新增，供 `subagent_type` 派发） |
| 项目内 `docs/omni_powers/` | 状态工作区（新增独立子目录，不改用户已有文档） |

禁止写入：

| 禁止 | 原因 |
|---|---|
| `~/.claude/settings.json` | 不加 hook、不设 `$OP_HOME` env |
| 用户项目已有文件（CLAUDE.md/README/docs/*） | 不归档、不重构、不提炼作 blueprint |

> 措辞修订：初版"不改用户文档"过强——`docs/omni_powers/` 本身是往用户项目写新文件。精确表述为「不修改用户已有文件，仅新增独立子目录」，卖点不削弱。

### 1.2.1 lite 安装链【待实现，P0】

skill/agent 怎么从 omni_powers 仓库进 `~/.claude/`?heavy 靠 opinit（含 hook 注册 + 写 `$OP_HOME` env），lite 不改 settings.json **不能复用 opinit**。需**独立 lite installer**：

- 只 `cp`（或 `ln -s`）`skills/oplintake` `skills/oplrun` `agents/op-*.md` 到 `~/.claude/skills/` `~/.claude/agents/`。
- **绝不碰 `~/.claude/settings.json`**（不注册 hook、不设 env）。
- 装完即用——不依赖用户 clone 仓库到固定路径（因方案 B 自包含，§8.3）。
- 形态：仓库内全量 `install.sh`（已实现，heavy+lite 一次装齐，按项目 opinit/oplinit 选模式）。

> 这是 P0 缺口，无它 lite 无法上机。列 §14 顶部。

### 1.3 门禁保留度

- 闸门：**默认只有闸门 A**（spec + task 拆分人审）。**异常分支仍升级人工裁决**：reviewer 2 轮 FAIL、Stage 4 3 轮 FAIL、阻塞 issue 是否转 task。
- 双裁决 review：**保留**。
- **Stage 4 验收降级**（非全保留）：lite 只保留「独立角色裸评 + E2E 固化 + 破坏检查 + 对抗探索」。**不承诺**"防抄实现"（无 worktree 隔离）、"baseline 对照"（无 op_blueprint/baselines）、"跨迭代回归检测"。详见 §9 裸评退化。

> 措辞修订：初版"闸门 A 唯一人工点""Stage 4 全保留"均过强。异常必有人裁；Stage 4 三大能力 lite 丢失。

## 2. 架构核心洞察：共享"是什么"，分离"怎么集成环境"

系统切两层：

- **执行内核**（干什么、判定标准）：spec、AC/不变量、TDD、双裁决、验收对抗、状态机、Agent 职责——**与模式无关，共享**。
- **环境集成层**（怎么装、怎么校验、脚本怎么定位）：安装、证据校验、脚本寻址、blueprint 来源、闸门数、收口角色——**heavy/lite 全部差异收敛在此**。

关键：差异面压缩到环境集成层，两版最大复用，Agent 与 spec 逻辑单点维护，同步演进。

## 3. 两版差异面（收敛后 6 点）

| 维度 | heavy | lite |
|---|---|---|
| 安装 | opinit：hook 注册 + 归档旧文档 + 重构 CLAUDE.md + `$OP_HOME` env | 全量 install.sh 铺 skill+agent → `/oplinit` 建 `docs/omni_powers/` 三区（§1.2.1） |
| 证据校验 | hook 机器强制（PostToolUse/SubagentStop） | leader 每轮亲自验证（§8 上下文账 + G1 水位检查） |
| 脚本/环境入口定位 | `$OP_HOME` | `${OP_SCRIPT_ROOT:-$OP_HOME}` fallback，lite dispatch 注入 skill 自带目录（§8.3） |
| blueprint 来源 | 提炼用户 CLAUDE.md/docs/代码 | 无 blueprint 真相源，只建自己的树（连锁影响见 §9） |
| 闸门 | A + C 两处人工批复 | 默认 A 一处（异常仍升级人裁） |
| 收口角色 | op-closer 独立 Agent | leader 代劳（减 closer） |

**其余全部共享**：三执行 agent 职责、spec 模板、双裁决、Stage 4 验收+对抗+E2E、状态机（去"收口中"）、depends_on、compact 恢复。

## 4. 复用分层

| 层 | 组件 | heavy | lite |
|---|---|:-:|:-:|
| Agent（职责共享，环境入口 profile 化） | op-implementer / op-reviewer / op-evaluator | ✓ | ✓ |
| Agent（heavy 独有） | op-closer | ✓ | ✗ |
| 内部 skill | opspec / opred / optriage | ← 共享（opspec 需 profile 参数，§9） → |
| 状态渲染 | opstatus（读 profile 自适应寻址） | ← 共享 → |
| 核心协议 | RULES.md（含 profile 分叉段，§11） | ← 共享 → |
| **入口编排（薄壳）** | init/intake/run | opinit + opintake + oprun | oplintake + oplrun |

> 更正：初版复用矩阵把四 agent 全标"完全共享"错误——closer lite 不用，且三执行 agent 需环境入口 profile 化才能共用。

## 5. 目录架构（omni_powers 仓库）

```
omni_powers/
├── RULES.md                    # 共享核心协议 + profile 分叉段（§11）
│
├── agents/                     # 装到 ~/.claude/agents/ 供 subagent_type 派发
│   ├── op-implementer.md       #   共享（环境入口 profile 化改造）
│   ├── op-reviewer.md          #   共享（同上）
│   ├── op-evaluator.md         #   共享（同上 + lite 裸评分支，§9）
│   └── op-closer.md            #   heavy 独有（lite 不派）
│
├── skills/
│   ├── opspec/  opred/  optriage/  opstatus/   # 共享内部（opspec/opstatus 加 profile 感知）
│   ├── opinit/  opintake/  oprun/              # heavy 入口（现状保留不动）
│   ├── oplinit/                # lite 入口①：零侵入骨架初始化 + profile=lite
│   ├── oplintake/              # lite 入口②：需求→spec→拆task→闸门A
│   └── oplrun/                 # lite 入口③：task循环+双裁决+Stage4裸评（leader 自验代 hook）
│
├── install.sh                  # 全量安装器：铺全部 skill+agent 进 ~/.claude，可选设 OP_HOME
├── scripts/build_lite.sh       # lite 副本漂移校验
└── docs/
    └── omni_powers_lite_design.md   # 本文档
```

命名：lite 三入口 `oplinit`（骨架）+ `oplintake`（需求→spec→task）+ `oplrun`（执行），与 heavy `opinit/opintake/oprun` 对称。**全量安装**（`install.sh`）一次铺好两模式全部 skill+agent 到 `~/.claude`，**按项目选模式**：heavy 跑 `/opinit`，lite 跑 `/oplinit`。

## 6. profile 机制

项目首次运行时落 `docs/omni_powers/profile`（单行值 `heavy` | `lite`）。

作用：

- **compact 恢复**：leader 读 profile 判断走哪套编排、是否期待 hook、脚本怎么寻址。
- **共享脚本 / opstatus**：读 profile 决定环境入口寻址（`$OP_HOME` 还是 dispatch 注入）与是否有 closer/闸门 C 阶段。
- **互斥保护**：同一项目只认一个 profile，防混跑污染状态。

判定表：

| 场景 | 动作 |
|---|---|
| `/oplintake` 首次运行，无 profile | 写 `profile=lite` |
| `/opinit` 首次运行，无 profile | 写 `profile=heavy` |
| 已有 profile 与当前 skill 模式冲突 | die 提示，不混跑（不清场、不转换，要求用户显式处理） |

## 7. lite 工作流

### 7.1 状态机（lite）

**沿用 heavy 的 task 状态机，仅删「收口中」态**（收口在 lite 是 leader 瞬时操作，不占 task 态）：

```
待规划 → 待开始 → 进行中 → 审阅中 → 完成
  ↓             ↑ FAIL(≤2轮)
挂起 ───────────┘
   2轮FAIL → 阻塞（下游跳过）
```

- **不新增「验收中」task 态**。Stage 4 是 **spec 级阶段活动**（整份 spec 所有 task 闭环后跑一次），不是 per-task 状态——与 heavy 模型一致。
- 状态语义（含义/blocked_by/阻塞传播/挂起/回滚）**完全复用 RULES.md**，lite 只在 profile 分叉段声明「无收口中态」。

> 更正：初版把「验收中」塞进 task 状态机，混淆了 spec 级与 task 级。Stage 4 验收对整份 spec 做一次，task 不进「验收中」。

### 7.2 `/oplintake "<需求>"`

```
⓪ 前置：/oplinit 已建三区骨架 + profile=lite（骨架职责在独立入口 oplinit，非 oplintake——与 heavy opinit 对称；步骤零校验 profile，非 lite 则 die）
① spec 编写：leader 主会话按内联模板生成 op_execution/specs/{前缀}.md（AC + 不变量 + 内联设计探索；模板内联进 oplintake，未走共享 opspec——opspec 已有 profile 感知段，供直接调用兜底）
② 拆 task 写 op_execution/tasks_list.json（depends_on 机读）
③ 【闸门 A】呈报 spec + task 拆分给用户审
   人批 → status: approved（无 git 写保护 hook；靠约定 + git diff 可回溯）
终点：task status=待开始，写 leader_checkpoint.md，交给 /oplrun
```

### 7.3 `/oplrun`

```
读 profile（校验 lite）+ leader_checkpoint.md + jq 查 tasks_list.json
循环（每 task，选 depends_on 全完成、ID 最小）：
  派 op-implementer（subagent_type）→ TDD → tasks/{TID}/report.md
  leader 亲自验证（§8）：读 report evidence 路径 + 跑测试命令读 verdict + 读关键 diff hunk
  派 op-reviewer → 双裁决 → tasks/{TID}/review.md（末行 verdict）
    ├─ FAIL 第1轮 → 回 implementer fail 模式修
    ├─ FAIL 第2轮 → 阻塞(quality)，写 issues，下游跳过（异常人裁）
    └─ PASS → leader 收口（代 closer）：
        · op_close_post（lite 砍除 op_close_pre——其唯一职责是标「收口中」，lite 无此态，review PASS 后直接收口）→ git commit → task 目录归档到 op_record/tasks/
        · append decisions.md（来源标记 leader-close，§10）
全 task 闭环 → Stage 4：派 op-evaluator（裸评退化，§9）→ E2E + AC逐条 + 破坏检查 + 对抗探索
  ├─ FAIL(≤3轮) → 修复 task 回流重验（到顶异常人裁）
  └─ PASS → leader 归档叶子 + 完结报告（无闸门 C，自动完成）
```

## 8. 无 hook 的替代与代价

### 8.1 纪律替代

| heavy hook 职责 | lite 替代 |
|---|---|
| 校验"新鲜机器证据"防作弊 | leader 收 sub agent 返回后**亲自跑测试命令 + 读关键 diff** 再判 |
| `current_task` 注入 + SubagentStop 校验 | leader 循环内自持 task 指针，写 leader_checkpoint.md |
| spec 写保护（拦截未授权改动） | spec 由 leader 单点掌控；降级为约定 + git diff 可回溯（无强制拦截） |

### 8.2 leader 自验的上下文账（初版遗漏，本版补）

**问题**：heavy 用 hook + sub agent 隔离，就是为把 diff/测试输出挡在 leader 主会话外。lite leader 每 task 读 report + 跑测试 + 读 diff，N 个 task 后上下文膨胀。

**缓解策略**（写入 oplrun 契约）：

1. **证据走文件**：implementer 把测试输出写 `tasks/{TID}/report.md` 的 evidence 段（或独立 evidence 文件），leader **只读 verdict 行 + evidence 路径**，不把全量测试输出纳入上下文。
2. **只读关键 hunk**：leader 读 diff 时用 `git diff --stat` + 定向读改动核心 hunk，不全量 `git diff`。
3. **量级适配**：承认 lite 更适合中小 task 量（单 spec ≤ ~8 task）；超大需求建议走 heavy。
4. **上下文水位检查**（G1，写入 oprun 契约）：oplrun 每 N task（如 3）自检 leader 上下文水位，逼近阈值时提示 `/compact` 或建议转 heavy。**否则跑到第 8 task 静默失能**——这是 lite「自验代 hook」的根本张力，必须有检测机制，不能默默崩。

### 8.3 环境入口 profile 化 + 脚本根来源（解 `$OP_HOME` 依赖）

**【现状】** 四 agent 首行 `bash "$OP_HOME/scripts/op_check_env.sh"`、implementer 的 `op_coder_check.sh`、evaluator 的 `op_assemble_eval_brief.sh` 共 6 处引用 `$OP_HOME`。lite 无 env 可依。

**agent 派发机制**：lite agent 定义装 `~/.claude/agents/op-*.md`（§1.2 允许），leader 用 `subagent_type: "op-implementer"` 派发（与 heavy 同机制）。**agent markdown 是静态文件，靠 fallback 变量写法两版共用一份**（下）。

**profile 化 = fallback 变量写法（P2，方案 A，两版共用一份 agent 文件）**：

```bash
# 6 处硬编码统一改写：heavy 下 OP_SCRIPT_ROOT 未设 → 走 $OP_HOME；lite dispatch 注入 → 走 skill 自带目录
bash "${OP_SCRIPT_ROOT:-$OP_HOME}/scripts/op_check_env.sh"
bash "${OP_SCRIPT_ROOT:-$OP_HOME}/skills/oprun/scripts/op_coder_check.sh"
```

- **变量约定**：`OP_SCRIPT_ROOT`（脚本根）+ `OP_PROFILE`（`heavy`|`lite`）。leader dispatch prompt 里注入，agent 读它。
- **heavy 现状不动**：`OP_SCRIPT_ROOT` 未注入时 fallback 到 `$OP_HOME`，heavy 行为零变化——消解「heavy 保留不动」与「去 $OP_HOME」的表面冲突。
- **lite 自带脚本**：`OP_SCRIPT_ROOT` 指向 skill 自身目录（`${BASH_SOURCE[0]}` 探测，§下）。

**脚本根来源 = lite skill 自包含（方案 B，已定）**：

- lite 与 omni_powers 仓库**物理分离**（skill 装在 `~/.claude/skills/`，仓库脚本在别处）。`$OP_HOME` 不存在，`${BASH_SOURCE}` 只能探到 skill 自身目录 → 仓库脚本探不到。
- 因此 **lite skill 自带所需脚本**到 skill 目录内（骨架模板不用独立 `templates/`，由 `oplinit/scripts/oplinit_skeleton.sh` **内联生成**——骨架职责从 oplintake 移到独立入口 oplinit，与 heavy opinit 对称）：
  ```
  ~/.claude/skills/oplinit/
  ├── SKILL.md
  └── scripts/          # op_check_env(仅jq/git) + oplinit_skeleton（三区骨架内联模板 + profile=lite + 互斥 die）
  ~/.claude/skills/oplintake/
  ├── SKILL.md
  └── scripts/          # op_check_env(仅jq/git)
  ~/.claude/skills/oplrun/
  ├── SKILL.md
  └── scripts/          # 自带 lite 版：见下「lite 脚本集」
  ```
- **leader 注入的脚本根 = skill 自身目录**，靠 `${BASH_SOURCE[0]}` 自探测，dispatch prompt 里传给 agent（`OP_SCRIPT_ROOT`）。
- **真正"装了 skill 就能跑"**——不依赖任何 env、不依赖用户 clone 仓库、不依赖绝对路径记录。

**lite 脚本集（修正初版"精简集"低估，§13 详列）**：对照 §7.3 全链，lite 实际需近 oprun 全集——`op_jq` / `op_status`(去收口中) / `op_coder_check` / `op_read_verdict` / `op_close_post` / `op_check_env`(仅jq/git) / `op_assemble_eval_brief`(裸评简化版，§9)。**不含** `test_lock.sh`（spec 写保护降级为约定，§8.1）、`op_checkpoint.sh`（leader 内联）、`op_close_pre.sh`（lite 无「收口中」态，砍除）。「逻辑稳定」成立，但数量非"极少"。

**副本同步代价（可控）**：lite 自带脚本与 heavy 仓库脚本成两份副本。缓解：仓库内构建脚本从 `scripts/` + `skills/oprun/scripts/` 生成 lite 副本（待实现 #11），避免手抄漂移。

**op_check_env.sh**：heavy 版留 `$OP_HOME` 强校验；lite 自带版只校验 jq/git（无 OP_HOME 段）。

> 更正：初版 §13 "不复制脚本"被推翻——物理分离下不自包含就无法定位脚本。用户已定方案 B 自包含。

## 9. Blueprint 缺失的连锁影响（初版遗漏，本版补）

lite 无 blueprint 真相源，不只影响 closer——逐角色退化矩阵：

| 消费者 | 缺失的 blueprint 部件 | lite 退化形态 |
|---|---|---|
| op-implementer | architecture.md / conventions.md（定向包） | 无架构地图/编码规范，只能靠 spec 单文档 + 现有代码归纳 |
| op-reviewer | test.md（可写性矩阵、危险模式清单） | 判定依据内联进 reviewer lite 分支 prompt（从 design §2 蒸馏最小集） |
| op-evaluator | specs/{feature}.md 生效规格 + baselines/ | **裸评退化**：无隔离、无基准对比、无跨迭代回归检测，只做首次裸评 |
| leader | baselines_index.md | 无二阶判断对照素材 |

**evaluator 裸评退化（用户已确认接受）**——lite 分支显式定义：

- **能做**：逐 AC 评估、跑/写 E2E、破坏检查、对抗探索（首次评）。
- **不能做**：worktree 结构隔离（evaluator 能读到 src/ 与 task 目录，防"抄实现"底线失效）、baseline 对照评、跨迭代回归。
- **实现**：evaluator.md 加 profile=lite 分支，跳过步骤 0 基准模式判定 / 步骤 2 存基准 / 重验对照逻辑（heavy 下这些是活代码，lite 下 skip）。

**evaluator brief 组装 lite 形态（P3）**：heavy 用 `op_assemble_eval_brief.sh` 组装 brief（含生效规格开工前基线 + baselines 索引）。lite 无基线/baselines，brief 组装随裸评退化——**lite 自带简化版脚本**：只 cat 工作 spec（op_execution/specs）+ AC + 启动方式，**跳过基线/baselines 段**。不整段 skip（evaluator 仍需 brief），是简化。

**opspec profile 参数**：heavy 可引用 op_blueprint/specs 映射；lite 只生成 op_execution/specs/{前缀}.md 单份，不要求 blueprint 映射。

**feature frontmatter 字段 lite 处理**：heavy 中 `feature` 映射 op_blueprint/specs/{feature}.md + baselines/{feature}/。lite 无 blueprint 映射目标——**保留字段但仅作前缀标识**（值 = spec 前缀，供 e2e/acceptance 目录命名），不映射 blueprint。保留而非删：便于未来 lite→heavy 迁移时字段语义可续接。

## 10. 收口的 decisions 来源标记（初版遗漏，本版补）

RULES.md 规定 decisions.md 多写入者均带来源标记。lite leader 代 closer 收口时 append，来源标记用 **`leader-close`**（区别于 heavy 的 closer 来源），保审计链完整。leader 在 per-task 收口时点 append（review PASS + commit 后）。

## 11. RULES.md profile 分叉（初版第 6 条展开）

RULES.md 共享，但含 profile 分叉段。lite 分叉声明（落地时逐条补进 RULES.md）：

- 脚本寻址：`$OP_HOME` → `${OP_SCRIPT_ROOT:-$OP_HOME}`（compact 恢复段的 `$OP_HOME/scripts/op_jq.sh` 改此写法，§8.3）。
- 状态机：**无「收口中」态**；`完成` 态定义改写——lite 不再是"closer 返回 + leader 审批后完成"，而是"review PASS + leader 收口 commit + close_check 通过"。
- 无闸门 C、无 closer 派发。
- **decisions 来源闭集加入 `leader-close`**（§10）。
- spec 写保护降级为约定 + git diff 可回溯（无 hook 强制拦截，§8.1）。
- evaluator 裸评可信度降级说明（无防抄/baseline/回归，§9）。
- compact 恢复：读 RULES.md → jq 查 `op_execution/tasks_list.json` → 读 `leader_checkpoint.md`（路径同 heavy，仅脚本前缀 profile 化）。

## 12. 目录（lite 复用 heavy 三区布局）

```
<project>/
├── e2e/                            # 【与 heavy 一致】evaluator 固化的验收 E2E 全集（项目根级，两版路径统一）
└── docs/omni_powers/
    ├── profile                      # heavy | lite（单行）
    ├── op_blueprint/                # lite 下仅路径兼容占位（空壳）——agent/reviewer/evaluator 不得当契约源
    ├── op_execution/
    │   ├── specs/{前缀}.md          # 规格：AC / 不变量 / 技术决策（lite 生效规格实际所在）
    │   ├── tasks_list.json         # 任务 + 状态（jq 查，唯一状态源）——与 heavy 同名
    │   ├── leader_checkpoint.md    # 断点续跑入口
    │   ├── issues/                 # 阻塞/技术债
    │   ├── tasks/{TID}/            # brief.md / report.md / review.md
    │   └── acceptance/{前缀}/      # eval_brief.md / eval.md
    └── op_record/
        ├── decisions.md            # append-only（来源标记 leader-close）
        ├── progress.md
        └── tasks/                  # 完成 task 归档
```

**e2e/ 路径两版统一**（用户已定）：lite 跟 heavy 用项目根 `<project>/e2e/`，脚本无需 profile 分叉寻址。代价：用户项目已有 `e2e/` 时共处（不覆盖，同目录按前缀分子目录）。

**op_blueprint/ 仅占位**：lite 下为空壳，仅为路径兼容（避免脚本找不到目录）。**明令**：implementer 定向包、reviewer test.md 判定、evaluator 生效规格/opspec/eval_brief **一律不读 op_blueprint/**，改读 op_execution/specs 或内联判定集（§9）。

> 更正：初版扁平单树（spec.md/tasks.json）与 heavy 三区不兼容，会让共享脚本找错路径。用户已定复用 heavy 布局。**统一 `tasks_list.json` 命名**（初版 `tasks.json` 会让 op_jq.sh/op_status.sh 失效）。初版 e2e/ 误置 op_execution/ 下，已改回项目根与 heavy 统一。

## 13. 脚本策略（修正初版失真清单）

**实际脚本清单**（亲核，初版审阅①漏查目录）：

| 位置 | 脚本 |
|---|---|
| `scripts/`（根） | op_check_env.sh / op_jq.sh / op_new_task.sh / op_status.sh / test_lock.sh |
| `skills/oprun/scripts/` | close_check.sh / op_checkpoint.sh / op_coder_check.sh / op_read_verdict.sh / op_assemble_eval_brief.sh / op_close_post.sh / op_close_pre.sh |

**lite 自带脚本集**（对照 §7.3 全链核出，「lite 自带?」列）：

| heavy 脚本 | lite 自带? | lite 版差异 |
|---|:-:|---|
| op_jq.sh | ✓ | 无（读相对路径 tasks_list.json） |
| op_status.sh | ✓ | 状态枚举去「收口中」 |
| op_coder_check.sh | ✓ | 环境入口 fallback 变量 |
| op_read_verdict.sh | ✓ | 无 |
| op_close_pre.sh | ✗ | **lite 砍除**（唯一职责是标「收口中」，lite 无此态——review PASS 后直接 op_close_post，用户已定） |
| op_close_post.sh | ✓ | 无「收口中」前置、兄弟脚本 `${BASH_SOURCE}` 自探测（无 OP_HOME） |
| op_check_env.sh | ✓ | 只校验 jq/git（无 OP_HOME 段） |
| op_assemble_eval_brief.sh | ✓ | 裸评简化：跳基线/baselines 段（§9） |
| close_check.sh | ✓ | 完成态定义随状态机改 |
| op_new_task.sh | ✗ | lite 拆 task 用 jq `.tasks += [{...}]` 直接写，不需模板拷贝 |
| test_lock.sh | ✗ | spec 写保护降级为约定（§8.1），不含 |
| op_checkpoint.sh | ✗ | leader 内联，不单列 |

**策略（方案 B 自包含，§8.3）**：

- **lite skill 自带脚本**到 `~/.claude/skills/opl*/scripts/`——物理分离下唯一可定位方案。骨架模板由 `oplinit_skeleton.sh` 内联生成（无独立 templates/ 目录）。
- lite 自带脚本读 `docs/omni_powers/op_execution/tasks_list.json`（项目内相对路径，两版一致）。
- 脚本根靠 `${BASH_SOURCE[0]}` 自探测，leader dispatch 注入给 agent（`OP_SCRIPT_ROOT`），**不依赖 `$OP_HOME`**。
- **副本同步**：`scripts/build_lite.sh` 校验 lite 副本与 heavy 源一致（逐字节类 diff + 改造类标记断言 + 三份 op_check_env 互检），`--sync` 修复，避免手抄漂移（#11 已实现）。
- **bootstrap 已解**：骨架逻辑用 skill 自带 `scripts/`（模板内联），`${BASH_SOURCE}` 定位，无"安装器自身怎么被找到"死结。

## 14. 待实现清单（修订）

> **落地状态（2026-07-06）**：核心链路已实现。唯一安装脚本 `install.sh`（heavy+lite 共用，10 skill + 4 agent，可选 --set-ophome）；lite 三入口 `oplinit`/`oplintake`/`oplrun`；三执行 agent profile 化 fallback + lite 分支；Stage 4 裸评接入；RULES profile 分叉段；CLAUDE.md 双模式入口；`build_lite.sh` 漂移校验；profile 互斥双向落地（opinit 写 heavy + 冲突 die，oplinit 写 lite + 冲突 die，opintake/oprun/oplintake/oplrun 入口校验）。端到端验证通过（骨架/状态流转/profile 互斥/resolver 双版/收口归档链/Stage4 brief/settings 合并）。
>
> **实现与本设计的偏差记录**（功能等价或有意收窄，正文已同步）：
> - `op_close_pre` lite 版从「跳过标收口中」改为**砍除**（§7.3/§13）。
> - 骨架模板从独立 `templates/` 改为 `oplinit_skeleton.sh` **内联生成**；骨架职责从 oplintake 移到独立入口 oplinit（§8.3）。
> - oplintake **未调共享 opspec**，spec 模板内联进 oplintake SKILL.md（§7.2 ② 的收窄；opspec 已加 profile 感知段供直接调用时用）。
> - opstatus 加 profile 感知段；lite 日常看进度仍由 oplrun 内联渲染（不强依赖 opstatus）。
> - 实现补充设计未列的三项：oplinit 写 `docs/omni_powers/.gitignore`（忽略 `*.lock`，只在自己子目录内）；oplrun 3.5 收口前 `git add {workset}`（lite 无 worktree，不 add 会丢代码出 commit）；agent `op_script()` 双路径 resolver（heavy 分两目录、lite 平铺，单行 fallback 不够）。
>
> 架构调整：按用户要求改为**唯一安装脚本 `install.sh` 全量装到 ~/.claude，按项目 opinit/oplinit 选重度/轻度**。lite「零侵入」精确定义为**不侵入用户项目**（不装项目 hook、不改项目已有文档），全局 `~/.claude` 一次性安装是用户主动配置。

### 14.1 P0 前提

| # | 项 | 依赖决策 |
|---|---|---|
| 0 | **全量 installer**（`install.sh`）：铺全部 skill+agent 进 `~/.claude/`，默认不碰 settings.json（--set-ophome 才写 OP_HOME） | §1.2.1 |

### 14.2 MVP 切片（先证 lite 本质能否成立）

用**一个真需求**跑通 `spec → task → implementer → reviewer → leader 收口` 全链，**校验 §8.2 leader 自验上下文账是否撑得住**（这是 lite 与 heavy 隔离原则的根本张力，须先立稳再投资其余）：

| # | 项 | 依赖 |
|---|---|---|
| 4 | 四 agent 环境入口 profile 化（`${OP_SCRIPT_ROOT:-$OP_HOME}` fallback + agent 派发） | §8.3 |
| 3 | 脚本根自探测 + dispatch 注入（`${BASH_SOURCE}` → leader → agent） | §8.3 |
| 1' | `oplintake` 简化版（骨架 + profile=lite + spec + 拆 task + 闸门 A；先不含 templates 完整化） | §7.2 |
| 2' | `oplrun` 简化版（循环 + leader 自验 §8.2/8.2.4 水位 + 双裁决；**先跳过 Stage 4**） | §7.3 §8 |
| 6 | `op_check_env.sh` lite 自带版（只 jq/git） | §8.3 |

### 14.3 补全（MVP 立稳后）

| # | 项 | 依赖 |
|---|---|---|
| 5 | `op-evaluator.md` lite 裸评分支 + brief 组装简化版（Stage 4 接入） | §9 |
| 7 | `opspec` / `opstatus` profile 感知 | §9 §6 |
| 8 | RULES.md profile 分叉段（无收口中态/完成态改写/无闸门C/无closer/leader-close/脚本寻址） | §11 |
| 9 | reviewer lite 分支内联 test.md 最小判定集 | §9 |
| 10 | CLAUDE.md「快速开始」加 lite 分支（`/oplintake` `/oplrun` 入口） | 接入路径 |
| 11 | 构建脚本：从 heavy scripts 生成 lite 副本（防漂移） | §8.3 §13 |
| 12 | profile edge case：已有 `docs/omni_powers/` 无 profile 时，检测 heavy 残留（探 op_blueprint 有无实体内容 / `$OP_HOME`）再定 lite/die | §6 |

## 15. 审阅意见处置记录

### 三轮审阅采纳项

- **第2轮**：角色数矛盾、`tasks.json`→`tasks_list.json`、agent `$OP_HOME` 冲突、「验收中」态混淆、零侵入措辞、闸门 A 措辞、blueprint 连锁矩阵、decisions 来源标记、上下文账、bootstrap、evaluator 裸评显式化、opspec profile 参数。
- **第3轮**：P4 安装链（→ #0）、P2 fallback 变量样例（`${OP_SCRIPT_ROOT:-$OP_HOME}`）、e2e/ 路径分叉、close 脚本写「收口中」、脚本数量描述失真、evaluator brief 组装 lite 形态、"共享"措辞过强、现状/待实现分界、feature 字段、profile edge case、G1 上下文水位、Stage 4 降级措辞、op_blueprint 占位标注、MVP 切片。

### 驳回（事实核查错误）

- 审阅①称「op_read_verdict/op_coder_check/op_close_*/close_check/op_checkpoint 6 脚本不存在」——**实存** `skills/oprun/scripts/`；称「opinit_register_hooks.sh 幽灵脚本」——**实存** `skills/opinit/scripts/`。审阅①漏查 oprun/opinit 的 scripts 子目录。
- 审阅③引用「design 原则 8/11」——**grep 无此编号，杜撰引用**。leader 自验与"上下文只留状态"的张力真实存在（§8.2 已承认并加 G1 水位检查），但不采其编号。
- 三份反复「当前代码 heavy-only，lite 卡死」定性为**阻断缺陷**——**驳回定性**：这是设计文档非已实现系统，"入口不存在/profile 未落地"是待实现项（§14），非文档错误。采纳其"标注现状/待实现分界"的修法（已加顶部 banner + 全文【现状】/【待实现】标注）。

### 用户裁决（累计）

① lite 复用 heavy 三区布局；② agent 装 `~/.claude/agents/`（只动 skills/agents，不动 settings.json）；③ 接受 evaluator 裸评退化；④ 脚本自包含（方案 B）；⑤ e2e/ 跟 heavy 用项目根；⑥ lite close 脚本跳过收口中；⑦ 先改文档标分界再实现。
