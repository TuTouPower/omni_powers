## 当前模型判断依据
- 主会话当前由 `default_opus` 驱动（根据系统提示 `default_opus[1m]`）。
- 环境变量 `ANTHROPIC_MODEL` = `default_model`。
- 本次审阅明确以 `opus` 视角进行。

## 审阅范围
本次审阅的对象包括以下核心 skills 模块文件（09_skills_core）：
1. `/home/karon/karson_ubuntu/omni_powers/skills/opinit/SKILL.md`
2. `/home/karon/karson_ubuntu/omni_powers/skills/opinit/scripts/opinit_register_hooks.sh`
3. `/home/karon/karson_ubuntu/omni_powers/skills/opinit/scripts/opinit_skeleton.sh`
4. `/home/karon/karson_ubuntu/omni_powers/skills/opintake/SKILL.md`
5. `/home/karon/karson_ubuntu/omni_powers/skills/opred/SKILL.md`
6. `/home/karon/karson_ubuntu/omni_powers/skills/opspec/SKILL.md`
7. `/home/karon/karson_ubuntu/omni_powers/skills/opstatus/SKILL.md`
8. `/home/karon/karson_ubuntu/omni_powers/skills/optriage/SKILL.md`

## 高优先级问题（CRITICAL / HIGH）
1. **Windows 路径中反斜杠引发 jq sub 逻辑错误风险（HIGH）**
   - **位置**：`skills/opinit/scripts/opinit_register_hooks.sh` 第 40-48 行。
   - **现象**：在 Windows (MINGW/MSYS/CYGWIN) 环境下，`WRAPPER_PATH` 会转换为形如 `C:\path\to\run-hook.cmd` 的 Windows 路径。该路径被传递给 jq 的 `sub` 函数进行正则替换：`.command |= sub("^bash \"\\$OP_HOME/hooks/run-hook\\.cmd\""; "\"" + $wrapper + "\"")`。
   - **影响**：虽然在 jq 1.6+ 中直接将 `$wrapper` 作为字符串参数传给 `sub` 不会引起双重转义解析，但若 wrapper 路径中存在特定正则反向引用字符或某些特殊转义符号，在特定 jq 版本下可能发生非预期的正则替换异常或解析报错。
   - **建议**：建议直接以精确 JSON 路径赋值替代正则 `sub` 替换，消除正则引擎对替换字符串内容的解析不确定性。例如：
     ```jq
     .hooks.PreToolUse[].hooks[].command |= "\"" + $wrapper + "\" pre_tool_use"
     ```
     或在 bash 侧处理完路径斜杠后再传递给 jq。

2. **重复运行 `/opinit` 导致 hooks 重复注册（HIGH）**
   - **位置**：`skills/opinit/scripts/opinit_register_hooks.sh` 第 56-62 行。
   - **现象**：当用户多次运行 `/opinit`（这在流程调整或重试时非常常见）时，`jq -s` 脚本直接通过 `+` 拼接用户已有 hooks 与模板 hooks：` (($u.hooks // {})[$k] // []) + ($t.hooks // {})[$k]`。
   - **影响**：由于没有进行去重校验，多次运行会将同一批 hooks 重复追加到 `.claude/settings.json` 中，导致每个阶段触发时，同一个 hook 被重复执行多次，严重消耗 token、增加响应延迟并可能引发状态竞争。
   - **建议**：在拼接后进行去重，或者在 reduce 过程中仅当目标命令不存在时才追加。例如：
     ```jq
     .hooks[$k] = (($u.hooks // {})[$k] // []) + (($t.hooks // {})[$k] | map(select(. as $item | $u.hooks[$k] // [] | map(.command == $item.command) | any | not)))
     ```

3. **Windows/跨平台回车换行符导致 `profile` 互斥校验失效（HIGH）**
   - **位置**：`skills/opintake/SKILL.md` 第 13 行；`skills/opstatus/SKILL.md` 第 13 行。
   - **现象**：`opintake/SKILL.md` 中进行 profile 校验时使用：`[ -f docs/omni_powers/profile ] && ! grep -qx heavy docs/omni_powers/profile`。
   - **影响**：如果项目部署在 Windows 上且开启了 `core.autocrlf`，或者编辑工具写入了 `heavy\r\n`，`grep -qx heavy` 将因为末尾的 `\r` 匹配失败，导致 `! grep -qx heavy` 条件成立（返回真），引发错误拦截，误判定为 lite 项目并阻断执行。
   - **建议**：使用过滤掉空白符的精确字符串对比来替代 `grep -qx`：
     ```bash
     [ -f docs/omni_powers/profile ] && [ "$(tr -d '[:space:]' < docs/omni_powers/profile)" != "heavy" ]
     ```

