---
name: opinit
description: >
  在一个已有的项目中初始化 omni_powers 工作流目录和规范文档，归档旧文档，重写导航并提取未执行计划。
---

# Op Init Skill

`/opinit` 帮助将现有的项目文档迁移至符合 omni_powers 规范的形态，重组文档并把**未做完的**遗留任务并入新流水线。

## 步骤一：创建标准目录结构

创建基础骨架与空数据结构：

```bash
mkdir -p "$OMNI_POWERS_DIR_BLUEPRINT"/{specs,components}
mkdir -p "$OMNI_POWERS_DIR_TASKS"/issues
mkdir -p "$OMNI_POWERS_DIR_RECORD"/tasks
mkdir -p docs/archive

touch "$OMNI_POWERS_DIR_RECORD"/progress.md
touch "$OMNI_POWERS_DIR_RECORD"/decisions.md
touch "$OMNI_POWERS_DIR_TASKS"/tech_debt.md
echo '{"tasks":[]}' > "$OMNI_POWERS_DIR_TASKS"/tasks_list.json
```

## 步骤二：识别并归档旧文档

将非结构化的 md 文件移入 `docs/archive`。排除 `README.md`, `CLAUDE.md`, `RULES.md`。

```bash
# 根目录归档
find . -maxdepth 1 -name "*.md" -not -name "README.md" -not -name "CLAUDE.md" -not -name "RULES.md" -exec mv {} docs/archive/ \;

# docs 目录归档（排除已在专属目录或 archive 里的文件）
find docs -maxdepth 1 -name "*.md" -exec mv {} docs/archive/ \;
```

## 步骤三：生成 Blueprint

派发 Agent 读取归档区，提炼当前事实：

```js
Agent({
  name: "blueprint-generator",
  model: "sonnet",
  prompt: "读取 docs/archive/ 中的文档。根据现有业务和架构，生成符合 omni_powers 规范的文档到 $OMNI_POWERS_DIR_BLUEPRINT/（包含 prd.md、architecture.md、domain.md、conventions.md）。只描述'现在是什么'，丢弃过时内容。"
})
```

## 步骤四：重写导航 (index.md)

基于全新的 Blueprint，生成目录导航：

```js
Agent({
  name: "index-generator",
  model: "haiku",
  prompt: "读取 $OMNI_POWERS_DIR_BLUEPRINT/ 下生成的规范文档列表和核心结构，在 docs/omni_powers/index.md 生成全局文档导航图（索引）。"
})
```

## 步骤五：提取**未执行**计划

忽略已经完成的历史任务。只关注还没做的需求或计划：

```bash
ls docs/archive/ | grep -iE 'task|plan|todo' || echo "无未执行计划文件"
```

若发现包含疑似未执行计划的文件，**必须停下来询问用户**：
`发现历史计划文件（如 tasks.md / plan.md），是否需要提取里面【还没做】的 task 加入到新的 tasks_list.json？(y/n)`

若用户选 `y`，派发 Agent 提取（严格过滤掉已完成的）：

```js
Agent({
  name: "task-extractor",
  model: "sonnet",
  prompt: "读取 docs/archive/ 下用户指定的任务文件。忽略所有已完成的历史任务，只识别其中【尚未执行/还没做】的开发计划。对于每一项独立的新任务，调用 bash $CLAUDE_PLUGIN_ROOT/scripts/op_new_task.sh \"任务标题\" \"任务详情\" 写入新的任务列表。"
})
```

## 步骤六：完成报告

向用户输出初始化总结：
1. 归档了哪些文件。
2. 生成了哪些 blueprint。
3. 提取了多少未执行的 task。
提示用户：可以运行 `/opstart` 开始工作。