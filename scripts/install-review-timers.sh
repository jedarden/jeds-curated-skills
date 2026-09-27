#!/usr/bin/env bash
# Install weekly systemd --user timers for factory review skills
#
# Usage:
#   ./scripts/install-review-timers.sh [--dry-run] [--uninstall]
#
# Installs the following weekly timers:
#   - factory-review-plan-vs-built:   Runs plan-vs-built skill over workspaces
#   - factory-review-find-stubs:     Runs find-stubs skill over workspaces
#   - factory-review-repo-hygiene:   Runs repo-hygiene skill over workspaces
#   - factory-review-memory-tool:     Runs memory-tool check (single invocation)
#   - factory-review-installed-drift: Runs scripts/check-installed.sh against
#                                     this repo (installed-skill drift: full
#                                     sweep + usage-statusline deployed copy)
#
# All timers run weekly with staggered schedules. The skill timers read
# workspaces from ~/.config/factory-review/workspaces.txt and file beads in the
# appropriate workspace using the configured bead backend. The drift timer is
# machine-local — one repo clone vs ~/.claude/skills/, not per-workspace — so
# it ignores the workspace list, always runs against the repo this installer
# was invoked from, and files its bead in that repo's own workspace.

set -euo pipefail

# Colors for output
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(dirname "$SCRIPT_DIR")"
# Resolved at install time: this machine shape is NixOS, where /bin/bash does
# not exist — a hardcoded /bin/bash ExecStart fails to start.
readonly BASH_BIN="$(command -v bash)"
readonly SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
readonly FACTORY_REVIEW_DIR="$HOME/.config/factory-review"
readonly WORKSPACES_CONFIG="$FACTORY_REVIEW_DIR/workspaces.txt"
readonly INSTALLER_MARKER="Managed by install-review-timers.sh"
DRY_RUN=false

# Timer/service units to install
readonly UNIT_NAMES=(
  factory-review-plan-vs-built
  factory-review-find-stubs
  factory-review-repo-hygiene
  factory-review-memory-tool
  factory-review-installed-drift
)

declare -A UNITS=(
  ["factory-review-plan-vs-built"]="plan-vs-built"
  ["factory-review-find-stubs"]="find-stubs"
  ["factory-review-repo-hygiene"]="repo-hygiene"
  ["factory-review-memory-tool"]="memory-tool"
  ["factory-review-installed-drift"]="check-installed"
)

# Staggered schedules (weekly on different days)
declare -A SCHEDULES=(
  ["factory-review-plan-vs-built"]="Mon 02:00"
  ["factory-review-find-stubs"]="Tue 02:00"
  ["factory-review-repo-hygiene"]="Wed 02:00"
  ["factory-review-memory-tool"]="Thu 02:00"
  ["factory-review-installed-drift"]="Fri 02:00"
)

# Show usage
show_usage() {
  cat <<EOF
Usage: $0 [OPTION]

Install weekly systemd --user timers for factory review skills.

Options:
  --dry-run         Print commands without executing
  --uninstall       Remove installed timers and services
  --help, -h        Show this help message

Installed timers:
  - factory-review-plan-vs-built   (Mon 02:00)
  - factory-review-find-stubs      (Tue 02:00)
  - factory-review-repo-hygiene     (Wed 02:00)
  - factory-review-memory-tool     (Thu 02:00)
  - factory-review-installed-drift  (Fri 02:00)

Skill timers read workspaces from ~/.config/factory-review/workspaces.txt.
The installed-drift timer is machine-local (this repo vs ~/.claude/skills/)
and ignores the workspace list.

After installation, reload systemd:
  systemctl --user daemon-reload

Enable timers (start running them):
  systemctl --user enable --now factory-review-*.timer

Check status:
  systemctl --user list-timers

EOF
}

# Parse arguments
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run)
        DRY_RUN=true
        shift
        ;;
      --uninstall)
        UNINSTALL=true
        shift
        ;;
      --help|-h)
        show_usage
        exit 0
        ;;
      *)
        echo -e "${RED}Error: Unknown option '$1'${NC}"
        show_usage
        exit 1
        ;;
    esac
  done
}

