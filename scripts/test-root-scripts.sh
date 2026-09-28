#!/usr/bin/env bash
#
# test-root-scripts.sh - Contract tests for the repo's own root scripts
#
# The README documents the contracts below; this suite pins them down so
# they cannot silently change:
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
#   install-hooks.sh pre-commit hook install:
#     writes an executable .git/hooks/pre-commit into the repo that contains
#     it, invoking exactly the three documented suites (validate-skills.sh,
#     test-root-scripts.sh, test-script-fixtures.sh); a re-run leaves the
#     hook byte-identical; an older two-suite hook is upgraded in place; a
#     foreign pre-existing hook is backed up to pre-commit.backup before the
#     documented hook replaces it; no .git/hooks means exit 1
#
#   install.sh usage-statusline out-of-tree install (the one skill whose
#   runtime artifact lives outside ~/.claude/skills/):
#     deploys ~/.claude/usage-statusline.sh (byte-identical to the repo copy,
#     executable) and merges a statusLine block into ~/.claude/settings.json —
#     idempotently, never displacing a statusLine that runs something else,
#     never dropping unrelated settings.json keys, and leaving invalid JSON
#     untouched (exit 1)
#
#   check-installed.sh stale-inline detection (the inline is expected drift
#   only while it matches what install.sh would produce TODAY):
#     a fresh install checks clean even though the installed scripts differ
#     from their repo sources (the derived inline matches byte-for-byte); a
#     hand-edited installed inline is drift; a lib/common.sh fixed in the
#     repo after an install makes every inlined installed copy stale — exit 1
#     naming "Stale inline" — and the documented fix (re-install) clears it
#     and lands the new helpers. Runs against a fixture copy of the repo, so
#     the lib-mutation never touches the real checkout.
#
#   check-installed.sh usage-statusline out-of-tree copy:
#     a drifted deployed copy is drift (exit 1) — including on the default
#     sweep of a machine that has the deployed copy but no skills-dir
#     usage-statusline install, which is the shape of the machine where
#     ADR-1's hardcoded /home/coding path was found live
#
#   check-push-ci.sh push-CI heartbeat (scripts/check-push-ci.sh):
#     exits 0 when a sensor-submitted (generateName exactly
#     "skills-validate-", never the manual "-manual-" prefix) workflow was
#     created at/after the newest non-CI-authored commit on origin/main;
#     1 is the alarm code (no workflow since the push, or nothing on
#     record); 2 is environmental (bad usage, no origin/main, kubectl
#     failure, malformed listing) and must never masquerade as an alarm —
#     including the empty-listing case, where command substitution's
#     trailing-newline stripping collapses the jq output and a naive
#     array read dies "unbound variable" under set -u; 3 means the push
#     is younger than the grace window and kubectl is never consulted.
#     Reference-walk and CI-author skip mirror the sensor's own filter
#     (body.head_commit.author.name != "Argo Workflows CI"). Runs against
#     a fixture bare origin + clone with fixed commit dates and a fake
#     kubectl shim on PATH — the real cluster is never contacted.
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
REVIEW_TIMER_INSTALL="$REPO_ROOT/scripts/install-review-timers.sh"

# Drop the ambient git context — same fix as test-script-fixtures.sh, for the
# same reason: the pre-commit hook runs this suite with git's environment
# exported, and the push-CI fixture below builds a throwaway bare origin +
# clone whose git calls must resolve inside the fixture, not in this repo.
# Inheriting GIT_DIR made the heartbeat's `git log origin/main` walk read THIS
# repo's history — its newest non-CI-authored commit is hours old, so the
# fixture's 2026 workflow timestamps all fell "before the push" and the two
# exit-0 contracts failed only when run from the hook. The suite treats the
# checkout as read-only files and never runs git against it, so dropping the
# context here is safe.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY
unset GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_COMMON_DIR

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
FAKE_REPOS=()
FAKE_REPO=""

log_pass() { echo -e "${GREEN}  ✓ $1${NC}"; PASSED=$((PASSED + 1)); }
log_fail() {
  echo -e "${RED}  ✗ $1${NC}"
  FAILED=$((FAILED + 1))
  FAILURES+=("$1")
}

