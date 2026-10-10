#!/usr/bin/env bash
# Sweep a repo for stub/mock/placeholder/incomplete code — the class of AI-generated
# incompleteness that passes lint/type-check but is silently fake. Report-only.
set -euo pipefail

REPO="${1:-.}"
if ! cd "$REPO" 2>/dev/null; then
    echo "error: cannot cd to $REPO" >&2
    exit 2
fi

if ! git rev-parse --git-dir &>/dev/null; then
    echo "error: $REPO is not a git repo" >&2
    exit 2
fi

if ! command -v rg &>/dev/null; then
    echo "error: ripgrep (rg) is required but not installed" >&2
    exit 2
fi

JSON_MODE=0
[[ "${2:-}" == "--json" ]] && JSON_MODE=1

declare -A PATTERNS=(
    [leftover-todo]='TODO|FIXME|XXX|HACK'
    [explicit-unimplemented]='unimplemented!\(|todo!\(|NotImplementedError|raise NotImplementedError|not[_ ]implemented'
    [placeholder-marker]='(?i)\bplaceholder\b|\bstub implementation\b|\bfake data\b|\bhardcoded (for now|placeholder|temp)'
    [empty-catch-swallow]='except\s*:\s*pass\s*$|catch\s*\([^)]*\)\s*\{\s*\}'
)

RESULTS_FILE=$(mktemp)
trap 'rm -f "$RESULTS_FILE"' EXIT

for category in "${!PATTERNS[@]}"; do
    pattern="${PATTERNS[$category]}"
    rg --pcre2 -n --no-heading -g '!target' -g '!node_modules' -g '!.git' -g '!dist' -g '!build' \
        "$pattern" . 2>/dev/null | while IFS=: read -r file line rest; do
        printf '%s\t%s\t%s\t%s\n' "$category" "$file" "$line" "$(echo "$rest" | sed 's/^[[:space:]]*//' | cut -c1-120)"
    done >> "$RESULTS_FILE" || true
done

COUNT=$(wc -l < "$RESULTS_FILE" | tr -d ' ')

if [[ "$JSON_MODE" == 1 ]]; then
    python3 -c "
import json, sys
rows = []
with open('$RESULTS_FILE') as f:
    for line in f:
        parts = line.rstrip('\n').split('\t', 3)
        if len(parts) == 4:
            rows.append({'category': parts[0], 'file': parts[1], 'line': int(parts[2]), 'text': parts[3]})
print(json.dumps({'count': len(rows), 'findings': rows}, indent=2))
"
else
    echo "=== find-stubs report: $REPO ==="
    echo "$COUNT findings"
    echo
    for category in "${!PATTERNS[@]}"; do
        n=$(grep -c "^$category	" "$RESULTS_FILE" 2>/dev/null) || true
        n="${n:-0}"
        [[ "$n" == "0" ]] && continue
        echo "--- $category ($n) ---"
        grep "^$category	" "$RESULTS_FILE" | awk -F'\t' '{printf "  %s:%s: %s\n", $2, $3, $4}'
        echo
    done
fi

[[ "$COUNT" -gt 0 ]] && exit 1 || exit 0
