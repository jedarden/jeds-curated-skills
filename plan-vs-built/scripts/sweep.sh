#!/usr/bin/env bash
# plan-vs-built: fleet-wide sweep. Discovers every repo under a root that has a
# plan, runs the read-only evidence collector against each, and emits a ranked
# triage index so the expensive per-deliverable pass can be spent where the
# mechanical signals say a plan and its artifacts have diverged.
#
# Strictly read-only: it only calls collect-evidence.sh, which never builds,
# never runs tests, never mutates a bead store, never touches a cluster.
#
# Usage: sweep.sh [root-dir] [--out <dir>] [--jobs N] [--depth N]
#                 [--filter <regex>] [--quiet]
# Exit:  0 index written, 2 usage error, 3 no repos with a plan found.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COLLECT="$HERE/collect-evidence.sh"

ROOT="${PWD}"
OUT_DIR="${PLAN_VS_BUILT_OUT:-${TMPDIR:-/tmp}/plan-vs-built}"
JOBS=6
DEPTH=4
FILTER=""
QUIET=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --out)    OUT_DIR="${2:?--out needs a directory}"; shift 2 ;;
        --jobs)   JOBS="${2:?--jobs needs a number}"; shift 2 ;;
        --depth)  DEPTH="${2:?--depth needs a number}"; shift 2 ;;
        --filter) FILTER="${2:?--filter needs a regex}"; shift 2 ;;
        --quiet)  QUIET=1; shift ;;
        -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
        -*) echo "error: unknown flag $1" >&2; exit 2 ;;
        *)  ROOT="$1"; shift ;;
    esac
done

[[ -x "$COLLECT" ]] || { echo "error: collector not found/executable: $COLLECT" >&2; exit 2; }
cd "$ROOT" 2>/dev/null || { echo "error: cannot cd to $ROOT" >&2; exit 2; }
ROOT="$PWD"
case "$OUT_DIR" in /*) : ;; *) OUT_DIR="$ROOT/$OUT_DIR" ;; esac
mkdir -p "$OUT_DIR" || { echo "error: cannot create $OUT_DIR" >&2; exit 2; }

# ------------------------------------------------------------------ discovery
# A repo qualifies if it is a git repo AND has a plan on disk, in either the
# standard docs/plan/plan.md layout or as a root-level plan.md.
mapfile -t CANDIDATES < <(
    {
        find "$ROOT" -mindepth 3 -maxdepth "$DEPTH" -path '*/docs/plan/plan.md' \
             -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null \
            | sed 's|/docs/plan/plan.md$||'
        find "$ROOT" -mindepth 2 -maxdepth 2 -name 'plan.md' \
             -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null \
            | sed 's|/plan.md$||'
    } | sort -u
)

REPOS=()
for c in "${CANDIDATES[@]:-}"; do
    [[ -n "$c" ]] || continue
    [[ -d "$c/.git" ]] || continue
    if [[ -n "$FILTER" ]]; then
        [[ "$(basename "$c")" =~ $FILTER ]] || continue
    fi
    REPOS+=("$c")
done

