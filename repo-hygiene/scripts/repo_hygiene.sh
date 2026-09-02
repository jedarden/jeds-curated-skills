#!/usr/bin/env bash
# repo_hygiene.sh — detect-and-REPORT repository hygiene audit.
#
# REPORT ONLY: this script never modifies the repository (it even runs git
# with --no-optional-locks so it will not touch the index). It is the
# harness-agnostic core of the repo-hygiene skill — any agent harness
# (claude-code, opencode, codex, aider, ...) can invoke it directly.
#
# Usage: repo_hygiene.sh [--json] [--file-beads] [repo-path]
#   repo-path defaults to the current directory.
#   --file-beads: file beads for findings via the repo's bead CLI (determined
#                 from .needle.yaml). Uses --unique-ref for deduplication so
#                 re-runs don't create duplicate beads.
#
# Checks:
#   - tracked build artifacts (target/, node_modules/, dist/, build/,
#     __pycache__/, *.pyc, .DS_Store)
#   - tracked files larger than 5 MB (index blob sizes)
#   - dead CI: tracked .github/workflows/*.yml|yaml (GH Actions are
#     disabled estate-wide; CI is Argo Workflows)
#   - README drift: version-looking badge strings vs the latest git tag,
#     and GitHub Actions badge URLs (dead by policy)
#   - working tree: dirty-file count and stash count
#   - .gitignore coverage vs detected language markers
#   - suspicious tracked files (.env, *.pem, *.key, id_rsa*) — flagged
#     for human review only; contents are never read
#   - ad hoc root-level test scripts (test_*.sh, test_*.py, test_*.rs) and
#     stray compiled binaries (ELF, by magic bytes) tracked directly in the
#     repo root — legit tests live under tests/; root-level scratch is debt
#
# Output: human-readable report, or --json:
#   {"repo": "...", "findings": [{"category","severity","count","examples":[]}], "clean": bool}
#
# Exit codes: 0 = clean, 1 = findings, 2 = usage error / not a git repo.
# Dependencies: git, coreutils, awk (no jq — JSON is hand-emitted).

set -euo pipefail

MAX_EXAMPLES=10
LARGE_FILE_BYTES=$((5 * 1024 * 1024))
FILE_BEADS=0
BEAD_CLI=""
BEAD_STORE_EXISTS=0

usage() {
  echo "Usage: repo_hygiene.sh [--json] [--file-beads] [repo-path]"
  echo "  Report-only repository hygiene audit (default repo-path: .)"
  echo "  Exit: 0 clean, 1 findings, 2 usage/not-a-repo"
}

# --- Argument parsing -------------------------------------------------------

JSON=0
FILE_BEADS=0
REPO="."
seen_path=0
for arg in "$@"; do
  case "$arg" in
    --json) JSON=1 ;;
    --file-beads) FILE_BEADS=1 ;;
    -h|--help) usage; exit 0 ;;
    -*)
      echo "error: unknown option: $arg" >&2
      usage >&2
      exit 2
      ;;
    *)
      if [[ $seen_path -eq 1 ]]; then
        echo "error: multiple repo paths given" >&2
        usage >&2
        exit 2
      fi
      REPO="$arg"
      seen_path=1
      ;;
  esac
done

if [[ ! -d "$REPO" ]]; then
  echo "error: not a directory: $REPO" >&2
  exit 2
fi

if [[ "$(git -C "$REPO" rev-parse --is-inside-work-tree 2>/dev/null || true)" != "true" ]]; then
  echo "error: not inside a git work tree: $REPO" >&2
  exit 2
fi

ROOT=$(git -C "$REPO" rev-parse --show-toplevel)

# All git access goes through this wrapper: --no-optional-locks keeps even
# `git status` from writing to .git (safe on repos we must not touch).
g() { git --no-optional-locks -C "$ROOT" "$@"; }

WORK=$(mktemp -d "${TMPDIR:-/tmp}/repo-hygiene.XXXXXX")
trap 'rm -rf "$WORK"' EXIT

# --- Findings accumulator ---------------------------------------------------

F_CAT=()
F_SEV=()
F_COUNT=()
F_EX=()   # newline-joined example strings, capped at MAX_EXAMPLES

add_finding() { # category severity count examples-newline-joined
  F_CAT+=("$1")
  F_SEV+=("$2")
  F_COUNT+=("$3")
  F_EX+=("$4")
}

