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

# Print the concrete commands that a workspace-review runner will execute.
# This is deliberately a preview only: it reads the configured list but never
# creates directories, changes units, invokes systemd, or files beads.
print_workspace_review_commands() {
  local skill_name="$1"
  local workspace raw_workspace quoted_workspace

  echo -e "${YELLOW}[DRY RUN] Workspace commands for ${skill_name}:${NC}"
  if [[ ! -f "$WORKSPACES_CONFIG" ]]; then
    echo "  (no configured workspaces: $WORKSPACES_CONFIG)"
    return 0
  fi
  if [[ ! -r "$WORKSPACES_CONFIG" ]]; then
    echo "  (workspace list is not readable: $WORKSPACES_CONFIG)"
    return 0
  fi

  while IFS= read -r raw_workspace || [[ -n "$raw_workspace" ]]; do
    # Match the child runner's list handling, including CRLF files. Do not
    # evaluate entries as shell input: paths remain literal data.
    raw_workspace="${raw_workspace%$'\r'}"
    if [[ "$raw_workspace" =~ ^[[:space:]]*$ ||
      "$raw_workspace" =~ ^[[:space:]]*# ]]; then
      continue
    fi
    if [[ "$raw_workspace" == "~"* && "$raw_workspace" != "~" &&
      "$raw_workspace" != "~/"* ]]; then
      echo "  (skipping malformed workspace entry: $raw_workspace)"
      continue
    fi

    workspace="${raw_workspace/#\~/$HOME}"
    if [[ "$workspace" != /* ]]; then
      workspace="$HOME/$workspace"
    fi
    printf -v quoted_workspace '%q' "$workspace"
    printf '  (cd -- %s && claude --print /%s .)\n' \
      "$quoted_workspace" "$skill_name"
  done < "$WORKSPACES_CONFIG"
}

# Generate the workspace-review service wrapper. The review loop itself lives
# in scripts/factory-review-workspace.sh so it can be tested and run without
# loading this installer's systemd lifecycle or host-check code.
generate_runner_script() {
  local unit_name="$1"
  local skill_name="$2"

  cat <<EOF
#!/usr/bin/env bash
# Runner script for ${unit_name}
# ${INSTALLER_MARKER}
# Auto-generated by install-review-timers.sh

set -uo pipefail

# The child adds the user's local command directories as well. Keep this
# wrapper small: the installer owns generated artifacts, while the child owns
# workspace iteration and review reporting. Include the Nix system path
# explicitly so the generated command works when invoked outside systemd.
export PATH="/run/current-system/sw/bin:\$HOME/.local/bin:\$HOME/.cargo/bin:\$PATH"

# REPO_ROOT is baked in when the service is installed, so the timer can
# invoke the tested child even when systemd starts with WorkingDirectory=%h.
exec "${BASH_BIN}" "${REPO_ROOT}/scripts/factory-review-workspace.sh" "${skill_name}"
EOF
}

# Generate the memory-tool service wrapper separately. memory-tool is a host
# check, not a workspace-list review: it must run once even when workspaces.txt
# is empty. The focused child owns the check and backend-aware filing logic.
generate_memory_runner_script() {
  local unit_name="$1"

  cat <<EOF
#!/usr/bin/env bash
# Runner script for ${unit_name}
# ${INSTALLER_MARKER}
# Auto-generated by install-review-timers.sh

set -uo pipefail

# The child adds the user's local command directories as well. Keep this
# wrapper small: the installer owns generated artifacts, while the child owns
# memory-tool execution and filing.
export PATH="\$HOME/.local/bin:\$HOME/.cargo/bin:\$PATH"

exec "${BASH_BIN}" "${REPO_ROOT}/scripts/factory-review-memory-tool.sh"
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

# Current files carry an explicit marker in a fixed generated-header position.
# Requiring that position prevents an unrelated same-named unit that merely
# mentions the marker in its description or payload from being treated as
# installer-owned. The byte comparison is a migration path for files
# generated by older versions of this installer, before the marker was added;
# it recognizes only the exact old output.
installer_owns_file() {
  local unit_name="$1"
  local file_kind="$2"
  local path="$3"

  [[ -f "$path" && ! -L "$path" ]] || return 1

  case "$file_kind" in
    service|timer)
      [[ "$(sed -n '2p' "$path")" == "# ${INSTALLER_MARKER}" ]] && return 0
      ;;
    runner)
      [[ "$(sed -n '3p' "$path")" == "# ${INSTALLER_MARKER}" ]] && return 0
      ;;
    *)
      return 1
      ;;
  esac

  cmp -s "$path" <(
    generate_owned_file "$unit_name" "$file_kind" |
      sed '/^# Managed by install-review-timers[.]sh$/d'
  )
}

# Return true when a unit is part of the current installer contract. The
# separate lookup is intentional: files from an older contract may still
# carry the ownership marker but no longer have entries in UNITS.
declared_unit() {
  local candidate="$1"
  local unit_name

  for unit_name in "${UNIT_NAMES[@]}"; do
    [[ "$unit_name" == "$candidate" ]] && return 0
  done
  return 1
}

# Discover marker-owned units that are no longer in UNIT_NAMES. This closes
# the lifecycle loop when a future installer release renames or retires a
# unit: reinstall and uninstall both remove only the old artifacts that this
# installer can positively identify as its own. Files with a marker in the
# wrong position, symlinks, and unrelated names are ignored.
stale_owned_units() {
  local path unit file_kind
  declare -A seen=()

  for file_kind in service timer; do
    for path in "$SYSTEMD_USER_DIR"/factory-review-*.$file_kind; do
      [[ -f "$path" && ! -L "$path" ]] || continue
      unit="${path##*/}"
      unit="${unit%.$file_kind}"
      declared_unit "$unit" && continue
      installer_owns_file "$unit" "$file_kind" "$path" || continue
      [[ -n "${seen[$unit]+present}" ]] && continue
      seen["$unit"]=1
      printf '%s\n' "$unit"
    done
  done

  for path in "$FACTORY_REVIEW_DIR"/factory-review-*.sh; do
    [[ -f "$path" && ! -L "$path" ]] || continue
    unit="${path##*/}"
    unit="${unit%.sh}"
    declared_unit "$unit" && continue
    installer_owns_file "$unit" runner "$path" || continue
    [[ -n "${seen[$unit]+present}" ]] && continue
    seen["$unit"]=1
    printf '%s\n' "$unit"
  done
}

remove_stale_owned_units() {
  local stale_unit

  while IFS= read -r stale_unit; do
    [[ -n "$stale_unit" ]] || continue
    echo -e "${YELLOW}Reconciling stale installer-owned unit:${NC} $stale_unit"
    uninstall_unit "$stale_unit"
  done < <(stale_owned_units)
}

# A checkout may be used from a shell without systemd installed at all. Keep
# that case distinct from a present systemctl whose user manager is unavailable
# so installation remains successful after writing the generated artifacts and
# the user gets one actionable warning instead of a shell-level command error.
user_systemctl_available() {
  command -v systemctl >/dev/null 2>&1
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
    if [[ "$skill_name" == "plan-vs-built" ||
      "$skill_name" == "find-stubs" ||
      "$skill_name" == "repo-hygiene" ]]; then
      print_workspace_review_commands "$skill_name"
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
    elif user_systemctl_available; then
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

  # Remove artifacts from an older installer contract before regenerating the
  # current set. The final daemon-reload below makes this reconciliation
  # visible to the user manager in the same transaction as installation.
  remove_stale_owned_units

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
    if ! user_systemctl_available; then
      echo -e "${YELLOW}Warning: systemctl is unavailable; unit files were installed but not activated.${NC}" >&2
    elif ! systemctl --user daemon-reload; then
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
  remove_stale_owned_units

  # Reload systemd after owned files changed. A no-op uninstall should not
  # disturb an unrelated user manager, and dry-run prints the command only.
  if [[ "$UNINSTALL_FOUND" == "true" && "$DRY_RUN" == "true" ]]; then
    echo -e "${YELLOW}[DRY RUN]${NC} systemctl --user daemon-reload"
  elif [[ "$UNINSTALL_FOUND" == "true" ]]; then
    if ! user_systemctl_available; then
      echo -e "${YELLOW}Warning: systemctl is unavailable; removed files are gone but the user manager was not reloaded.${NC}" >&2
    else
      echo -e "${BLUE}Reloading systemd...${NC}"
      if ! systemctl --user daemon-reload; then
        echo -e "${YELLOW}Warning: could not reload the systemd user manager; removed files are still gone.${NC}" >&2
      fi
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
