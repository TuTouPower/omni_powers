---
name: oplintake
description: >
  lite 需求入口（零侵入版）：spec 编写（task:spec 1:1）→ 拆 task → 闸门 A → tasks_list.json 就绪。
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
> lite 脚本走 `${OP_SCRIPT_ROOT:-$OP_HOME}` fallback——全量安装设了 `$OP_HOME` 则用它，否则指向 install.sh 装的共享 scripts 目录 `~/.claude/scripts/omni_powers/`（design §5.5）。

`/oplintake "<需求>"` 是 lite 模式需求入口。spec 编写（task:spec 1:1）→ 拆 task → 闸门 A。

## 步骤零：确认骨架就绪

```bash
# 命中即非 0 阻断（不能只 echo——leader 见非 0 必须停）
[ -f docs/omni_powers/profile ] && grep -qx lite docs/omni_powers/profile \
  || { echo "[FAIL] 未初始化或非 lite——先跑 /oplinit（heavy 项目用 /opintake）" >&2; false; }
```

**上面命令非 0 → 停**，提示先跑 `/oplinit`，本 skill 不建骨架（职责分离）。

## 步骤一：change type（决定测试规则）

**强制 spec**：调本 skill 即默认每 task 一份 spec（task:spec 1:1）。不需要 spec 的简单任务（改样式、加索引、三行 fix）不该调本 skill——直接做即可。入口不检查，信任用户判断（design §2.1）。

**change type**（决定测试规则）：feat 全流程 / fix 复现→回归测试→根因→修 / refactor 行为不变即契约 / perf benchmark 基线。

## 步骤二：spec 编写

> 建议本步骤前 `/model` 切 Opus（错误放大系数最大）。

写 `docs/omni_powers/op_execution/specs/{TID}_{slug}.md`（task:spec 1:1，每 task 一份）。TID 全局单调递增 T0001/T0002…永不复用。共享不变量/跨 task 技术决策复制进每个相关 task spec（自足）。

frontmatter：

```yaml
---
status: draft
type: feat        # feat|fix|refactor|perf
---
```

spec 正文必含：

- **假设清单**（先输出，供审）
- **不变量INV**：覆盖沉默失败区（数据隔离/持久化/权限）。每条编号 INV-1…
- **验收标准AC**：Given/When/Then，**Then 全部可翻译为断言**。每条编号 AC-1…
- **边界**：含竞态与失败路径
- **技术决策**：命中信号（验收标准涉及需论证的计算；含"高效/准确/一致"等词）→ 内联设计探索（候选 2-3、复杂度、推荐及理由），完整探索存 `op_record/decisions.md`

> lite 无 blueprint 定向包——spec 是 implementer 唯一契约源，须自足（含必要的架构/命名约束内联）。

## 步骤三：闸门 A（人工审 spec）

呈报一次 intake 的全部 task spec 给用户审（**闸门 A 预算 15-30 分钟/需求**，design 原则 11/§2.2；只读自然语言）：

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
  "id": "T0001",
  "title": "<语义级标题，一句 commit message 能说清>",
  "status": "待开始",
  "spec": "{TID}",
  "type": "实现",
  "depends_on": null,
  "workset": ["src/..."]
}
```

leader 用 jq 写入（`.tasks += [{...}]`）。`depends_on` 记前置依赖数组（无则 null）。

**接口先行**：被 2+ task 依赖的接口/数据模型，用代码先占位提交。

## 步骤五：写 checkpoint

编辑 `docs/omni_powers/op_execution/leader_checkpoint.md`：`next_step: 交 /oplrun 续跑`，关键上下文段填当前目标。

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