# Create workspace config if it doesn't exist. Dry-run must not create a
# user's config directory merely to preview the install.
ensure_workspace_config() {
  if [[ ! -f "$WORKSPACES_CONFIG" ]]; then
    if [[ "$DRY_RUN" == "true" ]]; then
      echo -e "${YELLOW}[DRY RUN] Would create workspace config:${NC} $WORKSPACES_CONFIG"
      return
    fi

    echo -e "${YELLOW}Creating workspace config: $WORKSPACES_CONFIG${NC}"
    mkdir -p "$(dirname "$WORKSPACES_CONFIG")"
    cat > "$WORKSPACES_CONFIG" <<'EOF'
# Factory review workspace list
# One workspace path per line
# Paths can be absolute or relative to $HOME
#
# Example:
# /home/coding/my-project
# ~/another-project
# projects/workspace
EOF
    echo -e "${GREEN}✓ Created default workspace config${NC}"
    echo -e "${YELLOW}  Edit $WORKSPACES_CONFIG to add your workspaces${NC}"
  fi
}

# Generate service file content
generate_service() {
  local unit_name="$1"
  local skill_name="$2"
  local runner_script="$3"

  cat <<EOF
[Unit]
# ${INSTALLER_MARKER}
Description=Factory Review: ${skill_name} skill
After=network.target

[Service]
Type=oneshot
ExecStart=${BASH_BIN} ${runner_script}
Nice=10
TimeoutSec=30min
Environment=PATH=/run/current-system/sw/bin:/usr/local/bin:/usr/bin:/bin
WorkingDirectory=%h

# Don't restart on failure — weekly run will retry
Restart=no

# Standard output and error to journal
StandardOutput=journal
StandardError=journal
EOF
}

# Generate timer file content
generate_timer() {
  local unit_name="$1"
  local schedule="${SCHEDULES[$unit_name]}"

  cat <<EOF
[Unit]
# ${INSTALLER_MARKER}
Description=Weekly Factory Review: ${unit_name}
Requires=${unit_name}.service

[Timer]
# SCHEDULES already carry the weekday ("Mon 02:00"), which is weekly by
# itself. Do not prefix "weekly" — systemd rejects
# "OnCalendar=weekly Mon 02:00" as unparseable (verified via
# systemd-analyze calendar) and the timer unit then fails to load.
OnCalendar=${schedule}
Persistent=true

[Install]
WantedBy=timers.target
EOF
}

# Generate runner script content
generate_runner_script() {
  local unit_name="$1"
  local skill_name="$2"

  cat <<EOF
#!/usr/bin/env bash
# Runner script for ${unit_name}
# ${INSTALLER_MARKER}
# Auto-generated by install-review-timers.sh

set -uo pipefail

# The service unit's Environment=PATH covers system dirs only. claude
# (~/.local/bin) and bead (~/.cargo/bin) install under \$HOME on this
# machine shape; without this line every bead/claude call below would
# silently fail under systemd while working fine when run by hand.
export PATH="\$HOME/.local/bin:\$HOME/.cargo/bin:\$PATH"

WORKSPACES_CONFIG="${WORKSPACES_CONFIG}"
SKILL_NAME="${skill_name}"
UNIT_NAME="${unit_name}"

# The skill itself is report-only here. The runner owns the output boundary:
# Claude's report is captured, printed to the journal, and filed as one
# deduplicated bead in the workspace that was reviewed. This keeps the timer
# backend-aware without asking each skill to write .beads directly.
REVIEW_PROTOCOL='After completing the requested review, end your response with exactly one line: FACTORY_REVIEW_RESULT: clean when there are no actionable findings, or FACTORY_REVIEW_RESULT: findings when there are actionable findings. Do not create beads; the timer runner files the captured report.'

review_is_clean() {
  local report_file="\$1"

  # The protocol above is the authoritative result. The format fallbacks keep
  # older installed copies useful when they emit their documented clean text
  # but do not know the protocol yet.
  if grep -Eqi '^FACTORY_REVIEW_RESULT:[[:space:]]*clean[[:space:]]*$' "\$report_file"; then
    return 0
  fi
  if grep -Eqi '^FACTORY_REVIEW_RESULT:[[:space:]]*findings[[:space:]]*$' "\$report_file"; then
    return 1
  fi
  [[ ! -s "\$report_file" ]] && return 0

  case "\$SKILL_NAME" in
    plan-vs-built)
      grep -Eqi 'no (actionable )?findings|nothing to file|0 gaps|all .*BUILT' "\$report_file"
      ;;
    find-stubs)
      grep -Eqi '(^|[^[:digit:]])0 findings([^[:digit:]]|$)|no findings|nothing to file' "\$report_file"
      ;;
    repo-hygiene)
      grep -Eqi 'clean[[:space:]]*[-—][[:space:]]*no findings|no findings|nothing to file' "\$report_file"
      ;;
    *)
      return 1
      ;;
  esac
}

