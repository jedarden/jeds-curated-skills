#!/usr/bin/env bash
# Selective installer for jeds-curated-skills
# Usage:
#   ./install.sh <skill-name> [<skill-name>...]   # Install specific skills
#   ./install.sh --all                             # Install every skill
#   ./install.sh --list                            # List available skills

set -euo pipefail

TARGET_DIR="$HOME/.claude/skills"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly NC='\033[0m' # No Color

# List all available skill directories in this repo
list_available_skills() {
    # Find directories containing SKILL.md or README.md that look like skills
    # Exclude .git, lib, scripts, docs, adr (unless it has a skill marker)
    for dir in "$SCRIPT_DIR"/*/; do
        dir="${dir%/}"
        basename="${dir##*/}"

        # Skip known non-skill directories
        case "$basename" in
            .git|.beads|lib|scripts|docs|.gitignore)
                continue
                ;;
        esac

        # Check if directory has skill markers
        if [[ -f "$dir/SKILL.md" ]] || [[ -f "$dir/README.md" ]] || [[ -f "$dir/skill.sh" ]]; then
            echo "$basename"
        fi
    done
}

# Install a single skill
install_skill() {
    local skill_name="$1"
    local src_dir="$SCRIPT_DIR/$skill_name"
    local dest_dir="$TARGET_DIR/$skill_name"

    # Validate source directory exists
    if [[ ! -d "$src_dir" ]]; then
        echo -e "${RED}Error: Skill '$skill_name' not found in repository${NC}"
        return 1
    fi

    # Check if already installed
    if [[ -d "$dest_dir" ]]; then
        echo -e "${YELLOW}⚠ $skill_name: already installed, overwriting...${NC}"
        rm -rf "$dest_dir"
    else
        echo -e "${GREEN}✓ Installing $skill_name...${NC}"
    fi

    # Copy skill directory
    cp -r "$src_dir" "$dest_dir"

    # Inline lib/common.sh into scripts that source it
    inline_lib_common "$dest_dir"

    echo -e "${GREEN}  → Installed to $dest_dir${NC}"

    # usage-statusline additionally deploys its runtime copy outside the
    # skills directory and wires it into settings.json
    if [[ "$skill_name" == "usage-statusline" ]]; then
        install_statusline
    fi
}

# Deploy usage-statusline's out-of-tree runtime copy and wire it into settings.json.
# usage-statusline is the one skill whose runtime artifact lives outside
# ~/.claude/skills/: scripts/usage-statusline.sh is copied to
# ~/.claude/usage-statusline.sh and referenced as the statusLine command in
# ~/.claude/settings.json (usage-statusline/SKILL.md steps 2-3).
#
# Idempotent: an identical deployed copy and an already-correct statusLine are
# left as-is. Non-destructive: settings.json is merged with jq so unrelated
# keys survive, and a statusLine that runs something else is never displaced.
install_statusline() {
    local src="$SCRIPT_DIR/usage-statusline/scripts/usage-statusline.sh"
    local dest="$HOME/.claude/usage-statusline.sh"
    local settings="$HOME/.claude/settings.json"

    if [[ ! -f "$src" ]]; then
        echo -e "${YELLOW}⚠ usage-statusline: $src not found, skipping out-of-tree deploy${NC}"
        return 0
    fi

    # 1. Deploy the script itself
    if [[ -f "$dest" ]] && ! cmp -s "$src" "$dest"; then
        echo -e "${YELLOW}⚠ usage-statusline.sh: already installed and differs from repo, overwriting...${NC}"
        echo -e "${YELLOW}  (run scripts/check-installed.sh usage-statusline first to see what changes)${NC}"
    fi
    # The installer usually runs inside `if ! install_skill ...`, where set -e
    # is suspended for the whole call chain — a failed copy must return, not
    # fall through to wiring statusLine at a path that was never written.
    if ! cp "$src" "$dest"; then
        echo -e "${RED}Error: failed to deploy $dest${NC}"
        return 1
    fi
    chmod +x "$dest"
    echo -e "${GREEN}✓ Deployed $dest${NC}"

    # 2. Wire the statusLine command into settings.json
    local cmd="/bin/bash $dest"

    if ! command -v jq >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠ jq not found — could not update $settings automatically${NC}"
        echo "  Merge this block into it manually:"
        printf '    {"statusLine": {"type": "command", "command": "%s", "padding": 0}}\n' "$cmd"
        return 0
    fi

    if [[ ! -f "$settings" ]]; then
        jq -n --arg cmd "$cmd" '{statusLine: {type: "command", command: $cmd, padding: 0}}' > "$settings"
        chmod 600 "$settings"
        echo -e "${GREEN}✓ Created $settings with statusLine wired (takes effect in new sessions)${NC}"
        return 0
    fi

    if ! jq -e . "$settings" >/dev/null 2>&1; then
        echo -e "${RED}Error: $settings is not valid JSON — leaving it untouched${NC}"
        echo "  Fix it, then re-run this installer to wire the statusLine."
        return 1
    fi

    if jq -e 'has("statusLine") and (.statusLine != null)' "$settings" >/dev/null; then
        local existing
        existing=$(jq -r '.statusLine.command // ""' "$settings")
        if [[ "$existing" == *usage-statusline.sh* ]]; then
            echo -e "${GREEN}✓ statusLine already wired in $settings (takes effect in new sessions)${NC}"
        else
            echo -e "${YELLOW}⚠ $settings already has a statusLine running something else — leaving it untouched${NC}"
            echo "  current command: $existing"
            echo "  To use this statusline instead, change statusLine.command to:"
            echo "    $cmd"
        fi
        return 0
    fi

    # Merge the statusLine block in alongside the existing keys. Write to a
    # temp file in the same directory and preserve the original mode, so an
    # interrupted write can't leave a truncated settings.json behind.
    local tmp mode
    tmp=$(mktemp "${settings}.XXXXXX")
    if ! jq --arg cmd "$cmd" '.statusLine = {type: "command", command: $cmd, padding: 0}' "$settings" > "$tmp"; then
        rm -f "$tmp"
        echo -e "${RED}Error: failed to merge statusLine into $settings${NC}"
        return 1
    fi
    mode=$(stat -c '%a' "$settings")
    chmod "$mode" "$tmp"
    mv -f "$tmp" "$settings"
    echo -e "${GREEN}✓ Wired statusLine into $settings (takes effect in new sessions)${NC}"
}

