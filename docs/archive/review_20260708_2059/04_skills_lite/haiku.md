# lite skills 审阅（haiku 视角）

## 当前模型判断依据

- 审阅任务由 haiku 视角承担（用户授权多模型审阅，model_override_authorized）。
- 本次只读、仅写报告。核心参考 `docs/omni_powers_design.md`（§5 lite 模式、§0.2 能力矩阵、§1.1 状态枚举、§5.5/§5.9 无 hook 替代）。
- 审阅对象：oplinit / oplintake / oplrun 三 skill 的 SKILL.md + scripts，含三份 op_check_env 副本与共享寻址。

## 审阅范围

| 路径 | 类型 |
|---|---|
| `skills/oplinit/SKILL.md` | 初始化流程 |
| `skills/oplinit/scripts/op_check_env.sh` | 环境检查 |
| `skills/oplinit/scripts/oplinit_skeleton.sh` | 骨架生成 |
| `skills/oplintake/SKILL.md` | 需求入口 |
| `skills/oplintake/scripts/op_check_env.sh` | 环境检查 |
| `skills/oplrun/SKILL.md` | 续跑执行 |
| `skills/oplrun/scripts/op_check_env.sh` | 环境检查 |
| `skills/oplrun/scripts/op_status.sh` | 状态流转 |
| `skills/oplrun/scripts/op_jq.sh` | tasks 查询 |
| `skills/oplrun/scripts/op_coder_check.sh` | implementer 模式 |
| `skills/oplrun/scripts/op_read_verdict.sh` | verdict 读取 |
| `skills/oplrun/scripts/op_assemble_eval_brief.sh` | 裸评 brief |
| `skills/oplrun/scripts/op_close_post.sh` | 收口 |
| `skills/oplrun/scripts/close_check.sh` | 收口检查 |
| `skills/oplrun/scripts/op_check_p0.sh` | P0 阻断 |
| 横向：`scripts/build_lite.sh` + heavy `scripts/op_status.sh` + `skills/oprun/scripts/op_close_post.sh` | 副本同步基线 |

## 高优先级问题

### H1. op_close_post 传 `完成` 给 op_status，但 op_status 枚举只认 `done`——收口必崩

- **位置**：`skills/oplrun/scripts/op_close_post.sh:55`；heavy 同源 `skills/oprun/scripts/op_close_post.sh:54` 同样中招。
- **现象**：`bash "$SCRIPT_DIR/op_status.sh" "$TID" 完成`，中文"完成"作 status 入参。
- **对比**：`skills/oplrun/scripts/op_status.sh:34` 枚举为 `pending|ready|in_progress|reviewing|done|blocked|obsolete|suspended`，第 36 行 `*) die "无效 status: $status"`。
- **影响**：per-task 收口（SKILL.md 3.6）调 close_post，close_post 内 `die "更新状态失败"`，task 永远停在 `reviewing`/`in_progress`，oplrun 循环死锁。design §5.6「收口是 leader 瞬时操作」无法兑现。
- **建议**：两版（heavy + lite）`op_close_post.sh` 第 54/55 行 `完成` → `done`。这是 heavy+lite 共享 bug，不只 lite。
- **置信度**：高（脚本逐字核对，枚举与入参白纸黑字不匹配）。
- **优先级**：CRITICAL（阻断收口，状态机卡死）。

### H2. oplintake 写 `"status": "待开始"`（中文），design §1.1 强制 ASCII——oplrun 选不到 task

- **位置**：`skills/oplintake/SKILL.md:83` 步骤四示例 JSON。
- **现象**：示例 task 记录 `"status": "待开始"`。
- **对比**：
  - design §1.1 状态枚举表明列「机读 ASCII」，`ready` 对应中文「待开始」。
  - design §1.1 末尾铁律：「脚本内 jq/grep 比较一律用左列 ASCII 值」。
  - `skills/oplrun/scripts/op_jq.sh:15` `select(.status=="ready")`——oplrun 3.1 选 task 查的就是 `ready`。