review_backend() {
  local workspace="\$1"
  local backend=""

  [[ -d "\$workspace/.beads" && -f "\$workspace/.needle.yaml" ]] || {
    echo none
    return
  }

  backend="\$(awk '\$1 == "backend:" || \$1 == "bead_cli.backend:" {print \$2; exit}' "\$workspace/.needle.yaml")"
  case "\$backend" in
    bead-rs|bead) echo bead-rs ;;
    bf|bead-forge) echo bf ;;
    *) echo none ;;
  esac
}

file_review_bead() {
  local workspace="\$1"
  local report_file="\$2"
  local backend bead_cli title description report_hash workspace_hash unique_ref
  local result rc=0 existing

  backend="\$(review_backend "\$workspace")"
  if [[ "\$backend" == none ]]; then
    echo "Review findings in \$workspace could not be filed: no supported bead backend/store." >&2
    return 1
  fi

  if [[ "\$backend" == bead-rs ]]; then
    bead_cli=bead
  else
    bead_cli=bf
  fi
  if ! command -v "\$bead_cli" >/dev/null 2>&1; then
    echo "Review findings in \$workspace could not be filed: '\$bead_cli' is not on PATH." >&2
    return 1
  fi

  report_hash="\$(sha256sum "\$report_file" | awk '{print substr(\$1,1,16)}')"
  workspace_hash="\$(printf '%s' "\$workspace" | sha256sum | awk '{print substr(\$1,1,16)}')"
  unique_ref="factory-review:\${SKILL_NAME}:\${workspace_hash}:\${report_hash}"
  title="Factory review: \${SKILL_NAME} findings in \${workspace}"
  description="\$(printf 'Factory review %s reported findings in %s.\n\nCaptured claude --print output:\n' "\$SKILL_NAME" "\$workspace"; cat "\$report_file")"

  if [[ "\$backend" == bf ]]; then
    # Legacy bf has no --unique-ref flag. An open-title lookup is the
    # compatibility deduplication path used by its installed skill contract.
    if ! existing="\$(cd "\$workspace" && "\$bead_cli" list --status open 2>/dev/null)"; then
      echo "Review findings in \$workspace could not be filed: '\$bead_cli list' failed." >&2
      return 1
    fi
    if grep -qF -- "\$title" <<<"\$existing"; then
      echo "Review findings already filed in \$workspace; nothing new to file."
      return 0
    fi
    if result="\$(cd "\$workspace" && "\$bead_cli" create \
        --title "\$title" \
        --description "\$description" \
        --priority p3 \
        --type task \
        --label factory-review \
        --label "\$SKILL_NAME" 2>&1)"; then
      echo "Filed review findings bead in \$workspace: \$result"
      return 0
    else
      rc=\$?
    fi
  else
    if result="\$(cd "\$workspace" && "\$bead_cli" create \
        --title "\$title" \
        --description "\$description" \
        --priority 3 \
        --issue-type task \
        --label factory-review \
        --label "\$SKILL_NAME" \
        --unique-ref "\$unique_ref" 2>&1)"; then
      if [[ "\$result" == EXISTING* ]]; then
        echo "Review findings already filed in \$workspace; nothing new to file."
      else
        echo "Filed review findings bead in \$workspace: \$result"
      fi
      return 0
    else
      rc=\$?
    fi
  fi

  echo "Review findings in \$workspace could not be filed (backend exit \$rc): \$result" >&2
  return 1
}

# Read workspaces from config
if [[ ! -f "\$WORKSPACES_CONFIG" ]]; then
  echo "Error: Workspace config not found: \$WORKSPACES_CONFIG" >&2
  exit 1
fi