count_lines() { # file -> plain integer (portable across wc paddings)
  local n
  n=$(wc -l < "$1")
  echo $((n))
}

# --- Bead filing functions -----------------------------------------------

detect_bead_backend() { # -> prints "bead-rs", "bf", or "none"
  if [[ ! -f "$ROOT/.needle.yaml" ]]; then
    echo "none"
    return
  fi

  # Extract the backend value from .needle.yaml
  local backend
  backend=$(grep -E '^\s+backend:\s*\S+' "$ROOT/.needle.yaml" | awk '{print $2}' || true)

  case "$backend" in
    bead-rs) echo "bead-rs" ;;
    bf) echo "bf" ;;
    *) echo "none" ;;
  esac
}

has_bead_store() { # -> 0 if store exists, 1 otherwise
  [[ -d "$ROOT/.beads" ]]
}

generate_hash() { # category, example -> md5 hash for unique ref
  local category="$1"
  local example="$2"
  printf '%s:%s' "$category" "$example" | md5sum | awk '{print $1}'
}

file_bead() { # category, example, severity
  local category="$1"
  local example="$2"
  local severity="$3"

  local backend
  backend=$(detect_bead_backend)

  if [[ "$backend" == "none" ]] || ! has_bead_store; then
    return 1
  fi

  # Generate a short description from the example (first ~60 chars)
  local short_desc
  short_desc=$(printf '%s' "$example" | head -c 60)

  # Generate hash for deduplication
  local hash
  hash=$(generate_hash "$category" "$short_desc")

  # Build the unique ref
  local unique_ref="hygiene:${category}:${hash}"

  # Build the title
  local title
  title="hygiene: ${category}: ${short_desc}"

  # Build the description
  local description
  description="Hygiene finding: ${category}

Severity: ${severity}
Example: ${example}

Filed by repo-hygiene after fix pass."

  # Determine which CLI to use
  local bead_cli
  if [[ "$backend" == "bead-rs" ]]; then
    if command -v bead >/dev/null 2>&1; then
      bead_cli="bead"
    else
      echo "Warning: bead-rs backend configured but 'bead' CLI not found" >&2
      return 1
    fi
  elif [[ "$backend" == "bf" ]]; then
    if command -v bf >/dev/null 2>&1; then
      bead_cli="bf"
    else
      echo "Warning: bf backend configured but 'bf' CLI not found" >&2
      return 1
    fi
  else
    return 1
  fi

  # File the bead with deduplication (must run from the target repo directory).
  # `|| rc=$?` keeps a CLI failure from tripping set -e and aborting the whole
  # audit after the report has already been produced.
  local result rc=0
  result=$(cd "$ROOT" && $bead_cli create --title "$title" \
                         --description "$description" \
                         --priority 3 \
                         --label hygiene \
                         --unique-ref "$unique_ref" 2>&1) || rc=$?

  if [[ $rc -ne 0 ]]; then
    echo "  [error] $title — bead create failed: $result" >&2
    return 1
  fi

  # Check if it was a new bead or an existing one. Status goes to stderr —
  # file_beads_for_findings runs under a command substitution, so stdout here
  # would pollute the captured count. EXISTING_CLOSED must be tested first:
  # it contains the substring EXISTING, so the reverse order would never
  # reach the closed branch.
  #
  # Return codes: 0 = created, 2 = already tracked (existing or closed),
  # 1 = skipped / failed.
  if [[ "$result" =~ EXISTING_CLOSED ]]; then
    echo "  [closed] $title (already resolved)" >&2
    return 2
  elif [[ "$result" =~ EXISTING ]]; then
    echo "  [existing] $title" >&2
    return 2
  fi

  # It's a new bead - extract the ID
  local bead_id
  bead_id=$(printf '%s' "$result" | grep -E '^[a-z0-9-]+$' || echo "$result")
  echo "  [created] $title ($bead_id)" >&2
  return 0
}

