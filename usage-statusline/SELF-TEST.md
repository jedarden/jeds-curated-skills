# Self-Test: usage-statusline

The rendering core (`scripts/usage-statusline.sh`) is scriptable without an
LLM: point it at a fixture `$HOME` and assert on exit code, line count, and
content. Everything below runs against a throwaway `HOME`, never the real one —
the script derives its cache, locks, credentials, and commit scan from `$HOME`
alone, and with no `~/.claude/.credentials.json` in the fixture the fetch path
bails at jq before any network call.

## Trigger Phrases

| Phrase | Expected |
|--------|----------|
| "set up the usage statusline" | Activates |
| "show my 5h/7d usage in the prompt line" | Activates |
| "the statusline is blank / broken" | Activates (troubleshoot path) |
| "/usage-statusline" | Activates |
| "how much of my weekly cap is left?" | Activates (explain path) |
| "write me a new statusline from scratch" | Does NOT activate — this skill installs and wires the bundled script |

## Structure

```bash
REPO="${REPO:-$HOME/jeds-curated-skills}"
SKILL_DIR="$REPO/usage-statusline"
ls -1 "$SKILL_DIR"         # README.md, SELF-TEST.md, SKILL.md, scripts/
ls -1 "$SKILL_DIR/scripts" # usage-statusline.sh
test -x "$SKILL_DIR/scripts/usage-statusline.sh" && echo "ok: executable"
command -v jq curl flock git >/dev/null && echo "ok: host deps present"
```

## Smoke test

One self-contained block: builds a fixture `HOME` in `mktemp -d`, writes a
fresh `usage.json` (fresh mtime ⇒ the 60 s cache TTL short-circuits the fetch),
plants a synthetic repo with two Claude-co-authored commits, and asserts.

```bash
REPO="${REPO:-$HOME/jeds-curated-skills}"
SL="$REPO/usage-statusline/scripts/usage-statusline.sh"
T="$(mktemp -d)"; H="$T/home"
mkdir -p "$H/.cache/claude-usage"

RESET_5H="$(date -u -d '+4 hours' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v+4H +%Y-%m-%dT%H:%M:%SZ)"
RESET_7D="$(date -u -d '+5 days'  +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v+5d +%Y-%m-%dT%H:%M:%SZ)"
cat > "$H/.cache/claude-usage/usage.json" <<EOF
{
  "limits": [
    {"kind": "session",       "percent": 12, "resets_at": "$RESET_5H"},
    {"kind": "weekly_all",    "percent": 34, "resets_at": "$RESET_7D"},
    {"kind": "weekly_scoped", "percent":  8, "resets_at": "$RESET_7D",
     "scope": {"model": {"display_name": "Opus"}}}
  ]
}
EOF

# Synthetic repo inside the maxdepth-2 find window, two Claude-co-authored commits.
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
mkdir -p "$H/fixture-repo" && git -C "$H/fixture-repo" init -q
for i in 1 2; do
  echo "$i" > "$H/fixture-repo/f.txt"
  git -C "$H/fixture-repo" add f.txt
  git -C "$H/fixture-repo" -c user.name=jedarden -c user.email=github@jedarden.com \
    commit -qm "fixture commit $i

Co-Authored-By: Claude <noreply@anthropic.com>"
done

fails=0
expect() { # expect <desc> <actual> <expected-substring>
  if [[ "$2" == *"$3"* ]]; then echo "PASS: $1"; else echo "FAIL: $1 — got: $2"; fails=$((fails+1)); fi
}

# Run 1: the commit count warms asynchronously (maybe_count_commits is
# backgrounded), so run 1 renders the pre-warm git-cache placeholder — usually
# "⎇ 0", but the background scan races the render, so only the SEGMENT is
# pinned here, not its value. The deterministic warmed-count pin is run 2.
out1="$(env HOME="$H" bash "$SL")"; rc1=$?
expect "run1 exit 0"            "rc=$rc1"        "rc=0"
[[ -n "$out1" && "$out1" != *$'\n'* ]] && echo "PASS: run1 single non-empty line" \
                                       || { echo "FAIL: run1 line shape"; fails=$((fails+1)); }
expect "run1 session window"    "$out1" "5h 12%"
expect "run1 weekly window"     "$out1" "7d 34%"
expect "run1 scoped cap label"  "$out1" "Opus  8%"   # %2d width: two spaces before a 1-digit percent
expect "run1 commit segment"    "$out1" "⎇"

# Trailing newline, checked on the raw bytes — "$(...)" strips them, so the
# single-line assert above cannot see this. The script's last printf omits the
# newline (Claude Code tolerates both, but a trailing-newline "fix" is a
# visible change).
env HOME="$H" bash "$SL" > "$T/raw.sl"
[ "$(tail -c1 "$T/raw.sl" | wc -l)" -eq 0 ] && echo "PASS: no trailing newline" \
                                            || { echo "FAIL: trailing newline"; fails=$((fails+1)); }

# Bounded wait for the async scan to land in git_commits.txt (TTL 300 s) — a
# bare sleep would flake on a loaded box; then run 2 pins the warmed count.
for _ in $(seq 1 50); do [ -f "$H/.cache/claude-usage/git_commits.txt" ] && break; sleep 0.2; done
[ "$(cat "$H/.cache/claude-usage/git_commits.txt" 2>/dev/null)" = "2" ] \
  && echo "PASS: git cache warmed to 2" || { echo "FAIL: git cache not warmed"; fails=$((fails+1)); }

# Run 2: commit count now cached — the deterministic pin.
out2="$(env HOME="$H" bash "$SL")"; rc2=$?
expect "run2 exit 0"            "rc=$rc2"        "rc=0"
[[ -n "$out2" && "$out2" != *$'\n'* ]] && echo "PASS: run2 single non-empty line" \
                                       || { echo "FAIL: run2 line shape"; fails=$((fails+1)); }
expect "run2 commit count"      "$out2" "⎇ 2"
expect "run2 windows still present" "$out2" "5h 12%"
expect "run2 scoped still present"  "$out2" "Opus  8%"

# ANSI re-render (what Claude Code actually displays) for eyeball confirmation.
printf '%b\n' "$(env HOME="$H" bash "$SL")" | cat -v
echo "-----"
[ "$fails" -eq 0 ] && echo "SMOKE TEST: ALL PASS" || echo "SMOKE TEST: $fails FAILURE(S)"
rm -rf "$T"
```