# Process each workspace. Keep going after one workspace fails so a single
# broken checkout does not hide findings from the rest of the configured list.
processed=0
failed=0
while IFS= read -r workspace; do
  # Skip empty lines and comments
  if [[ -z "\$workspace" || "\$workspace" =~ ^[[:space:]]*# ]]; then
    continue
  fi

  # Expand ~ to home directory
  workspace="\${workspace/#\~/\$HOME}"

  # Convert relative to absolute path
  if [[ ! "\$workspace" =~ ^/ ]]; then
    workspace="\$HOME/\$workspace"
  fi

  # Skip if workspace doesn't exist
  if [[ ! -d "\$workspace" ]]; then
    echo "Skipping non-existent workspace: \$workspace"
    continue
  fi

  processed=\$((processed + 1))
  echo "Running \${SKILL_NAME} on \$workspace..."

  cd "\$workspace" || {
    echo "Unable to enter workspace: \$workspace" >&2
    failed=1
    continue
  }

  review_output="\$(mktemp "\${TMPDIR:-/tmp}/factory-review.XXXXXX")" || {
    echo "Unable to create a review output file for \$workspace" >&2
    failed=1
    continue
  }

  # Keep the skill invocation visible and stable for the timer contract while
  # passing the result protocol as system guidance. Combined output is replayed
  # to the journal before any bead is filed, so a failed command is diagnosable.
  claude_rc=0
  claude --append-system-prompt "\$REVIEW_PROTOCOL" --print /\${SKILL_NAME} . \
    >"\$review_output" 2>&1 || claude_rc=\$?
  cat "\$review_output"

  if [[ \$claude_rc -ne 0 ]]; then
    echo "\${SKILL_NAME} failed in \$workspace (claude exit \$claude_rc)" >&2
    if [[ \$failed -eq 0 ]]; then
      failed=\$claude_rc
    fi
    rm -f "\$review_output"
    continue
  fi

  if review_is_clean "\$review_output"; then
    echo "\${SKILL_NAME} clean in \$workspace; nothing to file."
  elif ! file_review_bead "\$workspace" "\$review_output"; then
    if [[ \$failed -eq 0 ]]; then
      failed=1
    fi
  fi
  rm -f "\$review_output"
done < "\$WORKSPACES_CONFIG"

if [[ \$processed -eq 0 ]]; then
  echo "No configured workspaces; nothing to file."
fi

exit \$failed
EOF
}

# Generate the memory-tool runner separately. memory-tool is a host check, not
# a workspace-list review: it must run once even when workspaces.txt is empty.
# Its bead is filed through the home workspace's declared backend, just like
# repo-hygiene files findings through each target repo's backend.
generate_memory_runner_script() {
  local unit_name="$1"

  cat <<EOF
#!/usr/bin/env bash
# Runner script for ${unit_name}
# ${INSTALLER_MARKER}
# Auto-generated by install-review-timers.sh

set -uo pipefail

# The service unit's PATH covers system directories. memory-tool and bead/bf
# commonly live in the user's local bin directories.
export PATH="\$HOME/.local/bin:\$HOME/.cargo/bin:\$PATH"

INSTALL_REPO_ROOT="${REPO_ROOT}"
HOME_WORKSPACE="\${FACTORY_REVIEW_HOME_WORKSPACE:-\$HOME/jeds-curated-skills}"

# When the installer was run from the home workspace itself, use that exact
# checkout even if HOME has a different directory name in a fixture or clone.
if [[ ! -f "\$HOME_WORKSPACE/.needle.yaml" || ! -d "\$HOME_WORKSPACE/.beads" ]]; then
  if [[ -f "\$INSTALL_REPO_ROOT/.needle.yaml" && -d "\$INSTALL_REPO_ROOT/.beads" ]]; then
    HOME_WORKSPACE="\$INSTALL_REPO_ROOT"
  fi
fi

# Suppress diagnostics so a check cannot accidentally copy a token or other
# credential-bearing output into the systemd journal or the filed bead. The
# exit code is the durable finding; diagnostic detail is intentionally omitted.
check_rc=0
if (cd "\$HOME_WORKSPACE" && memory-tool check) >/dev/null 2>&1; then
  check_rc=0
else
  check_rc=\$?
fi

if [[ \$check_rc -eq 0 ]]; then
  echo "memory-tool check passed; nothing to file."
  echo "No bead needed."
  exit 0
fi

echo "memory-tool check failed with exit \$check_rc; attempting to file one bead."

backend=""
if [[ -f "\$HOME_WORKSPACE/.needle.yaml" ]]; then
  backend="\$(awk '\$1 == "backend:" || \$1 == "bead_cli.backend:" {print \$2; exit}' "\$HOME_WORKSPACE/.needle.yaml")"
fi

if [[ ! -d "\$HOME_WORKSPACE/.beads" || -z "\$backend" ]]; then
  echo "memory-tool check failed; nothing to file: home workspace has no bead store/backend (\$HOME_WORKSPACE)."
  exit \$check_rc
fi

case "\$backend" in
  bead-rs|bead)
    bead_cli="bead"
    backend_kind="bead-rs"
    ;;
  bf|bead-forge)
    bead_cli="bf"
    backend_kind="bf"
    ;;
  *)
    echo "memory-tool check failed; nothing to file: unsupported bead backend '\$backend'."
    exit \$check_rc
    ;;
