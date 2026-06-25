# 用户记录的经验 不作为参考 未经用户允许绝不准修改

- [obra/superpowers: An agentic skills framework & software development methodology that works.](https://github.com/obra/superpowers)
  - /superpowers:brainstorming 生成 spec
  - /superpowers:writing-plans 生成 plan
- [Fission-AI/OpenSpec: Spec-driven development (SDD) for AI coding assistants.](https://github.com/Fission-AI/OpenSpec)
- [mattpocock/skills: Skills for Real Engineers. Straight from my .claude directory.](https://github.com/mattpocock/skills)
  - /grill-me 生成 prd

上面三个项目的介绍在这里，/home/karon/karson_ubuntu/user_config_backup/overview

## GLM
该 skill 化的（按价值排）

  1. tech_debt-to-tasks（你提的）
  - 扫 tech_debt.md → 按主题归类 → 拆 task → 建 spec + tasks_list
  - 这轮我手动做：读 102 条、写正则归类、拆 8 个、写 spec。纯机械，该自动化
  - 触发：/tech-debt-tasks 或收口后自动提示

  2. 收口 checklist（最该搞，因为我每次都漏）
  - task 收口时强制 checklist：git status 清空 / tech_debt 整段追加 /
  checkpoint 更新 / review 归档完整 / specs 更新 / commit + hash 回填
  - 每项打勾才算闭环，缺一项不许进下个 task
  - 这轮 70 个 diff 堆积、tech_debt 漏记、checkpoint 不更新——全是没 checklist
  导致
  - 触发：收口前 /closeout-checklist T09

  3. task-spec-generator
  - 从需求/PRD 一句话 → brainstorming spec → writing-plans plan
  - 协议第3步"需求到 task 前置流程"，我现在每次手写 spec 慢且不一致
  - 触发：新 task 时 /gen-spec T41 <需求>

  4. review-triage
  - 读 review_*.md → 提取 verdict + tech_debt 表 + blockers → 结构化返回给
  leader
  - 协议"leader 只取首行 verdict，不读正文"，但我每次还是手动 sed/grep
  还常截断
  - skill 强制 schema 返回 {verdict, blockers[], tech_debt[]}，leader 不读正文
  - 触发：review 完成后自动

  不该 skill 化的

  - DAG 调度/并发编排：每次依赖图不同，leader 判断更灵活
  - FAIL 轮派活：本质就是 SendMessage，没必要包
  - coder 写代码：已有 TDD skill

  优先级

  收口 checklist > tech_debt-to-tasks > review-triage > spec-generator

  收口 checklist
  最急——它防的是"系统性漏提交/漏记录"，这轮栽得最惨。其他三个是效率提升。

  要我先写哪个 skill？建议从收口 checklist 开始，马上能用在后续 T22/T29/T30
  收口。

# CLAUDE
这套 harness 的本质瓶颈不是「能力不够」，是
  leader(opus) 的纪律不可靠——你自己栽的坑（70 diff
  堆积、漏记 tech_debt、恢复后该并发却串行）全是纪律
  失效，不是不会做。所以该补的 skill
  是把易漏的固定流程从「靠 leader
  自觉」变成「强制执行」，不是加新花样。

  最该做（按价值，呼应你 experience.md 但调整了排序）

  skill: closeout（收口编排）
  补的环节: step 6-8 全流程
  为什么是 skill 而非现状: 现在只有 close_check.sh
    验收，没有执行。收口 8 个动作（提 tech_debt
    结构化块→追加→整理 specs→改  status→git mv
  归档→写
     checkpoint→commit→回填 hash→跑 close_check）全靠

    leader
    串行记得。这是最常漏的环节，最该固化成一条引导流
  程。
  ────────────────────────────────────────
  skill: resume（compact 恢复）
  补的环节: compact 恢复流程
  为什么是 skill 而非现状: 协议白纸黑字写「⚠️
    恢复后必须重算 DAG，不吃 checkpoint
    惯性」——说明你真踩过串行坑。文字警告挡不住  LLM
    偷懒。skill 把「读三件套→强制重算 DAG
    层宽→重建/复用 team」变成不可跳过的步骤。
  ────────────────────────────────────────
  skill: intake（需求→task 前置）
  补的环节: step 0 前置流程
  为什么是 skill 而非现状: 现在依赖 leader 记得「先改

    ref 再 brainstorming 再 writing-plans」。skill
    串起来：改哪些 ref→追加 tasks_list→调 superpowers

    生成 spec/plan，保证顺序不乱、不漏 ref 同步。
  ────────────────────────────────────────
  skill: debt-to-tasks（技术债偿还）
  补的环节: tech_debt 偿还
  为什么是 skill 而非现状: 你已描述：扫
    tech_debt.md→按主题归类→拆偿还 task→建

  spec。纯机械，价值明确，但优先级最低——它在所有功能
      task 跑完后才用，不是高频。

  关键判断：别都做成 skill

  你 experience.md 里把「收口 checklist」当
  skill——但它最强的形态是脚本（已有 close_check.sh）+
  skill 编排混合。审核也指出 autofix 的 scope-check
  用 AI 判断不够硬。原则：

  - 能确定性判断的 → 脚本/hook（git mv、改
  status、回填 hash、文件齐全校验、scope
  行数检查）。close_check.sh 是正面样板。
  - 需要语义判断的才 → AI skill（「整理
  specs」要判断哪些是当前生效规格、review-triage
  要理解 blocker）。

  所以 closeout skill = 薄 AI 编排层（判断 specs
  整理）+ 厚脚本（机械动作），不是纯 prompt。

  不该做

  - DAG 调度 / FAIL 派活 / coder 写码——你
  experience.md 判断正确。前者每次依赖图不同需 leader
  灵活判断，后者已有 coder agent + TDD。
  - review-triage 独立 skill——task_review.js 的
  VERDICT schema 已经在做结构化返回，跑通后这个需求自
  - 能确定性判断的 → 脚本/hook（git mv、改
  status、回填 hash、文件齐全校验、scope
  行数检查）。close_check.sh 是正面样板。
  - 需要语义判断的才 → AI skill（「整理
  specs」要判断哪些是当前生效规格、review-triage
  要理解 blocker）。

  所以 closeout skill = 薄 AI 编排层（判断 specs
  整理）+ 厚脚本（机械动作），不是纯 prompt。

  不该做

  - DAG 调度 / FAIL 派活 / coder 写码——你
  experience.md 判断正确。前者每次依赖图不同需 leader
  灵活判断，后者已有 coder agent + TDD。
  - review-triage 独立 skill——task_review.js 的
  VERDICT schema 已经在做结构化返回，跑通后这个需求自
  动消失，别重复造。

  我的最终排序

  resume ≈ closeout  >  intake  >  debt-to-tasks

  我把 resume 提到和 closeout 并列第一（你原排序没有它
  ）——因为收口漏一次是脏数据，恢复错一次（该并发却串行
  ）是整波次效率归零，且协议已证明这坑你踩过。

  要我先写哪个？建议 resume：最小（读三件套+重算DAG+重
  建team）、马上能用、防的是最贵的错。


## DS
  1. 收口执行 skill（最急）
    - close_check.sh 只做检查，不执行收口动作
    - 缺的是：追加 progress.md → decisions.md →
  tech_debt.md → 更新 harness_blueprint/specs →
  git mv 归档 → 盖戳 → commit →
  checkpoint。全是机械步骤，漏一项就漂移
    - 触发：leader 判定双 PASS 后，/closeout T05
  2. 开工选 task skill
    - 第 0 步的 jq 查询 + DAG
  分层计算是纯算法，不是判断
    - skill 输出：下一个 task ID + 依赖是否满足 +
  同层可并发 task 列表 + 共享文件交集警告
    - leader 只做"串行还是并发"的策略判断，不手工
  jq

  P1 — 高频，已有思路

  3. task 初始化 skill
    - experience.md 提了
  task-spec-generator，但范围偏窄
    - 实际是：需求 → 更新 ref 文档 → 追加
  tasks_list.json → brainstorming spec →
  writing-plans plan → 建目录拷模板
    - 一条 /new-task "用户登录功能" 跑完全程
  4. review-triage skill（experience.md 已提）
    - 读 review_*.md → 结构化返回 {verdict,
  blockers[], tech_debt[]}
    - 在 task_review.js
  跑通前，这是手工模式的必要补充

  P2 — 低频但有价值

  5. tech_debt→tasks skill（experience.md 已提）
  6. worktree 生命周期 skill：git worktree add →
  跑完后 git worktree remove，避免残留 worktree
  7. compact 恢复 skill：自动读 quick_ref +
  tasks_list + checkpoint，重建编排状态

  不做： DAG 调度策略判断、FAIL 轮派活、coder
  写代码。这些要么需要 leader 判断，要么已有
  agent。


## MiMo

 1. leader-workflow（编排 skill）
  当前 leader 完全靠读 1500 行 protocol
  手动编排。需要一个 skill 把"选 task → 派 coder →
  调 task_review.js → 收口 → 更新
  checkpoint"串成可执行流程。leader 输入 /leader
  就能跑一轮。

  2. close-task（收口 skill）
  close_check.sh 是 bash 只做检查，但收口还有大量
  手动活（commit、归档、更新 tasks_list/tech_debt/
  checkpoint/progress）。需要一个 skill 把检查 +
  落盘 + commit 一条龙。

  3. sync-harness-docs（文档同步 skill）
  当前最大维护债：VERDICT schema 三处复制、引用失
  效、模板和实际文件不同步。需要一个 skill 扫描
  harness 目录的交叉引用和重复定义，报告不一致。

  次优先

  4. write-spec（规格生成 skill）
  brainstorming → spec.md 这步现在是 leader
  手工做。标准化输入（用户需求）→ 输出（符合
  template 的 spec.md）可以抽成 skill。

  5. compact-recovery（恢复 skill）
  当前恢复流程 5 步（读 checkpoint → 读 tasks_list
  → 读 quick_ref → 判断续/新 → 重建
  team）。可以一个 /recover 搞定。

  不需要 skill 的

  - coder 和 test-reviewer 已经有 agent
  prompt，够用
  - task_review.js 等 Workflow 脚本本身就是可执行
  skill，不需要再包一层

  ---
  优先级建议：先做
  1（leader-workflow），因为它把整个 harness
  从"读文档手动编排"变成"一个命令跑起来"。其他都是
  锦上添花。