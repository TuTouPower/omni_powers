#!/usr/bin/env bats

# op_trailer_unlock + git commit-msg/pre-commit 端到端
# 测试：scripts/op_trailer_unlock.sh + hooks/git/{pre-commit,commit-msg}

REPO="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
SCRIPT="$REPO/scripts/op_trailer_unlock.sh"

setup() {
  TEST_HOME="$(mktemp -d)"
  TEST_REPO="$(mktemp -d)"
  export HOME="$TEST_HOME"
  cd "$TEST_REPO"
  git init -q
  git config user.email t@t
  git config user.name t
  # 注册 git hooks
  mkdir -p .git/hooks
  cp "$REPO/hooks/git/pre-commit" .git/hooks/pre-commit
  cp "$REPO/hooks/git/commit-msg" .git/hooks/commit-msg
  chmod +x .git/hooks/pre-commit .git/hooks/commit-msg
}

teardown() {
  rm -rf "$TEST_HOME" "$TEST_REPO"
}

@test "op_trailer_unlock: 无 staged e2e → exit 1" {
  run bash "$SCRIPT"
  [ "$status" -ne 0 ]
  [[ "$output" == *"staged 无 e2e"* ]]
}

@test "op_trailer_unlock: 有 staged e2e → 输出 trailer + commit 成功" {
  mkdir -p e2e/b01
  echo "test" > e2e/b01/t.spec.js
  git add e2e/
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Op-E2e-Unlock: "* ]]
  trailer_line="$(echo "$output" | grep '^Op-E2e-Unlock:' | head -1)"
  # 用 trailer 提交，commit-msg 应放行
  git commit -q -m "test" -m "$trailer_line"
  [ -n "$(git log --oneline 2>/dev/null)" ]
}

@test "commit-msg: e2e 提交无 trailer → 被拦" {
  mkdir -p e2e/b01
  echo "test" > e2e/b01/t.spec.js
  git add e2e/
  run git commit -m "no trailer"
  [ "$status" -ne 0 ]
}

@test "pre-commit: approved spec 写保护" {
  mkdir -p docs/omni_powers/op_blueprint/specs
  printf -- '---\nstatus: approved\n---\n# spec\n' > docs/omni_powers/op_blueprint/specs/feat.md
  git add docs/omni_powers/op_blueprint/specs/feat.md
  run git commit -m "edit spec"
  [ "$status" -ne 0 ]
}

@test "commit-msg: 相同路径 staged 内容变化后旧 trailer 失效" {
  mkdir -p e2e/b01
  echo "first" > e2e/b01/t.spec.js
  git add e2e/
  trailer="$(bash "$SCRIPT" 2>/dev/null | head -1)"
  echo "second" > e2e/b01/t.spec.js
  git add e2e/
  run git commit -m "changed content" -m "$trailer"
  [ "$status" -ne 0 ]
}

@test "pre-commit: 使用 index 中 spec 状态而非工作树" {
  mkdir -p docs/omni_powers/op_blueprint/specs
  printf -- '---\nstatus: approved\n---\n# staged\n' > docs/omni_powers/op_blueprint/specs/feat.md
  git add docs/omni_powers/op_blueprint/specs/feat.md
  printf -- '---\nstatus: draft\n---\n# working tree\n' > docs/omni_powers/op_blueprint/specs/feat.md
  run git commit -m "index protected"
  [ "$status" -ne 0 ]
}

@test "commit-msg: staged 变了中国旧 trailer 失效" {
  mkdir -p e2e/b01
  echo "test" > e2e/b01/t.spec.js
  git add e2e/
  trailer="$(bash "$SCRIPT" 2>/dev/null | head -1)"
  # 加第二个 e2e 文件，staged 清单变了
  echo "test2" > e2e/b01/t2.spec.js
  git add e2e/
  run git commit -m "changed" -m "$trailer"
  [ "$status" -ne 0 ]
}
