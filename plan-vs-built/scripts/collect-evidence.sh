#!/usr/bin/env bash
# plan-vs-built: collect a read-only snapshot of what a repo has ACTUALLY built,
# so a plan.md can be checked against artifact reality rather than against prose.
#
# Read-only with respect to the audited repo: it never builds, never runs tests
# (`cargo test` here is intercepted and submits to iad-ci -- a "quick check"
# would fire off remote CI), never mutates a bead store, never touches a cluster.
#
# Usage: collect-evidence.sh [repo-path] [--json] [--out <dir>]
# Exit:  0 snapshot written, 2 usage error / not a git repo.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="."
JSON_MODE=0
OUT_DIR="${PLAN_VS_BUILT_OUT:-${TMPDIR:-/tmp}/plan-vs-built}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --json) JSON_MODE=1; shift ;;
        --out)  OUT_DIR="${2:?--out needs a directory}"; shift 2 ;;
        -h|--help)
            sed -n '2,12p' "$0"; exit 0 ;;
        -*) echo "error: unknown flag $1" >&2; exit 2 ;;
        *)  REPO="$1"; shift ;;
    esac
done

# Resolve --out to an absolute path while still in the invoking cwd.
case "$OUT_DIR" in /*) : ;; *) OUT_DIR="$PWD/$OUT_DIR" ;; esac

cd "$REPO" 2>/dev/null || { echo "error: cannot cd to $REPO" >&2; exit 2; }
if ! git rev-parse --git-dir &>/dev/null; then
    echo "error: $REPO is not a git repo" >&2; exit 2
fi
ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"
NAME="$(basename "$ROOT")"

# Never write into the repo under audit -- checked before anything is created.
case "$OUT_DIR" in
    "$ROOT"|"$ROOT"/*) echo "error: --out must be outside the repo under audit" >&2; exit 2 ;;
esac
mkdir -p "$OUT_DIR" || { echo "error: cannot create $OUT_DIR" >&2; exit 2; }

DC="${DECLARATIVE_CONFIG:-$HOME/declarative-config}"
SNAP="$OUT_DIR/$NAME"
mkdir -p "$SNAP"

# The human-readable snapshot is ALWAYS persisted, even in --json mode, so a
# multi-repo sweep can triage from the JSON and still read the detail later
# without re-running the collector.
LOG="$SNAP/snapshot.txt"
: > "$LOG"

say() { printf '%s\n' "$*" >> "$LOG"; [[ "$JSON_MODE" == 1 ]] || printf '%s\n' "$*"; }
have() { command -v "$1" &>/dev/null; }

# ---------------------------------------------------------------- repo state
BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
HEAD_SHA="$(git rev-parse --short HEAD 2>/dev/null)"
HEAD_EPOCH="$(git log -1 --format=%ct 2>/dev/null || echo 0)"
HEAD_DATE="$(git log -1 --format=%cI 2>/dev/null)"
DIRTY="$(git status --porcelain 2>/dev/null | grep -c . || true)"
UPSTREAM="$(git rev-parse --abbrev-ref '@{upstream}' 2>/dev/null || echo none)"
AHEAD=0; BEHIND=0
if [[ "$UPSTREAM" != none ]]; then
    read -r BEHIND AHEAD < <(git rev-list --left-right --count "$UPSTREAM...HEAD" 2>/dev/null || echo "0 0")
fi

say "=== plan-vs-built evidence snapshot: $NAME ==="
say "snapshot dir: $SNAP"
say
say "## REPO"
say "  root:     $ROOT"
say "  branch:   $BRANCH @ $HEAD_SHA ($HEAD_DATE)"
say "  upstream: $UPSTREAM (ahead $AHEAD / behind $BEHIND)"
say "  dirty:    $DIRTY uncommitted path(s)"
[[ "$DIRTY" -gt 0 ]] && say "  NOTE: uncommitted work is NOT built evidence -- a teammate or CI cannot see it."
say

# ---------------------------------------------------------------- plan files
say "## PLAN"
PLANS=()
while IFS= read -r p; do PLANS+=("$p"); done < <(
    git ls-files '*plan.md' 'docs/plan/*.md' 'docs/plan/**/*.md' 2>/dev/null | sort -u
)
PLAN_LINES=0
PLAN_LAST=""
if [[ ${#PLANS[@]} -eq 0 ]]; then
    say "  (no tracked plan.md found -- the skill's Step 1 resolution ladder applies)"
else
    for p in "${PLANS[@]}"; do
        plast="$(git log -1 --format=%cI -- "$p" 2>/dev/null)"
        plines="$(wc -l < "$p" 2>/dev/null | tr -d ' ')"
        PLAN_LINES=$((PLAN_LINES + ${plines:-0}))
        [[ "$plast" > "$PLAN_LAST" ]] && PLAN_LAST="$plast"
        say "  $p  (${plines} lines, last touched $plast)"
    done
fi
say

# ------------------------------------------------------- build systems/output
say "## BUILD ARTIFACTS"
STALE_NOTE=""
artifact_line() { # path
    local f="$1" m
    m="$(stat -c %Y "$f" 2>/dev/null || echo 0)"
    local flag=""
    if [[ "$m" -lt "$HEAD_EPOCH" ]]; then
        flag="  <-- STALE (older than HEAD commit)"
        STALE_NOTE="yes"
    fi
    say "    $(date -d "@$m" +%Y-%m-%dT%H:%M 2>/dev/null || echo '?')  $f$flag"
}

FOUND_BUILD=0
if [[ -f Cargo.toml ]]; then
    FOUND_BUILD=1
    say "  [rust] Cargo.toml"
    if [[ -d target/release ]]; then
        while IFS= read -r f; do artifact_line "$f"; done < <(
            find target/release -maxdepth 1 -type f -executable ! -name '*.d' ! -name '*.rlib' 2>/dev/null | head -20
        )
    else
        say "    (no target/release -- release build never run in this checkout)"
    fi
fi
if [[ -f package.json ]]; then
    FOUND_BUILD=1
    say "  [node] package.json"
    for d in dist build .next out public/build; do
        [[ -d "$d" ]] && artifact_line "$d"
    done
fi
if [[ -f go.mod ]]; then
    FOUND_BUILD=1
    say "  [go] go.mod"
    while IFS= read -r f; do artifact_line "$f"; done < <(
        find . -maxdepth 2 -type f -executable -not -path './.*' \
            ! -name '*.sh' ! -name '*.py' ! -name '*.js' ! -name '*.mjs' ! -name '*.ts' \
            2>/dev/null | head -10
    )
fi
if [[ -f pyproject.toml || -f setup.py ]]; then
    FOUND_BUILD=1
    say "  [python] pyproject/setup"
    [[ -d dist ]] && while IFS= read -r f; do artifact_line "$f"; done < <(find dist -maxdepth 1 -type f 2>/dev/null | head -10)
fi
[[ "$FOUND_BUILD" == 0 ]] && say "  (no recognized build system at repo root)"
[[ -n "$STALE_NOTE" ]] && say "  NOTE: a STALE artifact predates HEAD -- it is evidence of an OLD source tree, not this one."
say

# ---------------------------------------------------------------------- tests
say "## TESTS PRESENT (presence only -- this script never runs them)"
count_files() { git ls-files "$@" 2>/dev/null | grep -c . || true; }
RS_TESTS="$(git grep -l '#\[test\]\|#\[tokio::test\]' -- '*.rs' 2>/dev/null | grep -c . || true)"
[[ "$RS_TESTS" -gt 0 ]] && say "  rust:   $RS_TESTS file(s) containing #[test]"
JS_TESTS="$(count_files '*.test.*' '*.spec.*')"
[[ "$JS_TESTS" -gt 0 ]] && say "  js/ts:  $JS_TESTS test/spec file(s)"
# NOTE: a git pathspec is anchored at the repo root, so 'test_*.py' matches only
# root-level files -- tests/test_x.py needs the leading '*'. Patterns that already
# start with '*' (e.g. '*_test.py') are unaffected.
PY_TESTS="$(count_files 'test_*.py' '*/test_*.py' '*_test.py')"
[[ "$PY_TESTS" -gt 0 ]] && say "  python: $PY_TESTS test file(s)"
GO_TESTS="$(count_files '*_test.go')"
[[ "$GO_TESTS" -gt 0 ]] && say "  go:     $GO_TESTS test file(s)"
TOTAL_TESTS=$((RS_TESTS + JS_TESTS + PY_TESTS + GO_TESTS))
[[ "$TOTAL_TESTS" == 0 ]] && say "  (none found -- every 'works' claim in the plan is unverified by test)"
say

# ------------------------------------------------ local reference integrity
# Does tracked code point at files that are untracked (works here, broken on
# clone) or absent entirely (already broken)? Both classes ship silently.
say "## LOCAL REFERENCE INTEGRITY"
PHANTOM_N=0
MISSING_REFS_N=0
CHECKER="$SCRIPT_DIR/check-phantom-refs.py"
if [[ -f "$CHECKER" ]] && have python3; then
    python3 "$CHECKER" "$ROOT" --json --limit 12 > "$SNAP/phantom-refs.json" 2>/dev/null
    if [[ -s "$SNAP/phantom-refs.json" ]]; then
        read -r PHANTOM_N MISSING_REFS_N < <(
            python3 -c "import json,sys;d=json.load(open(sys.argv[1]));print(d['phantom'],d['missing'])" \
                "$SNAP/phantom-refs.json" 2>/dev/null || echo "0 0"
        )
        while IFS= read -r l; do say "$l"; done < <(
            python3 - "$SNAP/phantom-refs.json" <<'PY' 2>/dev/null
import json, sys
d = json.load(open(sys.argv[1]))
if not d["phantom"] and not d["missing"]:
    print("  no tracked file references an untracked or missing local path")
for v, note in (("PHANTOM", "tracked code -> UNTRACKED file (works here, breaks on clone;"
                            " deleting this tree destroys the only copy)"),
                ("MISSING", "tracked code -> file absent on disk (already broken)")):
    rows = [f for f in d["findings"] if f["verdict"] == v]
    n = d["phantom"] if v == "PHANTOM" else d["missing"]
    if not n:
        continue
    print(f"  {n} {v} reference(s) -- {note}")
    for f in rows:
        print(f"      {f['source']}:{f['line']} -> {f['target']}")
    if n > len(rows):
        print(f"      ... {n - len(rows)} more")
PY
        )
    fi
else
    say "  (checker unavailable -- check-phantom-refs.py or python3 missing)"
fi
say

# ----------------------------------------------------------------- containers
say "## CONTAINERS / IMAGE VERSIONS"
IMAGES=()
if [[ -d containers ]]; then
    for d in containers/*/; do
        [[ -d "$d" ]] || continue
        c="$(basename "$d")"
        v="(no VERSION file)"
        [[ -f "$d/VERSION" ]] && v="$(tr -d '[:space:]' < "$d/VERSION")"
        df="no Dockerfile"
        [[ -f "$d/Dockerfile" ]] && df="Dockerfile"
        say "  containers/$c: VERSION=$v ($df)"
        IMAGES+=("$c")
    done
else
    # Docker Hub repo names are lowercase; the repo basename may not be (AIVC -> aivc).
    [[ -f Dockerfile ]] && { say "  root Dockerfile (no containers/ layout)"; IMAGES+=("$(tr '[:upper:]' '[:lower:]' <<< "$NAME")"); }
    [[ ${#IMAGES[@]} -eq 0 ]] && say "  (no containers/ dir, no root Dockerfile)"
fi
say

# ------------------------------------------- where those images are consumed
say "## IMAGE PINS IN declarative-config"
PINNED_N=0
UNREFERENCED_N=0
if [[ -d "$DC" ]]; then
    if [[ ${#IMAGES[@]} -eq 0 ]]; then
        say "  (no images to look for)"
    else
        LNAME="$(tr '[:upper:]' '[:lower:]' <<< "$NAME")"
        for img in "${IMAGES[@]}"; do
            # A containers/<n> dir may publish as ronaldraygun/<n> OR, in
            # multi-container repos, as ronaldraygun/<repo>-<n> (commitgraph does
            # the latter for all 17). Match either, or every deployed image in
            # such a repo reads as "NOT REFERENCED".
            hits="$(grep -rhoiE "ronaldraygun/(${LNAME}-)?${img}:[A-Za-z0-9._-]+" "$DC" \
                    --exclude-dir=.git --exclude-dir=.claude --exclude-dir=node_modules \
                    2>/dev/null | sort -u)"
            if [[ -z "$hits" ]]; then
                UNREFERENCED_N=$((UNREFERENCED_N + 1))
                say "  ronaldraygun/$img: NOT REFERENCED anywhere in declarative-config (built but not deployed?)"
            else
                PINNED_N=$((PINNED_N + 1))
                while IFS= read -r h; do
                    case "$h" in
                        *:latest) say "  $h   <-- :latest, see CLAUDE.md prohibition (may be an image-updater placeholder)" ;;
                        *)        say "  $h" ;;
                    esac
                done <<< "$hits"
            fi
        done
    fi
else
    say "  (declarative-config not found at $DC -- set DECLARATIVE_CONFIG to override)"
fi
say

# -------------------------------------------------------------------- CI wiring
say "## CI (Argo WorkflowTemplates referencing this repo)"
CI_N=0
if [[ -d "$DC/k8s/iad-ci/argo-workflows" ]]; then
    hits="$(grep -rli -- "$NAME" "$DC/k8s/iad-ci/argo-workflows" 2>/dev/null | sort -u)"
    if [[ -z "$hits" ]]; then
        say "  none found -- no Argo CI template mentions '$NAME'"
    else
        CI_N="$(grep -c . <<< "$hits")"
        while IFS= read -r h; do say "  $(basename "$h")"; done <<< "$hits"
    fi
else
    say "  (argo-workflows dir not found under $DC)"
fi
GHA=0
if [[ -d .github/workflows ]]; then
    GHA=1
    say "  WARNING: .github/workflows exists -- GitHub Actions are banned org-wide (CLAUDE.md)"
fi
say

# ------------------------------------------------------------------- releases
say "## TAGS / RELEASES"
TAGS="$(git tag --sort=-creatordate 2>/dev/null | head -8)"
if [[ -n "$TAGS" ]]; then
    say "  git tags (newest first): $(echo "$TAGS" | tr '\n' ' ')"
else
    say "  no git tags"
fi
[[ -f VERSION ]] && say "  root VERSION file: $(tr -d '[:space:]' < VERSION)"
say "  (release-vs-tag drift is a known trap here: the Forgejo push mirror prunes"
say "   GitHub-only refs, which demotes a gh-created release to draft -- verify with"
say "   'gh release list' only if this repo is genuinely mirrored to GitHub.)"
say

# ---------------------------------------------------------------------- beads
say "## BEAD STORE"
BACKEND="none"
if [[ -f .beads/config.json && -d .beads/checkpoint ]]; then
    BACKEND="bead-rs"
elif [[ -f .beads/config.yaml || -f .beads/issues.jsonl ]]; then
    BACKEND="bf(legacy)"
elif [[ -d .beads ]]; then
    BACKEND="unrecognized(.beads exists)"
fi
DECLARED="$(grep -A2 'bead_cli' .needle.yaml 2>/dev/null | grep -oE 'backend:[[:space:]]*[a-z-]+' | awk '{print $2}')"
say "  on-disk shape: $BACKEND"
say "  .needle.yaml declares: ${DECLARED:-<nothing>}"
if [[ "$BACKEND" == "bead-rs" && -n "$DECLARED" && "$DECLARED" != "bead-rs" ]]; then
    say "  MISMATCH -- resolve before running ANY bead command (wrong CLI corrupts the store)"
fi

OPEN_N=0; CLOSED_N=0; INPROG_N=0
if [[ "$BACKEND" == "bead-rs" && -n "$DECLARED" && "$DECLARED" != "bead-rs" ]]; then
    say "  bead query skipped: backend declaration conflicts with on-disk store"
elif [[ "$BACKEND" == "bead-rs" ]] && have bead; then
    if bead list --json --limit 999999 > "$SNAP/beads.json" 2>/dev/null \
       && have jq && jq -e 'type == "array"' "$SNAP/beads.json" >/dev/null 2>&1; then
        OPEN_N="$(jq '[.[]|select(.status=="open")]|length' "$SNAP/beads.json")"
        INPROG_N="$(jq '[.[]|select(.status=="in_progress")]|length' "$SNAP/beads.json")"
        CLOSED_N="$(jq '[.[]|select(.status=="closed")]|length' "$SNAP/beads.json")"
        jq -r '.[]|select(.status=="closed")|[.id,.title]|@tsv' "$SNAP/beads.json" > "$SNAP/closed-beads.tsv"
        jq -r '.[]|select(.status=="open" and (.assignee//"")!="")|[.id,.assignee,.title]|@tsv' \
            "$SNAP/beads.json" > "$SNAP/open-but-assigned.tsv"
        STUCK="$( { grep -c . "$SNAP/open-but-assigned.tsv" 2>/dev/null || true; } | head -1)"
        STUCK="${STUCK:-0}"
        say "  counts: open=$OPEN_N in_progress=$INPROG_N closed=$CLOSED_N"
        say "  closed-bead list -> $SNAP/closed-beads.tsv  (audit these: closed != built)"
        if [[ "$STUCK" -gt 0 ]]; then
            say "  $STUCK open-but-ASSIGNED bead(s) -> $SNAP/open-but-assigned.tsv"
            say "    these are invisible to the ready frontier; needs 'bead update <id> --clear-assignee'"
        fi
    else
        say "  (bead list produced no parseable output, or jq missing)"
    fi
elif [[ "$BACKEND" == "bf(legacy)" ]]; then
    say "  legacy bf store -- 'bf' is decommissioned on this box; do NOT run 'bead' against it."
    say "  Resolve the backend question before creating any bead here."
else
    say "  no bead workspace ('bead init --prefix <short>' would create one)"
fi
say

# ------------------------------------------------------------ recent activity
say "## RECENT COMMITS (last 15)"
while IFS= read -r l; do say "$l"; done < <(git log -15 --format='  %cd %h %s' --date=short 2>/dev/null)
say

if [[ "$JSON_MODE" == 1 ]]; then
    python3 - "$SNAP" <<PY
import json, sys
snap = sys.argv[1]
print(json.dumps({
    "repo": "$NAME", "root": "$ROOT", "branch": "$BRANCH", "head": "$HEAD_SHA",
    "head_date": "$HEAD_DATE", "dirty_paths": int("$DIRTY" or 0),
    "upstream": "$UPSTREAM", "ahead": int("$AHEAD" or 0), "behind": int("$BEHIND" or 0),
    "plan_files": ${#PLANS[@]}, "plan_lines": int("$PLAN_LINES" or 0),
    "plan_last_touched": "${PLAN_LAST:-}",
    "bead_backend": "$BACKEND", "bead_backend_declared": "${DECLARED:-}",
    "beads": {"open": int("$OPEN_N" or 0), "in_progress": int("$INPROG_N" or 0),
              "closed": int("$CLOSED_N" or 0)},
    "test_files": {"rust": int("$RS_TESTS" or 0), "js": int("$JS_TESTS" or 0),
                   "python": int("$PY_TESTS" or 0), "go": int("$GO_TESTS" or 0),
                   "total": int("$TOTAL_TESTS" or 0)},
    "images": ${#IMAGES[@]},
    "images_pinned_in_declarative_config": int("$PINNED_N" or 0),
    "images_unreferenced": int("$UNREFERENCED_N" or 0),
    "ci_templates": int("$CI_N" or 0),
    "github_actions_present": bool($GHA),
    "phantom_refs": int("$PHANTOM_N" or 0),
    "missing_refs": int("$MISSING_REFS_N" or 0),
    "stale_artifacts": bool("$STALE_NOTE"),
    "snapshot_dir": snap, "snapshot_text": snap + "/snapshot.txt",
}, indent=2))
PY
fi

exit 0