esac

if ! command -v "\$bead_cli" >/dev/null 2>&1; then
  echo "memory-tool check failed; unable to file bead: '\$bead_cli' is not on PATH." >&2
  exit \$check_rc
fi

title="memory-tool check failure"
description="memory-tool check failed in \$HOME_WORKSPACE with exit \$check_rc; diagnostic output is intentionally omitted to avoid credential disclosure."
unique_ref="factory-review:memory-tool-check"
create_rc=0
bead_output="\$(mktemp "\${TMPDIR:-/tmp}/factory-review-memory-bead.XXXXXX")" || {
  echo "memory-tool check failed; unable to capture bead identifier." >&2
  exit \$check_rc
}
trap 'rm -f "\$bead_output"' EXIT

# Successful bead creation prints an identifier (or \`EXISTING ID\` for an
# idempotent replay). Read only that identifier back. In particular, never
# replay the complete backend output because a backend error or renderer may
# contain data that does not belong in the journal.
bead_id_from_output() {
  local line candidate
  while IFS= read -r line; do
    case "\$line" in
      EXISTING\ *) candidate="\${line#EXISTING }" ;;
      EXISTING_CLOSED\ *) candidate="\${line#EXISTING_CLOSED }" ;;
      *) candidate="\$line" ;;
    esac
    if [[ "\$candidate" =~ ^[[:alnum:]_.:-]+\$ ]]; then
      printf '%s\\n' "\$candidate"
      return 0
    fi
  done <"\$bead_output"
  return 1
}

if [[ "\$backend_kind" == "bf" ]]; then
  # Legacy bead-forge has no bead-rs --unique-ref flag. Its list operation is
  # the compatibility deduplication check; keep the query's output private as
  # well because backend renderers may include the full description.
  existing_beads=""
  if ! existing_beads="\$(cd "\$HOME_WORKSPACE" && "\$bead_cli" list --status open 2>/dev/null)"; then
    echo "memory-tool check failed; unable to file bead: existing bead lookup failed in \$HOME_WORKSPACE." >&2
    create_rc=1
  elif grep -qF -- "\$title" <<<"\$existing_beads"; then
    echo "An open memory-tool check failure bead already exists; nothing new to file."
  elif (cd "\$HOME_WORKSPACE" && "\$bead_cli" create \\
      --title "\$title" \\
      --description "\$description" \\
      --priority p3 \\
      --type task \\
      --label factory-review \\
      --label memory-tool >"\$bead_output" 2>/dev/null); then
    if bead_id="\$(bead_id_from_output)"; then
      echo "Filed memory-tool check failure bead \$bead_id in \$HOME_WORKSPACE."
    else
      echo "Filed memory-tool check failure bead in \$HOME_WORKSPACE (identifier unavailable)."
    fi
  else
    create_rc=\$?
  fi
else
  # bead-rs provides atomic idempotency, so concurrent timer retries and
  # repeated weekly failures resolve to one stable finding.
  if (cd "\$HOME_WORKSPACE" && "\$bead_cli" create \\
      --title "\$title" \\
      --description "\$description" \\
      --priority 3 \\
      --issue-type task \\
      --label factory-review \\
      --label memory-tool \\
      --unique-ref "\$unique_ref" >"\$bead_output" 2>/dev/null); then
    if bead_id="\$(bead_id_from_output)"; then
      if grep -q '^EXISTING' "\$bead_output"; then
        echo "Memory-tool check failure bead \$bead_id already exists in \$HOME_WORKSPACE; nothing new to file."
      else
        echo "Filed memory-tool check failure bead \$bead_id in \$HOME_WORKSPACE."
      fi
    else
      echo "Filed memory-tool check failure bead in \$HOME_WORKSPACE (identifier unavailable)."
    fi
  else
    create_rc=\$?
  fi
fi

if [[ \$create_rc -ne 0 ]]; then
  echo "memory-tool check failed; bead filing failed in \$HOME_WORKSPACE (backend exit \$create_rc)." >&2
  exit \$check_rc
fi

exit \$check_rc
EOF
}

