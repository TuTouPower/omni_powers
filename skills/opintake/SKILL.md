---
name: opintake
description: >
  需求入口：spec 编写（含设计探索，task:spec 1:1 每 task 一份）→ 闸门 A 批复 → 自动拆 task → tasks_list.json 就绪（顺序依赖机读，不进 spec 本体）。
  触发：/opintake "<需求>"、新需求、做个功能。
  终点：tasks_list 就绪，task status=`待开始`，leader_checkpoint 标注 spec 就绪，交给 /oprun。
---

# Op Intake Skill

> **运行前检查环境**：`bash "$OP_HOME/scripts/op_check_env.sh"`（jq/git/OP_HOME，缺失 die + 装法）
>
> **profile 互斥**：`[ -f docs/omni_powers/profile ] && ! grep -qx heavy docs/omni_powers/profile` 命中 → **停**，提示 lite 项目用 `/oplintake`，不混跑。（无 profile 文件 = 旧 heavy 项目，放行）

`/opintake "<需求>"` 是需求入口。spec 编写（task:spec 1:1）→ 闸门 A → 拆 task → task 待开始。

协议规则见 `RULES.md`。spec 模板与设计探索流程见内部 skill `opspec`。

## 步骤一：change type（决定测试规则）

**强制 spec**：调本 skill 即默认每 task 写一份 spec（task:spec 1:1）。不需要 spec 的简单任务（改样式、加索引、三行 fix）不该调本 skill——直接做即可。入口不做复杂度检查，信任用户判断（design §2.1）。

change type 只决定测试规则与 验收标准侧重（权威矩阵 design §3.1）：

| 类型 | 流程形态 | 契约来源 |
|---|---|---|
| feat | 全流程 | 工作 spec |
| fix | 复现 → 先写必然失败的回归测试 → 根因 → 修 → 变绿 | 那条回归测试 |
| refactor | "行为不变"即契约，验收标准是等价性验证 | 行为层测试套件 |
| perf | benchmark 基线 → 改 → 复测，验收标准是量化指标 | benchmark 基线 |
| style/test | 见 design §3.1 | — |

继续步骤二。

## 步骤二：工作 spec 编写（含内联设计探索）

> spec 编写归 leader 主会话，建议本步骤前 `/model` 切 Opus（错误放大系数最大，design §2.2）。

调用内部 skill `opspec`。spec 路径：`docs/omni_powers/op_execution/specs/{TID}_{slug}.md`（task:spec = 1:1，每 task 一份；TID 全局单调递增 T0001/T0002…永不复用；命名统一 `{TID}_{slug}.md`，标题放 markdown H1）。共享不变量/跨 task 技术决策**复制进每个相关 task spec**（自足）。

spec frontmatter：`status: draft`、`type: feat|refactor|perf|...`。

**方案先行（设计探索内联）**：命中信号（不变量/验收标准 涉及正确性需论证的计算；验收标准含"高效/准确/一致"等需算法保证的词）→ spec 编写时内联做设计探索，候选思路 2-3 个、复杂度与边界、推荐及理由，结论进技术决策区，完整探索存 `decisions.md`。

先输出假设清单一并供审。

## 步骤三：闸门 A（人工审 spec + 方案）

呈报一次 intake 的全部 task spec 给用户审（**闸门 A 预算 15-30 分钟/需求**——design 原则 11/§2.2：spec 含不变量+验收标准+边界+三类技术决策+可测性契约，是全系统唯一质量单点，5-10 分钟审不完只会橡皮图章；只读自然语言）：
- 不变量覆盖沉默失败区（数据隔离/持久化/权限）
- 边界含竞态与失败路径
- Then 全部可翻译为断言
- 技术决策无遗漏（拆 task 时发现某 task 产出约束他人而 spec 未写 = 打回补 spec）

人批 → `status: approved` + 写保护（**硬底线是 merge gate**——task 分支对 approved spec 路径零 diff，design §3.4；主分支侧 git pre-commit 拦 leader 误改 + 主会话 PreToolUse 拦截；subagent 场景 hook deny 失效，靠 merge gate + 结构）。是否立即 commit 需用户明确授权；闸门 A 批准本身不等于 commit 授权。

## 步骤四：拆 task 写入 tasks_list.json

沿低耦合缝隙切（层/模块/数据流阶段），先列缝再核工作集。

每个 task 写入 `tasks_list.json`：

```json
{
  "id": "T0003",
  "title": "<语义级标题，一句 commit message 能说清>",
  "status": "待开始",
  "spec": "T0001",
  "type": "实现",
  "depends_on": ["T0001"],
  "workset": ["src/store/session.ts"]
}
```

沿低耦合缝隙切（层/模块/数据流阶段）；天然不可分（横切重构/脚手架）→ 单 task 自足 spec，不硬锯（design §2.3）。

**接口先行 task**：被 2+ task 依赖的接口/数据模型，用代码先占位提交（编译器强制，严格强于文档签名）。

## 步骤五：顺序依赖归位（不进 spec 本体）

顺序依赖已在步骤四写入 `tasks_list.json`（`depends_on` 字段，机读）+ `leader_checkpoint.md`（人扫）。**不进 spec 本体**——spec 经闸门 A 写保护后追加会冲突。Stage 2 自检扫 `tasks_list.json` 依赖 + 拆 task 自检（跨 task 决策遗漏则回补 spec 再过 A，可跳过）。

## 终点：task 待开始

`tasks_list.json` 已写入 `status=待开始` 的 task（顺序依赖机读）+ `leader_checkpoint.md` 标注 spec 就绪。交接给 `/oprun`。

## compact 恢复

1. 读 `RULES.md`
2. jq 查 tasks_list.json 看是否有 draft/approved spec 待拆或待跑
3. 读对应 spec 文件

## 相关文件

| 文件 | 用途 |
|---|---|
| `RULES.md` | 规则手册 |
| `skills/opspec/SKILL.md` | spec 模板与设计探索（内部 skill，被本 skill 调用） |
| `scripts/op_new_task.sh` | 工作区创建 |
| `scripts/op_jq.sh` | tasks_list.json 查询 |
| `skills/opspec/SKILL.md` | spec 模板来源（`op_execution/specs/{TID}_{slug}.md` 由 opspec 生成） |
