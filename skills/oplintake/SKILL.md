---
name: oplintake
description: >
  lite 需求入口（零侵入版）：分拣 → spec 编写 → 拆 task → 闸门 A → tasks_list.json 就绪。
  触发：/oplintake "<需求>"、新需求、做个功能。
  前置：已跑 /oplinit 建骨架（profile=lite）。
  终点：task status=待开始，写 leader_checkpoint，交给 /oplrun。
---

# Op Lite Intake Skill

> **脚本根**：leader 定位本 skill 安装目录后用它：
> ```bash
> SKILL_DIR="<本 skill 安装目录>"   # 如 ~/.claude/skills/oplintake
> bash "$SKILL_DIR/scripts/op_check_env.sh"   # jq/git
> ```
> lite 脚本走 `${OP_SCRIPT_ROOT:-$OP_HOME}` fallback——全量安装设了 `$OP_HOME` 则用它，否则 leader dispatch 注入 skill 自带目录。

`/oplintake "<需求>"` 是 lite 模式需求入口。分拣 → spec → 拆 task → 闸门 A。

## 步骤零：确认骨架就绪

```bash
# 命中即非 0 阻断（不能只 echo——leader 见非 0 必须停）
[ -f docs/omni_powers/profile ] && grep -qx lite docs/omni_powers/profile \
  || { echo "[FAIL] 未初始化或非 lite——先跑 /oplinit（heavy 项目用 /opintake）" >&2; false; }
```

**上面命令非 0 → 停**，提示先跑 `/oplinit`，本 skill 不建骨架（职责分离）。

## 步骤一：入口分拣

**写不写 spec？** 命中任一则写：①跨范围（多模块/需拆 task）②改契约（接口/数据模型/边界）③高代价（数据损坏/不可逆/性能回退/安全）。

三条全不中（改样式/加索引/三行 fix）→ 不进 task 机制，直接改 + 测试 + commit，结束。

**change type**（决定测试规则）：feat 全流程 / fix 复现→回归测试→根因→修 / refactor 行为不变即契约 / perf benchmark 基线。

## 步骤二：spec 编写

> 建议本步骤前 `/model` 切 Opus（错误放大系数最大）。

写 `docs/omni_powers/op_execution/specs/{前缀}.md`。前缀编号：单需求 `a_darkmode`；多 task `b_website`（总述）+ `b01_pages`/`b02_contact`（叶子），封顶两层。

frontmatter：

```yaml
---
status: draft
type: feat        # feat|fix|refactor|perf
feature: {前缀}    # lite 下仅作前缀标识，不映射 blueprint（§9）
---
```

spec 正文必含：

- **假设清单**（先输出，供审）
- **不变量 INV**：覆盖沉默失败区（数据隔离/持久化/权限）。每条编号 INV-1…
- **验收标准 AC**：Given/When/Then，**Then 全部可翻译为断言**。每条编号 AC-1…
- **边界**：含竞态与失败路径
- **技术决策**：命中信号（AC 涉及需论证的计算；含"高效/准确/一致"等词）→ 内联设计探索（候选 2-3、复杂度、推荐及理由），完整探索存 `op_record/decisions.md`

> lite 无 blueprint 定向包——spec 是 implementer 唯一契约源，须自足（含必要的架构/命名约束内联）。

## 步骤三：闸门 A（人工审 spec）

呈报用户审（只读自然语言）：

- 不变量覆盖沉默失败区
- 边界含竞态与失败路径
- Then 全部可翻译为断言
- 技术决策无遗漏

人批 → 改 frontmatter `status: approved`。

> lite 无 hook 写保护——approved 后靠约定 + git diff 可回溯。leader 单点掌控 spec，不擅自改。

## 步骤四：拆 task 写 tasks_list.json

沿低耦合缝隙切（层/模块/数据流阶段）。每 task 追加到 `docs/omni_powers/op_execution/tasks_list.json`：

```json
{
  "id": "T01",
  "title": "<语义级标题，一句 commit message 能说清>",
  "status": "待开始",
  "spec": "{前缀}",
  "type": "实现",
  "covers_ac": ["AC-1"],
  "touches_inv": ["INV-1"],
  "depends_on": null,
  "risk_probe": false,
  "workset": ["src/..."]
}
```

leader 用 jq 写入（`.tasks += [{...}]`）。`depends_on` 记前置依赖数组（无则 null）。

**接口先行**：被 2+ task 依赖的接口/数据模型，用代码先占位提交。

**MVP 量级**：lite 适合单 spec ≤ ~8 task（leader 自验上下文账，§8.2）。超大需求建议走 heavy。

## 步骤五：写 checkpoint

编辑 `docs/omni_powers/op_execution/leader_checkpoint.md`：`next_step: 交 /oprun 续跑`，关键上下文段填当前目标。

## 终点

`tasks_list.json` 已就绪（status=待开始 + depends_on），spec approved。交接 `/oplrun`。

## compact 恢复

1. 读本 SKILL + `docs/omni_powers/profile`（确认 lite）
2. jq 查 tasks_list.json 看有无 draft/approved spec 待拆
3. 读对应 spec

## 相关文件

| 文件 | 用途 |
|---|---|
| `../oplinit/SKILL.md` | 骨架初始化（前置） |
| `scripts/op_check_env.sh` | 环境检查（jq/git） |
| `../oplrun/SKILL.md` | 续跑执行 |
