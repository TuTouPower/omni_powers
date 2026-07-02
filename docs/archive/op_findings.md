# omni_powers 实验发现

> 2026-06-25 实验验证。记录实验结论和决策依据，最终规则见 RULES.md。

## 实验 1：spawn 同名行为

**方法**：创建 team，spawn 两次 `name: "test"`。

**结果**：
| 次序 | 输入 name | 实际 agent_id | 实际 name |
|---|---|---|---|
| 第 1 次 | `test` | `test@test-team` | `test` |
| 第 2 次 | `test` | `test-2@test-team` | `test-2` |

**结论**：同名 spawn 自动加序号（`-2`, `--3`...），不报错，不复用。必须 spawn 前查 config。

## 实验 2：shutdown 机制

**方法**：SendMessage 含 `{"type":"shutdown_request"}`（嵌入文本，不能裸发 JSON）。

**结果**：
- teammate 回复 `shutdown_response` approve: true ✅
- teammate 标记 `isActive: false` ✅
- **但 Claude Code 实例和 tmux 面板不关闭** ❌ — 进程残留为孤儿
- config.json 中 `isActive: false` 条目残留

**结论**：shutdown 只是"口头关闭"，需额外清理 config + kill tmux pane。

## 实验 3：shutdown 后 config 残留

**方法**：shutdown `test` → 检查 config → 尝试 spawn 同名 `test`。

**结果**：
- shutdown 后 config 保留 `isActive: false` 条目
- 直接 spawn 同名 → 被加序号为 `test-2`
- jq 删除残留条目后 spawn 同名 → 正确得到 `test`

**结论**：shutdown 后必须用 jq 清 config 残留，否则同名 spawn 会被加序号。

## 实验 4：tmux 面板清理

**方法**：shutdown teammate 后检查 tmux 面板列表。

**结果**：
- shutdown 后面板仍存在
- config 中的 tmuxPaneId 可能不准确（面板已关闭/ID 被复用/teammate 重启后变化）
- `tmux kill-pane -t {paneId}` 可能失败

**结论**：tmux 清理不可靠，尝试 kill-pane，失败忽略。推荐用 in-process 模式避免此问题。

## 实验 5：Agent Team 上下文监控

**方法**：对比 tmux 和 in-process 模式。

| | tmux | in-process |
|---|---|---|
| 精确上下文占用 | ✅ `tmux capture-pane` | ❌ 拿不到 |
| shutdown 后清理 | 面板残留 | 无残留 |
| 适用 | 调试 | 生产 |

**结论**：推荐 in-process（D2）。tmux shutdown 后面板残留，不值得。上下文监控见实验 6 和 D5。

## 实验 6：ctx_stats 可用性

**方法**：spawn 三个 omni_powers agent，SendMessage 要求运行 `ctx_stats`。

**结果**：
| teammate | model 参数 | 实际模型 | ctx_stats |
|---|---|---|---|
| op-coder | `haiku` | `default_haiku` | ✅ 可用 |
| op-op-code-reviewer | `sonnet` | `default_sonnet` | ✅ 可用 |
| op-op-test-reviewer | `sonnet` | `default_sonnet` | ✅ 可用 |

**结论**：ctx_stats 在 teammate 上可用，但**对上下文监控无用**——只显示 context-mode 拦截了多少字节，不显示 teammate 的实际上下文窗口占用率，无法用于判断何时需重建 teammate。

## 实验 7：model 参数

**方法**：不传 model → 观察结果 → 显式传 model → 对比。

**结果**：
- 不传 model：继承主会话模型（Claude Opus 4-8），不是 agent 定义文件里的 model
- 显式传 model：正确使用 `default_haiku` / `default_sonnet`

**结论**：spawn 时必须显式传 `model` 参数。agent 定义文件里的 model 字段不被 spawn 读取。

## 实验 9：superpowers subagent-driven-development 研究

**日期**：2026-06-27

**方法**：逐文件研读 superpowers `subagent-driven-development` skill 的 SKILL.md、implementer-prompt.md、task-reviewer-prompt.md 及 3 个脚本。

**结果**：

| 设计点 | superpowers 做法 | omni_powers 现状 |
|---|---|---|
| 文件交接 | diff不进controller上下文，`review-package` 打包成文件传路径 | prompt里传文件路径，controller不读diff ✅ |
| 进度ledger | `.superpowers/sdd/progress.md`，compact后从ledger+git log恢复 | `leader_checkpoint.md` 起类似作用 |
| implementer自审 | coder完成前自审（completeness/quality/discipline/testing），写report | coder追加context.md，无结构化自审清单 |
| review维度 | 二维合一：spec合规（缺/多/错）+ 代码质量 | 二维分开：code_review + test_review（并行） |
| task-brief提取 | 脚本从plan提取单task文本，implementer只读自己的brief | coder直接读spec+plan全文 |
| fixer独立 | 独立fix子agent改完后追加report文件，reviewer重审 | coder自己修复，在review_*.md追加Fix-N |
| review-package | `BASE..HEAD` commit列表+stat+完整diff→单个文件 | reviewer直接跑git diff |

**可借鉴的点**：

1. **coder自审清单** — superpowers的implementer要求完成前自审4维度（completeness/quality/discipline/testing），比现在"追加context.md"更结构化
2. **task-brief隔离** — 从plan提取单task文本，避免coder读全局plan后过度设计。omni_powers spec/plan通常短，收益有限
3. **review-package** — 把diff打包成文件而不是让reviewer跑git命令，更可控（但当前也用git diff，无大问题）
4. **文件交接** — omni_powers已经在做（review文件→脚本读verdict），这个方向是对的
5. **进度ledger** — checkpoint已经起到恢复作用。但superpowers的ledger设计更简单：一行一条，compact后`cat .superpowers/sdd/progress.md`即知进度

**不照搬的理由**：

- superpowers review是串行（implementer→reviewer→fixer→re-review），omni_powers是code+test并行review后统一回coder修复。并行更快
- superpowers需要每task写report文件→review→fix→re-review循环，交互次数多。omni_powers一步并行review后按轮次退回，交互少
- superpowers的reviewer不信任implementer报告（"Do Not Trust the Report"），需要独立验证。omni_powers coder的context.md是给reviewer提供上下文，不是替代review
- superpowers假设每个task有明确的文件交接（brief/report/diff三个文件），omni_powers所有信息在task目录下，结构更紧凑

