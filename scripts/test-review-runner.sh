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
LEGACY_WORKSPACE="$HOME_DIR/work-legacy"
UNSUPPORTED_WORKSPACE="$HOME_DIR/work-unsupported"
NON_DIRECTORY_ENTRY="$HOME_DIR/not-a-directory"
UNSUPPORTED_HOME_ENTRY="~otheruser/workspace"
COMMAND_MARKER="$BASE/command-substitution-ran"
LITERAL_SHELL_PATH="$HOME_DIR/\$(touch $COMMAND_MARKER)"
CONFIG="$HOME_DIR/.config/factory-review/workspaces.txt"
CLAUDE_LOG="$BASE/claude.log"
CLAUDE_ARGS_LOG="$BASE/claude-args.log"
CLAUDE_PATH_LOG="$BASE/claude-path.log"
CLAUDE_SKILL_LOG="$BASE/claude-skill.log"
BEAD_LOG="$BASE/bead.log"
BEAD_CREATED="$BASE/bead-created.log"
BEAD_SEEN="$BASE/bead-seen.log"
BF_LOG="$BASE/bf.log"
BF_CREATED="$BASE/bf-created.log"

mkdir -p "$BIN_DIR" "$FIRST_WORKSPACE/.beads" "$SECOND_WORKSPACE/.beads" \
  "$LEGACY_WORKSPACE/.beads" \
  "$UNSUPPORTED_WORKSPACE/.beads" \
  "$(dirname "$CONFIG")"
printf '%s\n' fixture >"$NON_DIRECTORY_ENTRY"
mkdir -p "$LITERAL_SHELL_PATH"
printf 'bead_cli:\n  backend: bead-rs\n' >"$FIRST_WORKSPACE/.needle.yaml"
printf 'bead_cli:\n  backend: bead-rs\n' >"$SECOND_WORKSPACE/.needle.yaml"
printf 'bead_cli:\n  backend: bf\n' >"$LEGACY_WORKSPACE/.needle.yaml"
printf 'backend: bf\n' >"$LEGACY_WORKSPACE/.beads/config.yaml"
printf 'bead_cli:\n  backend: unsupported-fixture\n' >"$UNSUPPORTED_WORKSPACE/.needle.yaml"

cat >"$BIN_DIR/claude" <<'EOF'
#!/usr/bin/env bash
set -u
printf '%s\n' "${PWD:?}" >>"${REVIEW_RUNNER_CLAUDE_LOG:?}"
printf '%q ' "$@" >>"${REVIEW_RUNNER_CLAUDE_ARGS_LOG:?}"
printf '\n' >>"${REVIEW_RUNNER_CLAUDE_ARGS_LOG:?}"
printf '%s\n' "${PATH:?}" >>"${REVIEW_RUNNER_CLAUDE_PATH_LOG:?}"
skill=""
previous=""
for arg in "$@"; do
  if [[ "$previous" == --print ]]; then
    skill="$arg"
    break
  fi
  previous="$arg"
done
printf '%s\n' "$skill" >>"${REVIEW_RUNNER_CLAUDE_SKILL_LOG:?}"
if [[ "${REVIEW_RUNNER_CLAUDE_MODE:-clean}" == findings ]]; then
  printf '%s\n' \
    'FACTORY_REVIEW_FINDING: first fixture finding' \
    'first finding evidence' \
    'FACTORY_REVIEW_FINDING: second fixture finding' \
    'second finding evidence' \
    'FACTORY_REVIEW_RESULT: findings'
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
unique_ref=""
previous=""
for arg in "$@"; do
  if [[ "$previous" == --unique-ref ]]; then
    unique_ref="$arg"
    break
  fi
  previous="$arg"
done
if grep -qF -- "$unique_ref" "${REVIEW_RUNNER_BEAD_SEEN:?}" 2>/dev/null; then
  printf '%s\n' "EXISTING fixture-bead"
  exit 0
fi
printf '%s\n' "$unique_ref" >>"${REVIEW_RUNNER_BEAD_SEEN:?}"
printf '%s\n' fixture-bead >>"${REVIEW_RUNNER_BEAD_CREATED:?}"
printf '%s\n' fixture-bead
EOF
chmod +x "$BIN_DIR/bead"

cat >"$BIN_DIR/bf" <<'EOF'
#!/usr/bin/env bash
set -u
printf 'cwd=%q ' "${PWD:?}" >>"${REVIEW_RUNNER_BF_LOG:?}"
printf '%q ' "$@" >>"${REVIEW_RUNNER_BF_LOG:?}"
printf '\n' >>"${REVIEW_RUNNER_BF_LOG:?}"
if [[ "${1:-}" == list ]]; then
  cat "${REVIEW_RUNNER_BF_CREATED:?}" 2>/dev/null || true
  exit 0
fi
title=""
previous=""
for arg in "$@"; do
  if [[ "$previous" == --title ]]; then
    title="$arg"
    break
  fi
  previous="$arg"
done
if ! grep -qF -- "$title" "${REVIEW_RUNNER_BF_CREATED:?}" 2>/dev/null; then
  printf '%s\n' "$title" >>"${REVIEW_RUNNER_BF_CREATED:?}"
  printf '%s\n' fixture-bf >>"${REVIEW_RUNNER_BF_CREATED:?}.ids"
fi
printf '%s\n' fixture-bf
EOF
chmod +x "$BIN_DIR/bf"