# Generate the runner for the installed-skill drift timer. Unlike the
# workspace-loop runners, this one is machine-local: check-installed.sh diffs
# this repo (the source of truth the timers were installed from — the path is
# baked in below at install time) against ~/.claude/skills/, so it runs once,
# ignores workspaces.txt, and files its bead in this repo's own workspace.
#
# Exit-code contract (see scripts/check-installed.sh):
#   0 no drift            → unit succeeds, nothing filed
#   1 drift detected      → bead filed (deduped while an open drift bead for
#                           this check exists) and the unit fails, so the
#                           timer shows a non-zero result in list-timers
#   2 usage error / no ~/.claude/skills/ → no bead (this is not drift), the
#                           unit still fails and the reason is in the journal
generate_drift_runner_script() {
  local unit_name="$1"

  cat <<EOF
#!/usr/bin/env bash
# Runner script for ${unit_name}
# ${INSTALLER_MARKER}
# Auto-generated by install-review-timers.sh

# No -e: the checker's exit code is data to branch on, not a crash.
set -uo pipefail

# The service unit's PATH is system-only; bead lives in ~/.cargo/bin.
command -v bead >/dev/null 2>&1 || export PATH="\$HOME/.cargo/bin:\$HOME/.local/bin:\$PATH"

REPO_ROOT="${REPO_ROOT}"
TITLE="Installed-skill drift detected (weekly check-installed.sh run)"

cd "\$REPO_ROOT" || {
  echo "Error: repo not found: \$REPO_ROOT — reinstall the timers from the repo clone" >&2
  exit 2
}

OUT="\$(mktemp)"
trap 'rm -f "\$OUT"' EXIT

echo "Running scripts/check-installed.sh in \$REPO_ROOT (full sweep + usage-statusline deployed copy)..."
./scripts/check-installed.sh >"\$OUT" 2>&1
rc=\$?
cat "\$OUT"

if [[ \$rc -eq 0 ]]; then
  echo "No installed-skill drift detected."
  exit 0
fi

if [[ \$rc -ne 1 ]]; then
  echo "check-installed.sh exited \$rc (usage error or ~/.claude/skills/ missing — not drift);" >&2
  echo "no bead filed. See the checker output above." >&2
  exit "\$rc"
fi

echo "Drift detected — filing bead in \$REPO_ROOT"
if bead list --status open | grep -qF "\$TITLE"; then
  echo "An open drift bead for this check already exists — not filing a weekly duplicate."
  echo "This run's detail is in the journal: journalctl --user -u ${unit_name}.service"
else
  bead create --title "\$TITLE" --priority 2 --issue-type bug \\
    --label factory-review --label drift \\
    --description "Weekly ${unit_name} run found drift between ${REPO_ROOT} and ~/.claude/skills/. Full detail: journalctl --user -u ${unit_name}.service, or re-run scripts/check-installed.sh in the repo. Remedy: ./install.sh <skill> for each drifted skill (a bare cp -r is not enough — install.sh inlines lib/common.sh and redeploys the usage-statusline out-of-tree copy)." \\
    || echo "Warning: bead create failed — drift is recorded in this unit's journal only" >&2
fi

# Propagate the drift code so the oneshot unit is marked failed and the
# last result is visible in systemctl --user list-timers.
exit 1
EOF
}

# Generate one of the files owned by a unit. Keeping this dispatch in one
# place lets ownership checks compare a legacy install with the current
# generated output without duplicating the unit templates.
generate_owned_file() {
  local unit_name="$1"
  local file_kind="$2"
  local skill_name="${UNITS[$unit_name]}"
  local runner_script="$FACTORY_REVIEW_DIR/${unit_name}.sh"

  case "$file_kind" in
    service)
      generate_service "$unit_name" "$skill_name" "$runner_script"
      ;;
    timer)
      generate_timer "$unit_name"
      ;;
    runner)
      if [[ "$skill_name" == "memory-tool" ]]; then
        generate_memory_runner_script "$unit_name"
      elif [[ "$skill_name" == "check-installed" ]]; then
        generate_drift_runner_script "$unit_name"
      else
        generate_runner_script "$unit_name" "$skill_name"
      fi
      ;;
    *)
      echo "Internal error: unknown generated file kind '$file_kind'" >&2
      return 1
      ;;
  esac
}

