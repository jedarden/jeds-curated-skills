#!/usr/bin/env bash
#
# lint-shell.sh - ShellCheck lint pass for every shell script in this repo
#
# Complements scripts/validate-skills.sh (ADR-1 structural validation:
# frontmatter schema, reference integrity, bash -n, executable bits) with an
# enforced lint bar. Structural validation only proves a script parses; this
# proves it does not regress past the ShellCheck findings recorded in the
# committed baseline scripts/shellcheck-baseline.txt.
#
# Scope (relative to repo root):
#   *.sh            root scripts (install.sh)
#   lib/*.sh        shared shell library
#   scripts/*.sh    repo-level tooling (this harness included)
#   */scripts/*.sh  every skill's scripts
#
# Baseline ratchet: each finding is keyed as "<repo-relative-path>|<SCcode>"
# and counted per key. Against the baseline:
#   count > baseline  -> FAIL (a new finding was introduced); the offending
#                        lines are printed. Fix the finding, or if it is
#                        genuinely intentional, add it via --refresh and
#                        justify it in a comment next to the entry.
#   count < baseline  -> improvement; run --refresh to shrink the baseline
#                        (reported, but never fails the run).
#
# SC1091 ("Not following <path>, not specified as input") is excluded: with
# follow-sourcing off, it fires on every `source` of a file not passed on the
# command line regardless of whether that file exists, so it carries no
# signal here. The sourced file (lib/common.sh) is passed as an input itself
# and is linted directly.
#
# Usage:
#   scripts/lint-shell.sh              # lint against the baseline (default)
#   scripts/lint-shell.sh --refresh    # regenerate the baseline from current findings
#   scripts/lint-shell.sh --list       # print current findings, no comparison
#
# Graceful degradation (the ADR-1 dependency-tolerance rule): with no
# ShellCheck binary on PATH this exits 0 with a skip notice, so validate-skills.sh
# and the pre-commit hook keep working on a bare machine. ShellCheck >= 0.8
# is assumed for the -f gcc output shape. On a NixOS box without shellcheck
# in $PATH: nix shell nixpkgs#shellcheck -c scripts/lint-shell.sh
#
# The baseline is version-sensitive (codes and counts shift between
# releases). Its "# tool version:" header records the ShellCheck that
# generated it; a mismatch is warned about at check time. Note the header
# when refreshing and when pinning a version server-side (the skills-validate
# WorkflowTemplate currently runs in alpine/git, which has no shellcheck —
# the lint stays dormant there until the template installs a matching one).
#
# Exit codes: 0 = clean or skipped, 1 = new findings vs baseline, 2 = usage error

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
BASELINE="$SCRIPT_DIR/shellcheck-baseline.txt"

MODE="${1:-check}"

case "$MODE" in
    --refresh | --list | check) ;;
    *)
        echo "Usage: $0 [--refresh|--list]" >&2
        exit 2
        ;;
esac

if ! command -v shellcheck >/dev/null 2>&1; then
    echo "lint-shell: shellcheck not on PATH — lint skipped (structural bash -n is still enforced by validate-skills.sh)"
    exit 0
fi

cd "$REPO_ROOT" || exit 2

