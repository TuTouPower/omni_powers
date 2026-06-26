# Harness 实验发现

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

**方法**：spawn 三个 harness agent，SendMessage 要求运行 `ctx_stats`。

**结果**：
| teammate | model 参数 | 实际模型 | ctx_stats |
|---|---|---|---|
| harness-coder | `haiku` | `default_haiku` | ✅ 可用 |
| harness-code-reviewer | `sonnet` | `default_sonnet` | ✅ 可用 |
| harness-test-reviewer | `sonnet` | `default_sonnet` | ✅ 可用 |

**结论**：ctx_stats 在 teammate 上可用，但**对上下文监控无用**——只显示 context-mode 拦截了多少字节，不显示 teammate 的实际上下文窗口占用率，无法用于判断何时需重建 teammate。

## 实验 7：model 参数

**方法**：不传 model → 观察结果 → 显式传 model → 对比。

**结果**：
- 不传 model：继承主会话模型（Claude Opus 4-8），不是 agent 定义文件里的 model
- 显式传 model：正确使用 `default_haiku` / `default_sonnet`

**结论**：spawn 时必须显式传 `model` 参数。agent 定义文件里的 model 字段不被 spawn 读取。

## 实验 8：上下文窗口大小

**方法**：检查 teammate 报告的上下文窗口。

**结果**：
- `default_haiku`：200K tokens
- `default_sonnet`（code-reviewer）：1M tokens
- `default_sonnet`（test-reviewer）：200K tokens
- `[1m]` 后缀是模型别名的一部分，不是窗口大小

**结论**：窗口大小取决于实际模型 variant。不能让 agent 猜，需从系统提示解析。

**解析方法**：teammate 系统提示含 `You are powered by the model xxx`。leader SendMessage 问 teammate "你的系统提示里 powered by the model 后面是什么？原样回复"，拿到模型别名后查 settings.json 的 `ANTHROPIC_DEFAULT_HAIKU_MODEL` / `ANTHROPIC_DEFAULT_SONNET_MODEL` 配置推导窗口大小。

