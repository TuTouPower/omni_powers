# 当前 Diff 审查结论

- 审查日期：2026-07-14
- 固定点：`HEAD`（`ca5eae1`）
- 范围：全部 tracked working-tree diff，以及未跟踪文件：
  - `scripts/op_bind_project_skills.sh`
  - `tests/scripts/op_bind_project_skills.bats`
- 规格来源：`docs/op_decisions.md` D29/D30、`docs/omni_powers_design.md` §4.1/§5.2/§5.4

## 总结

当前改动方向正确：全局仅保留 `/opinit`、`/oplinit`，业务 skill 改为项目级绑定，agent 改为模板注入 `general-purpose`。但存在 3 个行为问题，其中 2 个 HIGH。合并前应修复。

## Standards

### HIGH：删除或覆盖同名非 OP 资产

以下位置按固定名称直接执行 `rm -rf`，未验证目标是否属于 omni_powers：

- `install.sh:116`：覆盖全局 `opinit`、`oplinit`
- `install.sh:124-138`：清理旧业务 skill 和 agent
- `scripts/op_bind_project_skills.sh:74`：覆盖项目 skill
- `uninstall.sh:41-47`：通用 `del()` 不检查所有权
- `uninstall.sh:164-168`：清理项目 skill

若用户已有同名自定义 skill 或 agent，安装、绑定或卸载会静默删除。违反 `uninstall.sh:16`“不动用户其它 skill/agent/hook”。

最小修复：删除或替换前验证软链目标位于当前 `$OP_HOME`；复制 fallback 资产需增加 ownership marker。发现非 OP 同名路径时失败并提示用户处理，不自动覆盖。

### HIGH：profile 冲突检查晚于项目 skill 绑定

- `skills/opinit/SKILL.md:18-24` 先绑定 heavy skill，profile 检查随后才由 skeleton 执行。
- `skills/oplinit/SKILL.md:29-56` 同样先绑定 lite skill，再检查 heavy 残留或 profile。

lite 项目误跑 `/opinit`，或 heavy 项目误跑 `/oplinit` 时，初始化最终会因 profile 冲突退出，但另一模式 skill 已写入 `.claude/skills/`，项目进入混合集状态。

违反 `docs/omni_powers_design.md:763-771`：同一项目只认一个 profile；冲突时应 `die`，不清场、不转换。

最小修复：bind 前读取现有 `OP_DOCS_DIR` 和 profile；模式冲突时不写任何文件，直接失败。增加 heavy→lite、lite→heavy 两个无副作用测试。

### MEDIUM：软链失败后复制，破坏升级契约

`scripts/op_bind_project_skills.sh:75-80` 在 `ln -s` 失败后执行 `cp -r` 并返回成功。

这会产生不会随 `$OP_HOME` 升级同步的项目副本，也使卸载无法仅凭软链目标判断归属。与以下规格不一致：

- `docs/op_decisions.md:485`：把对应 skill 软链到项目 `.claude/skills/`
- `docs/op_decisions.md:490`：软链 OP_HOME 便于升级

最小修复：软链失败直接报错；若必须支持复制模式，应显式参数启用、写 ownership marker，并在输出中说明需要重绑升级。

### MEDIUM：现行文档仍有旧模型残留

- `skills/oplrun/SKILL.md:228-230` 称“lite 不单装 opstatus”，但 D30 和 binder 均把 `opstatus` 纳入 lite 集。
- `docs/omni_powers_design.md:743-746` 仍称 lite 不碰项目配置并使用旧共享 scripts 路径。
- `docs/omni_powers_design.md:783-786` 同时允许修改项目 `CLAUDE.md`、禁止修改项目 `.claude/settings.json`，与当前 lite 初始化规则矛盾。
- `RULES.md:141` 仍称 lite 不修改项目级 `.claude/` 配置。

最小修复：以 D29/D30 最终决策为准，统一更新所有现行说明；归档文档可保留历史描述，但应明确标记已废弃。

### LOW：skill 清单分散维护

全局集、项目 heavy/lite 集和卸载并集分别维护于：

- `install.sh`
- `uninstall.sh`
- `scripts/op_bind_project_skills.sh`
- 多份文档

已出现 `opstatus` 描述漂移。这属于 Duplicated Code / Shotgun Surgery 判断项，不是硬错误。

建议：使用单一 manifest，或至少增加测试，精确断言全局、heavy、lite、卸载四个集合。

### LOW：尾随空格

`docs/op_decisions.md:486` 存在 trailing whitespace，导致 `git diff --check HEAD` 失败。

## Spec

### 缺失或部分实现

1. “同一项目只认一个 profile”仅由后续 skeleton 保护，bind 阶段无保护，失败不具备原子性。
2. “清理旧软链”实现扩大为按名称删除任意路径，未限定为旧 OP 软链。
3. “项目 skill 软链 OP_HOME”在失败路径退化为复制，无法保证升级同步。
4. 新测试未覆盖 profile 切换污染、同名非 OP 资产保护、软链失败行为。

### Scope creep

`uninstall.sh:82-83` 继续无条件删除 `~/.claude/scripts/omni_powers`，但新设计 `docs/omni_powers_design.md:671` 明确 install 不再向 `~/.claude/` 安装 scripts。该路径可能是历史产物，也可能不是当前安装拥有的资产；应在确认 ownership 后才清理。

## 验证结果

通过：

```text
bash -n install.sh
bash -n uninstall.sh
bash -n scripts/op_bind_project_skills.sh
```

失败：

```text
git diff --check HEAD
# docs/op_decisions.md:486: trailing whitespace
```

未执行：

```text
bats tests/scripts/op_bind_project_skills.bats
bats tests/scripts
```

原因：当前环境未安装 `bats`，命令返回 `127: command not found`。因此不能声称测试套件通过。

## 结论

当前 diff 不建议直接合并。阻断项：

1. 增加 OP 资产所有权校验，避免覆盖或删除同名用户资产。
2. 将 profile 互斥检查移到 bind 前，保证冲突失败零写入。
3. 明确软链失败策略，保持 D30 升级契约。

随后统一现行文档、补边界测试、修复 whitespace，再运行完整 Bats 套件。