- **影响**：leader 照 SKILL.md 写入中文 status，oplrun 的 `op_jq pending` 永远返回空，循环空转，无法进 implementer。SKILL.md 顶部"终点：task status=待开始"是渲染层中文表达，但步骤四示例直接落中文到 JSON 字段，混淆渲染层与机读层。
- **建议**：
  1. 步骤四示例 JSON 改 `"status": "ready"`。
  2. SKILL.md 顶部"终点：task status=待开始"补注"（机读 ready）"，或统一改"task status=ready"。
  3. design §5.6 lite 流程图同问题（`status: approved` 对，但下游"task status=ready"需在 SKILL 落地 ASCII）。
- **置信度**：高（design 明文 ASCII 铁律 + op_jq 代码实证）。
- **优先级**：CRITICAL（入口写错值，下游全断）。

### H3. P0 阻断检查（op_check_p0）在 oplrun 流程里无调用点——design §5.8/A18 P0 处置形同虚设

- **位置**：`skills/oplrun/SKILL.md` 全文搜不到 `op_check_p0`。
- **现象**：`scripts/op_check_p0.sh` 实现完整（扫 issues open P0、exit 1 拦归档），但 SKILL.md 步骤 3.5→3.6 之间、3.6 收口前后均未调它。
- **对比**：
  - design §5.8：P0 不事中阻断，但进 oplrun 结束报告标注——op_check_p0 是"事中机械检测、事后报告汇总"的桥。
  - op_check_p0.sh 注释明写"oplrun per-task 裸评 PASS 后、归档 task 前调本脚本"。
  - SKILL.md 3.5 末句"P0 不事中阻断（A18）"与 3.6 收口之间无 P0 扫描步骤。
- **影响**：P0 issue 即使存在，oplrun 既不事中扫也不进结束报告（结束报告段只说"扫 op_execution/issues/ open P0/P1 汇总"，但那是 leader 手动扫，无脚本兜底，易漏）。
- **建议**：
  1. SKILL.md 3.6 收口前显式 `bash "$SCRIPTS/op_check_p0.sh"`（exit 1 → 走 design §5.8 三选一）。
  2. 或在 3.5 裸评 PASS 后、3.6 前插 P0 检查子步骤，明确 P0 出现时 leader 呈报用户三选一的路径。
- **置信度**：高（脚本存在但 SKILL 流程无引用点，逻辑断链）。
- **优先级**：HIGH（P0 安全语义落地缺口，design §5.8 明文要求）。

## 中低优先级问题

### M1. op_status 用 flock，但 .gitignore 只忽略 `*.lock`——锁文件可能进暂存区

- **位置**：`skills/oplrun/scripts/op_status.sh:50-52`；`skills/oplinit/scripts/oplinit_skeleton.sh:39` 写 `docs/omni_powers/.gitignore`。
- **现象**：op_status 在 `$TASKS_FILE.lock`（= `docs/omni_powers/op_execution/tasks_list.json.lock`）上 flock；.gitignore 在 `docs/omni_powers/.gitignore`，规则 `*.lock`。
- **影响**：git 的 .gitignore 规则对子目录生效需 `**/*.lock` 或 `*.lock`（后者仅匹配当前目录同级，子目录锁文件可能漏）。实测 git 对 `docs/omni_powers/.gitignore` 中 `*.lock` 的匹配范围有限——`op_execution/tasks_list.json.lock` 可能不被忽略，进暂存区污染。
- **建议**：.gitignore 改 `**/*.lock` 或显式 `/op_execution/*.lock`，并在 oplinit_skeleton 落两行注释说明匹配范围。
- **置信度**：中（gitignore 语义需实测确认，但风险真实）。
- **优先级**：MEDIUM。

### M2. op_jq pending 命名误导——查询的是 `ready` 不是 `pending`