**Expected:** every line `PASS`, final line `SMOKE TEST: ALL PASS`. The
rendered line is `5h 12% █…~Nh │ 7d 34% … │ Opus  8% … │ ⎇ 2` with ANSI color
(green under 50 %, yellow 50–79 %, red ≥ 80 %). Exact bars and `~`-times are
deliberately **not** pinned: they depend on wall-clock distance to
`resets_at`. Pinned: exit 0, exactly one non-empty line, **no trailing
newline** (byte-checked on the raw output — the script's last `printf` omits
it; Claude Code tolerates both, but a trailing-newline "fix" is a visible
change), the three window labels with their percents, the width-2 padding
(`Opus  8%`), and the warmed commit count on run 2. Run 1 pins the `⎇`
segment only: the scan runs in the background and races the first render, so
its placeholder value is usually `⎇ 0` but is not guaranteed — the
deterministic assertion is run 2's `⎇ 2`, taken after a bounded wait on the
cache file (whose contents must be exactly `2`).

## Degraded-cache behavior

```bash
REPO="${REPO:-$HOME/jeds-curated-skills}"
SL="$REPO/usage-statusline/scripts/usage-statusline.sh"
T="$(mktemp -d)"; fails=0
expect() { # expect <desc> <actual> <expected-substring>
  if [[ "$2" == *"$3"* ]]; then echo "PASS: $1"; else echo "FAIL: $1 — got: $2"; fails=$((fails+1)); fi
}

# Case 1 — cache file absent (first ever run): documented to exit silently.
H1="$T/h1"
out="$(env HOME="$H1" bash "$SL" 2>"$T/err1")"; rc=$?
[ "$rc" -eq 0 ]             && echo "PASS: missing cache exit 0" || { echo "FAIL: rc=$rc"; fails=$((fails+1)); }
[ -z "$out" ]               && echo "PASS: missing cache stdout empty" || { echo "FAIL: stdout: $out"; fails=$((fails+1)); }
[ ! -s "$T/err1" ]          && echo "PASS: missing cache stderr empty" || { echo "FAIL: stderr"; fails=$((fails+1)); }

# Case 2 — empty (zero-byte) cache: jq fails, eval masks its exit status, set -u kills at first use.
mkdir -p "$T/h2/.cache/claude-usage" && : > "$T/h2/.cache/claude-usage/usage.json"
out="$(env HOME="$T/h2" bash "$SL" 2>"$T/err2")"; rc=$?
[ "$rc" -ne 0 ] && echo "PASS: empty cache exits non-zero (got $rc)" || { echo "FAIL: rc=0"; fails=$((fails+1)); }
[ -z "$out" ]   && echo "PASS: empty cache stdout empty"            || { echo "FAIL: stdout: $out"; fails=$((fails+1)); }
grep -q "p5h: unbound variable" "$T/err2" \
  && echo "PASS: empty cache fails at first window var" || { echo "FAIL: unexpected stderr"; fails=$((fails+1)); }

# Case 3 — valid JSON, wrong shape ({}): same path as case 2.
mkdir -p "$T/h3/.cache/claude-usage" && echo '{}' > "$T/h3/.cache/claude-usage/usage.json"
out="$(env HOME="$T/h3" bash "$SL" 2>/dev/null)"; rc=$?
[ "$rc" -ne 0 ] && [ -z "$out" ] && echo "PASS: wrong-shape cache: non-zero, no stdout" \
                                 || { echo "FAIL: rc=$rc out=$out"; fails=$((fails+1)); }

# Case 4 — stale cache (> 60 s old), fetch impossible (no creds): renders the stale
# values rather than going blank.
H4="$T/h4"; mkdir -p "$H4/.cache/claude-usage"
cat > "$H4/.cache/claude-usage/usage.json" <<'EOF'
{"limits": [
  {"kind": "session",    "percent": 60, "resets_at": "2026-09-16T00:00:00Z"},
  {"kind": "weekly_all", "percent": 85, "resets_at": "2026-09-20T00:00:00Z"}
]}
EOF
touch -d '10 minutes ago' "$H4/.cache/claude-usage/usage.json"
out="$(env HOME="$H4" bash "$SL" 2>/dev/null)"; rc=$?
expect "stale cache exit 0"        "rc=$rc" "rc=0"
expect "stale cache still renders" "$out"   "5h 60%"
expect "stale cache 7d window"     "$out"   "7d 85%"

# Case 5 — no weekly_scoped entry: the third window is omitted entirely.
H5="$T/h5"; mkdir -p "$H5/.cache/claude-usage"
cat > "$H5/.cache/claude-usage/usage.json" <<'EOF'
{"limits": [
  {"kind": "session",    "percent": 60, "resets_at": "2026-09-16T00:00:00Z"},
  {"kind": "weekly_all", "percent": 85, "resets_at": "2026-09-20T00:00:00Z"}
]}
EOF
out="$(env HOME="$H5" bash "$SL" 2>/dev/null)"; rc=$?
expect "no-scoped exit 0"    "rc=$rc" "rc=0"
expect "no-scoped 5h window" "$out"   "5h 60%"
grep -q "Opus" <<<"$out" && { echo "FAIL: scoped window leaked"; fails=$((fails+1)); } \
                         || echo "PASS: no third window without weekly_scoped"

[ "$fails" -eq 0 ] && echo "DEGRADED-CACHE: ALL PASS" || echo "DEGRADED-CACHE: $fails FAILURE(S)"
rm -rf "$T"
```

