#!/usr/bin/env bash
#
# check-installed.sh - Detect drift between installed skills and repo copies
#
# Skills are installed by copying into ~/.claude/skills/ (normally via
# install.sh) with no update or drift-detection mechanism. This script diffs
# installed copies against the repo to find silent divergence.
#
# usage-statusline additionally deploys a runtime copy OUT of the skills dir:
# ~/.claude/usage-statusline.sh, wired as the statusLine command in
# ~/.claude/settings.json. The per-skill directory diff can't see that file,
# so it is diffed separately — whenever usage-statusline is checked, and on
# any run where a deployed copy exists (a machine can have the deployment
# without the skills-dir install, which the sweep cannot intersect). That
# deployed copy is where drift was first found live (a hardcoded /home/coding
# path) — the incident that motivated ADR-1.
#
# A skill installed by a bare cp -r (rather than install.sh) can pass the
# directory diff while its scripts are broken: in the repo they source
# ../../lib/common.sh, which resolves outside the copied directory. That
# unresolvable-lib state is flagged as drift too, so the remedy below runs.
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
DIR_DRIFT_FLAGGED="" # usage-statusline already counted via its skills-dir diff

# Check that the installed skills directory exists
if [[ ! -d ~/.claude/skills/ ]]; then
  echo -e "${RED}Error: ~/.claude/skills/ directory not found${NC}"
  echo "Skills may not be installed on this system."
  exit 2
fi

# Determine which skills to check
if [[ $# -eq 0 ]]; then
  # No arguments: check all skills present in both repo and install dir
  mapfile -t SKILLS_TO_CHECK < <(comm -12 <(find . -maxdepth 2 -name SKILL.md -printf '%h\n' | sed 's|^\./||' | sort -u) <(ls -1 ~/.claude/skills/ | sort))
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
  # Ignore: .beads/ (repo tracking), .git/ (if present), .claude/ (local config)
  # Also ignore lib/common.sh inlining differences in scripts
  drift_output=$(diff -r --brief "$repo_dir" "$installed_dir" 2>/dev/null || true)

  # Filter out expected differences from lib/common.sh inlining
  if [[ -n "$drift_output" ]]; then
    filtered_output=""
    while IFS= read -r line; do
      # Parse diff output to get file paths
      if [[ "$line" =~ Files\ (.+)\ and\ (.+)\ differ ]]; then
        repo_file="${BASH_REMATCH[1]}"
        installed_file="${BASH_REMATCH[2]}"

        # Check if this is a script that sources lib/common.sh in the repo
        if grep -qF '../../lib/common.sh' "$repo_file" 2>/dev/null; then
          # Check if the installed version has the inlining marker
          if grep -qF 'Inlined from lib/common.sh during install' "$installed_file" 2>/dev/null; then
            # This is expected inlining - skip this difference
            continue
          fi
        fi
      fi
      filtered_output="$filtered_output$line"$'\n'
    done <<< "$drift_output"
    drift_output="${filtered_output%$'\n'}"
  fi

  # A bare cp -r of a skill directory copies the repo's raw
  # `source ../../lib/common.sh` verbatim. That path resolves to
  # ~/.claude/skills/lib/common.sh — a file a per-skill install never has
  # (install.sh inlines the lib instead; only a full repo clone into
  # ~/.claude/skills supplies it). The copy is byte-identical to the repo,
  # so the diff above sees nothing; detect the unresolvable path explicitly.
  broken_lib=""
  if ! [[ -f ~/.claude/skills/lib/common.sh ]] \
     && grep -rlF '../../lib/common.sh' "$installed_dir" --include='*.sh' >/dev/null 2>&1; then
    broken_lib=1
  fi

  if [[ -n "$drift_output" || -n "$broken_lib" ]]; then
    DRIFT_FOUND=1
    SKILLS_WITH_DRIFT=$((SKILLS_WITH_DRIFT + 1))
    if [[ "$skill" == "usage-statusline" ]]; then
      DIR_DRIFT_FLAGGED=1
    fi
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
    if [[ -n "$broken_lib" ]]; then
      echo -e "    ${YELLOW}Broken lib path:${NC} installed scripts source ../../lib/common.sh,"
      echo -e "    which resolves to missing ~/.claude/skills/lib/common.sh"
    fi
  else
    echo -e "${GREEN}  ✓ No drift${NC}"
  fi
done

# usage-statusline's out-of-tree runtime copy. Checked whenever usage-statusline
# is in scope (named explicitly, or picked up by the repo∩install-dir sweep),
# and also whenever a deployed copy exists — the sweep intersects repo skills
# with ~/.claude/skills/, so on a machine that has the deployed script and
# wiring but no ~/.claude/skills/usage-statusline/ (this machine, for one) the
# sweep alone would never scope it in, and exactly there is where live drift
# was found: the hardcoded /home/coding path that motivated ADR-1.
statusline_in_scope=0
if [[ " ${SKILLS_TO_CHECK[*]} " == *" usage-statusline "* ]]; then
  statusline_in_scope=1
fi
if [[ "$statusline_in_scope" -eq 0 ]] && [[ -f "$HOME/.claude/usage-statusline.sh" ]]; then
  statusline_in_scope=1
  # Nothing above counted this skill (it is not in the install dir for the
  # sweep to intersect), so this check is its only coverage — count it, or the
  # summary below would report drift inside "Checked 0 skill(s)".
  SKILLS_CHECKED=$((SKILLS_CHECKED + 1))
fi
if [[ "$statusline_in_scope" -eq 1 ]]; then
  echo "Checking usage-statusline (out-of-tree copy)..."
  repo_sl="$PWD/usage-statusline/scripts/usage-statusline.sh"
  deployed="$HOME/.claude/usage-statusline.sh"

  if [[ ! -f "$repo_sl" ]]; then
    echo -e "${YELLOW}  Warning: $repo_sl not found in repo${NC}"
  elif [[ ! -f "$deployed" ]]; then
    echo -e "${YELLOW}  Note: $deployed not deployed (statusline script not installed out-of-tree)${NC}"
  elif ! cmp -s "$repo_sl" "$deployed"; then
    DRIFT_FOUND=1
    # Don't double-count the skill when its skills-dir diff already flagged it
    if [[ -z "$DIR_DRIFT_FLAGGED" ]]; then
      SKILLS_WITH_DRIFT=$((SKILLS_WITH_DRIFT + 1))
    fi
    echo -e "${RED}  ✗ Drift detected${NC}"
    echo -e "    ${YELLOW}Modified:${NC} $deployed differs from usage-statusline/scripts/usage-statusline.sh"
  else
    echo -e "${GREEN}  ✓ No drift${NC}"
  fi
fi

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
  echo "To fix drift, re-install the affected skill(s) with the installer:"
  echo "  ./install.sh <skill>"
  echo "A bare cp -r is not enough: install.sh inlines the shared lib/common.sh"
  echo "into the scripts that source it, and for usage-statusline it also"
  echo "redeploys the out-of-tree ~/.claude/usage-statusline.sh copy."
  exit 1
fi
