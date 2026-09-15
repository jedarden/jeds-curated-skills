#!/usr/bin/env bash
#
# test-root-scripts.sh - Contract tests for the repo's own root scripts
#
# The README documents two contracts this suite pins down so they cannot
# silently change:
#
#   scripts/check-installed.sh exit codes:
#     0  installed copy matches the repo (no drift)
#     1  drift detected (installed file modified or missing), or a bare
#        cp -r install whose scripts reference the shared lib they cannot
#        resolve ("broken lib path")
#     2  missing ~/.claude/skills/ directory
#
#   install.sh behavior:
#     --list       lists available skills (and only skills)
#     <name>...    selective install: installs only the named skills and
#                  leaves other installed skills untouched
#     --all        installs every skill --list reports
#
#   install.sh usage-statusline out-of-tree install (the one skill whose
#   runtime artifact lives outside ~/.claude/skills/):
#     deploys ~/.claude/usage-statusline.sh (byte-identical to the repo copy,
#     executable) and merges a statusLine block into ~/.claude/settings.json —
#     idempotently, never displacing a statusLine that runs something else,
#     never dropping unrelated settings.json keys, and leaving invalid JSON
#     untouched (exit 1)
#
#   check-installed.sh usage-statusline out-of-tree copy:
#     a drifted deployed copy is drift (exit 1) — including on the default
#     sweep of a machine that has the deployed copy but no skills-dir
#     usage-statusline install, which is the shape of the machine where
#     ADR-1's hardcoded /home/coding path was found live
#
# Everything runs against a temporary HOME with a fake ~/.claude/skills/;
# the real HOME is never read or written. Usage:
#
#   scripts/test-root-scripts.sh
#
# Exit codes: 0 = all contracts hold, 1 = a contract is broken
#
# Wired alongside scripts/validate-skills.sh in the pre-commit hook installed
# by scripts/install-hooks.sh. The fixture skill (adr) deliberately has no
# scripts/ of its own, so the core assertions do not depend on lib/common.sh
# inlining behavior; the dedicated broken-lib contract below uses plan-review
# and synthesizes the lib source line when the repo's scripts do not carry
# it, so no assertion depends on the shared-lib extraction having landed.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
CHECK_INSTALLED="$REPO_ROOT/scripts/check-installed.sh"
INSTALL="$REPO_ROOT/install.sh"

# Fixture subject: a small skill used as the installed-copy stand-in.
FIXTURE_SKILL="adr"
# A script-bearing skill for the broken-lib contract: a bare cp -r of it
# cannot resolve ../../lib/common.sh in the skills dir. The contract
# synthesizes that source line into the installed copy when the repo's own
# scripts do not carry it yet, so it holds against any repo state.
LIB_FIXTURE_SKILL="plan-review"
# Synthetic sibling pre-seeded in the fake skills dir; install.sh must never
# touch it — that is the "doesn't touch other installed skills" contract.
SIBLING_SKILL="fixture-sibling-skill"
SIBLING_SENTINEL="do-not-touch-marker.txt"

# Color output for readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASSED=0
FAILED=0
FAILURES=()
FAKE_HOMES=()
FAKE_HOME=""
FAKE_SKILLS=""

log_pass() { echo -e "${GREEN}  ✓ $1${NC}"; PASSED=$((PASSED + 1)); }
log_fail() {
  echo -e "${RED}  ✗ $1${NC}"
  FAILED=$((FAILED + 1))
  FAILURES+=("$1")
}

cleanup() {
  local home
  for home in "${FAKE_HOMES[@]}"; do
    rm -rf "$home"
  done
}
trap cleanup EXIT

