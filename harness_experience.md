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
  - 改进：协议固化——按边界类型切。构建边界（每 step 正向进度）写 context.md；质量边界（FAIL 轮来回）写 review_*.md。FAIL 轮禁止碰 context.md，重审一个文件看全线程。

  5. commit 粒度 + 漏文件
  - T11 commit 漏了 specs/review 归档文件，补了一次
  - 并发同工作树导致改动混杂，收口要反复 git status 挑文件
  - 改进：worktree 隔离后，每 task 收口 = 自己 worktree 的全部改动，一次 commit 干净

leader 发现单个 task plan 太大 拆分成多个 step 的话是否应该分成多个 commit，多次收口
- 结论：不。收口是 task 级语义动作，step 凑不齐（status 不能→完成、目录不能归档、review 看整 task diff、回滚以 task 为粒度）。step 不收口、不单 commit。
- 真正的洞：大到要"多次收口" = 拆分粒度错了 → 拆 task 不是拆 commit。拆 task 派 task-splitter（sonnet）执行：建目录 + 切（非重跑）spec/plan + 改 tasks_list，全在它上下文跑，不污染 leader。
- WIP sub-commit 允许（崩溃保护），但与收口完全脱钩：纯代码落盘，不改 status/不归档/不写 checkpoint。