- **位置**：`skills/oplrun/scripts/op_jq.sh:14-18`。
- **现象**：`pending` 命令查 `status=="ready"`；`pending_plan` 查 `status=="pending"`。
- **影响**：SKILL.md 3.1 调 `op_jq pending` 取可跑 task，命名与 design §1.1 状态值 `pending`（待规划）撞名。leader 读脚本易误解，维护期改名风险。
- **建议**：重命名 `pending` → `runnable`（或 `ready`），`pending_plan` → `unplanned`；或保留命令名但注释强化"pending 命令 = ready 状态查询"。design §1.1 状态语义与脚本命令名解耦即可。
- **置信度**：中（功能正确，仅命名歧义）。
- **优先级**：LOW。

### M3. oplinit_skeleton 对"有 profile 目录但无 profile 文件"判定脆弱

- **位置**：`skills/oplinit/scripts/oplinit_skeleton.sh:24-27`。
- **现象**：`elif [ -d docs/omni_powers/op_execution ] && [ -f .../tasks_list.json ]` 判定疑似 heavy 残留。
- **影响**：lite 自己 oplinit 重跑时（幂等补缺），若用户手动删了 profile 文件但保留目录，脚本误判 die，阻塞幂等重跑。design §5.2 判定表"已有 docs/omni_powers/ 但无 profile → 默认 die"是正确语义，但判定条件应更严（如检测 .claude/hooks 痕迹，design §5.2 末行）。
- **建议**：加 heavy 特征探测（项目 `.claude/hooks.json` 或 `settings.local.json` 含 op hook 注册），降低误判。
- **置信度**：中。
- **优先级**：MEDIUM。

### M4. op_close_post 幂等重跑时跳过 verdict 校验路径——归档态重跑不验 review PASS

- **位置**：`skills/oplrun/scripts/op_close_post.sh:22-30`。
- **现象**：`ACTIVE_DIR` 在归档态取 `ARCHIVE_DIR`，仍会跑 verdict 校验（第 38-40 行）——这点正确。但归档态重跑时 `git mv` 段（42-45）跳过，progress 幂等追加（51）跳过，op_status die（H1）——组合下重跑行为半成品。
- **影响**：H1 修复前，close_post die 在 op_status；H1 修复后，归档态重跑逻辑需整体测一遍。
- **建议**：H1 修复后补一个重跑场景的集成测试（bats），覆盖"task 已归档、close_post 再跑"路径。
- **置信度**：中。
- **优先级**：LOW（依赖 H1 修复）。

### M5. oplrun SKILL 3.3 leader 自验只读 report 顶部 + evidence——无 verdict 机械读取，依赖 leader 主观判

- **位置**：`skills/oplrun/SKILL.md:110-117`。
- **现象**：leader 读 report.md head + 跑测试命令读 verdict + git diff --stat。
- **对比**：design §5.9「leader 亲自跑测试命令 + 读关键 diff 再判」——SKILL 落地基本对齐。但 leader 读"verdict"是测试命令输出，非脚本机械解析，无 PASS/FAIL 退出码兜底。
- **影响**：leader 长跑 compact 后判断易漂；无机械证据留存（只留 report.md 自述 evidence）。
- **建议**：leader 自验后把测试 verdict 写一行到 `tasks/{TID}/report.md` 的 leader-verify 段（机械追加），留审计轨迹。design §5.9 已暗示「脚本跑 + 单行 verdict 回传」。
- **置信度**：中。
- **优先级**：MEDIUM。

### M6. op_assemble_eval_brief 启动方式段只 echo "从工作 spec 提取"——未机械提取，留给 evaluator 自己读

