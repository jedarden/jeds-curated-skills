#!/usr/bin/env bash
# Quick automated scoring of a README against the core rubric, plus project-type detection.
# Usage: score-readme.sh <readme-file>
# Returns: detected project type, score percentage, section inventory, and missing items.

set -euo pipefail

FILE="${1:-}"
if [[ -z "$FILE" || ! -f "$FILE" ]]; then
  echo "Usage: score-readme.sh <readme-file>" >&2
  exit 1
fi

DIR="$(cd "$(dirname "$FILE")" && pwd)"

# --- Project type detection (heuristic from sibling files) ---
TYPE="unknown"
signals=()
[[ -f "$DIR/Dockerfile" || -f "$DIR/docker-compose.yml" || -f "$DIR/compose.yaml" ]] && signals+=("docker")
[[ -f "$DIR/package.json" ]] && signals+=("package.json")
[[ -f "$DIR/Cargo.toml" ]] && signals+=("Cargo.toml")
[[ -f "$DIR/pyproject.toml" || -f "$DIR/setup.py" ]] && signals+=("python")
[[ -f "$DIR/go.mod" ]] && signals+=("go.mod")
[[ -d "$DIR/bin" || -d "$DIR/cmd" ]] && signals+=("bin/cmd")

# bin entry in package.json or [[bin]] in Cargo.toml => CLI
has_bin=0
if [[ -f "$DIR/package.json" ]] && grep -qE '"bin"[[:space:]]*:' "$DIR/package.json" 2>/dev/null; then has_bin=1; fi
if [[ -f "$DIR/Cargo.toml" ]] && grep -qE '^\[\[bin\]\]' "$DIR/Cargo.toml" 2>/dev/null; then has_bin=1; fi
[[ -d "$DIR/cmd" ]] && has_bin=1

if [[ " ${signals[*]:-} " == *" docker "* ]]; then
  TYPE="service (Dockerfile/compose present — confirm)"
elif [[ $has_bin -eq 1 ]]; then
  TYPE="CLI (bin entry detected — confirm)"
elif [[ " ${signals[*]:-} " == *" package.json "* || " ${signals[*]:-} " == *" Cargo.toml "* || " ${signals[*]:-} " == *" python "* || " ${signals[*]:-} " == *" go.mod "* ]]; then
  TYPE="library (package manifest, no bin — confirm)"
fi

# --- Rubric heuristics ---
PASS=0
FAIL=0
FAILURES=()

check() {
  local label="$1"; shift
  local matched=0
  for pattern in "$@"; do
    if grep -qiE -e "$pattern" "$FILE" 2>/dev/null; then
      matched=1; break
    fi
  done
  if [[ $matched -eq 1 ]]; then
    ((PASS++)) || true
  else
    ((FAIL++)) || true
    FAILURES+=("MISSING: $label")
  fi
}

# A sibling file check (license/contributing/changelog often live as files)
file_check() {
  local label="$1"; shift
  local matched=0
  for f in "$@"; do
    if [[ -e "$DIR/$f" ]]; then matched=1; break; fi
  done
  if [[ $matched -eq 1 ]]; then
    ((PASS++)) || true
  else
    ((FAIL++)) || true
    FAILURES+=("MISSING: $label")
  fi
}

# 01 Orientation
check "1.4 Working example / screenshot above the fold" '```' '!\[' '<img' 'screenshot'
check "1.5 Status / maturity signal"        "!\[.*\]\(.*badge" "shields\.io" "status:" "alpha|beta|stable|experimental|wip"

# 02 Getting Started
check "2.1 Prerequisites"                    "prerequisite" "requirement" "you.ll need" "before you begin" "depends on"
check "2.2 Install instructions"             "## *install" "installation" "npm i(nstall)?" "pip install" "cargo (add|install)" "go install" "docker (run|pull)" "brew install"
check "2.3 Quickstart / usage"               "quick.?start" "getting started" "## *usage" "## *example"
check "2.7 Verification / first success"     "--version" "--help" "verify" "you should see" "expected output" "health"

# 03 Reference
check "3.1 Configuration / options"          "## *config" "configuration" "options" "settings" "flags"
check "3.3 API / CLI reference"              "## *api" "reference" "subcommand" "endpoints" "## *commands"
check "3.4 Environment variables"            "environment variable" "env var" "\bENV\b" "[A-Z_]{3,}=" "process\.env|std::env|os\.environ"

# 04 Maintenance
check "4.1 License (in README)"              "## *license" "licen[sc]e" "MIT|Apache|GPL|BSD|MPL|ISC"
file_check "4.1b LICENSE file"               "LICENSE" "LICENSE.md" "LICENSE.txt" "COPYING"
file_check "4.2 CONTRIBUTING"                "CONTRIBUTING.md" "CONTRIBUTING" ".github/CONTRIBUTING.md"
check "4.3 Troubleshooting / FAQ"            "troubleshoot" "\bFAQ\b" "common (issues|problems|errors)" "known issues"
file_check "4.6 Changelog"                   "CHANGELOG.md" "CHANGELOG" "CHANGES.md" "HISTORY.md"

# 4.7 is handled by an explicit placeholder scan below (grep -E can't do negative lookahead).
PLACEHOLDERS="$(grep -niE 'TODO|TBD|lorem ipsum|coming soon|example\.com|placeholder' "$FILE" 2>/dev/null || true)"

# --- Section inventory + word count ---
WORDS="$(wc -w < "$FILE" | tr -d ' ')"
SECTIONS="$(grep -cE '^#{1,3} ' "$FILE" 2>/dev/null || echo 0)"

# --- Tally ---
TOTAL=$((PASS + FAIL))
PCT=0
[[ $TOTAL -gt 0 ]] && PCT=$(( PASS * 100 / TOTAL ))

echo "=== README Score: $FILE ==="
echo ""
echo "Detected project type: $TYPE"
echo "Repo signals: ${signals[*]:-none}"
echo ""
echo "Word count: $WORDS"
echo "Top-level/section headings: $SECTIONS"
echo ""
echo "Heuristic score: $PASS / $TOTAL ($PCT%)"
echo ""

if [[ $PCT -ge 75 ]]; then
  echo "Status: STRONG (run the full review to catch depth/type gaps)"
elif [[ $PCT -ge 45 ]]; then
  echo "Status: NEEDS WORK (notable sections missing)"
else
  echo "Status: WEAK (fundamental sections absent — consider drafting from scratch)"
fi

echo ""
echo "--- Section inventory ---"
grep -nE '^#{1,3} ' "$FILE" 2>/dev/null || echo "  (no markdown headings found)"

echo ""
if [[ ${#FAILURES[@]} -gt 0 ]]; then
  echo "--- Missing (heuristic) ---"
  for f in "${FAILURES[@]}"; do
    echo "  $f"
  done
fi

echo ""
if [[ -n "$PLACEHOLDERS" ]]; then
  echo "--- Placeholder / TODO links found (item 4.7) ---"
  echo "$PLACEHOLDERS" | sed 's/^/  /'
else
  echo "Placeholder scan (4.7): clean"
fi

echo ""
echo "NOTE: heuristics only — grep cannot judge whether the quickstart actually runs."
echo "Always run the full review (subagent) for the zero-to-running verdict."
