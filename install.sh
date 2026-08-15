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
    echo -e "${GREEN}  → Installed to $dest_dir${NC}"
}

# Show usage
show_usage() {
    cat <<EOF
Usage: $0 [OPTION] | [skill-name] [skill-name...]

Selective installer for jeds-curated-skills. Copies skills to ~/.claude/skills/
without touching other directories already present.

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