# Deterministic, repo-relative target list
shopt -s nullglob
mapfile -t TARGETS < <(printf '%s\n' \
    ./*.sh \
    ./lib/*.sh \
    ./scripts/*.sh \
    ./*/scripts/*.sh | LC_ALL=C sort -u)
shopt -u nullglob

if [[ ${#TARGETS[@]} -eq 0 ]]; then
    echo "lint-shell: no shell scripts found under $REPO_ROOT"
    exit 0
fi

RAW_FINDINGS="$(shellcheck --exclude=SC1091 --format=gcc "${TARGETS[@]}" 2>&1 || true)"

LIVE_VERSION="$(shellcheck --version | awk '/^version:/ {print $2}')"

# Parse "path:line:col: level: message [SCxxxx]" into per-key counts + detail
declare -A ACT=()
declare -A DETAIL=()
UNPARSED=()
regex='^(.+):[0-9]+:[0-9]+: [a-z]+: .*\[(SC[0-9]+)\]$'
while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    if [[ "$line" =~ $regex ]]; then
        key="${BASH_REMATCH[1]}|${BASH_REMATCH[2]}"
        ACT[$key]=$(( ${ACT[$key]:-0} + 1 ))
        DETAIL[$key]+="$line"$'\n'
    else
        UNPARSED+=("$line")
    fi
done <<< "$RAW_FINDINGS"

if [[ ${#UNPARSED[@]} -gt 0 ]]; then
    echo "lint-shell: WARNING — output lines did not match expected shellcheck -f gcc shape (version drift?)" >&2
    printf '  %s\n' "${UNPARSED[@]}" >&2
fi

if [[ "$MODE" == "--list" ]]; then
    echo "$RAW_FINDINGS"
    exit 0
fi

if [[ "$MODE" == "--refresh" ]]; then
    # Hand-maintained justifications below the marker survive a refresh; the
    # generated section above it is rewritten.
    JUSTIFY_MARKER="# --- justifications (hand-maintained; everything above is refreshed) ---"
    JUSTIFICATIONS="$(awk -v m="$JUSTIFY_MARKER" 'index($0, m) == 1 { found = 1 } found' "$BASELINE" 2>/dev/null || true)"
    {
        echo "# ShellCheck baseline for scripts/lint-shell.sh"
        echo "# tool version: $LIVE_VERSION"
        echo "# regenerated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
        echo "# format: <repo-relative-path>|<SCcode>=<count> — findings at or below"
        echo "#   count pass; anything above is a failure. Entries exist to record"
        echo "#   known, accepted debt. Do not hand-edit counts — run"
        echo "#   scripts/lint-shell.sh --refresh."
        if [[ ${#ACT[@]} -eq 0 ]]; then
            echo "# (no findings)"
        else
            # mapfile, not unquoted $(...): a path containing whitespace
            # must not split into two keys
            KEYS=()
            mapfile -t KEYS < <(printf '%s\n' "${!ACT[@]}" | LC_ALL=C sort)
            for key in "${KEYS[@]}"; do
                echo "$key=${ACT[$key]}"
            done
        fi
        if [[ -n "$JUSTIFICATIONS" ]]; then
            echo ""
            printf '%s\n' "$JUSTIFICATIONS"
        fi
    } > "$BASELINE"
    echo "lint-shell: baseline refreshed ($LIVE_VERSION) — ${#ACT[@]} entr(ies) in $BASELINE"
    exit 0
fi

# --- compare against baseline ------------------------------------------------

if [[ ! -f "$BASELINE" ]]; then
    echo "lint-shell: baseline missing at $BASELINE" >&2
    echo "  run: scripts/lint-shell.sh --refresh" >&2
    exit 2
fi

BASELINE_VERSION="$(sed -n 's/^# tool version: //p' "$BASELINE" | head -1)"
if [[ -n "$BASELINE_VERSION" && "$BASELINE_VERSION" != "$LIVE_VERSION" ]]; then
    echo "lint-shell: WARNING — baseline was generated by ShellCheck $BASELINE_VERSION, running $LIVE_VERSION; counts may not be comparable" >&2
fi

declare -A BASE=()
base_regex='^(.+)\|(SC[0-9]+)=([0-9]+)$'
while IFS= read -r line; do
    [[ -z "$line" || "$line" == \#* ]] && continue
    if [[ "$line" =~ $base_regex ]]; then
        BASE["${BASH_REMATCH[1]}|${BASH_REMATCH[2]}"]="${BASH_REMATCH[3]}"
    else
        echo "lint-shell: malformed baseline line (fix or re-run --refresh): $line" >&2
        exit 2
    fi
done < "$BASELINE"

status=0
for key in "${!ACT[@]}"; do
    n=${ACT[$key]}
    b=${BASE[$key]:-0}
    if (( n > b )); then
        echo "lint-shell: FAIL $key — baseline $b, now $n:"
        printf '%s' "${DETAIL[$key]}"
        status=1
    elif (( n < b )); then
        echo "lint-shell: improved $key ($b -> $n) — consider scripts/lint-shell.sh --refresh"
    fi
done
for key in "${!BASE[@]}"; do
    if [[ -z "${ACT[$key]:-}" ]]; then
        echo "lint-shell: resolved $key (baseline ${BASE[$key]}) — consider scripts/lint-shell.sh --refresh"
    fi
done

if (( status == 0 )); then
    echo "lint-shell: OK — ${#ACT[@]} finding group(s), all within baseline (${#BASE[@]} entries)"
fi
exit "$status"