run_child() {
  local mode="$1"
  local skill="$2"
  env HOME="$HOME_DIR" PATH="$BIN_DIR:$PATH" \
    REVIEW_RUNNER_CLAUDE_MODE="$mode" \
    REVIEW_RUNNER_CLAUDE_LOG="$CLAUDE_LOG" \
    REVIEW_RUNNER_CLAUDE_ARGS_LOG="$CLAUDE_ARGS_LOG" \
    REVIEW_RUNNER_CLAUDE_PATH_LOG="$CLAUDE_PATH_LOG" \
    REVIEW_RUNNER_CLAUDE_SKILL_LOG="$CLAUDE_SKILL_LOG" \
    REVIEW_RUNNER_BEAD_LOG="$BEAD_LOG" \
    REVIEW_RUNNER_BEAD_CREATED="$BEAD_CREATED" \
    REVIEW_RUNNER_BEAD_SEEN="$BEAD_SEEN" \
    REVIEW_RUNNER_BF_LOG="$BF_LOG" \
    REVIEW_RUNNER_BF_CREATED="$BF_CREATED" \
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
: >"$CLAUDE_PATH_LOG"
: >"$CLAUDE_SKILL_LOG"
: >"$BEAD_SEEN"
: >"$BEAD_CREATED"
: >"$BF_CREATED"
rm -f "$BF_CREATED.ids"
for skill in plan-vs-built find-stubs repo-hygiene; do
  output="$(run_child clean "$skill")"
  assert_has "$skill clean in $FIRST_WORKSPACE; nothing to file." <(printf '%s\n' "$output")
  assert_has "$skill clean in $SECOND_WORKSPACE; nothing to file." <(printf '%s\n' "$output")
  assert_has "--print /$skill ." "$CLAUDE_ARGS_LOG"
done
assert_count 6 "$CLAUDE_LOG"
assert_has "$FIRST_WORKSPACE" "$CLAUDE_LOG"
assert_has "$SECOND_WORKSPACE" "$CLAUDE_LOG"
expected_order="$FIRST_WORKSPACE
$SECOND_WORKSPACE
$FIRST_WORKSPACE
$SECOND_WORKSPACE
$FIRST_WORKSPACE
$SECOND_WORKSPACE"
[[ "$(<"$CLAUDE_LOG")" == "$expected_order" ]]
assert_count 6 "$CLAUDE_PATH_LOG"
assert_count 6 <(grep -F '/run/current-system/sw/bin' "$CLAUDE_PATH_LOG")
expected_skills="/plan-vs-built
/plan-vs-built
/find-stubs
/find-stubs
/repo-hygiene
/repo-hygiene"
[[ "$(<"$CLAUDE_SKILL_LOG")" == "$expected_skills" ]]
[[ ! -s "$BEAD_LOG" ]]

# Malformed entries are reported and skipped explicitly. Shell-looking path
# text remains literal: reading the list must not evaluate command syntax.
printf '%s\n%s\n%s\n' "$UNSUPPORTED_HOME_ENTRY" "$NON_DIRECTORY_ENTRY" \
  "$LITERAL_SHELL_PATH" >"$CONFIG"
before="$(wc -l <"$CLAUDE_LOG")"
output="$(run_child clean repo-hygiene 2>&1)"
assert_has 'Skipping malformed workspace entry (unsupported home expansion)' \
  <(printf '%s\n' "$output")
assert_has 'Skipping malformed workspace entry (not a directory)' \
  <(printf '%s\n' "$output")
assert_has "repo-hygiene clean in $LITERAL_SHELL_PATH; nothing to file." \
  <(printf '%s\n' "$output")
[[ ! -e "$COMMAND_MARKER" ]]
[[ "$(wc -l <"$CLAUDE_LOG")" -eq $((before + 1)) ]]

# Findings are filed through the target workspace's backend and still use the
# selected skill; this also proves bead execution occurs in that workspace.
printf '%s\n%s\n' "$FIRST_WORKSPACE" "$LEGACY_WORKSPACE" >"$CONFIG"
: >"$BEAD_LOG"
: >"$BF_LOG"
: >"$BEAD_CREATED"
: >"$BF_CREATED"
output="$(run_child findings find-stubs)"
assert_has 'Filed review finding' <(printf '%s\n' "$output")
assert_count 2 "$BEAD_CREATED"
assert_count 2 "$BF_CREATED.ids"
assert_has "$FIRST_WORKSPACE" "$BEAD_LOG"
assert_has "$LEGACY_WORKSPACE" "$BF_LOG"
assert_has 'first fixture finding' "$BEAD_LOG"
assert_has 'second fixture finding' "$BF_LOG"

# A repeat report creates no new issues: bead-rs uses its stable unique ref,
# while legacy bf uses an open-title lookup for each individual finding.
output="$(run_child findings find-stubs)"
assert_has 'Review finding already filed' <(printf '%s\n' "$output")
assert_count 2 "$BEAD_CREATED"
assert_count 2 "$BF_CREATED.ids"

# Findings in a workspace whose declared backend is unsupported are reported
# as a filing failure without invoking a bead CLI or exposing tool output.
printf '%s\n' "$UNSUPPORTED_WORKSPACE" >"$CONFIG"
: >"$BEAD_LOG"
: >"$BEAD_CREATED"
rc=0
output="$(run_child findings find-stubs 2>&1)" || rc=$?
[[ "$rc" -eq 1 ]]
assert_has "unsupported bead backend 'unsupported-fixture'" <(printf '%s\n' "$output")
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