file_beads_for_findings() { # -> prints "<created> <already-tracked>" on stdout
  local created=0 existing=0
  local i line

  for ((i = 0; i < TOTAL; i++)); do
    local category="${F_CAT[$i]}"
    local severity="${F_SEV[$i]}"
    local count="${F_COUNT[$i]}"

    echo "Filing beads for category: $category ($count finding(s))" >&2

    # File a bead for each example (up to MAX_EXAMPLES)
    local examples_shown=0
    while IFS= read -r line && [[ $examples_shown -lt $MAX_EXAMPLES ]]; do
      [[ -z "$line" ]] && continue
      if file_bead "$category" "$line" "$severity"; then
        created=$((created + 1))
      elif [[ $? -eq 2 ]]; then
        existing=$((existing + 1))
      fi
      examples_shown=$((examples_shown + 1))
    done <<< "${F_EX[$i]}"

    # If there are more findings than examples, file one bead for the remainder
    if [[ $count -gt $MAX_EXAMPLES ]]; then
      local remainder_msg="$count total findings (see full report for details)"
      if file_bead "$category" "$remainder_msg" "$severity"; then
        created=$((created + 1))
      elif [[ $? -eq 2 ]]; then
        existing=$((existing + 1))
      fi
    fi
  done

  echo "$created $existing"
}

# --- Gather tracked file list once ------------------------------------------

# -z + tr gives raw (unquoted) paths so pattern matches are not defeated by
# git's C-style quoting of special characters. Paths containing a literal
# newline (pathological) will split; acceptable for a report-only heuristic.
g ls-files -z | tr '\0' '\n' > "$WORK/tracked"

# --- Check 1: tracked build artifacts ----------------------------------------

awk '
  /(^|\/)target\//       ||
  /(^|\/)node_modules\// ||
  /(^|\/)dist\//         ||
  /(^|\/)build\//        ||
  /(^|\/)__pycache__(\/|$)/ ||
  /\.pyc$/               ||
  /(^|\/)\.DS_Store$/
' "$WORK/tracked" > "$WORK/artifacts"

n=$(count_lines "$WORK/artifacts")
if [[ $n -gt 0 ]]; then
  add_finding "tracked-build-artifacts" "high" "$n" \
    "$(head -n "$MAX_EXAMPLES" "$WORK/artifacts")"
fi

# --- Check 2: tracked files > 5 MB (index blob sizes, batched) ---------------

# "sha<TAB>path" for regular-file index entries only (skip symlinks/gitlinks)
g ls-files -s -z | tr '\0' '\n' | awk -F'\t' '
  { n = split($1, m, " "); if (n >= 3 && m[1] ~ /^100/) print m[2] "\t" $2 }
' > "$WORK/index"

: > "$WORK/large"
if [[ -s "$WORK/index" ]]; then
  cut -f1 "$WORK/index" | g cat-file --batch-check='%(objectsize)' \
    > "$WORK/sizes" 2>/dev/null || true
  # paste => "size<TAB>sha<TAB>path"; missing objects yield non-numeric $1
  paste "$WORK/sizes" "$WORK/index" \
    | awk -F'\t' -v max="$LARGE_FILE_BYTES" \
        '$1 ~ /^[0-9]+$/ && $1 + 0 > max { print $1 "\t" $3 }' \
    | sort -rn \
    | awk -F'\t' '{ printf "%s (%.1f MB)\n", $2, $1 / 1048576 }' \
    > "$WORK/large"
fi

n=$(count_lines "$WORK/large")
if [[ $n -gt 0 ]]; then
  add_finding "large-tracked-files" "high" "$n" \
    "$(head -n "$MAX_EXAMPLES" "$WORK/large")"
fi

# --- Check 3: dead CI — tracked GitHub Actions workflows ---------------------

awk '/^\.github\/workflows\/[^\/]+\.(yml|yaml)$/' "$WORK/tracked" > "$WORK/workflows"

n=$(count_lines "$WORK/workflows")
if [[ $n -gt 0 ]]; then
  add_finding "dead-ci-workflows" "medium" "$n" \
    "$(head -n "$MAX_EXAMPLES" "$WORK/workflows")"
fi

# --- Check 4: README drift ---------------------------------------------------

README=""
for cand in README.md README.MD Readme.md readme.md README.markdown README; do
  if [[ -f "$ROOT/$cand" ]]; then README="$cand"; break; fi
done

