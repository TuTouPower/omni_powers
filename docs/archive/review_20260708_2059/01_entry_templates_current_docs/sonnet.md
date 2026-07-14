# Sonnet 审阅报告：入口/模板/当前文档

## 当前模型判断依据

依据 `/home/karon/.claude/settings.json` 顶层 `model` = `default_model`，`env.ANTHROPIC_MODEL` = `default_model`，当前会话 powered by `default_model`。本路不设置 model 覆盖，继承主会话。settings 中 secret 已省略，不写入报告。

## 审阅范围

以 `docs/omni_powers_design.md` 为规格核心，逐文件审阅以下文件与 design 的目录、流程、状态机、heavy/lite 差异、权限边界、交付状态的一致性：

- .gitattributes
- .gitignore
- CLAUDE.md
- RULES.md
- docs/op_decisions.md
- docs/op_first_run.md
- docs/op_install.md
- docs_template/omni_powers/README.md
- docs_template/omni_powers/index.md
- docs_template/omni_powers/op_blueprint/architecture.md
- docs_template/omni_powers/op_blueprint/baselines/baselines_index.md
- docs_template/omni_powers/op_blueprint/conventions.md
- docs_template/omni_powers/op_blueprint/domain.md
- docs_template/omni_powers/op_blueprint/prd.md
- docs_template/omni_powers/op_blueprint/spec_index.md
- docs_template/omni_powers/op_blueprint/specs/{feature}.md
- docs_template/omni_powers/op_blueprint/test.md
- docs_template/omni_powers/op_execution/issues/I-{YYYYMMDD}-{NN}.md
- docs_template/omni_powers/op_execution/issues/{TID}_quality.md
- docs_template/omni_powers/op_execution/leader_checkpoint.md
- docs_template/omni_powers/op_execution/tasks/{TID}/report.md
- docs_template/omni_powers/op_execution/tasks/{TID}/review.md
- docs_template/omni_powers/op_execution/tasks_list.json
- docs_template/omni_powers/op_record/decisions.md
- docs_template/omni_powers/op_record/progress.md

---

## 高优先级问题（CRITICAL / HIGH）

### H1. tasks_list.json 模板 `spec` 字段值错误

- **位置**: `docs_template/omni_powers/op_execution/tasks_list.json` 第 7/15/25 行
- **现象**: `"spec"` 字段值为 `"{TID}"`（纯占位符），而 design §2.3 明确规定 `"spec": "specs/T0003_xxx.md"`——即指向 spec 文件相对路径。
- **影响**: dispatch 脚本按 tasks_list.json 的 `spec` 字段定位 spec 文件，若照此模板填入纯 TID 而非路径，脚本找不到 spec 文件，整个 dispatch 链路断裂。
- **建议**: 将占位符改为 `"specs/{TID}_{slug}.md"` 或 `"specs/{TID}_<功能名>.md"`，与 design §2.3 的示例一致。
- **置信度**: 高
- **优先级**: HIGH

### H2. tasks_list.json 模板 `type` 字段不在 design task 元数据规范中

- **位置**: `docs_template/omni_powers/op_execution/tasks_list.json` 第 8/17/26 行
- **现象**: 模板包含 `"type": "实现"` 字段。design §2.3 的 task 元数据规范只列 id/title/status/spec/depends_on/workset，不含 `type`。且使用中文 `"实现"` 而非 spec frontmatter 的英文枚举（feat/fix/refactor/perf/style/test）。
- **影响**: 若 dispatch 脚本按 design 规范解析 tasks_list，不会期待该字段；若模板使用者照填中文 `"实现"`，与 spec frontmatter `type: feat` 产生中英双语并存，增加混淆。
- **建议**: 两选一：A) 从模板移除 `type` 字段（design 明确说"任务卡即 tasks_list.json 的一条记录，无独立文件"，spec 的 type 在 spec frontmatter 已有）；B) 若确实需要 tasks_list 携带 type（如免派判据依赖 change type），应在 design §2.3 的 task 元数据规范中正式定义该字段，且值使用 spec frontmatter 的英文枚举。
- **置信度**: 高
- **优先级**: HIGH

