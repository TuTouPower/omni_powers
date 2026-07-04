# 首跑计划：人工 leader 跑通全流程

> **定位**：一次性执行计划。目标——人工作为 leader，在真实项目上把 omni_powers 全流程（opinit → opintake → oprun → 闸门 C → 归档）跑通一遍，evaluator 按 TESTING_PLAN 用 CDP/CUA 执行验收。
> **形态**：半自动——主会话照 skill 执行，每个节点（dispatch / 状态流转 / commit / 闸门）停下人工确认。
> **产出**：跑通记录 + 摩擦点清单 + 人工 leader runbook 素材 + evaluator 二阶判断首批校准样例。
> **完成后**：本文档移 `docs/archive/`，结论沉淀进 op_decisions.md。

---

## 0. 前置检查（跑前一次做完）

### 环境（Win 宿主，插件在 Win 侧 Claude Code 调用）

- [ ] `jq --version`（hooks 依赖；无则 `choco install jq` / `scoop install jq`）
- [ ] Git for Windows（bash + cygpath，hook polyglot wrapper 依赖）
- [ ] `cua --version`（无则 PowerShell: `irm https://raw.githubusercontent.com/trycua/cua/main/libs/cua-driver/scripts/install.ps1 | iex`）
- [ ] `cua do-host-consent` 已做（一次性），`cua do switch host` + `cua do status` 确认 target=host
- [ ] `cua do screenshot` 能出图（验证权限/显示器就绪）
- [ ] Playwright 可用（靶子项目内 `npx playwright --version`）

### 模型档位（主会话当前为 haiku，不设则全线继承——必须设）

```
OP_IMPLEMENTER_MODEL=sonnet
OP_REVIEWER_MODEL=sonnet
OP_EVALUATOR_MODEL=opus      # computer use 多模态判断 + 对抗性思维
OP_CLOSER_MODEL=haiku
```

写进使用方 `.claude/settings.json` env 段（opinit 时顺带）。spec 编写在主会话——闸门 A 前 `/model` 切 Opus。

### 靶子项目

候选：两个 Electron 项目、两个浏览器扩展。**首跑选最小的 Electron 项目**：

- Electron 同时覆盖 CDP 域（渲染层）与 cua 域（原生壳层），一个靶子吃两条通道
- 前置确认：该项目 dev/test 构建能开 `--remote-debugging-port`（生产包通常关 CDP）
- 扩展项目留第二轮（headed persistent context 基建多一层）

---

## 1. 三阶段路线

```
阶段 1  首 spec（纯 CDP 域）─── 验证流程管道，零 cua 依赖
   ▼
阶段 2  CUA spike（流程外）──── 验证 cua-driver 驱动 Electron 壳层可行性
   ▼
阶段 3  第二 spec（含 cua 域 AC）─ 验证完整 evaluator 验收 + cua lane
```

### 阶段 1：首 spec，纯 CDP 域

**选题**：渲染层小 feat（TP-ELEC-001~003 范围：UI/表单/preload API/IPC），2-4 个 task 的量。刻意排除原生壳层。

**流程**（人工守每个节点）：

| 步骤 | 主会话做什么 | 人工确认什么 |
|---|---|---|
| `/opinit` | 生成三区骨架 + hooks 注册 + `$OP_HOME` env | 目录/hook 落对位置；Windows 路径无异常 |
| `/opintake "<需求>"` | 分拣 → spec（可测性契约含**通道字段**）→ 拆 task | — |
| **闸门 A** | 呈报 spec | INV 覆盖沉默失败区、Then 可断言、**每条 AC 通道判定对不对**、预期失败模式每 AC ≥1 条。批 → approved + commit |
| `/oprun` task 循环 | brief → implementer → reviewer 双裁决 → closer 收口 → commit | 每次 dispatch 前看 brief；verdict 后看 review.md；commit 前看 diff |
| **Stage 4 验收** | 组装 eval brief → 派 evaluator（CDP 通道跑 Playwright） | **自举例外**（design §12）：你对照 spec 手工复核 evaluator 每条 AC 结论 + 抽 1-2 条做二阶判断（只测了成功路径吗？）——这是首批校准素材 |
| **闸门 C** | 呈报四样：验收报告 + AC 追溯矩阵 + 自决决策表 + P0/P1 issue | 批 closer 收尾提案 → 写入 op_blueprint + baselines 合入 + 叶子归档 |

