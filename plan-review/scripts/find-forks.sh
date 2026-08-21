#!/usr/bin/env bash
# find-forks.sh — locate deferred, hedged, shadowed, and unquantified decisions in a plan.
#
# Usage: find-forks.sh <plan.md> [--quiet]
#
# This is a LOCATOR, not a score. It prints line-anchored hits so the reviewer knows where to
# look; it cannot tell whether a decision was actually made. A clean scan does not mean the
# plan is ready — run the decision ledger (SKILL.md Step 3). UNNOTICED forks never show here.
#
#   DEFER        explicit deferral: TBD, later, pending, to be decided, FILL IN, "see Open Questions"
#   HEDGE        a choice left soft: likely, probably, e.g., or similar, candidate, option, consider
#   SHADOW       decisions recorded where an implementer won't read them: ADR headers appended
#                after the Open Questions section (or deep in the file), struck-through lines
#   AMENDED      inline "decided/resolved/corrected <date>" parentheticals — check each lives in
#                its home section as a headline decision; fold the ones that are buried in prose
#   UNQUANTIFIED a knob named with no number on the line: timeout, interval, TTL, retention,
#                limit, budget, replicas, threshold, backoff, cap
#
# DECIDED-markers (decision:, rejected, revisit if, enforced by, MUST, ADR-n) are counted as a
# rough sense of how much the plan commits to — a hint, not a grade.
#
# Exit code: 0 on success (report-only), 2 on usage error. Self-contained; no shared library.

set -euo pipefail

FILE="${1:-}"
QUIET="${2:-}"
if [[ -z "$FILE" || ! -f "$FILE" ]]; then
  echo "Usage: find-forks.sh <plan.md> [--quiet]" >&2
  exit 2
fi

TOTAL_LINES=$(wc -l < "$FILE")
[[ $TOTAL_LINES -lt 1 ]] && TOTAL_LINES=1

# --- SHADOW threshold for ADR headers -------------------------------------------------------
# An ADR header counts as appended-after-the-fact when it sits past the Open Questions heading
# (that is where plans end) or past 70% of the file — but never before 40%, so a front-loaded
# "Decisions to Lock Early" section is not flagged.
OQ_LINE=$(grep -nE '^#{1,6} .*\bOpen Questions?\b' "$FILE" | head -1 | cut -d: -f1 || true)
P40=$(( TOTAL_LINES * 40 / 100 )); P70=$(( TOTAL_LINES * 70 / 100 ))
if [[ -n "${OQ_LINE:-}" && "$OQ_LINE" -lt "$P70" ]]; then CAND=$OQ_LINE; else CAND=$P70; fi
SHADOW_FROM=$(( CAND > P40 ? CAND : P40 ))
[[ $SHADOW_FROM -lt 1 ]] && SHADOW_FROM=1

# --- Patterns (extended regex, case-insensitive) ------------------------------------------
DEFER_RE='\bTBD\b|\bTODO\b|\bto be (decided|determined|defined|confirmed|designed)\b|\bnot yet (decided|designed|determined|chosen)\b|\bdecision pending\b|\bpending (review|decision)\b|\bundecided\b|\bfigure (it|this|that)? ?out\b|\bwe.?ll (see|decide|revisit|figure)\b|\bfor now\b|\bat some point\b|\bplaceholder\b|FILL IN|\bopen questions?\b|\blater\b|\beventually\b|\?\?|\bXXX\b'
HEDGE_RE='\blikely\b|\bprobably\b|\bmaybe\b|\bpossibly\b|\bperhaps\b|\bmight\b|\bcould (use|be|go)\b|\bor similar\b|\bsomething like\b|\be\.g\.|\bcandidate\b|\boptions?\b|\bif needed\b|\bas appropriate\b|\bnice.to.have\b|\bconsider(ing)?\b|\bideally\b|\bshould probably\b|\bpossible (approach|option)'
DECIDED_RE='\bdecided\b|\bdecision:|\bwe (chose|choose|use|will use|adopt|pick)\b|\bchosen\b|\brejected\b|\bADR-?[0-9]+|\blocked\b|\bratif(y|ied)\b|\bsupersede[sd]?\b|\bnon-negotiable\b|\bMUST( NOT)?\b|\brevisit if\b|\benforced by\b|\bbecause:'
KNOB_RE='\b(timeout|interval|ttl|retention|limit|budget|replicas|threshold|max(imum)?|min(imum)?|cadence|quota|window|backoff|cap)\b'
AMEND_RE='\b(decided|resolved|amended|corrected|narrowed|ratified|revised|superseded) [0-9]{4}-[0-9]{2}-[0-9]{2}'