cleanup() {
  local dir
  for dir in "${FAKE_HOMES[@]}" "${FAKE_REPOS[@]}"; do
    rm -rf "$dir"
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

# Fresh skeleton repo for the install-hooks.sh contracts. The installer
# derives its target .git/hooks from its own location (the parent of its
# scripts/ directory), not from the cwd, so the fixture is a temp dir whose
# scripts/ holds symlinks back to the real scripts — the installer's
# existence checks pass while every write lands in the skeleton, and the
# real repo's .git/hooks is never touched. Pass "bare" to skip git init for
# the not-a-git-repository contract.
new_fake_repo() {
  FAKE_REPO="$(mktemp -d "${TMPDIR:-/tmp}/jcs-install-hooks.XXXXXX")"
  if [[ "$FAKE_REPO" != "${TMPDIR:-/tmp}"/* ]]; then
    echo -e "${RED}fixture repo escaped tmp: $FAKE_REPO${NC}" >&2
    exit 1
  fi
  FAKE_REPOS+=("$FAKE_REPO")
  if [[ "${1:-}" != "bare" ]]; then
    git -C "$FAKE_REPO" init -q >/dev/null 2>&1 || {
      echo -e "${RED}fixture git init failed in $FAKE_REPO${NC}" >&2
      exit 1
    }
  fi
  mkdir -p "$FAKE_REPO/scripts"
  local script
  for script in install-hooks.sh validate-skills.sh \
    test-root-scripts.sh test-script-fixtures.sh; do
    ln -s "$REPO_ROOT/scripts/$script" "$FAKE_REPO/scripts/$script"
  done
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

# Same two, but against a fixture COPY of the repo instead of $REPO_ROOT.
# The stale-inline contracts mutate lib/common.sh — that must happen in the
# copy, never in the real checkout — so the installer and checker run from
# the copy's own paths, and the checker's $PWD-resolved repo skills are the
# copy's.
run_check_installed_in() {
  local repo_dir="$1"; shift
  (cd "$repo_dir" && env HOME="$FAKE_HOME" bash "$repo_dir/scripts/check-installed.sh" "$@")
}
run_install_in() {
  local repo_dir="$1"; shift
  env HOME="$FAKE_HOME" bash "$repo_dir/install.sh" "$@"
}

# Fixture copy of the repo holding everything the installer and checker
# touch: install.sh, lib/ (inline derivation + the shared lib itself),
# scripts/check-installed.sh, and one lib-sourcing skill. If the checkout's
# lib/common.sh has not landed yet (extraction pending), a minimal lib is
# synthesized so the inlining contracts hold against any repo state — the
# same independence rule the broken-lib contract follows.
new_inline_fixture_repo() {
  FAKE_REPO="$(mktemp -d "${TMPDIR:-/tmp}/jcs-inline-fixture.XXXXXX")"
  if [[ "$FAKE_REPO" != "${TMPDIR:-/tmp}"/* ]]; then
    echo -e "${RED}fixture repo escaped tmp: $FAKE_REPO${NC}" >&2
    exit 1
  fi
  FAKE_REPOS+=("$FAKE_REPO")
  mkdir -p "$FAKE_REPO/scripts" "$FAKE_REPO/lib"
  cp "$REPO_ROOT/install.sh" "$FAKE_REPO/install.sh"
  cp "$REPO_ROOT/scripts/check-installed.sh" "$FAKE_REPO/scripts/check-installed.sh"
  if compgen -G "$REPO_ROOT/lib/*.sh" >/dev/null; then
    cp "$REPO_ROOT/lib/"*.sh "$FAKE_REPO/lib/"
  fi
  if [[ ! -f "$FAKE_REPO/lib/common.sh" ]]; then
    printf '#!/usr/bin/env bash\nset -euo pipefail\nsynthetic_helper() { echo synthetic; }\n' \
      > "$FAKE_REPO/lib/common.sh"
  fi
  cp -r "$REPO_ROOT/$LIB_FIXTURE_SKILL" "$FAKE_REPO/$LIB_FIXTURE_SKILL"
}

# --- check-push-ci.sh fixtures ------------------------------------------------

# Fixture subject: the push-CI heartbeat. A bare origin + a clone with
# deterministic commit dates, and a fake kubectl first on PATH that replays a
# canned workflow listing. The real endpoint is never contacted: the script's
# server override points at a dead address, so a shim bypass fails fast
# instead of silently passing.

PUSH_CI_DIR=""
PUSH_CI_SHIM=""
PUSH_CI_MARKER=""
# The sensor drops pushes authored by this name; the heartbeat must skip the
# same commits when picking its reference.
PUSH_CI_CI_AUTHOR="Argo Workflows CI"
PUSH_CI_AUTHOR="Fixture Author"

# Emit a workflow-listing JSON. Each argument is "name|generateName|timestamp";
# no arguments yields the empty listing (the heartbeat's total-0 path).
write_wf_listing() {
  local out="$PUSH_CI_DIR/listing.json" item first=1
  printf '{"apiVersion":"argoproj.io/v1alpha1","kind":"Workflow","items":[' >"$out"
  for item in "$@"; do
    ((first)) || printf ',' >>"$out"
    first=0
    local name gen ts
    IFS='|' read -r name gen ts <<<"$item"
    printf '{"metadata":{"name":%s,"generateName":%s,"creationTimestamp":%s},"spec":{}}' \
      "$(jq -Rn --arg v "$name" '$v')" \
      "$(jq -Rn --arg v "$gen" '$v')" \
      "$(jq -Rn --arg v "$ts" '$v')" >>"$out"
  done
  printf ']}' >>"$out"
}

new_push_ci_fixture() {
  PUSH_CI_DIR="$(mktemp -d "${TMPDIR:-/tmp}/jcs-push-ci.XXXXXX")"
  if [[ "$PUSH_CI_DIR" != "${TMPDIR:-/tmp}"/* ]]; then
    echo -e "${RED}push-ci fixture escaped tmp: $PUSH_CI_DIR${NC}" >&2
    exit 1
  fi
  FAKE_REPOS+=("$PUSH_CI_DIR")
  git init -q --bare -b main "$PUSH_CI_DIR/origin.git"
  git clone -q "$PUSH_CI_DIR/origin.git" "$PUSH_CI_DIR/clone" 2>/dev/null
  push_ci_commit "base" "$PUSH_CI_AUTHOR" "2026-09-14T12:00:00Z"
  push_ci_commit "ci-tipped" "$PUSH_CI_CI_AUTHOR" "2026-09-14T13:00:00Z"
  git -C "$PUSH_CI_DIR/clone" push -q -u origin main
}

# Commit with deterministic author/committer identity and dates. The identity
# must go through the environment because a pre-commit hook inherits Git's
# outer commit identity, which would otherwise turn the synthetic CI commit
# into a human-authored one. The dates go through the environment because -c
# cannot set them.
push_ci_commit() {
  local msg="$1" author="$2" when="$3"
  GIT_AUTHOR_NAME="$author" GIT_AUTHOR_EMAIL=fixture@example.com \
    GIT_COMMITTER_NAME="$author" GIT_COMMITTER_EMAIL=fixture@example.com \
    GIT_AUTHOR_DATE="$when" GIT_COMMITTER_DATE="$when" \
    git -C "$PUSH_CI_DIR/clone" \
    -c user.name="$author" -c user.email=fixture@example.com \
    commit -q --allow-empty -m "$msg"
}

# Fake kubectl: records that it ran, then either fails or replays the canned
# listing. Baked as a standalone script so PATH shimming needs nothing else.
new_push_ci_shim() {
  PUSH_CI_SHIM="$(mktemp -d "${TMPDIR:-/tmp}/jcs-push-ci-shim.XXXXXX")"
  FAKE_REPOS+=("$PUSH_CI_SHIM")
  {
    printf '#!/usr/bin/env bash\n'
    printf '[[ -n "${PUSH_CI_KUBECTL_CALLED:-}" ]] && touch "${PUSH_CI_KUBECTL_CALLED}"\n'
    printf 'if [[ -n "${PUSH_CI_KUBECTL_FAIL:-}" ]]; then\n'
    printf '  echo "kubectl shim: intentional failure" >&2\n  exit 1\nfi\n'
    printf 'cat %q\n' "$PUSH_CI_DIR/listing.json"
  } >"$PUSH_CI_SHIM/kubectl"
  chmod +x "$PUSH_CI_SHIM/kubectl"
}

# Run the heartbeat inside the fixture clone with the shim first on PATH.
run_push_ci() {
  PUSH_CI_MARKER="$PUSH_CI_DIR/.kubectl-called"
  rm -f "$PUSH_CI_MARKER"
  (
    cd "$PUSH_CI_DIR/clone" || exit 2
    export PATH="$PUSH_CI_SHIM:$PATH"
    export SKILLS_CI_KUBECTL_SERVER="http://push-ci-fixture.invalid:1"
    export PUSH_CI_KUBECTL_CALLED="$PUSH_CI_MARKER"
    bash "$REPO_ROOT/scripts/check-push-ci.sh" "$@"
  )
}

kubectl_was_called() { [[ -e "$PUSH_CI_MARKER" ]]; }

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

# --- install-review-timers.sh fixtures --------------------------------------

# These fixtures exercise the generated review and memory-tool runners without
# touching the real user manager, home directory, or bead store. The fake
# claude command records every workspace execution and can emit clean,
# findings, or failure results. The fake bead CLIs model the two backends'
# relevant contracts: bead-rs deduplicates through --unique-ref, while legacy
# bf deduplicates by listing its open beads first.
REVIEW_TIMER_BASE=""
REVIEW_TIMER_HOME=""
REVIEW_TIMER_WORKSPACE=""
REVIEW_TIMER_LEGACY_WORKSPACE=""
REVIEW_TIMER_SHIM=""
REVIEW_TIMER_PATH=""
REVIEW_TIMER_NO_SYSTEMCTL_PATH=""
REVIEW_TIMER_SYSTEMCTL_LOG=""
REVIEW_TIMER_SYSTEMCTL_STATE=""
REVIEW_TIMER_BEAD_LOG=""
REVIEW_TIMER_BF_LOG=""
REVIEW_TIMER_BEAD_ISSUE=""
REVIEW_TIMER_BF_ISSUE=""
REVIEW_TIMER_BF_LIST_RC=0
REVIEW_TIMER_MEMORY_CWD_LOG=""
REVIEW_TIMER_CLAUDE_LOG=""
REVIEW_TIMER_CLAUDE_CWD_LOG=""
REVIEW_TIMER_MODE="pass"
REVIEW_TIMER_CLAUDE_MODE="clean"
REVIEW_TIMER_OUTPUT=""
REVIEW_TIMER_RC=0
REVIEW_TIMER_DRY_OUTPUT=""
REVIEW_TIMER_DRY_RC=0

new_review_timer_fixture() {
  REVIEW_TIMER_BASE="$(mktemp -d "${TMPDIR:-/tmp}/jcs-review-timers.XXXXXX")"
  if [[ "$REVIEW_TIMER_BASE" != "${TMPDIR:-/tmp}"/* ]]; then
    echo -e "${RED}review-timer fixture escaped tmp: $REVIEW_TIMER_BASE${NC}" >&2
    exit 1
  fi
  FAKE_REPOS+=("$REVIEW_TIMER_BASE")

  REVIEW_TIMER_HOME="$REVIEW_TIMER_BASE/home"
  REVIEW_TIMER_WORKSPACE="$REVIEW_TIMER_BASE/home-workspace"
  REVIEW_TIMER_LEGACY_WORKSPACE="$REVIEW_TIMER_BASE/legacy-workspace"
  REVIEW_TIMER_SHIM="$REVIEW_TIMER_BASE/shim"
  REVIEW_TIMER_SYSTEMCTL_LOG="$REVIEW_TIMER_BASE/systemctl.log"
  REVIEW_TIMER_SYSTEMCTL_STATE="$REVIEW_TIMER_BASE/systemctl-timers"
  REVIEW_TIMER_BEAD_LOG="$REVIEW_TIMER_BASE/bead.log"
  REVIEW_TIMER_BF_LOG="$REVIEW_TIMER_BASE/bf.log"
  REVIEW_TIMER_BEAD_ISSUE="$REVIEW_TIMER_BASE/bead-issue-count"
  REVIEW_TIMER_BF_ISSUE="$REVIEW_TIMER_BASE/bf-issue-count"
  REVIEW_TIMER_MEMORY_CWD_LOG="$REVIEW_TIMER_BASE/memory-tool.cwd"
  REVIEW_TIMER_CLAUDE_LOG="$REVIEW_TIMER_BASE/claude.log"
  REVIEW_TIMER_CLAUDE_CWD_LOG="$REVIEW_TIMER_BASE/claude.cwd"

  mkdir -p "$REVIEW_TIMER_HOME/.local/bin" "$REVIEW_TIMER_SHIM" \
    "$REVIEW_TIMER_WORKSPACE/.beads" "$REVIEW_TIMER_LEGACY_WORKSPACE/.beads"
  : >"$REVIEW_TIMER_SYSTEMCTL_LOG"

  # Keep a second PATH containing the commands needed to render units but no
  # systemctl. This exercises the installer's optional activation path without
  # contacting the host user manager.
  REVIEW_TIMER_NO_SYSTEMCTL_PATH="$REVIEW_TIMER_BASE/no-systemctl-path"
  mkdir -p "$REVIEW_TIMER_NO_SYSTEMCTL_PATH"
  local tool
  for tool in awk bash cat chmod cmp dirname grep mkdir mktemp rm sed sha256sum; do
    ln -s "$(command -v "$tool")" "$REVIEW_TIMER_NO_SYSTEMCTL_PATH/$tool"
  done

  cat >"$REVIEW_TIMER_SHIM/systemctl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${REVIEW_TIMER_SYSTEMCTL_LOG:?}"

# Model the two user-manager operations the installer relies on. Installation
# records enabled timers, and list-timers exposes those same units so the
# fixture can assert the user-facing visibility contract without touching the
# real user manager.
if [[ "${1:-}" == --user && "${2:-}" == list-timers ]]; then
  while IFS= read -r timer; do
    [[ -n "$timer" ]] || continue
    printf 'fixture  %s\n' "$timer"
  done <"${REVIEW_TIMER_SYSTEMCTL_STATE:?}"
  exit 0
fi
if [[ "${1:-}" == --user && "${2:-}" == enable && "${3:-}" == --now ]]; then
  printf '%s\n' "${@:4}" >"${REVIEW_TIMER_SYSTEMCTL_STATE:?}"
fi
exit 0
EOF
  chmod +x "$REVIEW_TIMER_SHIM/systemctl"
  REVIEW_TIMER_PATH="$REVIEW_TIMER_SHIM:$PATH"
  : >"$REVIEW_TIMER_SYSTEMCTL_STATE"

  printf 'bead_cli:\n  backend: bead-rs\n' >"$REVIEW_TIMER_WORKSPACE/.needle.yaml"
  printf '{}\n' >"$REVIEW_TIMER_WORKSPACE/.beads/config.json"
  printf 'bead_cli:\n  backend: bf\n' >"$REVIEW_TIMER_LEGACY_WORKSPACE/.needle.yaml"
  printf 'backend: bf\n' >"$REVIEW_TIMER_LEGACY_WORKSPACE/.beads/config.yaml"

  cat >"$REVIEW_TIMER_HOME/.local/bin/memory-tool" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "${PWD:?}" >"${REVIEW_TIMER_MEMORY_CWD_LOG:?}"
printf '%s\n' 'diagnostic token=fixture-secret' >&2
if [[ "${REVIEW_TIMER_MODE:-pass}" == pass ]]; then
  exit 0
fi
exit "${REVIEW_TIMER_FAILURE_RC:-23}"
EOF
  chmod +x "$REVIEW_TIMER_HOME/.local/bin/memory-tool"

  cat >"$REVIEW_TIMER_HOME/.local/bin/claude" <<'EOF'
#!/usr/bin/env bash
set -u
printf '%s\n' "${PWD:?}" >>"${REVIEW_TIMER_CLAUDE_CWD_LOG:?}"
printf 'claude' >>"${REVIEW_TIMER_CLAUDE_LOG:?}"
printf ' %q' "$@" >>"$REVIEW_TIMER_CLAUDE_LOG"
printf '\n' >>"$REVIEW_TIMER_CLAUDE_LOG"
case "${REVIEW_TIMER_CLAUDE_MODE:-clean}" in
  findings)
    printf '%s\n' 'review fixture: finding' 'FACTORY_REVIEW_RESULT: findings'
    ;;
  fail)
    printf '%s\n' 'review fixture: command failure' 'FACTORY_REVIEW_RESULT: findings'
    exit "${REVIEW_TIMER_CLAUDE_FAILURE_RC:-23}"
    ;;
  *)
    printf '%s\n' 'review fixture: success' 'FACTORY_REVIEW_RESULT: clean'
    ;;
esac
EOF
  chmod +x "$REVIEW_TIMER_HOME/.local/bin/claude"

  cat >"$REVIEW_TIMER_HOME/.local/bin/bead" <<'EOF'
#!/usr/bin/env bash
set -u
printf 'bead' >>"${REVIEW_TIMER_BEAD_LOG:?}"
printf ' %q' "$@" >>"$REVIEW_TIMER_BEAD_LOG"
printf ' cwd=%q' "${PWD:?}" >>"$REVIEW_TIMER_BEAD_LOG"
printf '\n' >>"$REVIEW_TIMER_BEAD_LOG"
if [[ "${1:-}" != create ]]; then
  exit 2
fi
if [[ -e "${REVIEW_TIMER_BEAD_ISSUE:?}" ]]; then
  printf 'EXISTING fixture-memory-failure\n'
else
  printf '1\n' >"$REVIEW_TIMER_BEAD_ISSUE"
  printf 'fixture-memory-failure\n'
fi
EOF
  chmod +x "$REVIEW_TIMER_HOME/.local/bin/bead"

  cat >"$REVIEW_TIMER_HOME/.local/bin/bf" <<'EOF'
#!/usr/bin/env bash
set -u
printf 'bf' >>"${REVIEW_TIMER_BF_LOG:?}"
printf ' %q' "$@" >>"$REVIEW_TIMER_BF_LOG"
printf ' cwd=%q' "${PWD:?}" >>"$REVIEW_TIMER_BF_LOG"
printf '\n' >>"$REVIEW_TIMER_BF_LOG"
if [[ "${1:-}" == list ]]; then
  if [[ "${REVIEW_TIMER_BF_LIST_RC:-0}" -ne 0 ]]; then
    exit "${REVIEW_TIMER_BF_LIST_RC}"
  fi
  if [[ -e "${REVIEW_TIMER_BF_ISSUE:?}" ]]; then
    printf '%s\n' 'memory-tool check failure'
    for skill in plan-vs-built find-stubs repo-hygiene; do
      printf 'Factory review: %s findings in %s\n' "$skill" \
        "${REVIEW_TIMER_LEGACY_WORKSPACE:?}"
    done
  fi
  exit 0
fi
if [[ "${1:-}" != create ]]; then
  exit 2
fi
if [[ -e "${REVIEW_TIMER_BF_ISSUE:?}" ]]; then
  printf 'unexpected duplicate\n' >&2
  exit 3
fi
printf '1\n' >"$REVIEW_TIMER_BF_ISSUE"
printf 'fixture-memory-failure\n'
EOF
  chmod +x "$REVIEW_TIMER_HOME/.local/bin/bf"
}

run_review_timer_install() {
  env HOME="$REVIEW_TIMER_HOME" PATH="$REVIEW_TIMER_PATH" \
    REVIEW_TIMER_SYSTEMCTL_LOG="$REVIEW_TIMER_SYSTEMCTL_LOG" \
    REVIEW_TIMER_SYSTEMCTL_STATE="$REVIEW_TIMER_SYSTEMCTL_STATE" \
    bash "$REVIEW_TIMER_INSTALL" "$@"
}

run_review_timer_install_without_systemctl() {
  env HOME="$REVIEW_TIMER_HOME" PATH="$REVIEW_TIMER_NO_SYSTEMCTL_PATH" \
    REVIEW_TIMER_SYSTEMCTL_LOG="$REVIEW_TIMER_SYSTEMCTL_LOG" \
    REVIEW_TIMER_SYSTEMCTL_STATE="$REVIEW_TIMER_SYSTEMCTL_STATE" \
    bash "$REVIEW_TIMER_INSTALL" "$@"
}

run_review_timer_dry_run() {
  local dry_home="$1"
  shift
  env HOME="$dry_home" PATH="$REVIEW_TIMER_PATH" \
    REVIEW_TIMER_SYSTEMCTL_LOG="$REVIEW_TIMER_SYSTEMCTL_LOG" \
    REVIEW_TIMER_SYSTEMCTL_STATE="$REVIEW_TIMER_SYSTEMCTL_STATE" \
    bash "$REVIEW_TIMER_INSTALL" "$@"
}

run_review_timer_list_timers() {
  env HOME="$REVIEW_TIMER_HOME" PATH="$REVIEW_TIMER_PATH" \
    REVIEW_TIMER_SYSTEMCTL_LOG="$REVIEW_TIMER_SYSTEMCTL_LOG" \
    REVIEW_TIMER_SYSTEMCTL_STATE="$REVIEW_TIMER_SYSTEMCTL_STATE" \
    systemctl --user list-timers --all --no-legend
}

run_review_timer_runner() {
  local workspace="$1"
  env HOME="$REVIEW_TIMER_HOME" PATH="$REVIEW_TIMER_PATH" \
    FACTORY_REVIEW_HOME_WORKSPACE="$workspace" \
    REVIEW_TIMER_MODE="$REVIEW_TIMER_MODE" \
    REVIEW_TIMER_FAILURE_RC=23 \
    REVIEW_TIMER_SYSTEMCTL_LOG="$REVIEW_TIMER_SYSTEMCTL_LOG" \
    REVIEW_TIMER_WORKSPACE="$REVIEW_TIMER_WORKSPACE" \
    REVIEW_TIMER_LEGACY_WORKSPACE="$REVIEW_TIMER_LEGACY_WORKSPACE" \
    REVIEW_TIMER_BEAD_LOG="$REVIEW_TIMER_BEAD_LOG" \
    REVIEW_TIMER_BF_LOG="$REVIEW_TIMER_BF_LOG" \
    REVIEW_TIMER_BEAD_ISSUE="$REVIEW_TIMER_BEAD_ISSUE" \
    REVIEW_TIMER_BF_ISSUE="$REVIEW_TIMER_BF_ISSUE" \
    REVIEW_TIMER_BF_LIST_RC="$REVIEW_TIMER_BF_LIST_RC" \
    REVIEW_TIMER_MEMORY_CWD_LOG="$REVIEW_TIMER_MEMORY_CWD_LOG" \
    "$REVIEW_TIMER_HOME/.config/factory-review/factory-review-memory-tool.sh"
}

run_review_timer_review_runner() {
  local unit_name="$1"
  env HOME="$REVIEW_TIMER_HOME" PATH="$REVIEW_TIMER_PATH" \
    REVIEW_TIMER_CLAUDE_LOG="$REVIEW_TIMER_CLAUDE_LOG" \
    REVIEW_TIMER_CLAUDE_CWD_LOG="$REVIEW_TIMER_CLAUDE_CWD_LOG" \
    REVIEW_TIMER_CLAUDE_MODE="$REVIEW_TIMER_CLAUDE_MODE" \
    REVIEW_TIMER_CLAUDE_FAILURE_RC=23 \
    REVIEW_TIMER_WORKSPACE="$REVIEW_TIMER_WORKSPACE" \
    REVIEW_TIMER_LEGACY_WORKSPACE="$REVIEW_TIMER_LEGACY_WORKSPACE" \
    REVIEW_TIMER_BEAD_LOG="$REVIEW_TIMER_BEAD_LOG" \
    REVIEW_TIMER_BF_LOG="$REVIEW_TIMER_BF_LOG" \
    REVIEW_TIMER_BEAD_ISSUE="$REVIEW_TIMER_BEAD_ISSUE" \
    REVIEW_TIMER_BF_ISSUE="$REVIEW_TIMER_BF_ISSUE" \
    "$REVIEW_TIMER_HOME/.config/factory-review/factory-review-${unit_name}.sh"
}

capture_review_timer_runner() {
  local workspace="$1"
  REVIEW_TIMER_RC=0
  REVIEW_TIMER_OUTPUT="$(run_review_timer_runner "$workspace" 2>&1)" || \
    REVIEW_TIMER_RC=$?
}

capture_review_timer_review_runner() {
  local unit_name="$1"
  REVIEW_TIMER_RC=0
  REVIEW_TIMER_OUTPUT="$(run_review_timer_review_runner "$unit_name" 2>&1)" || \
    REVIEW_TIMER_RC=$?
}

capture_review_timer_dry_run() {
  local dry_home="$1"
  REVIEW_TIMER_DRY_RC=0
  REVIEW_TIMER_DRY_OUTPUT="$(run_review_timer_dry_run "$dry_home" --dry-run 2>&1)" || \
    REVIEW_TIMER_DRY_RC=$?
}

assert_review_timer_rc() {
  local expected="$1" label="$2"
  if [[ "$REVIEW_TIMER_RC" == "$expected" ]]; then
    log_pass "$label (exit $REVIEW_TIMER_RC)"
  else
    log_fail "$label — expected exit $expected, got $REVIEW_TIMER_RC"
  fi
}

assert_review_timer_dry_rc() {
  local expected="$1" label="$2"
  if [[ "$REVIEW_TIMER_DRY_RC" == "$expected" ]]; then
    log_pass "$label (exit $REVIEW_TIMER_DRY_RC)"
  else
    log_fail "$label — expected exit $expected, got $REVIEW_TIMER_DRY_RC"
  fi
}

assert_review_timer_output_has() {
  local label="$1" needle="$2"
  if grep -qF -- "$needle" <<<"$REVIEW_TIMER_OUTPUT"; then
    log_pass "$label"
  else
    log_fail "$label — output did not contain expected status"
  fi
}

assert_review_timer_output_not_has() {
  local label="$1" needle="$2"
  if grep -qF -- "$needle" <<<"$REVIEW_TIMER_OUTPUT"; then
    log_fail "$label — sensitive fixture text was exposed"
  else
    log_pass "$label"
  fi
}

file_excludes() {
  local needle="$1" file="$2"
  [[ ! -e "$file" ]] || ! grep -qF -- "$needle" "$file"
}

test_workspace_review_child() {
  echo "=== factory-review workspace child fixture ==="
  local output rc=0
  output="$(bash "$REPO_ROOT/scripts/test-review-runner.sh" 2>&1)" || rc=$?
  if [[ "$rc" == 0 ]]; then
    log_pass "workspace child fixture covers iteration, invocation, filing, and no-op lists"
  else
    log_fail "workspace child fixture failed (exit $rc)"
    echo "$output" | sed 's/^/      /'
  fi
}

test_review_timer_contracts() {
  echo ""
  echo "=== install-review-timers.sh lifecycle fixtures ==="
  new_review_timer_fixture

  expect_exit 0 "review-timer install exits 0" run_review_timer_install

  local unit_dir="$REVIEW_TIMER_HOME/.config/systemd/user"
  local unit_names=(
    factory-review-plan-vs-built
    factory-review-find-stubs
    factory-review-repo-hygiene
    factory-review-memory-tool
    factory-review-installed-drift
  )
  local schedules=(
    'Mon 02:00'
    'Tue 02:00'
    'Wed 02:00'
    'Thu 02:00'
    'Fri 02:00'
  )
  local workspace_units=(
    factory-review-plan-vs-built
    factory-review-find-stubs
    factory-review-repo-hygiene
  )
  local workspace_skills=(plan-vs-built find-stubs repo-hygiene)
  local unit service timer unit_runner snapshot_dir i

  expect_ok "review-timer installer passes bash syntax" \
    bash -n "$REVIEW_TIMER_INSTALL"

  # Every installer-owned unit has the same service guarantees. Check all
  # five generated pairs, including the machine-local drift timer, rather
  # than allowing the memory unit alone to stand in for the lifecycle.
  snapshot_dir="$REVIEW_TIMER_BASE/first-install"
  mkdir -p "$snapshot_dir"
  for i in "${!unit_names[@]}"; do
    unit="${unit_names[$i]}"
    service="$unit_dir/$unit.service"
    timer="$unit_dir/$unit.timer"
    unit_runner="$REVIEW_TIMER_HOME/.config/factory-review/$unit.sh"
    expect_ok "$unit service is a oneshot" grep -qF 'Type=oneshot' "$service"
    expect_ok "$unit service has the shared timeout" grep -qF 'TimeoutSec=30min' "$service"
    expect_ok "$unit service has Nice=10" grep -qF 'Nice=10' "$service"
    expect_ok "$unit service has the system PATH" grep -qF \
      'Environment=PATH=/run/current-system/sw/bin:/usr/local/bin:/usr/bin:/bin' \
      "$service"
    expect_ok "$unit service runs from the home directory" grep -qF \
      'WorkingDirectory=%h' "$service"
    expect_ok "$unit service does not restart" grep -qF 'Restart=no' "$service"
    expect_ok "$unit service sends stdout to the journal" grep -qF \
      'StandardOutput=journal' "$service"
    expect_ok "$unit service sends stderr to the journal" grep -qF \
      'StandardError=journal' "$service"
    expect_ok "$unit timer requires its service" grep -qF \
      "Requires=$unit.service" "$timer"
    expect_ok "$unit timer has its staggered weekly schedule" grep -qF \
      "OnCalendar=${schedules[$i]}" "$timer"
    expect_ok "$unit timer is persistent" grep -qF 'Persistent=true' "$timer"
    expect_ok "$unit timer is installable" grep -qF 'WantedBy=timers.target' "$timer"
    expect_ok "$unit runner is executable" test -x "$unit_runner"
    expect_ok "$unit runner passes bash syntax" bash -n "$unit_runner"
    cp "$service" "$snapshot_dir/$unit.service"
    cp "$timer" "$snapshot_dir/$unit.timer"
    cp "$unit_runner" "$snapshot_dir/$unit.sh"
  done

  # The three workspace-list timers share the same generated runner contract:
  # each service must reach claude --print, and each timer must occupy a
  # distinct weekday slot. Keep these assertions separate from the five-unit
  # lifecycle loop above so the workspace review surface cannot be masked by
  # the memory or installed-drift timers.
  for i in "${!workspace_units[@]}"; do
    unit="${workspace_units[$i]}"
    service="$unit_dir/$unit.service"
    unit_runner="$REVIEW_TIMER_HOME/.config/factory-review/$unit.sh"
    expect_ok "$unit service launches its generated runner" grep -qF \
      "$unit.sh" "$service"
    expect_ok "$unit runner passes its workspace skill" grep -qF \
      "factory-review-workspace.sh\" \"${workspace_skills[$i]}" "$unit_runner"
    expect_ok "$unit runner delegates to the workspace-review child" grep -qF \
      'factory-review-workspace.sh' "$unit_runner"
    if command -v systemd-analyze >/dev/null 2>&1; then
      expect_ok "$unit timer has a valid weekly calendar" \
        systemd-analyze calendar "${schedules[$i]}"
    fi
  done

  local memory_runner="$REVIEW_TIMER_HOME/.config/factory-review/factory-review-memory-tool.sh"
  expect_ok "memory-tool child passes bash syntax" bash -n \
    "$REPO_ROOT/scripts/factory-review-memory-tool.sh"
  expect_ok "memory runner delegates to the focused memory-tool child" grep -qF \
    'factory-review-memory-tool.sh' "$memory_runner"
  expect_ok "memory runner does not contain the workspace loop" \
    test "$(grep -cF -- 'workspaces.txt' "$memory_runner" || true)" = 0

  # Parse the actual generated files with systemd's verifier when the host
  # provides it. The structural assertions above catch contract drift, while
  # this catches syntax or calendar errors that a shell fixture cannot see.
  if command -v systemd-analyze >/dev/null 2>&1; then
    local generated_units=("$unit_dir"/*.service "$unit_dir"/*.timer)
    local systemd_verify_log="$REVIEW_TIMER_BASE/systemd-analyze.log"
    if systemd-analyze verify "${generated_units[@]}" >"$systemd_verify_log" 2>&1; then
      log_pass "generated factory-review units pass systemd-analyze verify"
    else
      log_fail "generated factory-review units fail systemd-analyze verify"
      sed 's/^/      /' "$systemd_verify_log" >&2
    fi
  else
    echo "SKIP: systemd-analyze is unavailable; generated-unit verification was not checked"
  fi

  expect_ok "install requests a user-manager reload" grep -qF \
    -- '--user daemon-reload' "$REVIEW_TIMER_SYSTEMCTL_LOG"
  expect_ok "install enables every generated timer" grep -qF \
    -- '--user enable --now factory-review-plan-vs-built.timer factory-review-find-stubs.timer factory-review-repo-hygiene.timer factory-review-memory-tool.timer factory-review-installed-drift.timer' \
    "$REVIEW_TIMER_SYSTEMCTL_LOG"

  # The installer promises that enabled timers are visible through the same
  # systemctl --user surface operators use to inspect the schedule. The fake
  # user manager exposes the timers it received from enable --now, so this is
  # an end-to-end visibility assertion rather than only a log assertion.
  local visible_timers
  visible_timers="$(run_review_timer_list_timers)"
  for unit in factory-review-plan-vs-built factory-review-find-stubs \
    factory-review-repo-hygiene factory-review-memory-tool; do
    expect_ok "$unit is visible through systemctl --user list-timers" \
      grep -qF -- "$unit.timer" <<<"$visible_timers"
  done
  expect_ok "machine-local drift timer is visible through systemctl --user" \
    grep -qF -- 'factory-review-installed-drift.timer' <<<"$visible_timers"

  # An owned artifact may be edited or generated by an older installer. A
  # repeat install must repair that drift back to the deterministic output.
  printf '\n# local drift\n' >>"$unit_dir/factory-review-memory-tool.service"
  printf '\n# local drift\n' >>"$REVIEW_TIMER_HOME/.config/factory-review/factory-review-memory-tool.sh"
  expect_exit 0 "review-timer re-install repairs owned drift" run_review_timer_install
  for unit in "${unit_names[@]}"; do
    expect_ok "re-install preserves $unit service byte-for-byte" cmp -s \
      "$snapshot_dir/$unit.service" "$unit_dir/$unit.service"
    expect_ok "re-install preserves $unit timer byte-for-byte" cmp -s \
      "$snapshot_dir/$unit.timer" "$unit_dir/$unit.timer"
    expect_ok "re-install preserves $unit runner byte-for-byte" cmp -s \
      "$snapshot_dir/$unit.sh" \
      "$REVIEW_TIMER_HOME/.config/factory-review/$unit.sh"
  done

  local dry_home="$REVIEW_TIMER_BASE/dry-home"
  mkdir -p "$dry_home"
  local dry_systemctl_log="$REVIEW_TIMER_BASE/systemctl.before-dry-run"
  local dry_systemctl_state="$REVIEW_TIMER_BASE/systemctl-state.before-dry-run"
  cp "$REVIEW_TIMER_SYSTEMCTL_LOG" "$dry_systemctl_log"
  cp "$REVIEW_TIMER_SYSTEMCTL_STATE" "$dry_systemctl_state"
  capture_review_timer_dry_run "$dry_home"
  assert_review_timer_dry_rc 0 "review-timer dry-run exits 0"
  for i in "${!workspace_units[@]}"; do
    unit="${workspace_units[$i]}"
    expect_ok "dry-run prints $unit service" grep -qF \
      "$unit.service" <<<"$REVIEW_TIMER_DRY_OUTPUT"
    expect_ok "dry-run prints $unit timer" grep -qF \
      "$unit.timer" <<<"$REVIEW_TIMER_DRY_OUTPUT"
    expect_ok "dry-run prints $unit skill command" grep -qF \
      "factory-review-workspace.sh\" \"${workspace_skills[$i]}" <<<"$REVIEW_TIMER_DRY_OUTPUT"
    expect_ok "dry-run prints the workspace-review child" grep -qF \
      'factory-review-workspace.sh' <<<"$REVIEW_TIMER_DRY_OUTPUT"
    expect_ok "dry-run prints $unit weekly schedule" grep -qF \
      "OnCalendar=${schedules[$i]}" <<<"$REVIEW_TIMER_DRY_OUTPUT"
  done
  expect_ok "dry-run prints generated service settings" grep -qF \
    'Type=oneshot' <<<"$REVIEW_TIMER_DRY_OUTPUT"
  expect_ok "dry-run prints the generous timeout" grep -qF \
    'TimeoutSec=30min' <<<"$REVIEW_TIMER_DRY_OUTPUT"
  expect_ok "dry-run prints the system PATH" grep -qF \
    'Environment=PATH=/run/current-system/sw/bin:' <<<"$REVIEW_TIMER_DRY_OUTPUT"
  expect_ok "review-timer dry-run prints daemon-reload" grep -qF \
    'systemctl --user daemon-reload' <<<"$REVIEW_TIMER_DRY_OUTPUT"
  expect_ok "review-timer dry-run prints timer activation" grep -qF \
    'systemctl --user enable --now' <<<"$REVIEW_TIMER_DRY_OUTPUT"
  expect_ok "review-timer dry-run has no filesystem side effects" \
    test ! -e "$dry_home/.config"
  expect_ok "review-timer dry-run does not mutate systemctl log" \
    cmp -s "$dry_systemctl_log" "$REVIEW_TIMER_SYSTEMCTL_LOG"
  expect_ok "review-timer dry-run does not mutate systemctl state" \
    cmp -s "$dry_systemctl_state" "$REVIEW_TIMER_SYSTEMCTL_STATE"

  local no_systemctl_output no_systemctl_rc=0
  no_systemctl_output="$(run_review_timer_install_without_systemctl 2>&1)" || \
    no_systemctl_rc=$?
  if [[ "$no_systemctl_rc" == 0 ]] &&
    grep -qF -- 'systemctl is unavailable; unit files were installed but not activated.' \
      <<<"$no_systemctl_output"; then
    log_pass "install without systemctl keeps generated units and warns cleanly"
  else
    log_fail "install without systemctl should succeed with one actionable warning"
    echo "$no_systemctl_output" | tail -8 | sed 's/^/      /'
  fi
  expect_ok "install without systemctl does not emit a command-not-found error" \
    test "$(grep -cF -- 'command not found' <<<"$no_systemctl_output" || true)" = 0

  # Manually execute each workspace review service in a configured fixture.
  # The fake claude records its cwd and arguments, then emits an explicit
  # clean result. The two configured workspaces exercise both backend paths;
  # no real agent or workspace is contacted.
  local workspace_config="$REVIEW_TIMER_HOME/.config/factory-review/workspaces.txt"
  printf '%s\n%s\n' "$REVIEW_TIMER_WORKSPACE" "$REVIEW_TIMER_LEGACY_WORKSPACE" \
    >"$workspace_config"
  local review_unit
  REVIEW_TIMER_CLAUDE_MODE=clean
  rm -f "$REVIEW_TIMER_BEAD_LOG" "$REVIEW_TIMER_BF_LOG" \
    "$REVIEW_TIMER_BEAD_ISSUE" "$REVIEW_TIMER_BF_ISSUE"
  for review_unit in plan-vs-built find-stubs repo-hygiene; do
    capture_review_timer_review_runner "$review_unit"
    assert_review_timer_rc 0 "manual $review_unit service succeeds"
    assert_review_timer_output_has "manual $review_unit clean run is explicit" \
      "$review_unit clean in $REVIEW_TIMER_WORKSPACE; nothing to file."
  done
  expect_ok "clean review visits the first workspace for every skill" test \
    "$(grep -cFx -- "$REVIEW_TIMER_WORKSPACE" "$REVIEW_TIMER_CLAUDE_CWD_LOG")" = 3
  expect_ok "clean review visits the second workspace for every skill" test \
    "$(grep -cFx -- "$REVIEW_TIMER_LEGACY_WORKSPACE" "$REVIEW_TIMER_CLAUDE_CWD_LOG")" = 3
  expect_ok "clean review files no bead-rs findings" \
    test ! -e "$REVIEW_TIMER_BEAD_ISSUE"
  expect_ok "clean review files no legacy findings" \
    test ! -e "$REVIEW_TIMER_BF_ISSUE"
  expect_ok "plan review invokes claude with its skill" grep -qF -- \
    '--print /plan-vs-built .' "$REVIEW_TIMER_CLAUDE_LOG"
  expect_ok "repo-hygiene review invokes claude with its skill" grep -qF -- \
    '--print /repo-hygiene .' "$REVIEW_TIMER_CLAUDE_LOG"
  expect_ok "find-stubs review invokes claude with its skill" grep -qF -- \
    '--print /find-stubs .' "$REVIEW_TIMER_CLAUDE_LOG"

  # A findings result is captured and filed through each target workspace's
  # declared backend. The report is carried in the create call and the stable
  # reference makes the bead-rs path idempotent.
  REVIEW_TIMER_CLAUDE_MODE=findings
  rm -f "$REVIEW_TIMER_BEAD_LOG" "$REVIEW_TIMER_BF_LOG"
  for review_unit in plan-vs-built find-stubs repo-hygiene; do
    # Reset the fake stores between skills so each review proves its own
    # backend filing path; memory-tool below separately covers deduplication.
    rm -f "$REVIEW_TIMER_BEAD_ISSUE" "$REVIEW_TIMER_BF_ISSUE"
    capture_review_timer_review_runner "$review_unit"
    assert_review_timer_rc 0 "finding $review_unit service succeeds"
    assert_review_timer_output_has "finding $review_unit files a bead" \
      'Filed review findings bead'
  done
  expect_ok "findings create one bead per review via bead-rs" test \
    "$(grep -c '^bead create ' "$REVIEW_TIMER_BEAD_LOG")" = 3
  expect_ok "findings create one bead per review via legacy bf" test \
    "$(grep -c '^bf create ' "$REVIEW_TIMER_BF_LOG")" = 3
  expect_ok "finding report reaches bead-rs description" grep -qF -- \
    'review fixture: finding' "$REVIEW_TIMER_BEAD_LOG"
  expect_ok "finding report reaches legacy description" grep -qF -- \
    'review fixture: finding' "$REVIEW_TIMER_BF_LOG"
  capture_review_timer_review_runner plan-vs-built
  assert_review_timer_rc 0 "repeated finding service remains successful"
  assert_review_timer_output_has "repeated finding is deduplicated" \
    'Review findings already filed'
  expect_ok "repeated finding keeps one bead-rs issue" \
    test "$(<"$REVIEW_TIMER_BEAD_ISSUE")" = 1
  expect_ok "repeated finding does not create another legacy issue" test \
    "$(grep -c '^bf create ' "$REVIEW_TIMER_BF_LOG")" = 3

  # A failed Claude command is reported and leaves the service nonzero while
  # the loop still attempts the next configured workspace.
  REVIEW_TIMER_CLAUDE_MODE=fail
  rm -f "$REVIEW_TIMER_CLAUDE_CWD_LOG"
  capture_review_timer_review_runner plan-vs-built
  assert_review_timer_rc 23 "failed review preserves Claude exit status"
  assert_review_timer_output_has "failed review reports Claude failure" \
    'plan-vs-built failed in '
  expect_ok "failed review still visits every workspace" test \
    "$(grep -cFx -- "$REVIEW_TIMER_WORKSPACE" "$REVIEW_TIMER_CLAUDE_CWD_LOG")" = 1
  expect_ok "failed review continues to the second workspace" test \
    "$(grep -cFx -- "$REVIEW_TIMER_LEGACY_WORKSPACE" "$REVIEW_TIMER_CLAUDE_CWD_LOG")" = 1

  # An empty review workspace list has an explicit, successful no-op result.
  : >"$workspace_config"
  capture_review_timer_review_runner plan-vs-built
  assert_review_timer_rc 0 "empty review workspace service succeeds"
  assert_review_timer_output_has "empty review reports nothing to file" \
    'No configured workspaces; nothing to file.'

  # A passing check must not invoke a backend and must not expose the fake
  # token that the fixture emits on stderr.
  REVIEW_TIMER_MODE=pass
  rm -f "$REVIEW_TIMER_BEAD_LOG" "$REVIEW_TIMER_BEAD_ISSUE"
  capture_review_timer_runner "$REVIEW_TIMER_WORKSPACE"
  assert_review_timer_rc 0 "passing memory check succeeds"
  assert_review_timer_output_has "passing check reports nothing to file" \
    'memory-tool check passed; nothing to file.'
  assert_review_timer_output_has "passing check reports no bead needed" \
    'No bead needed.'
  assert_review_timer_output_not_has "passing check suppresses diagnostics" \
    'fixture-secret'
  expect_ok "passing check runs in the configured home workspace" \
    grep -qFx -- "$REVIEW_TIMER_WORKSPACE" "$REVIEW_TIMER_MEMORY_CWD_LOG"
  expect_ok "passing check files no bead" \
    test ! -e "$REVIEW_TIMER_BEAD_ISSUE"
  expect_ok "passing check never invokes bead-rs" \
    test ! -e "$REVIEW_TIMER_BEAD_LOG"

  # A failed bead-rs check returns the check's failure code, files one stable
  # issue, and remains idempotent on the next failed run.
  REVIEW_TIMER_MODE=fail
  capture_review_timer_runner "$REVIEW_TIMER_WORKSPACE"
  assert_review_timer_rc 23 "failed bead-rs memory check preserves failure code"
  assert_review_timer_output_has "failed bead-rs check reports filing" \
    'Filed memory-tool check failure bead fixture-memory-failure in '
  assert_review_timer_output_not_has "failed bead-rs check suppresses diagnostics" \
    'fixture-secret'
  expect_ok "failed bead-rs check creates one issue" \
    test "$(<"$REVIEW_TIMER_BEAD_ISSUE")" = 1
  expect_ok "bead-rs filing uses the stable unique reference" \
    grep -qF -- '--unique-ref factory-review:memory-tool-check' \
    "$REVIEW_TIMER_BEAD_LOG"
  expect_ok "bead-rs filing excludes diagnostics" \
    file_excludes 'fixture-secret' "$REVIEW_TIMER_BEAD_LOG"
  expect_ok "failure bead carries workspace and exit context" \
    grep -qF -- "$REVIEW_TIMER_WORKSPACE" "$REVIEW_TIMER_BEAD_LOG"
  expect_ok "failure bead records the check exit context" \
    grep -qF -- 'exit\ 23' "$REVIEW_TIMER_BEAD_LOG"
  expect_ok "failure bead records the check command context" \
    grep -qF -- 'command:\ memory-tool\ check' "$REVIEW_TIMER_BEAD_LOG"
  capture_review_timer_runner "$REVIEW_TIMER_WORKSPACE"
  assert_review_timer_rc 23 "repeated bead-rs failure preserves failure code"
  assert_review_timer_output_has "repeated bead-rs failure identifies the existing bead" \
    'Memory-tool check failure bead fixture-memory-failure already exists'
  expect_ok "repeated bead-rs failure remains one issue" \
    test "$(<"$REVIEW_TIMER_BEAD_ISSUE")" = 1

  # The legacy backend uses its own create flag spelling and list-based
  # deduplication; it must receive the same failure exactly once.
  rm -f "$REVIEW_TIMER_BF_LOG" "$REVIEW_TIMER_BF_ISSUE"
  capture_review_timer_runner "$REVIEW_TIMER_LEGACY_WORKSPACE"
  assert_review_timer_rc 23 "failed legacy memory check preserves failure code"
  assert_review_timer_output_has "failed legacy check identifies the filed bead" \
    'Filed memory-tool check failure bead fixture-memory-failure in '
  expect_ok "legacy filing uses the legacy type flag" \
    grep -qF -- '--type task' "$REVIEW_TIMER_BF_LOG"
  expect_ok "legacy filing uses the legacy priority flag" \
    grep -qF -- '--priority p3' "$REVIEW_TIMER_BF_LOG"
  expect_ok "legacy filing excludes diagnostics" \
    file_excludes 'fixture-secret' "$REVIEW_TIMER_BF_LOG"
  capture_review_timer_runner "$REVIEW_TIMER_LEGACY_WORKSPACE"
  assert_review_timer_rc 23 "repeated legacy failure preserves failure code"
  expect_ok "repeated legacy failure remains one issue" \
    test "$(<"$REVIEW_TIMER_BF_ISSUE")" = 1
  expect_ok "legacy rerun does not create a second bead" \
    test "$(grep -c '^bf create ' "$REVIEW_TIMER_BF_LOG" || true)" = 1

  # An explicitly selected home workspace must not silently fall back to the
  # install checkout when its backend declaration is missing or unsupported.
  # Both cases preserve the check failure and leave the backend stores alone.
  local missing_backend_workspace="$REVIEW_TIMER_BASE/missing-backend-workspace"
  mkdir -p "$missing_backend_workspace/.beads"
  printf 'bead_cli:\n' >"$missing_backend_workspace/.needle.yaml"
  rm -f "$REVIEW_TIMER_BEAD_LOG" "$REVIEW_TIMER_BEAD_ISSUE" \
    "$REVIEW_TIMER_BF_LOG" "$REVIEW_TIMER_BF_ISSUE"
  capture_review_timer_runner "$missing_backend_workspace"
  assert_review_timer_rc 23 "missing backend preserves check failure code"
  assert_review_timer_output_has "missing backend reports nothing to file" \
    'home workspace has no bead store/backend'
  expect_ok "missing backend does not file bead-rs issue" \
    test ! -e "$REVIEW_TIMER_BEAD_ISSUE"
  expect_ok "missing backend does not invoke bead-rs" \
    test ! -e "$REVIEW_TIMER_BEAD_LOG"
  expect_ok "missing backend check runs in the selected workspace" \
    grep -qFx -- "$missing_backend_workspace" "$REVIEW_TIMER_MEMORY_CWD_LOG"

  local unsupported_backend_workspace="$REVIEW_TIMER_BASE/unsupported-backend-workspace"
  mkdir -p "$unsupported_backend_workspace/.beads"
  printf 'bead_cli:\n  backend: unknown-backend\n' \
    >"$unsupported_backend_workspace/.needle.yaml"
  capture_review_timer_runner "$unsupported_backend_workspace"
  assert_review_timer_rc 23 "unsupported backend preserves check failure code"
  assert_review_timer_output_has "unsupported backend reports the configured value" \
    "unsupported bead backend 'unknown-backend'"
  expect_ok "unsupported backend still does not file bead-rs issue" \
    test ! -e "$REVIEW_TIMER_BEAD_ISSUE"
  expect_ok "unsupported backend still does not invoke bead-rs" \
    test ! -e "$REVIEW_TIMER_BEAD_LOG"
  expect_ok "unsupported backend check runs in the selected workspace" \
    grep -qFx -- "$unsupported_backend_workspace" "$REVIEW_TIMER_MEMORY_CWD_LOG"

  # A legacy open-bead lookup failure must not fall through to create: without
  # a successful deduplication check, filing could create an unbounded stream
  # of duplicate failure beads on every timer run.
  REVIEW_TIMER_BF_LIST_RC=17
  rm -f "$REVIEW_TIMER_BF_LOG" "$REVIEW_TIMER_BF_ISSUE"
  capture_review_timer_runner "$REVIEW_TIMER_LEGACY_WORKSPACE"
  assert_review_timer_rc 23 "legacy lookup failure preserves check failure code"
  assert_review_timer_output_has "legacy lookup failure reports unable to file" \
    'existing bead lookup failed'
  expect_ok "legacy lookup failure creates no bead" \
    test ! -e "$REVIEW_TIMER_BF_ISSUE"
  expect_ok "legacy lookup failure never calls create" \
    test "$(grep -c '^bf create ' "$REVIEW_TIMER_BF_LOG" || true)" = 0
  REVIEW_TIMER_BF_LIST_RC=0

  # Dry-run uninstall must preview the manager commands and removals without
  # changing any of the currently installed artifacts.
  REVIEW_TIMER_DRY_RC=0
  REVIEW_TIMER_DRY_OUTPUT="$(run_review_timer_install --dry-run --uninstall 2>&1)" || \
    REVIEW_TIMER_DRY_RC=$?
  assert_review_timer_dry_rc 0 "review-timer uninstall dry-run exits 0"
  expect_ok "uninstall dry-run prints timer stop" grep -qF \
    'systemctl --user stop factory-review-plan-vs-built.timer' \
    <<<"$REVIEW_TIMER_DRY_OUTPUT"
  expect_ok "uninstall dry-run prints daemon-reload" grep -qF \
    'systemctl --user daemon-reload' <<<"$REVIEW_TIMER_DRY_OUTPUT"
  expect_ok "uninstall dry-run leaves an owned service" test -f \
    "$unit_dir/factory-review-plan-vs-built.service"
  expect_ok "uninstall dry-run leaves the workspace list" test -f \
    "$workspace_config"

  # Only the units and runner files owned by this installer may disappear.
  local foreign_unit="$unit_dir/foreign.timer"
  local foreign_runner="$REVIEW_TIMER_HOME/.config/factory-review/foreign.sh"
  printf 'foreign timer\n' >"$foreign_unit"
  printf 'foreign runner\n' >"$foreign_runner"
  expect_exit 0 "review-timer uninstall exits 0" run_review_timer_install --uninstall
  for unit in "${unit_names[@]}"; do
    expect_ok "uninstall removes $unit service" \
      test ! -e "$unit_dir/$unit.service"
    expect_ok "uninstall removes $unit timer" \
      test ! -e "$unit_dir/$unit.timer"
    expect_ok "uninstall removes $unit runner" \
      test ! -e "$REVIEW_TIMER_HOME/.config/factory-review/$unit.sh"
    expect_ok "uninstall stops $unit before removal" grep -qF \
      -- "--user stop $unit.timer" "$REVIEW_TIMER_SYSTEMCTL_LOG"
    expect_ok "uninstall disables $unit before removal" grep -qF \
      -- "--user disable $unit.timer" "$REVIEW_TIMER_SYSTEMCTL_LOG"
  done
  expect_ok "uninstall preserves the workspace list" test -f "$workspace_config"
  expect_ok "uninstall preserves a foreign unit" test -e "$foreign_unit"
  expect_ok "uninstall preserves a foreign runner" test -e "$foreign_runner"

  # A same-named unit that was not generated by this installer is still
  # unrelated configuration: install must refuse to clobber it, and
  # uninstall must leave it and its manager state alone.
  local colliding_unit=factory-review-installed-drift
  local colliding_service="$unit_dir/$colliding_unit.service"
  local colliding_timer="$unit_dir/$colliding_unit.timer"
  local colliding_runner="$REVIEW_TIMER_HOME/.config/factory-review/$colliding_unit.sh"
  # A copied marker in the wrong location is not proof of ownership. This
  # protects an unrelated unit whose payload happens to mention the marker.
  printf 'foreign service\nunrelated setting\n# Managed by install-review-timers.sh\n' \
    >"$colliding_service"
  printf 'foreign timer\nunrelated setting\n# Managed by install-review-timers.sh\n' \
    >"$colliding_timer"
  printf 'foreign runner\nunrelated setting\nanother setting\n# Managed by install-review-timers.sh\n' \
    >"$colliding_runner"
  : >"$REVIEW_TIMER_SYSTEMCTL_LOG"
  expect_exit 1 "review-timer install rejects same-named foreign files" \
    run_review_timer_install
  expect_ok "collision preserves the foreign service" grep -qF \
    'foreign service' "$colliding_service"
  expect_ok "collision preserves the foreign timer" grep -qF \
    'foreign timer' "$colliding_timer"
  expect_ok "collision preserves the foreign runner" grep -qF \
    'foreign runner' "$colliding_runner"
  expect_exit 0 "review-timer uninstall ignores same-named foreign files" \
    run_review_timer_install --uninstall
  expect_ok "uninstall preserves a same-named foreign service" test -e \
    "$colliding_service"
  expect_ok "uninstall preserves a same-named foreign timer" test -e \
    "$colliding_timer"
  expect_ok "uninstall preserves a same-named foreign runner" test -e \
    "$colliding_runner"
  expect_ok "uninstall does not manage a foreign same-named timer" \
    test ! -s "$REVIEW_TIMER_SYSTEMCTL_LOG"

  # Once all owned artifacts are gone, repeating uninstall is a no-op: it must
  # not issue manager commands for the unrelated same-named files above.
  expect_exit 0 "repeated review-timer uninstall exits 0" \
    run_review_timer_install --uninstall
  expect_ok "repeated uninstall still preserves the foreign service" test -e \
    "$colliding_service"
  expect_ok "repeated uninstall still preserves the foreign timer" test -e \
    "$colliding_timer"
  expect_ok "repeated uninstall still preserves the foreign runner" test -e \
    "$colliding_runner"
  expect_ok "repeated uninstall does not manage a foreign timer" \
    test ! -s "$REVIEW_TIMER_SYSTEMCTL_LOG"
}

# Probe the real user manager when the host provides one. This is read-only:
# the isolated fixture above owns installation, while this check only confirms
# that an already-installed configuration is visible to operators. A clean
# host, a shell without a user bus, or a host without systemd records a skip
# instead of turning an optional integration check into a suite failure.
test_live_review_timer_visibility() {
  echo ""
  echo "=== live systemctl --user timer visibility (optional) ==="

  if ! command -v systemctl >/dev/null 2>&1; then
    echo "SKIP: systemctl is unavailable; live timer visibility was not checked"
    return
  fi

  local listing
  if ! listing="$(systemctl --user list-timers --all --no-legend 2>/dev/null)"; then
    echo "SKIP: systemctl --user user manager is unavailable; live timer visibility was not checked"
    return
  fi

  local missing=() unit
  for unit in factory-review-plan-vs-built factory-review-find-stubs \
    factory-review-repo-hygiene factory-review-memory-tool; do
    if ! grep -qF -- "$unit.timer" <<<"$listing"; then
      missing+=("$unit.timer")
    fi
  done

  if [[ ${#missing[@]} -eq 0 ]]; then
    log_pass "systemctl --user exposes all four workspace review timers"
  else
    echo "SKIP: systemctl --user is available, but the four workspace timers are not installed (${missing[*]})"
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

# --- check-installed.sh stale-inline detection -------------------------------

test_stale_inline_contracts() {
  echo ""
  echo "=== check-installed.sh stale-inline detection ==="
  new_fake_home
  new_inline_fixture_repo

  # Deterministic lib-sourcing victim: the extraction may or may not have
  # landed in the checkout this suite runs in, so the fixture repo's copy of
  # the victim is given the source line when it does not carry one. The
  # fixture repo is a temp copy — the real checkout is never modified.
  local victim_repo="$FAKE_REPO/$LIB_FIXTURE_SKILL/scripts/find-forks.sh"
  if ! grep -qF '../../lib/common.sh' "$victim_repo"; then
    sed -i '2isource "$(dirname "$0")/../../lib/common.sh"' "$victim_repo"
  fi
  local victim_installed="$FAKE_SKILLS/$LIB_FIXTURE_SKILL/scripts/find-forks.sh"

  # Install from the fixture repo: the victim's installed copy carries the
  # inlining marker, and — the pinned invariant — is byte-identical to what
  # the checker derives from the current repo script + current repo lib, so
  # the repo-vs-installed difference checks clean.
  run_install_in "$FAKE_REPO" "$LIB_FIXTURE_SKILL" >/dev/null 2>&1
  expect_ok "install inlined the lib into the installed copy" \
    grep -qF 'Inlined from lib/common.sh during install' "$victim_installed"
  expect_exit 0 "fresh install: derived inline matches installed copy → 0" \
    run_check_installed_in "$FAKE_REPO" "$LIB_FIXTURE_SKILL"

  # A hand-edited installed inline is not excused by its marker: it no longer
  # matches the derivation, so it is drift, named as a stale inline.
  echo "# tampered after install" >> "$victim_installed"
  local stale_out actual=0
  stale_out="$(run_check_installed_in "$FAKE_REPO" "$LIB_FIXTURE_SKILL" 2>&1)" || actual=$?
  if [[ "$actual" == 1 ]] && grep -q "Stale inline" <<< "$stale_out" \
     && grep -q "find-forks.sh" <<< "$stale_out"; then
    log_pass "hand-edited installed inline → 1 naming it a stale inline"
  else
    log_fail "hand-edited installed inline — expected exit 1 naming a stale inline, got $actual"
    echo "$stale_out" | tail -5 | sed 's/^/      /'
  fi
  # The documented fix clears it.
  run_install_in "$FAKE_REPO" "$LIB_FIXTURE_SKILL" >/dev/null 2>&1
  expect_exit 0 "documented fix (re-install) clears the stale inline → 0" \
    run_check_installed_in "$FAKE_REPO" "$LIB_FIXTURE_SKILL"

  # The core scenario: lib/common.sh is fixed in the repo AFTER an install.
  # Installed copies keep the helpers they were inlined with; a plain
  # repo-vs-installed diff cannot tell that state from a legitimate inline,
  # so the checker must re-derive the expected inline and call the mismatch
  # stale. The lib is appended to in the fixture repo, never the real one.
  cat >> "$FAKE_REPO/lib/common.sh" <<'EOF'

# Added after the install above; a current inline must carry it.
post_install_helper() { echo "lib changed after install"; }
EOF
  actual=0
  stale_out="$(run_check_installed_in "$FAKE_REPO" "$LIB_FIXTURE_SKILL" 2>&1)" || actual=$?
  if [[ "$actual" == 1 ]] && grep -q "Stale inline" <<< "$stale_out" \
     && grep -q "find-forks.sh" <<< "$stale_out"; then
    log_pass "lib fixed after install → 1 with the inlined copies named stale"
  else
    log_fail "lib fixed after install — expected exit 1 naming stale inlines, got $actual"
    echo "$stale_out" | tail -5 | sed 's/^/      /'
  fi

  # The documented fix re-inlines from the current lib: the refreshed copy
  # must both check clean and actually carry the new helper — proving the
  # inline is current, not merely excused.
  run_install_in "$FAKE_REPO" "$LIB_FIXTURE_SKILL" >/dev/null 2>&1
  expect_exit 0 "documented fix (re-install) lands the new lib helpers → 0" \
    run_check_installed_in "$FAKE_REPO" "$LIB_FIXTURE_SKILL"
  expect_ok "refreshed installed copy carries the post-install helper" \
    grep -qF 'post_install_helper' "$victim_installed"
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

# --- install-hooks.sh pre-commit hook install --------------------------------

# The three suite invocations the README's Testing section documents the
# pre-commit hook to run, in order. Matched against the hook's non-comment
# lines, so wording drift in the hook's own comments cannot fake a pass.
DOCUMENTED_HOOK_SUITES='scripts/validate-skills.sh
scripts/test-root-scripts.sh
scripts/test-script-fixtures.sh'

# Assert the hook's non-comment lines invoke exactly the documented three
# suites — none missing, none duplicated, nothing extra.
expect_hook_suites() {
  local label="$1" hook="$2"
  local found
  found="$(grep -v '^[[:space:]]*#' "$hook" | grep -oE 'scripts/[a-z-]+\.sh' || true)"
  if [[ "$found" == "$DOCUMENTED_HOOK_SUITES" ]]; then
    log_pass "$label"
  else
    log_fail "$label — non-comment suite references:"
    echo "$found" | sed 's/^/      /'
  fi
}

test_install_hooks_contracts() {
  echo ""
  echo "=== install-hooks.sh pre-commit hook install ==="
  new_fake_repo
  local hook="$FAKE_REPO/.git/hooks/pre-commit"

  # Fresh install: exit 0, an executable hook on disk invoking exactly the
  # documented three suites. The hook is checked by content, never executed
  # — it re-derives its repo root from its own path, so running it here
  # would point the suites at the skeleton repo, not a skills checkout.
  expect_exit 0 "fresh install exits 0" bash "$FAKE_REPO/scripts/install-hooks.sh"
  expect_ok "fresh install wrote .git/hooks/pre-commit" test -f "$hook"
  expect_ok "installed hook is executable" test -x "$hook"
  expect_hook_suites "installed hook invokes exactly the documented three suites" "$hook"

  # Re-run: exit 0, byte-identical hook — no duplicated suite lines, no clobber.
  cp "$hook" "$FAKE_REPO/pre-commit.first"
  expect_exit 0 "re-run exits 0 (idempotent)" bash "$FAKE_REPO/scripts/install-hooks.sh"
  expect_ok "re-run left the hook byte-identical" \
    cmp -s "$FAKE_REPO/pre-commit.first" "$hook"

  # An older hook of ours — the two-suite shape from before the fixtures
  # suite existed — is recognized as ours and upgraded in place to the
  # documented three.
  printf '#!/usr/bin/env bash\nbash "%s/scripts/validate-skills.sh" || exit 1\nbash "%s/scripts/test-root-scripts.sh" || exit 1\n' \
    "$FAKE_REPO" "$FAKE_REPO" > "$hook"
  expect_exit 0 "older two-suite hook: install exits 0" bash "$FAKE_REPO/scripts/install-hooks.sh"
  expect_hook_suites "older two-suite hook upgraded to the documented three" "$hook"

  # A foreign pre-existing hook is backed up byte-identically to
  # pre-commit.backup, then replaced by the documented hook.
  printf '#!/bin/sh\necho foreign hook ran\n' > "$FAKE_REPO/foreign-hook"
  cp "$FAKE_REPO/foreign-hook" "$hook"
  expect_exit 0 "install over a foreign hook exits 0" bash "$FAKE_REPO/scripts/install-hooks.sh"
  expect_ok "foreign hook preserved byte-identically at pre-commit.backup" \
    cmp -s "$FAKE_REPO/foreign-hook" "$FAKE_REPO/.git/hooks/pre-commit.backup"
  expect_hook_suites "hook installed over a foreign one invokes the documented three" "$hook"

  # Not a git repository (no .git/hooks): refused with exit 1.
  new_fake_repo bare
  expect_exit 1 "no .git/hooks → exit 1, nothing installed" \
    bash "$FAKE_REPO/scripts/install-hooks.sh"
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

# --- check-push-ci.sh push-CI heartbeat --------------------------------------

test_push_ci_contracts() {
  echo ""
  echo "=== check-push-ci.sh push-CI heartbeat ==="
  new_push_ci_fixture
  new_push_ci_shim

  # Usage surface.
  expect_exit 0 "--help exits 0" run_push_ci --help
  expect_exit 2 "unknown option exits 2" run_push_ci --nonsense
  expect_exit 2 "missing --grace-minutes value exits 2" run_push_ci --grace-minutes
  expect_exit 2 "negative --grace-minutes value exits 2" run_push_ci --grace-minutes=-1

  # The reference walk skips a CI-authored tip (mirrors the sensor filter):
  # HEAD is authored by "Argo Workflows CI" at 13:00, so the reference is the
  # human commit at 12:00. A 12:30 workflow is OLDER than the tip but newer
  # than the reference — it verifies only if the skip happened.
  write_wf_listing "skills-validate-abc123|skills-validate-|2026-09-14T12:30:00Z"
  expect_exit 0 "CI-authored tip skipped to its parent (12:30 wf verifies against 12:00 ref)" \
    run_push_ci

  # Manual runs must not count: only generateName exactly "skills-validate-"
  # proves the webhook path; a newer "skills-validate-manual-" run plus an
  # older sensor run must still fail.
  write_wf_listing \
    "skills-validate-old|skills-validate-|2026-09-14T11:00:00Z" \
    "skills-validate-manual-new|skills-validate-manual-|2026-09-14T14:00:00Z"
  expect_exit 1 "manual run is not mistaken for a sensor delivery" run_push_ci

  # Heartbeat OK: sensor workflow newer than the reference commit, stamped
  # with fractional seconds (the API server occasionally emits them — the
  # parse must strip, not choke).
  write_wf_listing "skills-validate-fract|skills-validate-|2026-09-14T12:30:00.123456Z"
  expect_exit 0 "sensor workflow at/after reference commit → 0" run_push_ci

  # Heartbeat FAIL: newest sensor workflow predates the reference push.
  write_wf_listing "skills-validate-stale|skills-validate-|2026-09-14T11:30:00Z"
  expect_exit 1 "no workflow since the reference push → 1 (the alarm code)" run_push_ci

  # Nothing on record at all: the empty listing collapses under command
  # substitution's trailing-newline stripping — must be the alarm (1), not a
  # crash, and not an environmental 2.
  write_wf_listing
  expect_exit 1 "zero sensor workflows on record → 1 (not an unbound-variable crash)" run_push_ci

  # Environmental failures are 2, never the alarm code.
  write_wf_listing "skills-validate-abc123|skills-validate-|2026-09-14T12:30:00Z"
  PUSH_CI_KUBECTL_FAIL=1 expect_exit 2 "kubectl failure → 2 (environmental)" run_push_ci
  unset PUSH_CI_KUBECTL_FAIL # must not leak into the assertions below
  printf '{"kind":"Workflow","spec":{}}' >"$PUSH_CI_DIR/listing.json" # no .items
  expect_exit 2 "malformed listing → 2 (environmental)" run_push_ci

  # A repo without origin/main is environmental, not an alarm.
  expect_exit 2 "no origin/main → 2" bash -c \
    "cd '$PUSH_CI_DIR' && mkdir -p orphan && cd orphan &&
     git init -q -b main . &&
     PATH='$PUSH_CI_SHIM:$PATH' SKILLS_CI_KUBECTL_SERVER='http://push-ci-fixture.invalid:1' \
     bash '$REPO_ROOT/scripts/check-push-ci.sh'"

  # Grace window: a too-recent push is not judgeable (3) and must not reach
  # kubectl at all.
  push_ci_commit "just-now" "$PUSH_CI_AUTHOR" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  git -C "$PUSH_CI_DIR/clone" push -q origin main
  write_wf_listing "skills-validate-abc123|skills-validate-|2026-09-14T12:30:00Z"
  expect_exit 3 "push younger than the grace window → 3" run_push_ci --grace-minutes 60
  expect_ok "grace-window run never consulted kubectl" \
    test ! -e "$PUSH_CI_DIR/.kubectl-called"
}

main() {
  echo "Root-script contract tests for jeds-curated-skills"
  echo "Repo root: $REPO_ROOT"
  echo "(fixtures run against a temp HOME; the real HOME is untouched)"

  test_check_installed_contracts
  test_stale_inline_contracts
  test_install_contracts
  test_install_hooks_contracts
  test_workspace_review_child
  test_review_timer_contracts
  test_live_review_timer_visibility
  test_statusline_contracts
  test_push_ci_contracts

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