# Fresh temp HOME with an empty fake ~/.claude/skills/. Every script
# invocation below goes through run_check_installed/run_install, which
# override HOME, so nothing escapes into the real home directory.
new_fake_home() {
  FAKE_HOME="$(mktemp -d "${TMPDIR:-/tmp}/jcs-root-scripts.XXXXXX")"
  if [[ "$FAKE_HOME" != "${TMPDIR:-/tmp}"/* ]]; then
    echo -e "${RED}fixture home escaped tmp: $FAKE_HOME${NC}" >&2
    exit 1
  fi
  FAKE_SKILLS="$FAKE_HOME/.claude/skills"
  mkdir -p "$FAKE_SKILLS"
  FAKE_HOMES+=("$FAKE_HOME")
}

# Run check-installed.sh against the fixture home. The script resolves repo
# skills relative to $PWD, so it must run from the repo root.
run_check_installed() {
  (cd "$REPO_ROOT" && env HOME="$FAKE_HOME" bash "$CHECK_INSTALLED" "$@")
}

# Run install.sh against the fixture home. install.sh derives SCRIPT_DIR from
# $0, so the cwd is irrelevant here.
run_install() {
  env HOME="$FAKE_HOME" bash "$INSTALL" "$@"
}

# Assert a command exits with the expected code; print its tail on failure.
expect_exit() {
  local expected="$1" label="$2"
  shift 2
  local output actual=0
  output="$("$@" 2>&1)" || actual=$?
  if [[ "$actual" == "$expected" ]]; then
    log_pass "$label (exit $actual)"
  else
    log_fail "$label — expected exit $expected, got $actual"
    echo "$output" | tail -5 | sed 's/^/      /'
  fi
}

# Assert a command succeeds; used with test/grep/diff.
expect_ok() {
  local label="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    log_pass "$label"
  else
    log_fail "$label"
  fi
}

# --- check-installed.sh exit codes -----------------------------------------

test_check_installed_contracts() {
  echo ""
  echo "=== check-installed.sh exit codes ==="
  new_fake_home

  # Clean tree: seed the fixture skill with a plain copy, then both check
  # forms must report no drift.
  cp -r "$REPO_ROOT/$FIXTURE_SKILL" "$FAKE_SKILLS/$FIXTURE_SKILL"

  expect_exit 0 "clean tree, named skill → 0" \
    run_check_installed "$FIXTURE_SKILL"
  expect_exit 0 "clean tree, all-skills sweep → 0" \
    run_check_installed

  # Exit 0 alone cannot distinguish a real sweep from an empty intersection:
  # "No skills to check" also exits 0, which is how a ./-prefix mismatch
  # between find -printf '%h' (./adr) and ls -1 (adr) once made the no-arg
  # form silently check zero skills. With the fixture installed, the sweep
  # naming it is the non-vacuous proof the intersection fired.
  local sweep_out
  sweep_out="$(run_check_installed 2>&1)"
  if grep -q "^Checking ${FIXTURE_SKILL}\.\.\.$" <<< "$sweep_out"; then
    log_pass "all-skills sweep checks the installed fixture (non-empty intersection)"
  else
    log_fail "all-skills sweep checked nothing — fixture absent from sweep output"
    echo "$sweep_out" | tail -5 | sed 's/^/      /'
  fi

  # Drift: a modified installed file must be detected.
  echo "local edit" >> "$FAKE_SKILLS/$FIXTURE_SKILL/SKILL.md"
  expect_exit 1 "modified installed file → 1" \
    run_check_installed "$FIXTURE_SKILL"

  # The README's documented fix for drift (re-install with install.sh) must
  # clear it. adr has no scripts, so this stays independent of lib inlining.
  run_install "$FIXTURE_SKILL" >/dev/null 2>&1
  expect_exit 0 "documented fix (install.sh re-install) clears drift → 0" \
    run_check_installed "$FIXTURE_SKILL"

  # A file missing from the install but present in the repo is drift too.
  rm "$FAKE_SKILLS/$FIXTURE_SKILL/CHECKLIST-QUALITY.md"
  expect_exit 1 "file missing from install → 1" \
    run_check_installed "$FIXTURE_SKILL"

  # Missing ~/.claude/skills/ entirely is the exit-2 contract.
  rm -rf "$FAKE_HOME/.claude/skills"
  expect_exit 2 "missing ~/.claude/skills/ → 2" \
    run_check_installed "$FIXTURE_SKILL"

  # A bare cp -r of a skill whose scripts source the shared lib is
  # byte-identical to the repo — the diff sees no drift — but its source path
  # resolves to ~/.claude/skills/lib/common.sh, which a per-skill install
  # never has. That broken-lib state must be flagged (exit 1, with the path
  # named) so the documented fix gets run, and install.sh — which inlines the
  # lib — must clear it.
  new_fake_home
  cp -r "$REPO_ROOT/$LIB_FIXTURE_SKILL" "$FAKE_SKILLS/$LIB_FIXTURE_SKILL"
  # Reproduce the bare-cp state without depending on repo state: if the
  # repo's plan-review scripts do not source the shared lib yet (extraction
  # not landed), write the source line into the installed copy so the
  # unresolvable path exists for the checker to find.
  if ! grep -rqF '../../lib/common.sh' "$FAKE_SKILLS/$LIB_FIXTURE_SKILL"; then
    sed -i '2isource "$(dirname "$0")/../../lib/common.sh"' \
      "$FAKE_SKILLS/$LIB_FIXTURE_SKILL/scripts/find-forks.sh"
  fi
  local broken_out actual=0
  broken_out="$(run_check_installed "$LIB_FIXTURE_SKILL" 2>&1)" || actual=$?
  if [[ "$actual" == 1 ]] && grep -q "Broken lib path" <<< "$broken_out"; then
    log_pass "bare cp -r of lib-sourcing skill → 1 with broken-lib path named"
  else
    log_fail "bare cp -r of lib-sourcing skill — expected exit 1 naming the broken lib, got $actual"
    echo "$broken_out" | tail -5 | sed 's/^/      /'
  fi
  run_install "$LIB_FIXTURE_SKILL" >/dev/null 2>&1
  expect_exit 0 "documented fix (install.sh) clears broken lib → 0" \
    run_check_installed "$LIB_FIXTURE_SKILL"
}

# --- install.sh flag behavior -----------------------------------------------

test_install_contracts() {
  echo ""
  echo "=== install.sh flag behavior ==="
  new_fake_home

  # --list: exits 0, names skills, and does not name repo-internal dirs.
  expect_exit 0 "--list exits 0" run_install --list
  local list_output
  list_output="$(run_install --list)"
  expect_ok "--list names the fixture skill" \
    grep -q "^  - ${FIXTURE_SKILL}$" <<< "$list_output"
  if grep -qE "^  - (lib|scripts|docs)$" <<< "$list_output"; then
    log_fail "--list excludes repo-internal directories"
  else
    log_pass "--list excludes repo-internal directories"
  fi

  # Selective install must not touch other installed skills.
  mkdir -p "$FAKE_SKILLS/$SIBLING_SKILL"
  echo "sibling sentinel" > "$FAKE_SKILLS/$SIBLING_SKILL/SKILL.md"
  echo "hands off" > "$FAKE_SKILLS/$SIBLING_SKILL/$SIBLING_SENTINEL"

  expect_exit 0 "selective install exits 0" run_install "$FIXTURE_SKILL"
  expect_ok "installed skill lands in fake ~/.claude/skills/" \
    test -f "$FAKE_SKILLS/$FIXTURE_SKILL/SKILL.md"
  expect_ok "sibling skill still present" \
    test -f "$FAKE_SKILLS/$SIBLING_SKILL/SKILL.md"
  expect_ok "sibling sentinel file untouched" \
    test -f "$FAKE_SKILLS/$SIBLING_SKILL/$SIBLING_SENTINEL"
  expect_ok "sibling SKILL.md content unchanged" \
    grep -q "^sibling sentinel$" "$FAKE_SKILLS/$SIBLING_SKILL/SKILL.md"
  # The selective install must produce a copy the drift checker calls clean.
  expect_exit 0 "post-install round-trip: drift check → 0" \
    run_check_installed "$FIXTURE_SKILL"

  # An unknown skill name fails without creating anything.
  expect_exit 1 "unknown skill name → 1" \
    run_install definitely-not-a-skill
  expect_ok "failed install created nothing" \
    test ! -e "$FAKE_SKILLS/definitely-not-a-skill"

  # --all installs every skill --list reported.
  local expected_skills missing=""
  expected_skills="$(run_install --list | sed -n 's/^  - //p')"
  expect_exit 0 "--all exits 0" run_install --all
  local name
  while IFS= read -r name; do
    [[ -d "$FAKE_SKILLS/$name" ]] || missing="$missing $name"
  done <<< "$expected_skills"
  if [[ -z "$missing" ]]; then
    log_pass "--all installed every skill --list reported"
  else
    log_fail "--all did not install:$missing"
  fi
  expect_ok "sibling sentinel survives --all" \
    test -f "$FAKE_SKILLS/$SIBLING_SKILL/$SIBLING_SENTINEL"
}

# --- usage-statusline out-of-tree install ------------------------------------

test_statusline_contracts() {
  echo ""
  echo "=== usage-statusline out-of-tree install ==="
  local repo_sl="$REPO_ROOT/usage-statusline/scripts/usage-statusline.sh"

  # Fresh home: install deploys the runtime copy and creates settings.json.
  new_fake_home
  expect_exit 0 "usage-statusline install exits 0" run_install usage-statusline
  expect_ok "runtime script deployed to ~/.claude/" \
    cmp -s "$repo_sl" "$FAKE_HOME/.claude/usage-statusline.sh"
  expect_ok "deployed runtime script is executable" \
    test -x "$FAKE_HOME/.claude/usage-statusline.sh"
  expect_ok "settings.json created with statusLine wired to the deployed copy" \
    jq -e --arg cmd "/bin/bash $FAKE_HOME/.claude/usage-statusline.sh" \
      '.statusLine == {type: "command", command: $cmd, padding: 0}' \
      "$FAKE_HOME/.claude/settings.json"
  expect_ok "created settings.json is owner-only" \
    test "$(stat -c '%a' "$FAKE_HOME/.claude/settings.json")" = "600"

  # Idempotent: a second run changes nothing observable.
  expect_exit 0 "re-install exits 0 (idempotent)" run_install usage-statusline
  expect_ok "re-install: deployed copy still matches repo" \
    cmp -s "$repo_sl" "$FAKE_HOME/.claude/usage-statusline.sh"
  expect_ok "re-install: statusLine still correctly wired" \
    jq -e --arg cmd "/bin/bash $FAKE_HOME/.claude/usage-statusline.sh" \
      '.statusLine == {type: "command", command: $cmd, padding: 0}' \
      "$FAKE_HOME/.claude/settings.json"

  # Non-destructive merge: pre-existing keys survive alongside statusLine.
  new_fake_home
  printf '{"model":"opus","permissions":{"allow":["Bash(ls)"]}}' \
    > "$FAKE_HOME/.claude/settings.json"
  expect_exit 0 "install over existing settings.json exits 0" run_install usage-statusline
  expect_ok "pre-existing keys survive the merge" \
    jq -e '.model == "opus" and .permissions.allow == ["Bash(ls)"]' \
      "$FAKE_HOME/.claude/settings.json"
  expect_ok "statusLine added beside them" \
    jq -e '.statusLine.type == "command"' "$FAKE_HOME/.claude/settings.json"

  # Non-destructive: a statusLine running something else is never displaced.
  new_fake_home
  printf '{"statusLine":{"type":"command","command":"cat /tmp/other.sh"}}' \
    > "$FAKE_HOME/.claude/settings.json"
  expect_exit 0 "install alongside foreign statusLine exits 0" run_install usage-statusline
  expect_ok "foreign statusLine command untouched" \
    jq -e '.statusLine.command == "cat /tmp/other.sh"' \
      "$FAKE_HOME/.claude/settings.json"

  # Non-destructive: invalid JSON is reported (exit 1) and left byte-identical.
  new_fake_home
  printf '{ this is not json' > "$FAKE_HOME/.claude/settings.json"
  cp "$FAKE_HOME/.claude/settings.json" "$FAKE_HOME/settings.before"
  expect_exit 1 "install against invalid settings.json → 1" run_install usage-statusline
  expect_ok "invalid settings.json left byte-identical" \
    cmp -s "$FAKE_HOME/settings.before" "$FAKE_HOME/.claude/settings.json"

  # Drift in the deployed copy is drift, even with no skills-dir install —
  # the live machine's shape, where ADR-1's hardcoded path hid. Named check,
  # then the default sweep (which cannot intersect usage-statusline out of
  # ~/.claude/skills/ here, so the out-of-tree check must fire on the
  # deployed copy's existence alone).
  new_fake_home
  cp -r "$REPO_ROOT/$FIXTURE_SKILL" "$FAKE_SKILLS/$FIXTURE_SKILL"
  mkdir -p "$FAKE_HOME/.claude"
  cp "$repo_sl" "$FAKE_HOME/.claude/usage-statusline.sh"
  echo "# local edit" >> "$FAKE_HOME/.claude/usage-statusline.sh"
  local sl_out actual=0
  sl_out="$(run_check_installed usage-statusline 2>&1)" || actual=$?
  if [[ "$actual" == 1 ]] && grep -q "out-of-tree copy" <<< "$sl_out"; then
    log_pass "drifted deployed copy, named check → 1 naming the out-of-tree copy"
  else
    log_fail "drifted deployed copy, named check — expected exit 1 naming the out-of-tree copy, got $actual"
    echo "$sl_out" | tail -5 | sed 's/^/      /'
  fi
  actual=0
  sl_out="$(run_check_installed 2>&1)" || actual=$?
  if [[ "$actual" == 1 ]] && grep -q "out-of-tree copy" <<< "$sl_out"; then
    log_pass "drifted deployed copy, default sweep → 1 (skills-dir install absent)"
  else
    log_fail "drifted deployed copy, default sweep — expected exit 1, got $actual"
    echo "$sl_out" | tail -5 | sed 's/^/      /'
  fi
  # The documented fix (install.sh) clears both copies' drift.
  run_install usage-statusline >/dev/null 2>&1
  expect_exit 0 "documented fix (install.sh) clears deployed-copy drift → 0" \
    run_check_installed usage-statusline
}

main() {
  echo "Root-script contract tests for jeds-curated-skills"
  echo "Repo root: $REPO_ROOT"
  echo "(fixtures run against a temp HOME; the real HOME is untouched)"

  test_check_installed_contracts
  test_install_contracts
  test_statusline_contracts

  echo ""
  echo "========================================"
  echo "Root-Script Contract Test Summary"
  echo "========================================"
  echo "Passed: $PASSED"
  echo "Failed: $FAILED"
  if [[ $FAILED -gt 0 ]]; then
    echo ""
    local f
    for f in "${FAILURES[@]}"; do
      echo -e "  ${RED}✗ $f${NC}"
    done
    echo ""
    echo -e "${RED}FAILED: $FAILED contract(s) broken${NC}"
    exit 1
  fi
  echo -e "${GREEN}PASSED: all documented root-script contracts hold${NC}"
  exit 0
}

main "$@"
