---
name: opintake
description: >
  需求入口：分拣 → spec 编写（含设计探索）→ 闸门 A 批复 → 自动拆 task → tasks_list.json 就绪（顺序依赖机读，不进 spec 本体）。
  触发：/opintake "<需求>"、新需求、做个功能。
  终点：状态标为"就绪"，交给 /oprun。
---

# Op Intake Skill

> **运行前检查环境**：`bash "$OP_HOME/scripts/op_check_env.sh"`（jq/git/OP_HOME，缺失 die + 装法）

`/opintake "<需求>"` 是需求入口。分拣 → spec → 闸门 A → 拆 task → 就绪。

协议规则见 `RULES.md`。spec 模板与设计探索流程见内部 skill `opspec`。

## 步骤一：入口分拣（两条正交判定）

### 1.1 写不写工作 spec？——三条判据

命中任意一条就写：①**跨范围**（多模块/需拆 task）；②**改契约**（接口、数据模型、模块边界）；③**高代价**（数据损坏、不可逆迁移、性能回退、安全）。

三条全不中（改样式、加索引、改变量名、三行 fix）→ 不写 spec 不进 task 机制，契约就是任务卡一句话或那条回归测试，门禁只剩测试规则 + 机器证据 + commit。结束。

### 1.2 change type？——只决定测试规则和退化流程形态

| 类型 | 流程形态 | 契约来源 |
|---|---|---|
| feat | 全流程（若写 spec）或轻量直做 | 工作 spec / 任务卡 |
| fix | 复现 → 先写必然失败的回归测试 → 根因 → 修 → 变绿 | 那条回归测试 |
| style | 不进流程，formatter/linter | — |
| refactor | "行为不变"即契约；大型的写 spec，AC 是等价性验证 | 行为层测试套件 |
| perf | benchmark 基线 → 改 → 复测；大型的写 spec | benchmark 基线 |

写 spec 则继续步骤二。

## 步骤二：工作 spec 编写（含内联设计探索）

> spec 编写归 leader 主会话，建议本步骤前 `/model` 切 Opus（错误放大系数最大，design §5.2）。

调用内部 skill `opspec`。spec 路径：`docs/omni_powers/op_execution/specs/{前缀}.md`（前缀编号：单需求 a_darkmode，多 task b_website 总述 + b01_pages/b02_contact 叶子，封顶两层；命名统一 `{前缀}.md`，标题放 markdown H1，与 opspec/design/eval brief 一致）。

spec frontmatter：`status: draft`、`type: feat|refactor|perf|...`。

**方案先行（设计探索内联）**：命中信号（INV/AC 涉及正确性需论证的计算；验收标准含"高效/准确/一致"等需算法保证的词）→ spec 编写时内联做设计探索，候选思路 2-3 个、复杂度与边界、推荐及理由，结论进技术决策区，完整探索存 `decisions.md`。

先输出假设清单一并供审。

## 步骤三：闸门 A（人工审 spec + 方案）

呈报给用户审（2-5 分钟，只读自然语言）：
- 不变量覆盖沉默失败区（数据隔离/持久化/权限）
- 边界含竞态与失败路径
- Then 全部可翻译为断言
- 技术决策无遗漏（拆 task 时发现某 task 产出约束他人而 spec 未写 = 打回补 spec）

人批 → `status: approved` + commit + 写保护（git 层 + 主会话 hook 拦截未经变更子流程的改动；subagent 场景 hook 失效，靠 git 层）。

## 步骤四：拆 task 写入 tasks_list.json

沿低耦合缝隙切（层/模块/数据流阶段），先列缝再核工作集。

每个 task 写入 `tasks_list.json`：

```json
{
  "id": "T03",
  "title": "<语义级标题，一句 commit message 能说清>",
  "status": "待开始",
  "spec": "b01",
  "type": "实现",
  "covers_ac": ["AC-1", "AC-2"],
  "touches_inv": ["INV-1"],
  "depends_on": ["T01"],
  "risk_probe": false,
  "workset": ["src/store/session.ts"]
}
```

token 消耗 ≈ 工作集 × 2-3。预算红线 ≈ 名义上限一半：`spec + 任务卡 + 工作集` 超 60-80K 即警惕。逃生阀：能沿缝拆的拆；天然不可分 → 换 1M 模型，禁止硬锯出不可运行的中间状态。

**接口先行 task**：被 2+ task 依赖的接口/数据模型，用代码先占位提交（编译器强制，严格强于文档签名）。

## 步骤五：顺序依赖归位（不进 spec 本体）

顺序依赖已在步骤四写入 `tasks_list.json`（`depends_on` 字段，机读）+ `leader_checkpoint.md`（人扫）。**不进 spec 本体**——spec 经闸门 A 写保护后追加会冲突。Stage 2 自检扫 `tasks_list.json` 依赖 + 拆 task 自检（跨 task 决策遗漏则回补 spec 再过 A，可跳过）。

## 终点：就绪

`tasks_list.json` 就绪（顺序依赖机读）+ 状态标"就绪"。交接给 `/oprun`。

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
| `docs_template/omni_powers/op_execution/specs/` | spec 模板 |