# Current files carry an explicit marker. The byte comparison is a migration
# path for files generated by older versions of this installer, before the
# marker was added; it recognizes only the exact old output and never treats
# an arbitrary same-named user file as installer-owned.
installer_owns_file() {
  local unit_name="$1"
  local file_kind="$2"
  local path="$3"

  [[ -f "$path" && ! -L "$path" ]] || return 1
  if grep -qF -- "# ${INSTALLER_MARKER}" "$path" 2>/dev/null; then
    return 0
  fi

  cmp -s "$path" <(
    generate_owned_file "$unit_name" "$file_kind" |
      sed '/^# Managed by install-review-timers[.]sh$/d'
  )
}

# Refuse to overwrite a same-named file that this installer did not create.
# This keeps an unrelated user unit/configuration recoverable and makes the
# ownership rule true even when an operator later runs --uninstall.
validate_install_targets() {
  local conflicts=0
  local unit_name file_kind path

  for unit_name in "${UNIT_NAMES[@]}"; do
    for file_kind in service timer runner; do
      if [[ "$file_kind" == runner ]]; then
        path="$FACTORY_REVIEW_DIR/${unit_name}.sh"
      else
        path="$SYSTEMD_USER_DIR/${unit_name}.${file_kind}"
      fi

      if [[ -e "$path" || -L "$path" ]] &&
        ! installer_owns_file "$unit_name" "$file_kind" "$path"; then
        echo -e "${RED}Error: refusing to overwrite unrelated file:${NC} $path" >&2
        conflicts=1
      fi
    done
  done

  if (( conflicts )); then
    echo -e "${YELLOW}No files were changed. Remove or move the conflicting files, then retry.${NC}" >&2
    return 1
  fi
}

# Install a single unit (service + timer + runner script)
install_unit() {
  local unit_name="$1"
  local skill_name="${UNITS[$unit_name]}"
  local service_file="$SYSTEMD_USER_DIR/${unit_name}.service"
  local timer_file="$SYSTEMD_USER_DIR/${unit_name}.timer"
  local runner_script="$FACTORY_REVIEW_DIR/${unit_name}.sh"

  echo -e "${BLUE}Installing $unit_name...${NC}"

  # Generate and install service file
  if [[ "$DRY_RUN" == "true" ]]; then
    echo -e "${YELLOW}[DRY RUN] Would create:${NC} $service_file"
    generate_service "$unit_name" "$skill_name" "$runner_script"
  else
    generate_owned_file "$unit_name" service > "$service_file"
    echo -e "${GREEN}  ✓ Created:${NC} $service_file"
  fi

  # Generate and install timer file
  if [[ "$DRY_RUN" == "true" ]]; then
    echo -e "${YELLOW}[DRY RUN] Would create:${NC} $timer_file"
    generate_timer "$unit_name"
  else
    generate_owned_file "$unit_name" timer > "$timer_file"
    echo -e "${GREEN}  ✓ Created:${NC} $timer_file"
  fi

  # Generate and install runner script
  if [[ "$DRY_RUN" == "true" ]]; then
    echo -e "${YELLOW}[DRY RUN] Would create:${NC} $runner_script"
    if [[ "$skill_name" == "memory-tool" ]]; then
      generate_memory_runner_script "$unit_name"
    elif [[ "$skill_name" == "check-installed" ]]; then
      generate_drift_runner_script "$unit_name"
    else
      generate_runner_script "$unit_name" "$skill_name"
    fi
  else
    mkdir -p "$(dirname "$runner_script")"
    generate_owned_file "$unit_name" runner > "$runner_script"
    chmod +x "$runner_script"
    echo -e "${GREEN}  ✓ Created:${NC} $runner_script"
  fi

  echo ""
}

