#!/usr/bin/env bash
# Focused fixture for scripts/factory-review-workspace.sh.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNNER="$SCRIPT_DIR/factory-review-workspace.sh"
BASE="$(mktemp -d "${TMPDIR:-/tmp}/jcs-review-runner.XXXXXX")"
trap 'rm -rf "$BASE"' EXIT

HOME_DIR="$BASE/home"
BIN_DIR="$HOME_DIR/.local/bin"
FIRST_WORKSPACE="$HOME_DIR/work one"
SECOND_WORKSPACE="$HOME_DIR/work-two"
UNSUPPORTED_WORKSPACE="$HOME_DIR/work-unsupported"
CONFIG="$HOME_DIR/.config/factory-review/workspaces.txt"
CLAUDE_LOG="$BASE/claude.log"
CLAUDE_ARGS_LOG="$BASE/claude-args.log"
BEAD_LOG="$BASE/bead.log"

mkdir -p "$BIN_DIR" "$FIRST_WORKSPACE/.beads" "$SECOND_WORKSPACE/.beads" \
  "$UNSUPPORTED_WORKSPACE/.beads" \
  "$(dirname "$CONFIG")"
printf 'bead_cli:\n  backend: bead-rs\n' >"$FIRST_WORKSPACE/.needle.yaml"
printf 'bead_cli:\n  backend: bead-rs\n' >"$SECOND_WORKSPACE/.needle.yaml"
printf 'bead_cli:\n  backend: unsupported-fixture\n' >"$UNSUPPORTED_WORKSPACE/.needle.yaml"

cat >"$BIN_DIR/claude" <<'EOF'
#!/usr/bin/env bash
set -u
printf '%s\n' "${PWD:?}" >>"${REVIEW_RUNNER_CLAUDE_LOG:?}"
printf '%q ' "$@" >>"${REVIEW_RUNNER_CLAUDE_ARGS_LOG:?}"
printf '\n' >>"${REVIEW_RUNNER_CLAUDE_ARGS_LOG:?}"
if [[ "${REVIEW_RUNNER_CLAUDE_MODE:-clean}" == findings ]]; then
  printf '%s\n' 'fixture finding' 'FACTORY_REVIEW_RESULT: findings'
else
  printf '%s\n' 'fixture clean' 'FACTORY_REVIEW_RESULT: clean'
fi
EOF
chmod +x "$BIN_DIR/claude"

cat >"$BIN_DIR/bead" <<'EOF'
#!/usr/bin/env bash
set -u
printf 'cwd=%q ' "${PWD:?}" >>"${REVIEW_RUNNER_BEAD_LOG:?}"
printf '%q ' "$@" >>"${REVIEW_RUNNER_BEAD_LOG:?}"
printf '\n' >>"${REVIEW_RUNNER_BEAD_LOG:?}"
printf '%s\n' fixture-bead
EOF
chmod +x "$BIN_DIR/bead"

run_child() {
  local mode="$1"
  local skill="$2"
  env HOME="$HOME_DIR" PATH="$BIN_DIR:$PATH" \
    REVIEW_RUNNER_CLAUDE_MODE="$mode" \
    REVIEW_RUNNER_CLAUDE_LOG="$CLAUDE_LOG" \
    REVIEW_RUNNER_CLAUDE_ARGS_LOG="$CLAUDE_ARGS_LOG" \
    REVIEW_RUNNER_BEAD_LOG="$BEAD_LOG" \
    bash "$RUNNER" "$skill"
}

assert_has() {
  local needle="$1" file="$2"
  grep -qF -- "$needle" "$file"
}

assert_count() {
  local expected="$1" file="$2"
  [[ "$(wc -l <"$file")" -eq "$expected" ]]
}

# Blank, whitespace-only, and comment lines are ignored; absolute and
# whitespace-containing paths are still visited in list order.
printf '\n   \n# ignored\n%s\n%s\n' "$FIRST_WORKSPACE" "$SECOND_WORKSPACE" >"$CONFIG"
: >"$CLAUDE_LOG"
: >"$CLAUDE_ARGS_LOG"
for skill in plan-vs-built find-stubs repo-hygiene; do
  output="$(run_child clean "$skill")"
  assert_has "$skill clean in $FIRST_WORKSPACE; nothing to file." <(printf '%s\n' "$output")
  assert_has "$skill clean in $SECOND_WORKSPACE; nothing to file." <(printf '%s\n' "$output")
  assert_has "--print /$skill ." "$CLAUDE_ARGS_LOG"
done
assert_count 6 "$CLAUDE_LOG"
assert_has "$FIRST_WORKSPACE" "$CLAUDE_LOG"
assert_has "$SECOND_WORKSPACE" "$CLAUDE_LOG"
[[ ! -s "$BEAD_LOG" ]]

# Findings are filed through the target workspace's backend and still use the
# selected skill; this also proves bead execution occurs in that workspace.
output="$(run_child findings find-stubs)"
assert_has 'Filed review findings bead' <(printf '%s\n' "$output")
assert_count 2 "$BEAD_LOG"
assert_has "$FIRST_WORKSPACE" "$BEAD_LOG"
assert_has "$SECOND_WORKSPACE" "$BEAD_LOG"
assert_has 'fixture finding' "$BEAD_LOG"

# Findings in a workspace whose declared backend is unsupported are reported
# as a filing failure without invoking a bead CLI or exposing tool output.
printf '%s\n' "$UNSUPPORTED_WORKSPACE" >"$CONFIG"
: >"$BEAD_LOG"
rc=0
output="$(run_child findings find-stubs 2>&1)" || rc=$?
[[ "$rc" -eq 1 ]]
assert_has 'no supported bead backend/store' <(printf '%s\n' "$output")
[[ ! -s "$BEAD_LOG" ]]

# An empty/whitespace-only list is a successful explicit no-op.
printf '\n  # no workspaces\n\t\n' >"$CONFIG"
before="$(wc -l <"$CLAUDE_LOG")"
output="$(run_child clean plan-vs-built)"
assert_has 'No configured workspaces; nothing to file.' <(printf '%s\n' "$output")
[[ "$(wc -l <"$CLAUDE_LOG")" -eq "$before" ]]

# A missing list is also a safe explicit no-op.
rm -f "$CONFIG"
output="$(run_child clean repo-hygiene)"
assert_has 'No configured workspaces; nothing to file.' <(printf '%s\n' "$output")
[[ "$(wc -l <"$CLAUDE_LOG")" -eq "$before" ]]

echo "factory-review-workspace fixture: PASS"