### H3. README.md 模板 TID 示例与四位数编码规范不一致

- **位置**: `docs_template/omni_powers/README.md` 第 38 行
- **现象**: 命名约定写 `{TID}` 如 `T05`（两位数）。design §1 TID 编码规则为四位数 `T0001/T0002/…`，D27 A5 已完成全文统一为四位。template 仍用两位置例。
- **影响**: 使用者照模板建 T05 后发现与 tasks_list.json 四位数格式不匹配，脚本按固定宽度解析可能出错。
- **建议**: 将 `T05` 改为 `T0005`。
- **置信度**: 高
- **优先级**: HIGH

### H4. tasks_list.json 模板缺少 `depends_on` 的完整性与设计规范对照

- **位置**: `docs_template/omni_powers/op_execution/tasks_list.json` 第 3-33 行
- **现象**: 模板包含三条示例 task，T0001 的 `depends_on: null`，T0002/T0003 的 `depends_on: ["T0001"]`。但 T0003 没有 `eval` 和 `eval_reason` 字段（与 T0001 不一致）。design §2.5 (D9) 说 task schema 字段包含 `eval: "required"|"skip"` + `eval_reason`，T0001 有此字段而 T0003 没有。模板内示例不一致。
- **影响**: 使用者可能认为 `eval` 字段可选，但 T0001 有而 T0003 没有，字段存在性不一致，脚本 jq 查询可能因缺少字段而报错（取决于是否用 `// "required"` fallback）。
- **建议**: 所有示例 task 统一包含 `eval` 和 `eval_reason` 字段；非行为型 task 设 `"eval": "skip"` 并填 `"eval_reason"`。
- **置信度**: 高
- **优先级**: HIGH

---

## 中低优先级问题（MEDIUM / LOW）

### M1. RULES.md lite compact 恢复脚本路径指向旧位置

- **位置**: `RULES.md` 第 140 行
- **现象**: lite compact 恢复段写 `$SCRIPTS` = `~/.claude/skills/oplrun/scripts`。design §5.5 明确最终目标是共享 `~/.claude/scripts/omni_powers/`，当前因 D5 过渡期 lite 副本暂保留。RULES.md 反映了过渡态但无"此路径将在完整归并后变更"的标注。
- **影响**: 归并完成后 RULES.md 路径过期，compact 恢复找不到脚本。
- **建议**: 在该行加注 "D5 过渡期路径，完整归并后改为 `~/.claude/scripts/omni_powers/`"。
- **置信度**: 高
- **优先级**: MEDIUM

### M2. leader_checkpoint.md 模板引用 heavy 专用路径，未适配 lite

- **位置**: `docs_template/omni_powers/op_execution/leader_checkpoint.md` 第 3 行
- **现象**: 模板写 `bash "$OP_HOME/skills/oprun/scripts/close_check.sh" {TID}`。lite 无 `$OP_HOME`，应使用 `${OP_SCRIPT_ROOT:-$OP_HOME}` fallback 或 lite 专用 close_check 路径。
- **影响**: lite 用户照模板执行会因 `$OP_HOME` 为空而失败。
- **建议**: 改为 fallback 写法，或加 profile 分叉注释说明 lite 下替换路径。
- **置信度**: 高
- **优先级**: MEDIUM

### M3. RULES.md 状态机图缺少"跳过"状态

- **位置**: `RULES.md` 第 20-25 行
- **现象**: ASCII 状态机图展示 `待规划 → 待开始 → 进行中 → 审阅中 → 收口中 → 完成` 主路径 + 挂起/阻塞分流，但"跳过"态不在图内。表格（第 27-37 行）有"跳过"态定义。
- **影响**: 读者看图以为只有 7 个态，扫表发现有 8 个态。不阻碍功能，但降低可读性。
- **建议**: 状态机图增加"跳过"态的进入/退出分支。至少在图下方注明"跳过态见表格"。
- **置信度**: 中
- **优先级**: LOW

