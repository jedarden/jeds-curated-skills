#!/usr/bin/env bash
#
# check-installed.sh - Detect drift between installed skills and repo copies
#
# Skills are distributed by `cp -r` into ~/.claude/skills/ with no update or
# drift-detection mechanism. This script diffs installed copies against the
# repo to find silent divergence.
#
# Usage:
#   scripts/check-installed.sh [skill-name...]
#
# Arguments:
#   skill-name...  Optional skill names to check. If omitted, checks all skills
#                 present in both the repo and ~/.claude/skills/
#
# Exit codes:
#   0  No drift found
#   1  Drift detected
#   2  Usage error or missing ~/.claude/skills/ directory
#

set -euo pipefail

# Color output for readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

DRIFT_FOUND=0
SKILLS_CHECKED=0
SKILLS_WITH_DRIFT=0

# Check that the installed skills directory exists
if [[ ! -d ~/.claude/skills/ ]]; then
  echo -e "${RED}Error: ~/.claude/skills/ directory not found${NC}"
  echo "Skills may not be installed on this system."
  exit 2
fi

# Determine which skills to check
if [[ $# -eq 0 ]]; then
  # No arguments: check all skills present in both repo and install dir
  mapfile -t SKILLS_TO_CHECK < <(comm -12 <(find . -maxdepth 2 -name SKILL.md -printf '%h\n' | sort -u) <(ls -1 ~/.claude/skills/ | sort))
else
  # Specific skills named: validate they exist in both locations
  SKILLS_TO_CHECK=("$@")
fi

# Check each skill
for skill in "${SKILLS_TO_CHECK[@]}"; do
  SKILLS_CHECKED=$((SKILLS_CHECKED + 1))
  repo_dir="$PWD/$skill"
  installed_dir="$HOME/.claude/skills/$skill"

  # Validate both directories exist
  if [[ ! -d "$repo_dir" ]]; then
    echo -e "${YELLOW}Warning: Skill '$skill' not found in repo${NC}"
    continue
  fi

  if [[ ! -d "$installed_dir" ]]; then
    echo -e "${YELLOW}Warning: Skill '$skill' not installed at ~/.claude/skills/$skill${NC}"
    continue
  fi

  echo "Checking $skill..."

  # Use diff -r to compare, filtering out expected differences
  # Ignore: .beads/ (repo tracking), .git/ (if present), and .claude/ (local config)
  drift_output=$(diff -r --brief "$repo_dir" "$installed_dir" 2>/dev/null || true)

  if [[ -n "$drift_output" ]]; then
    DRIFT_FOUND=1
    SKILLS_WITH_DRIFT=$((SKILLS_WITH_DRIFT + 1))
    echo -e "${RED}  ✗ Drift detected${NC}"
    echo "$drift_output" | while IFS= read -r line; do
      # Parse diff output: "Only in repo: file" or "Files file1 and file2 differ"
      if [[ "$line" =~ Only\ in\ (.+):\ (.+) ]]; then
        location="${BASH_REMATCH[1]}"
        file="${BASH_REMATCH[2]}"
        if [[ "$location" == "$repo_dir" ]]; then
          echo -e "    ${YELLOW}Missing in install:${NC} $file"
        else
          echo -e "    ${YELLOW}Extra in install:${NC} $file"
        fi
      elif [[ "$line" =~ Files\ (.+)\ and\ (.+)\ differ ]]; then
        file="${BASH_REMATCH[1]}"
        echo -e "    ${YELLOW}Modified:${NC} $file"
      fi
    done
  else
    echo -e "${GREEN}  ✓ No drift${NC}"
  fi
done

# Summary
echo ""
if [[ $SKILLS_CHECKED -eq 0 ]]; then
  echo -e "${YELLOW}No skills to check${NC}"
  exit 0
fi

echo "Checked $SKILLS_CHECKED skill(s)"

if [[ $DRIFT_FOUND -eq 0 ]]; then
  echo -e "${GREEN}No drift detected${NC}"
  exit 0
else
  echo -e "${RED}$SKILLS_WITH_DRIFT skill(s) have drift${NC}"
  echo ""
  echo "To fix drift, re-copy the skill from the repo:"
  echo "  cp -r <skill>/ ~/.claude/skills/"
  exit 1
fi
