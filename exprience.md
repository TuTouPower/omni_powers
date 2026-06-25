# 用户记录的经验 不作为参考

[mattpocock/skills](https://github.com/mattpocock/skills)

/grill-me 生成 prd
/superpowers:brainstorming 生成 spec
/superpowers:writing-plans 生成 plan

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