### M4. CLAUDE.md 目录树缺 `docs/op_first_run.md` 条目

- **位置**: `CLAUDE.md` 第 48-53 行
- **现象**: `docs/` 段列出 `op_decisions.md`、`omni_powers_design.md`、`op_install.md`、`archive/`，不含 `op_first_run.md`（该文件存在于 `docs/` 目录下）。
- **影响**: 读者可能不知道首跑计划文档的存在。
- **建议**: 在 docs/ 列表中追加 `op_first_run.md`。
- **置信度**: 高
- **优先级**: LOW

### M5. index.md 模板引用 `$OP_HOME` 无 lite fallback 说明

- **位置**: `docs_template/omni_powers/index.md` 第 4/52/53 行
- **现象**: 引用 `$OP_HOME/RULES.md`、`$OP_HOME/docs/omni_powers_design.md`。lite 用户（未跑 `--set-ophome`）没有该变量。
- **影响**: lite 用户照此引用会因 `$OP_HOME` 为空而无法定位文件。
- **建议**: 加注 "lite 模式下 OP_HOME 可能未设，请参考 profile 中脚本寻址规则定位对应文件"。
- **置信度**: 高
- **优先级**: LOW

### M6. index.md 模板引用"已归档 task 的 brief/report/review"与当前结构不一致

- **位置**: `docs_template/omni_powers/index.md` 第 45 行
- **现象**: op_record 段写 "已归档 task 的 brief/report/review"。design §1.1 (D27) 已明确"无 brief 文件"，task 目录只有 report.md 和 review.md 两个文件。
- **影响**: 模板让使用者误以为存在 brief.md，实际 task 目录只有 2 文件平铺。
- **建议**: 将 "brief/report/review" 改为 "report/review"。
- **置信度**: 高
- **优先级**: MEDIUM

### M7. op_first_run.md 模型档位示例过时

- **位置**: `docs/op_first_run.md` 第 26-29 行
- **现象**: 模型档位设置为 `OP_REVIEWER_MODEL=sonnet`。design §2 推荐 reviewer 用 Opus（"Opus / 强审弱错开同档盲区"）。首跑文档建议 reviewer 用 sonnet 可能是成本考量，但与 design 推荐不一致且未说明理由。
- **影响**: 首跑用户可能沿用此配置，导致 reviewer 审查深度不足。
- **建议**: 改为 `OP_REVIEWER_MODEL=opus` 或加注释说明首跑期成本控制原因。
- **置信度**: 中
- **优先级**: LOW

### M8. conventions.md 模板"安全"节与 design 测试可写性矩阵结构不匹配

- **位置**: `docs_template/omni_powers/op_blueprint/conventions.md` 第 38-41 行
- **现象**: conventions 模板有"安全（编码相关）"节。design §1.3 文档职责矩阵中 conventions.md 的职责为"编码约定：命名/风格/文件组织/浏览器 API/不可变性/日志规则/适配器开发步骤（编码独占）"。安全编码约束放在 conventions 合理，但 design 职责矩阵未列出"安全"作为 conventions 的显式内容区。
- **影响**: 轻微——conventions 加上安全编码约束属于合理扩展，不违规。
- **建议**: 如果安全编码约束是项目 conventions 的一部分，应在 design §1.3 conventions 职责行补充"安全编码"入口。
- **置信度**: 低
- **优先级**: LOW

### M9. op_decisions.md D22 末尾留有"待澄清"悬空项

- **位置**: `docs/op_decisions.md` 第 344 行
- **现象**: D22 末写 "两者张力（轻量直做保留为 heavy 内嵌路径 vs 完全剥离出 omni_powers）留待后续裁决，本条先记定位意图。" 这是一个未闭合的决策点，留作待办。
- **影响**: 不影响当前流程，但 design §2.1 的"轻量直做"段是否保留取决于此裁决，存在潜在不一致风险。
- **建议**: 无——这是有意识的推迟裁决，design 应同步标注此点待定。
- **置信度**: 高
- **优先级**: LOW