# Uninstall a single unit
uninstall_unit() {
  local unit_name="$1"
  local service_file="$SYSTEMD_USER_DIR/${unit_name}.service"
  local timer_file="$SYSTEMD_USER_DIR/${unit_name}.timer"
  local runner_script="$FACTORY_REVIEW_DIR/${unit_name}.sh"

  local timer_owned=false
  local file_owned=false

  echo -e "${BLUE}Removing $unit_name...${NC}"

  if installer_owns_file "$unit_name" timer "$timer_file"; then
    timer_owned=true
  fi

  # Stop and disable timer first (if not dry run)
  if [[ "$timer_owned" == "true" ]]; then
    if [[ "$DRY_RUN" == "true" ]]; then
      echo -e "${YELLOW}[DRY RUN]${NC} systemctl --user stop ${unit_name}.timer"
      echo -e "${YELLOW}[DRY RUN]${NC} systemctl --user disable ${unit_name}.timer"
    elif command -v systemctl >/dev/null 2>&1; then
      systemctl --user is-active "${unit_name}.timer" >/dev/null 2>&1 && \
        systemctl --user stop "${unit_name}.timer" >/dev/null 2>&1 || true
      systemctl --user is-enabled "${unit_name}.timer" >/dev/null 2>&1 && \
        systemctl --user disable "${unit_name}.timer" >/dev/null 2>&1 || true
    fi
  fi

  # Remove files
  local file file_kind
  for file_kind in service timer runner; do
    case "$file_kind" in
      service) file="$service_file" ;;
      timer) file="$timer_file" ;;
      runner) file="$runner_script" ;;
    esac
    if installer_owns_file "$unit_name" "$file_kind" "$file"; then
      file_owned=true
      if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${YELLOW}[DRY RUN] Would remove:${NC} $file"
      else
        rm -f "$file"
        echo -e "${GREEN}  ✓ Removed:${NC} $file"
      fi
    fi
  done

  if [[ "$file_owned" == "true" ]]; then
    UNINSTALL_FOUND=true
  fi

  echo ""
}

# Main install logic
install_all() {
  echo -e "${BLUE}Installing factory review timers...${NC}"
  echo ""

  validate_install_targets

  # Create systemd user directory
  if [[ "$DRY_RUN" == "false" ]]; then
    mkdir -p "$SYSTEMD_USER_DIR"
  fi

  # Ensure workspace config exists
  ensure_workspace_config

  # Install each unit
  for unit_name in "${UNIT_NAMES[@]}"; do
    install_unit "$unit_name"
  done

  timer_units=()
  for unit_name in "${UNIT_NAMES[@]}"; do
    timer_units+=("${unit_name}.timer")
  done

  # Make an install immediately visible in `systemctl --user list-timers`.
  # A user manager may not be available in a non-login shell, so unit files
  # are still considered installed when these optional activation steps fail.
  if [[ "$DRY_RUN" == "true" ]]; then
    echo -e "${YELLOW}[DRY RUN]${NC} systemctl --user daemon-reload"
    echo -e "${YELLOW}[DRY RUN]${NC} systemctl --user enable --now ${timer_units[*]}"
  else
    if ! systemctl --user daemon-reload; then
      echo -e "${YELLOW}Warning: systemd user manager unavailable; unit files were installed but not activated.${NC}" >&2
    elif ! systemctl --user enable --now "${timer_units[@]}"; then
      echo -e "${YELLOW}Warning: timers were installed but could not be enabled; run systemctl --user enable --now ${timer_units[*]} when the user manager is available.${NC}" >&2
    fi
  fi

  # Show next steps
  cat <<EOF

${GREEN}Installation complete!${NC}

Next steps:
  1. Review workspace config:
     cat $WORKSPACES_CONFIG

  2. Reload systemd:
     systemctl --user daemon-reload

  3. Enable timers:
     systemctl --user enable --now factory-review-*.timer

  4. Check status:
     systemctl --user list-timers | grep factory-review

  5. Test a service manually:
     systemctl --user start factory-review-memory-tool.service
     journalctl --user -u factory-review-memory-tool.service

To uninstall:
  $0 --uninstall

EOF
}

# Main uninstall logic
uninstall_all() {
  echo -e "${BLUE}Uninstalling factory review timers...${NC}"
  echo ""

  UNINSTALL_FOUND=false

  # Uninstall each unit
  for unit_name in "${UNIT_NAMES[@]}"; do
    uninstall_unit "$unit_name"
  done

  # Reload systemd after owned files changed. A no-op uninstall should not
  # disturb an unrelated user manager, and dry-run prints the command only.
  if [[ "$UNINSTALL_FOUND" == "true" && "$DRY_RUN" == "true" ]]; then
    echo -e "${YELLOW}[DRY RUN]${NC} systemctl --user daemon-reload"
  elif [[ "$UNINSTALL_FOUND" == "true" ]] && command -v systemctl >/dev/null 2>&1; then
    echo -e "${BLUE}Reloading systemd...${NC}"
    if ! systemctl --user daemon-reload; then
      echo -e "${YELLOW}Warning: could not reload the systemd user manager; removed files are still gone.${NC}" >&2
    fi
  fi

  echo -e "${GREEN}Uninstallation complete!${NC}"
  echo ""
}

# Main
parse_args "$@"

if [[ "${UNINSTALL:-false}" == "true" ]]; then
  uninstall_all
else
  install_all
fi
