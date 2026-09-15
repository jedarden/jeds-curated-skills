#!/usr/bin/env bash
#
# test-root-scripts.sh - Contract tests for the repo's own root scripts
#
# The README documents two contracts this suite pins down so they cannot
# silently change:
#
#   scripts/check-installed.sh exit codes:
#     0  installed copy matches the repo (no drift)
#     1  drift detected (installed file modified or missing)
#     2  missing ~/.claude/skills/ directory
#
#   install.sh behavior:
#     --list       lists available skills (and only skills)
#     <name>...    selective install: installs only the named skills and
#                  leaves other installed skills untouched
#     --all        installs every skill --list reports
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
# scripts/ of its own, so these assertions do not depend on lib/common.sh
# inlining behavior.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
CHECK_INSTALLED="$REPO_ROOT/scripts/check-installed.sh"
INSTALL="$REPO_ROOT/install.sh"

# Fixture subject: a small skill used as the installed-copy stand-in.
FIXTURE_SKILL="adr"
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

  # Clean tree: install the fixture skill the way the README says skills are
  # distributed (cp -r), then both check forms must report no drift.
  cp -r "$REPO_ROOT/$FIXTURE_SKILL" "$FAKE_SKILLS/$FIXTURE_SKILL"

  expect_exit 0 "clean tree, named skill → 0" \
    run_check_installed "$FIXTURE_SKILL"
  expect_exit 0 "clean tree, all-skills sweep → 0" \
    run_check_installed

  # Drift: a modified installed file must be detected.
  echo "local edit" >> "$FAKE_SKILLS/$FIXTURE_SKILL/SKILL.md"
  expect_exit 1 "modified installed file → 1" \
    run_check_installed "$FIXTURE_SKILL"

  # The README's documented fix for drift (re-copy the skill) must clear it.
  rm -rf "$FAKE_SKILLS/$FIXTURE_SKILL"
  cp -r "$REPO_ROOT/$FIXTURE_SKILL/" "$FAKE_SKILLS/$FIXTURE_SKILL"
  expect_exit 0 "documented fix (re-copy) clears drift → 0" \
    run_check_installed "$FIXTURE_SKILL"

  # A file missing from the install but present in the repo is drift too.
  rm "$FAKE_SKILLS/$FIXTURE_SKILL/CHECKLIST-QUALITY.md"
  expect_exit 1 "file missing from install → 1" \
    run_check_installed "$FIXTURE_SKILL"

  # Missing ~/.claude/skills/ entirely is the exit-2 contract.
  rm -rf "$FAKE_HOME/.claude/skills"
  expect_exit 2 "missing ~/.claude/skills/ → 2" \
    run_check_installed "$FIXTURE_SKILL"
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

main() {
  echo "Root-script contract tests for jeds-curated-skills"
  echo "Repo root: $REPO_ROOT"
  echo "(fixtures run against a temp HOME; the real HOME is untouched)"

  test_check_installed_contracts
  test_install_contracts

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