4. **共享 Skill 在 lite 模式下因硬编码 `$OP_HOME` 导致执行崩溃（HIGH）**
   - **位置**：`skills/optriage/SKILL.md` 第 10 行 (`bash "$OP_HOME/scripts/op_check_env.sh"`)、第 84 行 (`bash "$OP_HOME/scripts/op_new_task.sh {TID}`)；`skills/opstatus/SKILL.md` 第 27-31 行。
   - **现象**：`optriage` 与 `opstatus` 是 heavy 和 lite 两版共享的 skills，但在这些 `.md` 的指令描述中硬编码了 `$OP_HOME/scripts/...` 路径。而根据设计文档，lite 模式没有 `$OP_HOME`，脚本平铺在共享目录 `~/.claude/scripts/omni_powers/`（由 `OP_SCRIPT_ROOT` 指向）。
   - **影响**：当在 lite 模式下运行 `/oplrun` 触发 `optriage`，或运行 `/opstatus` 时，Agent 会严格按照指令执行，因 `$OP_HOME` 为空，最终执行 `bash /scripts/op_check_env.sh`，抛出 "No such file or directory" 错误并导致整个流程中断崩溃。
   - **建议**：使用设计文档中建议的双路径 resolver 机制或优雅降级变量语法：
     ```bash
     bash "${OP_SCRIPT_ROOT:-$OP_HOME/scripts}/op_check_env.sh"
     ```
     （由于 lite 模式下 `OP_SCRIPT_ROOT` 对应平铺的共享目录，而 heavy 模式下 `$OP_HOME/scripts` 对应子目录，上述语法恰好能完美自适应两者的目录层级差异！）

## 中低优先级问题（MEDIUM / LOW）
5. **`optriage/SKILL.md` 命令中缺少闭合双引号导致语法错误（MEDIUM）**
   - **位置**：`skills/optriage/SKILL.md` 第 84 行。
   - **现象**：`bash "$OP_HOME/scripts/op_new_task.sh {TID}`。
   - **影响**：在 bash 命令中，双引号未闭合。如果 Agent 照搬执行，会导致 shell 报错 `unexpected EOF while looking for matching '"'`，执行失败。
   - **建议**：修正为：
     ```bash
     bash "${OP_SCRIPT_ROOT:-$OP_HOME/scripts}/op_new_task.sh" "{TID}"
     ```

6. **Windows 兼容性下 jq `walk` 依赖限制（MEDIUM）**
   - **位置**：`skills/opinit/scripts/opinit_register_hooks.sh` 第 41 行。
   - **现象**：使用了 `walk` 函数遍历 JSON。
   - **影响**：`walk/1` 是 jq 1.6+ 引入的内置函数，但在较旧的 jq 1.5 运行环境下并非默认内置（需要手动定义）。这可能会导致在一些旧系统上重构 hooks 失败。
   - **建议**：鉴于 `settings.template.json` 结构非常固定，建议直接指定字段更新，避免依赖 `walk` 函数，提升环境兼容性。

7. **`optriage` 手动计算 TID 逻辑过于繁琐（MEDIUM）**
   - **位置**：`skills/optriage/SKILL.md` 第 69 行 (`1. 用 jq 取当前最大 TID，新 task 从 T{NN+1} 开始`)。
   - **现象**：指令要求 Agent 使用 `jq` 自行提取并计算下一个单调递增的 TID（如将 `T0002` 解析为 `2` 再加 `1` 格式化为 `T0003`）。
   - **影响**：由 LLM 编写复杂的 `jq` 算术表达式容易出错或因格式细节而失败，导致 task 编号错乱或生成空 TID。
   - **建议**：既然已经有 `op_new_task.sh`，建议将 "计算下一个 TID" 的逻辑内聚到该 shell 脚本中（支持传入 `auto` 作为参数），减轻 Agent 在运行时的计算负担，确保编号生成的绝对确定性。

8. **`opstatus/SKILL.md` 缺少对 profile 文件不存在的优雅降级（LOW）**
   - **位置**：`skills/opstatus/SKILL.md` 第 13 行 (`profile 感知：先 cat docs/omni_powers/profile。`)。
   - **影响**：如果项目由于某种原因 profile 文件缺失，直接运行 `cat` 会产生 stderr 错误，可能导致 Agent 认为环境异常。
   - **建议**：提示 Agent 在读取时使用容错方式，如：`[ -f docs/omni_powers/profile ] && cat docs/omni_powers/profile || echo "heavy"`。

## 改进建议
- **统一脚本路径表示法**：在所有的 `SKILL.md` 文件中，凡是调用 `scripts/` 下脚本的地方，统一使用 `${OP_SCRIPT_ROOT:-$OP_HOME/scripts}/<script_name>` 的语法。这能从根本上消除 heavy/lite 两版在脚本路径、平铺 vs 子目录上的结构差异，使共享 Skill 的维护成本大幅降低。
- **强化 `optriage` 的鲁棒性**：将 issue 文件重命名和 status 修改做成确定性的脚本命令，而不是让 Agent 手动编辑 Markdown frontmatter，防止人工编辑失误导致 JSON 属性损坏。

## 不确定项 / 可能误报
- `opred/SKILL.md` 中提到：`leader 解锁（test_lock.sh 已删 Q3）`。这可能需要确认在真实仓库中，所有的旧 `test_lock.sh` 引用是否已经彻底清理干净，以避免遗留死代码或文档误导。
