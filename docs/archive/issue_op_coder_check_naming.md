# op_coder_check.sh 命名残留与路径不一致

## 现状

文件 `skills/oprun/scripts/op_coder_check.sh` 是 implementer 启动前的模式判定器（读 review.md 的 verdict 行数，判 normal/fail/blocked）。v6 已把 agent `op-coder` 改名为 `op-implementer`，但脚本文件名和所有引用点未同步。

## 两个独立问题

### 问题 1：命名残留

`op_coder` 是旧 agent 名（v6 前）。v6 后统一用 `op-implementer`（见 `docs/op_decisions.md:214`）。脚本应改名为 `op_implementer_check.sh`。

9 个引用点需同步：

| 文件 | 行 | 当前引用 |
|---|---|---|
| `skills/oprun/scripts/op_coder_check.sh` | 2,3,10 | 文件名自身 + 用法注释 |
| `skills/oprun/SKILL.md` | 122,151,311 | 调用 + dispatch prompt + 文件表 |
| `skills/oplrun/SKILL.md` | 77,96,254 | 调用 + dispatch prompt + 文件表 |
| `agents/op-implementer.md` | 33 | 启动命令 |
| `docs/omni_powers_design.md` | 822 | 脚本清单表 |

### 问题 2：位置不一致

脚本实体在 `skills/oprun/scripts/op_coder_check.sh`，但消费者找了不同路径：

| 消费者 | 引用路径 | 能否解析 |
|---|---|---|
| op-implementer agent | `$OP_HOME/scripts/op_coder_check.sh` | **否** — `op_script()` resolver 只查 `$OP_HOME/scripts/` |
| oprun SKILL.md | `$OP_HOME/skills/oprun/scripts/op_coder_check.sh` | 能 |
| oplrun SKILL.md | `$SCRIPTS/op_coder_check.sh`（=`$OP_HOME/scripts/`） | **否** |

agent 启动时 `bash "$(op_script op_coder_check.sh)"` → `op_script()` 在 `$OP_HOME/scripts/` 找不到文件 → 返回空 → bash 空参数报错。implementer 启动直接炸。

## 影响

- implementer 无法判定自己是正向开发还是 FAIL 修复轮，可能拿错模式
- oprun/oplrun dispatch 时的 prompt 引了正确的绝对路径（skill 内部），但 agent 自身引用无效
- 安装版已部署到 `~/.claude/skills/oprun/scripts/op_coder_check.sh`，同名残留

## 建议处理

1. 文件移到 `scripts/op_implementer_check.sh`（agent resolver 统一入口）
2. 9 个引用点同步改名
3. 安装版同步更新（`install.sh` 已覆盖 `scripts/` 目录则自动生效）
4. 两问题可分两个 commit：先移位置、再改名