if [[ ${#REPOS[@]} -eq 0 ]]; then
    echo "no git repos with a plan found under $ROOT (depth $DEPTH${FILTER:+, filter /$FILTER/})" >&2
    exit 3
fi

[[ "$QUIET" == 1 ]] || echo "=== plan-vs-built sweep: ${#REPOS[@]} repo(s) under $ROOT -> $OUT_DIR ==="

# ------------------------------------------------------------------ collection
export COLLECT OUT_DIR
collect_one() {
    local repo="$1" name
    name="$(basename "$repo")"
    mkdir -p "$OUT_DIR/$name"
    if ! "$COLLECT" "$repo" --json --out "$OUT_DIR" > "$OUT_DIR/$name/evidence.json" 2> "$OUT_DIR/$name/collect.err"; then
        # Keep a machine-readable stub so the index still accounts for the repo.
        printf '{"repo":"%s","root":"%s","collect_error":true}\n' "$name" "$repo" \
            > "$OUT_DIR/$name/evidence.json"
    fi
}
export -f collect_one

printf '%s\n' "${REPOS[@]}" | xargs -P "$JOBS" -I{} bash -c 'collect_one "$@"' _ {}

# ---------------------------------------------------------------------- index
python3 - "$OUT_DIR" "$QUIET" <<'PY'
import json, os, sys

out, quiet = sys.argv[1], sys.argv[2] == "1"
rows = []
for name in sorted(os.listdir(out)):
    p = os.path.join(out, name, "evidence.json")
    if not os.path.isfile(p):
        continue
    try:
        with open(p) as fh:
            rows.append(json.load(fh))
    except Exception as e:
        rows.append({"repo": name, "collect_error": True, "parse_error": str(e)})

def triage(r):
    """Mechanical suspicion signals only. These do NOT assign verdicts -- they
    rank which repos most likely hide a plan/artifact divergence, so the
    per-deliverable pass is spent in the right order."""
    flags, score = [], 0
    if r.get("collect_error"):
        return ["collect-error"], 99
    beads = r.get("beads") or {}
    op, ip, cl = beads.get("open", 0), beads.get("in_progress", 0), beads.get("closed", 0)
    tests = (r.get("test_files") or {}).get("total", 0)
    imgs = r.get("images", 0)

    # Highest-weighted signal in the sweep: tracked code pointing at an
    # untracked file is invisible to review, breaks any fresh clone, and the
    # only copy dies with the working tree.
    if r.get("phantom_refs", 0) > 0:
        flags.append(f"PHANTOM-REFS:{r['phantom_refs']}"); score += 6
    if r.get("missing_refs", 0) > 0:
        flags.append(f"missing-refs:{r['missing_refs']}"); score += 4
    if r.get("images_unreferenced", 0) > 0:
        flags.append("undeployed"); score += 3
    if tests == 0:
        flags.append("no-tests"); score += 3
    if cl > 0 and op == 0 and ip == 0:
        flags.append("all-closed"); score += 3
    if imgs > 0 and r.get("ci_templates", 0) == 0:
        flags.append("no-ci"); score += 2
    if r.get("ahead", 0) > 0:
        flags.append(f"unpushed:{r['ahead']}"); score += 2
    if r.get("github_actions_present"):
        flags.append("gh-actions"); score += 2
    if str(r.get("bead_backend", "")).startswith("bf"):
        flags.append("bf-legacy"); score += 2
    if r.get("bead_backend") == "none":
        flags.append("no-beads"); score += 2
    dec = r.get("bead_backend_declared") or ""
    if r.get("bead_backend") == "bead-rs" and dec and dec != "bead-rs":
        flags.append("backend-MISMATCH"); score += 5
    if r.get("stale_artifacts"):
        flags.append("stale-artifacts"); score += 1
    if r.get("dirty_paths", 0) > 0:
        flags.append(f"dirty:{r['dirty_paths']}"); score += 1
    if r.get("plan_lines", 0) >= 400 and (op + ip + cl) == 0:
        flags.append("big-plan-no-beads"); score += 2
    return flags, score

for r in rows:
    r["triage_flags"], r["triage_score"] = triage(r)

rows.sort(key=lambda r: (-r["triage_score"], r.get("repo", "")))

with open(os.path.join(out, "index.json"), "w") as fh:
    json.dump(rows, fh, indent=2)

hdr = ["score", "repo", "plan_lines", "tests", "imgs", "open", "inprog", "closed", "flags"]
with open(os.path.join(out, "index.tsv"), "w") as fh:
    fh.write("\t".join(hdr) + "\n")
    for r in rows:
        b = r.get("beads") or {}
        fh.write("\t".join(str(x) for x in [
            r["triage_score"], r.get("repo", "?"), r.get("plan_lines", 0),
            (r.get("test_files") or {}).get("total", 0), r.get("images", 0),
            b.get("open", 0), b.get("in_progress", 0), b.get("closed", 0),
            ",".join(r["triage_flags"]) or "-",
        ]) + "\n")

if not quiet:
    w = max((len(r.get("repo", "")) for r in rows), default=4)
    print(f"\n{'SCORE':>5}  {'REPO':<{w}}  {'PLAN':>5} {'TEST':>4} {'IMG':>3} "
          f"{'OPEN':>4} {'PROG':>4} {'CLSD':>4}  FLAGS")
    for r in rows:
        b = r.get("beads") or {}
        print(f"{r['triage_score']:>5}  {r.get('repo','?'):<{w}}  "
              f"{r.get('plan_lines',0):>5} {(r.get('test_files') or {}).get('total',0):>4} "
              f"{r.get('images',0):>3} {b.get('open',0):>4} {b.get('in_progress',0):>4} "
              f"{b.get('closed',0):>4}  {','.join(r['triage_flags']) or '-'}")
    print(f"\n{len(rows)} repo(s). index -> {out}/index.json  {out}/index.tsv")
    print("Per-repo detail: <out>/<repo>/snapshot.txt, closed-beads.tsv, open-but-assigned.tsv")
    print("NOTE: flags rank where to look. They are NOT verdicts -- a verdict needs an "
          "observation against a plan deliverable.")
PY

exit 0
