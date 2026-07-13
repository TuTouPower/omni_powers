#!/usr/bin/env bash
# op_assemble_eval_brief：机械组装 evaluator brief（leader 不参与内容，防主会话污染）
# 用法: op_assemble_eval_brief.sh <TID>
# 产出: docs/omni_powers/op_execution/acceptance/{TID}/eval_brief.md
# 内容源（固定路径 cat，per-task 不写 op_blueprint 故生效规格天然是开工前基线）:
#   - 工作 spec: op_execution/specs/{TID}_{slug}.md（AC/INV/边界/可测性契约）
#   - 生效规格: op_blueprint/specs/{feature}.md（经 spec_index 索引）
#   - baselines 索引: op_blueprint/baselines/baselines_index.md（首次为空）
# 不含: implementer 的 report/diff/review、src/**、tasks/**（evaluator worktree 不挂载）
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
TID="${1:?用法: op_assemble_eval_brief.sh <TID>}"
ACCEPT_DIR="$ROOT/docs/omni_powers/op_execution/acceptance/$TID"
BLUEPRINT_DIR="$ROOT/docs/omni_powers/op_blueprint"

die() { echo "[FAIL] $*" >&2; exit 1; }

# spec 文件名 {TID}_{slug}.md，glob 取唯一匹配
WORK_SPEC=$(ls "$ROOT"/docs/omni_powers/op_execution/specs/${TID}_*.md 2>/dev/null | head -1 || true)
[ -n "$WORK_SPEC" ] || die "工作 spec 不存在: specs/${TID}_*.md"
mkdir -p "$ACCEPT_DIR"

BRIEF="$ACCEPT_DIR/eval_brief.md"

{
  echo "# Evaluator Brief: $TID"
  echo
  echo "> 机械组装（op_assemble_eval_brief.sh），leader 不参与内容，主会话污染传不过来。"
  echo "> 你只读本文件 + 启动应用。src/**、tasks/** 不在你的 worktree（结构隔离）。"
  echo

  echo "## 工作 spec（AC/INV/边界/可测性契约/预期失败模式——剥设计探索结论，防 evaluator 被过程带偏，design §2.5/G2）"
  echo
  # 剥"## 设计探索结论"段（到下个 ## 级标题），保留结论性段（探索过程存 decisions.md，不入 brief）
  awk '/^## 设计探索结论/{skip=1; next} /^## /{skip=0} !skip' "$WORK_SPEC"
  echo

  echo "## 生效规格（开工前基线）"
  echo
  if [ -f "$BLUEPRINT_DIR/spec_index.md" ]; then
    echo "（spec_index.md 索引；按 TID 定位对应 specs/{feature}.md）"
    cat "$BLUEPRINT_DIR/spec_index.md"
  else
    echo "（spec_index.md 缺失，无历史生效规格——首次验收）"
  fi
  echo

  echo "## baselines 索引（重验对照；首次为空）"
  echo
  if [ -f "$BLUEPRINT_DIR/baselines/baselines_index.md" ]; then
    cat "$BLUEPRINT_DIR/baselines/baselines_index.md"
  else
    echo "（首次验收，无 baselines——裸评建基准）"
  fi
  echo

  echo "## 应用启动方式"
  echo
  echo "从上方工作 spec 的「可测性契约」段提取。"
  echo

  echo "## 执行纪律"
  echo
  echo "- 所有 Bash 命令必须在 dispatch 指定的 eval worktree 内执行。"
  echo "- cd 后用相对路径写产物，禁止用绝对路径写主工作区。"
  echo "- 写 Playwright selector 前先 dump 目标页面 DOM，实测属性后再写；禁止猜测 data-* 属性名。
- **禁止用 .fill() 替代真实用户交互**：range/touch/slider 控件必须用 pointer 轨迹（mouse.move → mouse.down → mouse.move → mouse.up）模拟拖动。`.fill()` 只证明 input handler 能响应程序赋值，不能证明用户可操作。"
  echo

  echo "## E2E 固化落点"
  echo
  echo "- 固化产物必须写入仓库跟踪路径 \`e2e/$TID/\`（或项目 playwright testMatch 可发现路径）。"
  echo "- 若有 playwright.config，先执行 \`npx playwright test --list\` 确认发现方式。"
  echo "- 写在 worktree 临时目录、teardown 即丢的脚本不算固化。"
  echo

  echo "## ⚠️ 构建产物新鲜度（强制自检，本轮改进——防跑旧代码伪绿）"
  echo
  echo "验收前必须确认加载的构建产物来自**当前 task 分支最新源码**，而非 leader 预放的旧产物："
  echo "- **自建优先**：能自己从当前分支跑 build（见可测性契约的构建命令）就自建，别信别人放的 artifacts/dist。"
  echo "- **无法自建时校验指纹**：对比构建产物与源码的时间戳/hash——\`find <src> -newer <artifacts/dist入口文件>\` 若有输出，说明源码比产物新 = 产物陈旧，判 INSUFFICIENT_EVIDENCE 并报告，不得用旧产物验收。"
  echo "- **E2E 脚本路径校验**：E2E 用相对路径（\$__dirname 等）定位产物时，脚本内必须先 \`fs.existsSync\` 断言产物入口存在，不存在直接抛错——禁止静默跑不存在/错位的产物（T0002 事故直接教训）。"
  echo "- 加载产物后，先截图/取版本标识确认是新代码再跑 AC。"
  echo

  echo "## 执行后端（按 AC 通道字段选，CDP 优先）"
  echo
  echo "- 通道字段在上方可测性契约每条 AC 上（CDP | cua | 直驱）。能用 CDP 一律 CDP。"
  echo "- CDP: Playwright（Electron 用 _electron.launch；扩展用 launchPersistentContext + --load-extension，headed）"
  if command -v cua >/dev/null 2>&1; then
    echo "- cua: 可用（$(cua --version 2>/dev/null | head -1)）。用法: cua do screenshot / click / type / key / window ls / zoom（Look→Act→Verify，每次 UI 变化后重截图）"
    echo "  - 当前 target: $(cua do status 2>/dev/null | head -3 | tr '\n' ' ' || echo '未知，先 cua do status 确认')"
  else
    echo "- cua: **不可用**（本机未装）。cua 通道的 AC 一律判 INSUFFICIENT_EVIDENCE 并写明缺失，禁止跳过或降级推断。"
  fi
  echo "- 直驱: Bash/HTTP/SQL（CLI/DB/API/进程类 AC）"
  echo

} > "$BRIEF"

echo "[OK] evaluator brief 组装完成: $BRIEF"
echo "[下一步] evaluator 只读 \$BRIEF + 启动应用，按 brief 内 AC/可测性契约执行验收"
