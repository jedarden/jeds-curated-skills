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
readonly WORKSPACES_CONFIG="$HOME/.config/factory-review/workspaces.txt"
DRY_RUN=false

# Timer/service units to install
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

# Create workspace config if it doesn't exist
ensure_workspace_config() {
  if [[ ! -f "$WORKSPACES_CONFIG" ]]; then
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

  cat <<EOF
[Unit]
Description=Factory Review: ${skill_name} skill
After=network.target

[Service]
Type=oneshot
ExecStart=${BASH_BIN} -c 'source ~/.config/factory-review/${unit_name}.sh'
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

set -euo pipefail

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

# Process each workspace
while IFS= read -r workspace; do
  # Skip empty lines and comments
  [[ -z "\$workspace" || "\$workspace" =~ ^[[:space:]]*# ]] && continue

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

  echo "Running \${SKILL_NAME} on \$workspace..."

  # Run the skill with bead output
  case "\$SKILL_NAME" in
    memory-tool)
      # Special case: memory-tool runs once, not per-workspace
      memory-tool check || {
        echo "memory-tool check failed - filing bead in home workspace"
        cd "\$HOME/jeds-curated-skills" 2>/dev/null || cd "\$HOME"
        bead create --title "memory-tool check failure" --priority 3 --issue-type task \
          --label factory-review --label memory-tool || true
      }
      break  # Only run once
      ;;
    repo-hygiene)
      # repo-hygiene with bead filing
      cd "\$workspace"
      claude --print /\${SKILL_NAME} --file-beads . || true
      ;;
    *)
      # Regular skill: run with claude --print
      cd "\$workspace"
      claude --print /\${SKILL_NAME} . || true
      ;;
  esac
done < "\$WORKSPACES_CONFIG"
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
  local runner_script="$HOME/.config/factory-review/${unit_name}.sh"

  echo -e "${BLUE}Installing $unit_name...${NC}"

  # Generate and install service file
  if [[ "$DRY_RUN" == "true" ]]; then
    echo -e "${YELLOW}[DRY RUN] Would create:${NC} $service_file"
    generate_service "$unit_name" "$skill_name"
  else
    generate_service "$unit_name" "$skill_name" > "$service_file"
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
    if [[ "$skill_name" == "check-installed" ]]; then
      generate_drift_runner_script "$unit_name"
    else
      generate_runner_script "$unit_name" "$skill_name"
    fi
  else
    mkdir -p "$(dirname "$runner_script")"
    if [[ "$skill_name" == "check-installed" ]]; then
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
  local runner_script="$HOME/.config/factory-review/${unit_name}.sh"

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
  for unit_name in "${!UNITS[@]}"; do
    install_unit "$unit_name"
  done

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
  for unit_name in "${!UNITS[@]}"; do
    uninstall_unit "$unit_name"
  done

  # Reload systemd if not dry run
  if [[ "$DRY_RUN" == "false" ]]; then
    echo -e "${BLUE}Reloading systemd...${NC}"
    systemctl --user daemon-reload
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