# grep helpers: every call tolerates "no match".
g()  { grep -niE "$1" "$FILE" 2>/dev/null || true; }
gE() { grep -nE  "$1" "$FILE" 2>/dev/null || true; }
not_heading() { grep -vE '^[0-9]+:#' || true; }
not_table()   { grep -vE '^[0-9]+:\s*\|' || true; }
not_quote()   { grep -vE '^[0-9]+:\s*>' || true; }
no_digits()   { grep -vE '^[0-9]+:.*[0-9]' || true; }
fmt()         { sed -E 's/^([0-9]+):\s*/:\1  /' | cut -c1-150; }

mapfile -t DEFER_HITS   < <(g "$DEFER_RE"   | not_heading)
mapfile -t HEDGE_HITS   < <(g "$HEDGE_RE"   | not_quote)
mapfile -t DECIDED_HITS < <(g "$DECIDED_RE")
mapfile -t UNQ_HITS     < <(g "$KNOB_RE"    | no_digits | not_heading | not_table)
mapfile -t SHADOW_ADR   < <(gE '^#{1,6} .*\b(ADR|Decision Record)' | awk -F: -v from="$SHADOW_FROM" '$1 >= from' || true)
mapfile -t SHADOW_STRUCK< <(gE '~~[^~]+~~')
mapfile -t AMEND_HITS   < <(g "$AMEND_RE"   | not_heading | not_table)

count_distinct_lines() {  # distinct line numbers across the given hit strings
  printf '%s\n' "$@" | grep -oE '^[0-9]+' 2>/dev/null | sort -un | wc -l | tr -d ' ' || true
}

n_defer=${#DEFER_HITS[@]}
n_hedge=${#HEDGE_HITS[@]}
n_decided=${#DECIDED_HITS[@]}
n_unq=${#UNQ_HITS[@]}
n_amend=${#AMEND_HITS[@]}
n_shadow=$(count_distinct_lines "${SHADOW_ADR[@]+"${SHADOW_ADR[@]}"}" "${SHADOW_STRUCK[@]+"${SHADOW_STRUCK[@]}"}")
[[ -z "$n_shadow" ]] && n_shadow=0

echo "=== find-forks: $FILE ($TOTAL_LINES lines) ==="
echo ""
printf 'DEFER %d · HEDGE %d · SHADOW %d · AMENDED %d · UNQUANTIFIED %d · DECIDED-markers %d\n' \
  "$n_defer" "$n_hedge" "$n_shadow" "$n_amend" "$n_unq" "$n_decided"
echo "(locator only — a clean scan is not a verdict; run the decision ledger)"
echo ""

print_list() {  # title, then hits
  local title="$1"; shift
  echo "--- $title ($#) ---"
  if [[ $# -eq 0 ]]; then echo "  (none)"; else local h; for h in "$@"; do printf '  %s\n' "$(printf '%s' "$h" | fmt)"; done; fi
  echo ""
}

if [[ "$QUIET" != "--quiet" ]]; then
  print_list "DEFER — explicit deferrals"        "${DEFER_HITS[@]+"${DEFER_HITS[@]}"}"
  print_list "HEDGE — soft choices"              "${HEDGE_HITS[@]+"${HEDGE_HITS[@]}"}"
  echo "--- SHADOW — decisions not where an implementer reads ($n_shadow) ---"
  if [[ $n_shadow -eq 0 ]]; then
    echo "  (none)"
  else
    if [[ ${#SHADOW_ADR[@]} -gt 0 ]]; then
      echo "  ADR headers appended after the plan's end (from line $SHADOW_FROM):"
      for h in "${SHADOW_ADR[@]}"; do printf '    %s\n' "$(printf '%s' "$h" | fmt)"; done
    fi
    if [[ ${#SHADOW_STRUCK[@]} -gt 0 ]]; then
      echo "  struck-through lines (did the answer reach the body?):"
      for h in "${SHADOW_STRUCK[@]}"; do printf '    %s\n' "$(printf '%s' "$h" | fmt)"; done
    fi
  fi
  echo ""
  print_list "AMENDED — dated inline amendments (fold the buried ones)" "${AMEND_HITS[@]+"${AMEND_HITS[@]}"}"
  print_list "UNQUANTIFIED — knob named, no number on the line"        "${UNQ_HITS[@]+"${UNQ_HITS[@]}"}"
fi

if [[ $n_defer -eq 0 && $n_shadow -eq 0 ]]; then
  echo "Hint: no explicit deferrals or shadow decisions. UNNOTICED forks are invisible to grep — walk the ledger catalog."
else
  echo "Hint: each DEFER/SHADOW line is a candidate DN. Read the line, classify it, propose the decision."
fi
if [[ $n_amend -ge 20 ]]; then
  echo "Hint: $n_amend dated amendments — decisions are being recorded as parentheticals. Consider \`--lock\` to fold them into Form 1 headlines."
fi
exit 0