### M10. op_install.md 提到的旧机制可能误导读者

- **位置**: `docs/op_install.md` 全文
- **现象**: 文档顶部已标注废弃，但全文描述 `$CLAUDE_PLUGIN_ROOT`、`plugin.json`、`opstart`、`opplan`、`optask`、`opdebt`、`op-coder` 等所有旧名。虽已加废弃头，但 381 行的旧技术细节对读者是不必要的信息负担。
- **影响**: 新读者可能翻阅后产生混淆（旧名/旧流程与当前 design 完全不同）。
- **建议**: 考虑进一步精简为仅保留"为什么废弃"的摘要，其余内容删减。当前标注 + 主体保留的方式可接受但不理想。
- **置信度**: 中
- **优先级**: LOW

---

## 改进建议

### S1. 模板文件统一 profile 感知标注

当前多个模板（leader_checkpoint.md、index.md）使用了 heavy 专用路径或变量（`$OP_HOME`），未标注 lite 下的替代方式。建议所有引用脚本路径/环境变量的模板统一采用以下模式之一：
- 使用 `${OP_SCRIPT_ROOT:-$OP_HOME}` fallback 写法
- 在注释中标注 "heavy: 使用 X; lite: 使用 Y"

### S2. tasks_list.json 模板中补回 `spec` 字段的正确格式

如 H1 所述，当前 `"spec": "{TID}"` 应为 `"spec": "specs/{TID}_{slug}.md"`。同时建议在模板注释中注明 spec 文件路径相对于 `op_execution/` 目录。

### S3. RULES.md 状态枚举加 ASCII 对照列

RULES.md 第 27-37 行状态表使用中文值（`待规划`/`待开始`/…），与 design §1.1 定义的 ASCII 机读值（`pending`/`ready`/…）缺少直观的对照。建议在表中增加一列 "机读值 (ASCII)"，使读者一眼能看到 `待开始` = `ready` 的映射关系，避免向脚本传入中文 status。

### S4. README.md 模板补充 lite 分支说明

模板 README.md 描述的是 heavy 完整三区模型（含 blueprint 真相源）。lite 用户照此模板会困惑——他们也有 op_blueprint/ 目录但只是空壳。建议在模板中加一小段 lite 差异声明或引导到 design §5。

### S5. 协调 index.md 与设计文档对 op_record 内容的描述

- index.md 第 45 行：`brief/report/review` → 应为 `report/review`
- design §1 第 107 行：`已完成 task 的 report/review 归档` —— 正确
- RULES.md 不做 section、progress.md 一行一 task —— 正确
建议逐文件 grep `brief` 统一清理（design D27 已明确无 brief 文件）。

---

## 不确定项 / 可能误报

### U1. tasks_list.json 模板 `type` 字段是刻意补充还是遗留

如 H2 所述，`type` 字段不在 design §2.3 task 元数据规范中，但可能是有意为之——eval 免派判据依赖 change type（feat/fix/refactor），dispatch 脚本需要此信息。若是刻意补充，应同步更新 design §2.3 的 task 元数据规范，并确认值用英文枚举还是中文。本报告按"design 为唯一契约"原则标记为 HIGH，若确认是刻意补充则降级为 LOW（纯文档补齐）。

### U2. op_first_run.md 应被视为历史档案还是现行文档

该文件定位为"一次性执行计划"，完成后移 `docs/archive/`。当前尚未归档。若仍为现行文档，模型档位（M7）、`$OP_HOME` 引用等应与 design 对齐；若即将归档，则无需修复。本报告按现行文档对待，标记了几处 LOW 问题。

### U3. RULES.md lite compact 恢复路径在 D5 完成后的迁移风险

M1 已记录当前过渡态。但 design §5.5 说"完整归并...待重构"，无明确时间线。若此过渡态维持较久，建议在 RULES.md 中明确标注为过渡路径，防止未来被当作"最终形态"。
