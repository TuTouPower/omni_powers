# omni_powers_design.md 审阅报告（Opus）

## 审阅范围

- 审阅对象：`docs/omni_powers_design.md`
- 审阅维度：结构完整性、需求/状态机一致性、heavy/lite 分叉一致性、Agent 协作边界、可执行性、风险与遗漏
- 审阅方式：只读审阅，不修改原文档

## 总体结论

文档具备较强架构深度与实操价值。核心理念“规格是唯一契约”“资产与工单分离”准确针对 LLM 自动开发中常见的假绿、同源污染、上下文污染问题。heavy/lite 分叉通过“执行内核共享 + 环境集成层差异”收敛，抽象清晰，长期维护成本可控。

文档对 Claude Code 当前限制有清醒声明：hook 对 subagent 的拦截失效、P2 前结构隔离与 CI 证据链尚未落地、heavy 当前主要增量是流程资产而非安全隔离。这种诚实声明提升可信度。

主要风险集中在 P2 前后交界：e2e 合法写入与 git 硬锁机制尚未定型、过渡期 evaluator 防抄实现依赖纪律、lite 模式上下文膨胀缺强制保护。

## 主要问题

### CRITICAL

无。

### HIGH

#### H1. e2e 合法写入与 git 硬锁冲突仍是开放风险

`docs/omni_powers_design.md` §8.3 明确登记 `e2e/**` 硬锁与合法写入路径冲突：evaluator 固化 PASS 测试、leader 转交 BUG-* patch、closer 提案后 leader 改跨功能既有 e2e。

问题不是记录不足，而是该点直接影响 P2 隔离模型能否闭环。若硬锁先实现、合法入口后补，容易出现两种失败形态：evaluator 被锁死；或解锁通道过宽导致硬锁失效。

#### H2. P2 前 evaluator 访问隔离仍高度依赖纪律

`docs/omni_powers_design.md` §8.1、§10、§0.1 已明确当前 worktree 未排除 `src/**`、task 目录、`decisions.md`，结构隔离尚未落地。过渡期主要靠 prompt 与路径约定。

这会削弱 Stage 4 独立验收的核心价值：evaluator 若读到实现细节，可能按实现写测试，导致实现错、测试也错、一起绿。文档已诚实标注，但需要在运行层尽早给出可检测审计。

### MEDIUM

#### M1. lite leader 上下文水位保护偏软

`docs/omni_powers_design.md` §14.1 写到每 N task 自检上下文水位，逼近阈值提示 `/compact` 或建议转 heavy。该策略正确，但“提示”不足以阻断风险。lite 的 leader 亲自读 report、跑测试、读 diff，连续 task 后容易进入静默失能。

#### M2. decisions.md append-only 多写者依赖串行纪律

`docs/omni_powers_design.md` §7.4 将 `decisions.md` 定义为多来源 append-only 文件，并用 task 严格串行规避冲突。正常路径成立，但中断、重试、subagent 延迟回报、人工恢复时仍可能重复 append 或顺序错位。

#### M3. `OP_SCRIPT_ROOT` 注入失败缺显式探活

`docs/omni_powers_design.md` §13.3 依赖 leader dispatch prompt 注入 `OP_SCRIPT_ROOT` / `OP_PROFILE`。若漏传或路径错误，agent 可能在后续脚本调用处才失败，错误定位成本偏高。

### LOW

#### L1. §10 防线描述与映射表信息重复

`docs/omni_powers_design.md` §10 正文与防线层映射表都描述当前/目标状态。重复本身无害，但会增加维护漂移风险。

#### L2. §15 落地状态承载过多决策史

`docs/omni_powers_design.md` §15 同时写落地状态、新增决策、用户裁决，信息密度较高。作为尾注可读，但长期更适合只保留状态摘要，决策细节回链 `docs/op_decisions.md` 或归档文档。

## 具体建议

1. **先定 e2e 合法写入入口，再落 git 硬锁。** 建议统一由 leader 主会话执行合法写入，配套 commit trailer + 解锁脚本校验；evaluator/implementer 只产 patch 或报告，不直接越过硬锁。
2. **给过渡期 evaluator 加审计脚本。** 在 P2 结构隔离未落地前，扫描 evaluator 操作记录或验收报告引用路径，发现 `src/**`、task 目录、`decisions.md` 访问痕迹时标红，不把 advisory 当安全。
3. **lite 水位检查从提示升级为软阻断。** 连续触发阈值后暂停流程，要求用户 `/compact`、拆 spec，或转 heavy。
4. **decisions.md append 增加去重与时序标记。** 每次 append 带 task id、round、来源、hash；post 收口脚本检查本 task 追加是否存在且只存在一次。
5. **agent 脚本入口前置探活。** `op-implementer`、`op-reviewer`、`op-evaluator` 调脚本前先解析 `${OP_SCRIPT_ROOT:-$OP_HOME}`，为空或目录不存在则输出明确 FATAL。

## 值得保留的设计

1. **§0.1 安全增量诚实声明。** 明确 P2 前 heavy≈lite 防篡改水位，避免误导用户。
2. **§3 三区制。** `op_blueprint` / `op_execution` / `op_record` 分离，能降低工作产物污染生效规格的风险。
3. **§5.2 契约边界规则。** “是否需要改 spec 文本”作为执行期自决与阻塞的机械分界，清晰可操作。
4. **§8.1 hard-pass gate + 预期失败模式 + 破坏检查。** 将 evaluator 从“看起来可以”拉回“亲自观察到 Then”。
5. **§13 执行内核与环境集成层二分。** heavy/lite 共享核心逻辑，差异集中在安装、校验、脚本定位、blueprint、闸门、收口角色。
6. **§14.3 lite 退化矩阵。** 逐角色说明缺失 blueprint 后具体退化形态，避免“lite 等价 heavy”误读。

## 验证清单

- [ ] §8.3 是否已从开放问题变为明确机制：合法写入入口、身份校验、失败处理均定义。
- [ ] P2 前是否有 evaluator 访问源码/任务目录的审计手段。
- [ ] P2 worktree sparse-checkout 是否覆盖 Linux、macOS、Windows Git Bash / WSL。
- [ ] lite `oplrun` 是否实现上下文水位检查，并在连续告警时暂停。
- [ ] `decisions.md` append 是否具备 task id + 来源 + 去重标记。
- [ ] `${OP_SCRIPT_ROOT:-$OP_HOME}` 是否在所有共享 agent 中有前置探活。
- [ ] §10 防线状态是否收敛到单表维护，减少重复声明。
- [ ] §15 决策史是否回链到 `docs/op_decisions.md` 或归档文档，正文只保留当前状态。