- **位置**：`skills/oplrun/scripts/op_assemble_eval_brief.sh:37-38`。
- **现象**：brief 的"应用启动方式"段只输出一句指引，不提取 spec 可测性契约里的实际启动命令。
- **对比**：design §2.5 brief 机械组装应含"启动方式"具体值；heavy 版（`skills/oprun/scripts/op_assemble_eval_brief.sh`）行为需对比确认。
- **影响**：evaluator 需回读 spec 找启动命令，brief 自足性打折；A11 禁止读 task 目录实现细节，但 spec 是允许读的，影响有限。
- **建议**：brief 组装时 awk/grep 提取 spec「可测性契约-应用启动方式」行落入 brief，减少 evaluator 二次解析。
- **置信度**：中。
- **优先级**：LOW。

### M7. close_check 第 3 项 git status 提醒 grep 正则脆弱

- **位置**：`skills/oplrun/scripts/close_check.sh:43`。
- **现象**：`grep -v "^[MADRC? ]\+ ${arch}"`——`arch` 含 `/`，正则未转义，路径含特殊字符（如 `.`）时误匹配。
- **影响**：task ID 含点或正则元字符时 WARN 误报。当前 TID 格式 `T0001` 安全，但防御性不足。
- **建议**：用 `grep -vF` 或 `git status --porcelain | grep -v -- "^. ${arch}"`（-F 字面匹配）。
- **置信度**：中。
- **优先级**：LOW。

### M8. build_lite.sh 改造版标记校验不覆盖 op_close_post——H1 类 bug 无机制拦截

- **位置**：`scripts/build_lite.sh` MUTATED_MARK 段（需读完整确认，但从已读部分看改造版清单含 op_check_env/op_jq/op_status/op_close_post/op_assemble_eval_brief）。
- **现象**：build_lite 只校验"逐字节复制类"diff 一致 + 改造版含 lite 标记字符串。H1（完成→done）是 heavy 与 lite **共有** bug，build_lite 对比 lite vs heavy 源时，若 heavy 源也错，lite 同步复制错误，校验通过——漂移检测对"共有 bug"无效。
- **影响**：共有 bug 漏检，build_lite 绿不代表正确。
- **建议**：加 op_status 枚举与 close_post 入参的一致性专项断言（如 grep close_post 调 op_status 的 status 值，逐一 case 校验落在 op_status 枚举内）。
- **置信度**：中。
- **优先级**：MEDIUM（H1 已暴露，需补机制防复发）。

## 改进建议（汇总）

1. **立即修 H1**：heavy + lite 两版 `op_close_post.sh` 的 `完成` → `done`。一行修复，解除收口死锁。
2. **立即修 H2**：`oplintake/SKILL.md` 步骤四示例 + 顶部终点描述，status 统一 ASCII `ready`，中文仅渲染层。
3. **补 H3**：`oplrun/SKILL.md` 3.5/3.6 间插入 `op_check_p0.sh` 调用，落实 design §5.8 P0 事中检测。
4. **强健性**：M8 给 build_lite 加"入参-枚举"一致性专项校验，防共有 bug 复发。
5. **命名清理**：M2 `op_jq pending` → `runnable`，消除与状态值 `pending` 撞名。
6. **gitignore 加固**：M1 `*.lock` → `**/*.lock`。

## 不确定项

- **build_lite.sh 完整 MUTATED_MARK 清单未读全**：M8 结论基于已读 40 行推断，若改造版标记已覆盖 op_close_post 的"完成/done"校验，则 H1 应被 build_lite 拦住——但实测 H1 存在，反推校验未覆盖。需读 build_lite 第 25-38 行确认。
- **heavy op_status 是否也接受中文**：已确认 heavy `scripts/op_status.sh:38` 枚举纯 ASCII，不接受"完成"。但 heavy 流程是否在 close_post 外有独立 `op_status done` 调用绕过——未全量搜 heavy oprun SKILL，需 heavy 分块审阅交叉确认。
- **oplrun 结束报告"扫 issues"是否调 op_check_p0**：SKILL 收尾段（233 行）说"扫 op_execution/issues/ open P0/P1 汇总"，可能 leader 手动 jq 扫，与 op_check_p0 功能重叠或互补——需确认两者职责边界，避免重复扫描或漏扫。