**Expected:** `DEGRADED-CACHE: ALL PASS`.

**Known quirk (pin, don't silently "fix"):** cases 2–3 exit non-zero through
`set -u` (`p5h: unbound variable`), *not* through the `|| exit 0` guard on the
`eval` line — `eval "$(jq …)"` discards jq's exit status (failed jq ⇒ empty
substitution ⇒ `eval ""` ⇒ 0), so the guard only fires on malformed jq
*output*, never on malformed input. The user-visible behavior is still fine
for a statusline (blank render, non-zero exit — Claude Code shows nothing), so
the script ships as-is; if this ever changes (guard moved inside the
substitution, or a shape check before `eval`), this file's cases 2–3 must be
deliberately re-pinned.

## Functional Test (LLM in the loop, install path)

The script is tested above; the *skill* is the install-and-wire wrapper:

1. Run the skill against a machine (or scratch user account) without the
   statusline installed. Expected: dependency check (Step 1), copy to
   `~/.claude/usage-statusline.sh` + `chmod +x` (Step 2), a **merged**
   `statusLine` block in `~/.claude/settings.json` — existing top-level keys
   preserved (Step 3), real absolute path, no `USERNAME` placeholder.
2. `jq . ~/.claude/settings.json` parses after the edit (merge did not
   corrupt JSON).
3. New Claude Code session renders the line. On the very first run the output
   is blank for a few seconds until `usage.json` populates — that is the
   Case 1 behavior above, not a defect.
4. No-op idempotency: re-running the skill on an installed machine must not
   duplicate the `statusLine` key or clobber unrelated settings.

## Expected Behaviors

- **Read-only world**: the script writes only under `$HOME/.cache/claude-usage/`
  (cache, locks, git count) and — only when refreshing an expiring token —
  `~/.claude/.credentials.json`. Nothing else is mutated.
- **Stale beats blank**: an unreachable usage API renders the last cached
  values (Case 4) rather than an empty statusline.
- **Concurrency**: fetch and commit-scan are `flock -n` guarded; a crashed run
  can leave a stale lock — SKILL.md troubleshooting says to delete
  `fetch.lock`/`git.lock` rather than the script retrying forever.
- **Commit scan scope**: only `.git` dirs at `$HOME` maxdepth 2; repos nested
  deeper or outside `$HOME` are not counted (pinned by construction: the
  fixture repo sits at exactly depth 2).
- **Resets format**: `resets_at` values must carry `Z` or fractional-seconds+
  offset (`sub("\\.[0-9]+\\+00:00$"; "Z")` strips only that shape) — a fixture
  using a bare `+00:00` offset without fractional seconds breaks
  `fromdateiso8601` and lands in the Case-2 blank path.
