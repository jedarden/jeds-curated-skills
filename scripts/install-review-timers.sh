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

  # repo-hygiene's skill contract includes --file-beads; the other review
  # skills file their findings as part of their normal invocation.
  if [[ "\$SKILL_NAME" == "repo-hygiene" ]]; then
    claude --print /\${SKILL_NAME} --file-beads . || {
      echo "\${SKILL_NAME} failed in \$workspace" >&2
      failed=1
    }
  else
    claude --print /\${SKILL_NAME} . || {
      echo "\${SKILL_NAME} failed in \$workspace" >&2
      failed=1
    }
  fi
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

check_output=""
check_rc=0
if check_output="\$(memory-tool check 2>&1)"; then
  check_rc=0
else
  check_rc=\$?
fi
if [[ -n "\$check_output" ]]; then
  printf '%s\\n' "\$check_output"
fi

if [[ \$check_rc -eq 0 ]]; then
  echo "memory-tool check passed; nothing to file."
  exit 0
fi

echo "memory-tool check failed with exit \$check_rc; attempting to file one bead."

backend=""
if [[ -f "\$HOME_WORKSPACE/.needle.yaml" ]]; then
  backend="\$(awk '\$1 == "backend:" {print \$2; exit}' "\$HOME_WORKSPACE/.needle.yaml")"
fi

if [[ ! -d "\$HOME_WORKSPACE/.beads" || -z "\$backend" ]]; then
  echo "memory-tool check failed; nothing to file: home workspace has no bead store/backend (\$HOME_WORKSPACE)."
  exit \$check_rc
fi

case "\$backend" in
  bead-rs) bead_cli="bead" ;;
  bf) bead_cli="bf" ;;
  *)
    echo "memory-tool check failed; nothing to file: unsupported bead backend '\$backend'."
    exit \$check_rc
    ;;
esac

if ! command -v "\$bead_cli" >/dev/null 2>&1; then
  echo "memory-tool check failed; unable to file bead: '\$bead_cli' is not on PATH." >&2
  exit \$check_rc
fi

description="memory-tool check failed with exit \$check_rc; see this service's journal for its output."
create_output=""
create_rc=0
if create_output="\$(cd "\$HOME_WORKSPACE" && "\$bead_cli" create \\
    --title "memory-tool check failure" \\
    --description "\$description" \\
    --priority 3 \\
    --issue-type task \\
    --label factory-review \\
    --label memory-tool \\
    --unique-ref factory-review:memory-tool-check 2>&1)"; then
  create_rc=0
else
  create_rc=\$?
fi
if [[ -n "\$create_output" ]]; then
  printf '%s\\n' "\$create_output"
fi

if [[ \$create_rc -ne 0 ]]; then
  echo "memory-tool check failed; bead filing failed in \$HOME_WORKSPACE." >&2
  exit \$check_rc
fi

echo "Filed (or already had) the memory-tool check failure bead in \$HOME_WORKSPACE."
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
    generate_service "$unit_name" "$skill_name" "$runner_script" > "$service_file"
    echo -e "${GREEN}  ✓ Created:${NC} $service_file"
  fi

  # Generate and install timer file
  if [[ "$DRY_RUN" == "true" ]]; then
    echo -e "${YELLOW}[DRY RUN] Would create:${NC} $timer_file"
    generate_timer "$unit_name"
  else
    generate_timer "$unit_name" > "$timer_file"
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
    if [[ "$skill_name" == "memory-tool" ]]; then
      generate_memory_runner_script "$unit_name" > "$runner_script"
    elif [[ "$skill_name" == "check-installed" ]]; then
      generate_drift_runner_script "$unit_name" > "$runner_script"
    else
      generate_runner_script "$unit_name" "$skill_name" > "$runner_script"
    fi
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

  echo -e "${BLUE}Removing $unit_name...${NC}"

  # Stop and disable timer first (if not dry run)
  if [[ "$DRY_RUN" == "false" ]]; then
    systemctl --user is-active "${unit_name}.timer" >/dev/null 2>&1 && \
      systemctl --user stop "${unit_name}.timer" >/dev/null 2>&1 || true
    systemctl --user is-enabled "${unit_name}.timer" >/dev/null 2>&1 && \
      systemctl --user disable "${unit_name}.timer" >/dev/null 2>&1 || true
  fi

  # Remove files
  for file in "$service_file" "$timer_file" "$runner_script"; do
    if [[ -f "$file" ]]; then
      if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${YELLOW}[DRY RUN] Would remove:${NC} $file"
      else
        rm -f "$file"
        echo -e "${GREEN}  ✓ Removed:${NC} $file"
      fi
    fi
  done

  echo ""
}

# Main install logic
install_all() {
  echo -e "${BLUE}Installing factory review timers...${NC}"
  echo ""

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
    echo -e "${YELLOW}[DRY RUN] systemctl --user daemon-reload${NC}"
    echo -e "${YELLOW}[DRY RUN] systemctl --user enable --now${NC} ${timer_units[*]}"
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

  # Uninstall each unit
  for unit_name in "${UNIT_NAMES[@]}"; do
    uninstall_unit "$unit_name"
  done

  # Reload systemd if not dry run
  if [[ "$DRY_RUN" == "false" ]]; then
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