# Inline lib/common.sh into scripts that source it
# This makes installed scripts self-contained (no dependency on ../../lib/)
inline_lib_common() {
    local skill_dir="$1"
    local lib_common="$SCRIPT_DIR/lib/common.sh"

    # Check if lib/common.sh exists
    if [[ ! -f "$lib_common" ]]; then
        return 0
    fi

    # Find all .sh files in the skill directory
    while IFS= read -r script; do
        # Check if script sources ../../lib/common.sh
        if grep -qF '../../lib/common.sh' "$script"; then
            # Create a temporary file
            local tmp_file
            tmp_file=$(mktemp)

            # Copy script up to (but not including) the source line
            awk '/source.*..\/..\/lib\/common\.sh/{exit} 1' "$script" > "$tmp_file"

            # Add a marker comment
            echo '# --- Inlined from lib/common.sh during install ---' >> "$tmp_file"

            # Append lib/common.sh content (skip shebang, blank lines, and comments at start)
            # Keep everything from 'set -euo pipefail' to the end
            awk 'f; /^set -euo pipefail/{f=1}' "$lib_common" >> "$tmp_file"

            # Append the rest of the script after the source line
            awk 'f; /source.*..\/..\/lib\/common\.sh/{f=1; next}' "$script" >> "$tmp_file"

            # Replace original script with inlined version
            mv "$tmp_file" "$script"
        fi
    done < <(find "$skill_dir" -type f -name "*.sh")
}

# Show usage
show_usage() {
    cat <<EOF
Usage: $0 [OPTION] | [skill-name] [skill-name...]

Selective installer for jeds-curated-skills. Copies skills to ~/.claude/skills/
without touching other directories already present.

usage-statusline installs differently from the rest: in addition to the skill
directory, its runtime script is deployed to ~/.claude/usage-statusline.sh and
wired as the statusLine command in ~/.claude/settings.json. Both steps are
idempotent, and existing settings.json keys are never overwritten.

Options:
  --all              Install every skill from this repository
  --list, -l         List all available skills
  --help, -h         Show this help message

Arguments:
  skill-name         One or more skill names to install (see --list)

Examples:
  $0 plan-review                    # Install plan-review only
  $0 plan-review repo-hygiene       # Install multiple skills
  $0 --all                          # Install everything
  $0 --list                         # See what's available

EOF
}

# Main logic
main() {
    # Ensure target directory exists
    mkdir -p "$TARGET_DIR"

    # Parse arguments
    if [[ $# -eq 0 ]]; then
        show_usage
        list_available_skills
        exit 0
    fi

    case "$1" in
        --help|-h)
            show_usage
            exit 0
            ;;
        --list|-l)
            echo "Available skills:"
            list_available_skills | while read -r skill; do
                echo "  - $skill"
            done
            exit 0
            ;;
        --all)
            echo "Installing all skills from jeds-curated-skills..."
            echo ""
            local failed=0
            while IFS= read -r skill; do
                if ! install_skill "$skill"; then
                    failed=1
                fi
            done < <(list_available_skills)

            echo ""
            if [[ $failed -eq 0 ]]; then
                echo -e "${GREEN}✓ All skills installed successfully${NC}"
            else
                echo -e "${RED}✗ Some skills failed to install${NC}"
                exit 1
            fi
            ;;
        *)
            # Install specific skills
            local failed=0
            for skill in "$@"; do
                if ! install_skill "$skill"; then
                    failed=1
                fi
            done

            echo ""
            if [[ $failed -eq 0 ]]; then
                echo -e "${GREEN}✓ Installation complete${NC}"
            else
                echo -e "${RED}✗ Some skills failed to install${NC}"
                exit 1
            fi
            ;;
    esac
}

main "$@"
