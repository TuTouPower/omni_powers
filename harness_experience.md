每次搞完关闭无用的 teammate

用 workflow

 做错的（3 个核心问题）

  1. teammate 不会复用，全靠你两次纠正才改
  - coder FAIL 轮新开 coder-t24-2（该唤醒 coder-t24）
  - reviewer 跨 task 新开 reviewer-2/test-reviewer-2（该唤醒常驻 reviewer）
  - 根因：teammate 发 idle 通知后，我没当它"可唤醒资源"，直接 spawn 新的
  - 改进：idle = 可唤醒。FAIL 轮/新 review 一律 SendMessage 唤醒原实例，绝不新 spawn。spawn 只用于"全新 task + coder 上下文已满需重建"

  2. worktree 隔离漏做
  - 协议明确写 isolation: "worktree"，我 spawn 时漏传参数
  - 同工作树跑 4 个 coder，收口时 T11 漏文件、T09 改动和其他 task 混在一起，commit 边界模糊
  - 改进：下一批起每个并发 coder 带 isolation: "worktree"，收口时 leader 串行合并 + 跑全量测试

  3. 开工没重算 DAG，吃 checkpoint 惯性
  - checkpoint 写"串行"，我没按协议"开工调度"四步重算，直接单跑 T9
  - 你提醒才并发
  - 改进：恢复时 checkpoint 只提供断点，调度逻辑必须按协议重算层宽

  流程层面的洞

  4. FAIL 轮的修改记录位置不一致
  - T7 coder 写在 context.md，test-reviewer 重审要跨文件找
  - T11/T24/T27 改进为写 review_*.md 同文件追加
  - 改进：协议固化——FAIL 轮 coder 在 review_*.md 追加"修改记录"段，不写 context.md

  5. commit 粒度 + 漏文件
  - T11 commit 漏了 specs/review 归档文件，补了一次
  - 并发同工作树导致改动混杂，收口要反复 git status 挑文件
  - 改进：worktree 隔离后，每 task 收口 = 自己 worktree 的全部改动，一次 commit 干净

  6. cost hook 误报
  - StrategicCompact hook 按 200k 窗口算报 92%，实际 1m 窗口才 19%，差点误触发 compact
  - 改进：hook 需按实际窗口（1m）算阈值，或忽略该提示