**边跑边记**（本阶段核心产出之二）：
- Windows 摩擦点：`sed -i`/路径拼接/jq 在 Git Bash 下的异常，逐条记
- 人工 leader runbook：每 stage「跑什么脚本 → 看什么文件 → 批什么」一行，攒成 `docs/op_manual_leader.md` 底稿

### 阶段 2：CUA spike（首跑后立即，不进 task 机制）

只回答一个问题：**cua-driver 能否驱动该 Electron app 的原生壳层**。

- [ ] `cua do window ls <app>` 能列出目标窗口
- [ ] 点一次应用菜单（TP-ELEC-007 最小版）：`zoom → screenshot → click → screenshot` 验证菜单项被触发
- [ ] 抓一个结构化副作用（`cua do shell` 查日志/文件）佐证操作生效
- [ ] （可选）扩展工具栏图标点击（TP-EXT-016 最小版），为第二轮扩展项目探路

失败路径也有价值：某能力不行（托盘/IME/DPI，见 TESTING_PLAN 附 A 风险表）→ 记入 issues，对应 cua 域 AC 在 spec 期就判定为「人工验收步骤清单」而非自动化。

### 阶段 3：第二 spec，含 cua 域 AC

**选题**：带 1-2 条原生壳层 AC 的小 feat（如菜单项触发某行为），CDP 域 AC 为主、cua 域 AC 点缀。

验证目标（阶段 1 已验证的不重复看）：
- [ ] spec 通道判定：CDP/cua 混合正确标注，闸门 A 能审出错标
- [ ] eval brief「执行后端」段：cua 探测输出正确（可用 → version+target）
- [ ] evaluator cua 通道：Look→Act→Verify 真操作，结构化副作用作硬证据，截图作锚点
- [ ] 降级规则：可故意 `cua do switch` 到错误 target 一次，验证 evaluator 判 `INSUFFICIENT_EVIDENCE` 而非跳过（钓鱼审计最小版）
- [ ] cua 域固化物：`// channel: cua` 标注 + 独立 lane，破坏检查一次性验证

---

## 2. 成功标准

| # | 标准 | 验证方式 |
|---|---|---|
| 1 | 全流程走通：opinit → 闸门 A → task 循环 → Stage 4 → 闸门 C → 归档，无死锁 | 叶子归档进 op_record/，前缀标完成 |
| 2 | 状态机与脚本在 Windows 实跑无阻断性 bug | 摩擦点清单里无 P0 项未修 |
| 3 | evaluator 产出可信：hard-pass gate 无推论式 PASS，固化测试破坏检查全过 | 人工复核 + 抽查二阶判断 |
| 4 | cua 通道端到端可用（或明确判定不可用 + 降级路径生效） | 阶段 3 勾选项 |
| 5 | runbook 素材成型 | `docs/op_manual_leader.md` 底稿存在 |

## 3. 中断与回退

- 任一 task 两轮 review 不过 → 照 RULES.md 阻塞分流，**不为首跑放水**——阻塞本身是有效测试结果
- spec 期发现契约要改 → 走 spec 变更子流程（人批），验证该子流程也算赚
- 插件自身 bug → 修插件（WSL 侧开发）→ Win 侧重装/刷新 → 从 checkpoint 续跑（顺带验证 compact/续跑恢复）
- 阶段 2 spike 失败且无解 → 阶段 3 改纯 CDP 选题，cua 域整体降级为人工验收清单，记 decisions.md

## 4. 首跑后动作

1. 摩擦点清单 → 逐条转 issue/fix，走轻量直做或 task 机制
2. runbook 底稿 → 定稿 `docs/op_manual_leader.md`
3. 二阶判断校准素材 → 若抓到放水案例，写首条偏差指令进 evaluator few-shot（design §8.1 调教循环启动）
4. 本文档 → `docs/archive/`，结论并入 op_decisions.md（D20）
5. 第二轮靶子：浏览器扩展项目（TP-EXT 域，headed persistent context + 安装流程 cua 域）