if [[ -n "$README" ]]; then
  # 4a. GitHub Actions badge URLs — dead by policy regardless of tag state
  grep -nE 'github\.com/[^") ]+/actions(/workflows)?/|img\.shields\.io/github/(actions|workflow)' \
    "$ROOT/$README" > "$WORK/gh_badges" 2>/dev/null || true
  n=$(count_lines "$WORK/gh_badges")
  if [[ $n -gt 0 ]]; then
    add_finding "readme-dead-ci-badges" "medium" "$n" \
      "$(awk -F: -v r="$README" '{ printf "%s:%s (GitHub Actions badge — Actions disabled by policy)\n", r, $1 }' \
          "$WORK/gh_badges" | head -n "$MAX_EXAMPLES")"
  fi

  # 4b. version-looking badge strings vs latest tag
  latest_tag=$(g describe --tags --abbrev=0 2>/dev/null || true)
  if [[ -n "$latest_tag" ]]; then
    tag_ver=${latest_tag#v}
    # Only look at badge-ish lines; require a v/version prefix so plain
    # numbers (e.g. "Apache-2.0") do not false-positive.
    grep -Ei '!\[|badge|shields' "$ROOT/$README" 2>/dev/null \
      | grep -oEi '(version[-_: =/]?v?|\bv)[0-9]+\.[0-9]+(\.[0-9]+)?' \
      | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' \
      | sort -u > "$WORK/badge_vers" || true

    : > "$WORK/drift"
    while IFS= read -r bv; do
      [[ -z "$bv" ]] && continue
      if [[ "$bv" != "$tag_ver" ]]; then
        echo "$README says '$bv' but latest tag is '$latest_tag'" >> "$WORK/drift"
      fi
    done < "$WORK/badge_vers"

    n=$(count_lines "$WORK/drift")
    if [[ $n -gt 0 ]]; then
      add_finding "readme-version-drift" "low" "$n" \
        "$(head -n "$MAX_EXAMPLES" "$WORK/drift")"
    fi
  fi
fi

# --- Check 5: working tree state ---------------------------------------------

g status --porcelain > "$WORK/dirty" 2>/dev/null || true
n=$(count_lines "$WORK/dirty")
if [[ $n -gt 0 ]]; then
  add_finding "dirty-working-tree" "low" "$n" \
    "$(cut -c1-200 "$WORK/dirty" | head -n "$MAX_EXAMPLES")"
fi

g stash list > "$WORK/stashes" 2>/dev/null || true
n=$(count_lines "$WORK/stashes")
if [[ $n -gt 0 ]]; then
  add_finding "stash-pileup" "low" "$n" \
    "$(cut -c1-200 "$WORK/stashes" | head -n "$MAX_EXAMPLES")"
fi

# --- Check 6: .gitignore coverage vs language markers ------------------------

has_ignore_entry() { # dir-name (literal, no regex metachars expected)
  [[ -f "$ROOT/.gitignore" ]] || return 1
  grep -qE "^/?(\*\*/)?$1/?[[:space:]]*$" "$ROOT/.gitignore"
}

: > "$WORK/gitignore_gaps"
if grep -qE '(^|/)Cargo\.toml$' "$WORK/tracked"; then
  has_ignore_entry "target" \
    || echo "target/ — Cargo.toml present but target/ not ignored" >> "$WORK/gitignore_gaps"
fi
if grep -qE '(^|/)package\.json$' "$WORK/tracked"; then
  has_ignore_entry "node_modules" \
    || echo "node_modules/ — package.json present but node_modules/ not ignored" >> "$WORK/gitignore_gaps"
fi
if grep -qE '\.py$|(^|/)pyproject\.toml$|(^|/)setup\.py$' "$WORK/tracked"; then
  has_ignore_entry "__pycache__" \
    || echo "__pycache__/ — Python sources present but __pycache__/ not ignored" >> "$WORK/gitignore_gaps"
fi

n=$(count_lines "$WORK/gitignore_gaps")
if [[ $n -gt 0 ]]; then
  add_finding "gitignore-gaps" "medium" "$n" "$(cat "$WORK/gitignore_gaps")"
fi

# --- Check 7: suspicious tracked files (report only, never read) -------------

awk '
  /(^|\/)\.env$/       ||
  /\.pem$/             ||
  /\.key$/             ||
  /(^|\/)id_rsa[^\/]*$/
' "$WORK/tracked" > "$WORK/suspicious"

n=$(count_lines "$WORK/suspicious")
if [[ $n -gt 0 ]]; then
  add_finding "suspicious-tracked-files" "needs-review" "$n" \
    "$(head -n "$MAX_EXAMPLES" "$WORK/suspicious")"
fi

# --- Check 8: ad hoc root-level test scripts / stray binaries ---------------

# Root-level (path has no '/') test_*.sh|py|rs are ad hoc scratch files —
# legit tests live under tests/ (or src/**/tests/). Also flag any compiled
# binary (ELF, via `file`) tracked directly in root. Both are hygiene debt
# that tends to regenerate quarter over quarter; this catches it early.
# Files under tests/, scripts/, src/, etc. carry a '/' and are never matched.

awk '!/\// && /^test_.*\.(sh|py|rs)$/ { print $0 " (ad hoc test script)" }' \
  "$WORK/tracked" > "$WORK/root_tests"

: > "$WORK/root_bins"
# Detect compiled ELF binaries by magic bytes (\x7f 'E' 'L' 'F' at offset 0)
# using head + od (both coreutils) — no `file` dependency, so the check runs
# everywhere the rest of the script does. Symlinks are followed; text files
# and short files never match the 8-hex-digit magic 7f454c46.
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  if [[ "$(head -c 4 "$ROOT/$f" 2>/dev/null | od -An -tx1 | tr -d ' \n')" == "7f454c46" ]]; then
    echo "$f (ELF binary)" >> "$WORK/root_bins"
  fi
done < <(awk '!/\//' "$WORK/tracked")

cat "$WORK/root_tests" "$WORK/root_bins" > "$WORK/scratch"
n=$(count_lines "$WORK/scratch")
if [[ $n -gt 0 ]]; then
  add_finding "root-ad-hoc-files" "medium" "$n" \
    "$(head -n "$MAX_EXAMPLES" "$WORK/scratch")"
fi

# --- Output ------------------------------------------------------------------

TOTAL=${#F_CAT[@]}

json_escape() { # string -> JSON-safe string on stdout (no surrounding quotes)
  local s=$1
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  s=${s//$'\t'/\\t}
  s=${s//$'\n'/\\n}
  s=${s//$'\r'/\\r}
  # strip any remaining control characters
  printf '%s' "$s" | LC_ALL=C tr -d '\000-\037'
}

emit_json() {
  local clean="true"
  [[ $TOTAL -gt 0 ]] && clean="false"

  printf '{"repo":"%s","findings":[' "$(json_escape "$ROOT")"
  local i first_ex line
  for ((i = 0; i < TOTAL; i++)); do
    [[ $i -gt 0 ]] && printf ','
    printf '{"category":"%s","severity":"%s","count":%d,"examples":[' \
      "$(json_escape "${F_CAT[$i]}")" "$(json_escape "${F_SEV[$i]}")" "${F_COUNT[$i]}"
    first_ex=1
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      if [[ $first_ex -eq 1 ]]; then first_ex=0; else printf ','; fi
      printf '"%s"' "$(json_escape "$line")"
    done <<< "${F_EX[$i]}"
    printf ']}'
  done
  printf '],"clean":%s}\n' "$clean"
}

emit_human() {
  echo "=== Repo Hygiene Report: $ROOT ==="
  echo ""
  if [[ $TOTAL -eq 0 ]]; then
    echo "Clean — no findings."
    return
  fi
  local i shown line
  for ((i = 0; i < TOTAL; i++)); do
    printf '[%s] %s — %s finding(s)\n' "${F_SEV[$i]}" "${F_CAT[$i]}" "${F_COUNT[$i]}"
    shown=0
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      printf '    %s\n' "$line"
      shown=$((shown + 1))
    done <<< "${F_EX[$i]}"
    if [[ ${F_COUNT[$i]} -gt $shown ]]; then
      printf '    ... and %d more\n' $(( F_COUNT[i] - shown ))
    fi
    echo ""
  done
  echo "$TOTAL finding categor$([[ $TOTAL -eq 1 ]] && echo "y" || echo "ies"). Report only — nothing was modified."
}

if [[ $JSON -eq 1 ]]; then
  emit_json
else
  emit_human
fi

# --- File beads for remaining findings (if requested) --------------------

if [[ $FILE_BEADS -eq 1 && $TOTAL -gt 0 ]]; then
  if [[ "$(detect_bead_backend)" == "none" ]] || ! has_bead_store; then
    echo "" >&2
    echo "Bead filing skipped — this repo has no bead store / bead_cli.backend; findings reported above only." >&2
  else
    echo "" >&2
    echo "Filing beads for remaining findings..." >&2

    read -r created existing < <(file_beads_for_findings)

    echo "" >&2
    if [[ $created -gt 0 ]]; then
      echo "Filed $created new bead(s); $existing already tracked." >&2
    else
      echo "No new bead(s); $existing already tracked." >&2
    fi
  fi
fi

if [[ $TOTAL -gt 0 ]]; then
  exit 1
fi
exit 0
