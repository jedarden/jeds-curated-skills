# Self-Test: usage-statusline

The rendering core (`scripts/usage-statusline.sh`) is scriptable without an
LLM: point it at a fixture `$HOME` and assert on exit code, line count, and
content. Everything below runs against a throwaway `HOME`, never the real one —
the script derives its cache, locks, credentials, and commit scan from `$HOME`
alone, and with no `~/.claude/.credentials.json` in the fixture the fetch path
bails before any network call. (The fetch-path tests in "Format-drift and
failure isolation" put a stub `curl` on `PATH` instead, with fake credentials —
still no network.)

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

# Run 1: the commit count warms asynchronously (count_commits is
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

# Case 1 — cache file absent (first ever run): the quota data is unavailable, not
# the whole line. Says so, and the host and commit segments still render.
H1="$T/h1"
out="$(env HOME="$H1" bash "$SL" 2>"$T/err1")"; rc=$?
expect "missing cache exit 0"        "rc=$rc" "rc=0"
expect "missing cache says so"       "$out"   "usage n/a"
expect "missing cache keeps host"    "$out"   "cpu "
expect "missing cache keeps commits" "$out"   "⎇"
[ ! -s "$T/err1" ]          && echo "PASS: missing cache stderr empty" || { echo "FAIL: stderr"; fails=$((fails+1)); }

# Case 2 — empty (zero-byte) cache: exit 0, usage n/a, and the reason is logged.
mkdir -p "$T/h2/.cache/claude-usage" && : > "$T/h2/.cache/claude-usage/usage.json"
out="$(env HOME="$T/h2" bash "$SL" 2>"$T/err2")"; rc=$?
expect "empty cache exit 0"        "rc=$rc" "rc=0"
expect "empty cache says so"       "$out"   "usage n/a"
expect "empty cache keeps host"    "$out"   "cpu "
grep -q "zero windows" "$T/h2/.cache/claude-usage/statusline.log" \
  && echo "PASS: empty cache logged" || { echo "FAIL: nothing in statusline.log"; fails=$((fails+1)); }
[ ! -s "$T/err2" ]          && echo "PASS: empty cache stderr empty" || { echo "FAIL: stderr"; fails=$((fails+1)); }

# Case 3 — valid JSON, wrong shape ({}): same outcome as case 2.
mkdir -p "$T/h3/.cache/claude-usage" && echo '{}' > "$T/h3/.cache/claude-usage/usage.json"
out="$(env HOME="$T/h3" bash "$SL" 2>/dev/null)"; rc=$?
expect "wrong-shape cache exit 0"  "rc=$rc" "rc=0"
expect "wrong-shape cache says so" "$out"   "usage n/a"

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

**Re-pinned 2026-09-23** (bead `jedscura-db44b85b`). Cases 1–3 used to pin a
blank line and a non-zero exit (`p5h: unbound variable` through `set -u`, with
`eval "$(jq …)"` discarding jq's exit status). That was the same defect that
blanked the whole statusline on 2026-09-23 when the API returned a whole-second
timestamp, so the pin was deliberately reversed: unreadable quota data now
costs the quota segments only. Do not restore the old expectations.

## Format-drift and failure isolation

Everything the script reads from outside itself — the usage payload, `/proc`,
git, the network, the credentials file — can change shape without notice. This
block pins the contract that one bad input costs one segment, never the line:

- the 2026-09-23 incident shape (whole-second `+00:00` reset) and every other
  `resets_at` spelling of the same instant, including numeric offsets and epoch
  seconds/milliseconds; unusable values keep the window with unknown pace;
- odd `percent` values (float, string, null, negative, absent, over 100);
- a hostile `display_name` is data, never code (the old `eval` executed
  `$(…)` in it) and control characters cannot reach the terminal;
- several scoped caps, unknown limit kinds, junk in `limits[]`, a missing
  session limit, and the legacy `five_hour`/`seven_day` fields as a fallback;
- nine kinds of unreadable cache, a first run, a read-only cache dir, a stale
  cache (marked, not hidden), and the no-trailing-newline pin;
- the fetch path against a stub `curl`: a good response replaces the cache
  atomically at mode 600; a 200 with garbage or an HTTP error keeps the last
  good cache and is logged; tokens never appear in `curl`'s argv; a malformed
  refresh response leaves the credentials file byte-identical, a valid one
  rotates the tokens, preserves every other field and keeps mode 600;
- rendering never waits on the network (a 5 s-slow API still renders in < 2 s).

Run it against any candidate script with `SL=/path/to/script`. Against the
pre-hardening script (commit `56fa105`) it fails 58 checks; the point of each
case is that it can fail.

```bash
REPO="${REPO:-$HOME/jeds-curated-skills}"
SL="${SL:-$REPO/usage-statusline/scripts/usage-statusline.sh}"
T="$(mktemp -d)"; fails=0
ok()  { echo "PASS: $1"; }
bad() { echo "FAIL: $1"; fails=$((fails+1)); }
expect() { [[ "$2" == *"$3"* ]] && ok "$1" || bad "$1 — wanted [$3] in: $2"; }
refute() { [[ "$2" != *"$3"* ]] && ok "$1" || bad "$1 — found [$3] in: $2"; }
fmt() { date -u -d "@$1" "$2" 2>/dev/null || date -u -r "$1" "$2"; }   # GNU, then BSD
seg7() { sed -E 's/.*(7d +[0-9]+% [█▓▒░]+ ~[^ ]+).*/\1/'; }
mkhome() { H="$T/$1"; C="$H/.cache/claude-usage"; mkdir -p "$C"; echo 2 > "$C/git_commits.txt"; }
put() { printf '%s' "$1" > "$C/usage.json"; }          # fresh mtime => no fetch
doc() { put "{\"limits\":[$(IFS=,; echo "$*")]}"; }
run() { raw="$(env HOME="$H" bash "$SL" 2>"$H/stderr.txt")"; rc=$?
        out="$(printf '%s' "$raw" | sed 's/\x1b\[[0-9;]*m//g')"; }

NOW=$(date +%s); E5=$((NOW + 4*3600)); E7=$((NOW + 5*86400))
Z5=$(fmt $E5 +%Y-%m-%dT%H:%M:%SZ); Z7=$(fmt $E7 +%Y-%m-%dT%H:%M:%SZ)
S='{"kind":"session","percent":12,"resets_at":"'$Z5'"}'
W='{"kind":"weekly_all","percent":34,"resets_at":"'$Z7'"}'
sco() { echo '{"kind":"weekly_scoped","percent":'"$1"',"resets_at":"'"$Z7"'","scope":{"model":{"display_name":"'"$2"'"}}}'; }

echo "== 1. The 2026-09-23 incident: scoped limit with a whole-second +00:00 reset"
mkhome inc
doc "$S" "$W" '{"kind":"weekly_scoped","percent":0,"resets_at":"'"$(fmt $E7 +%Y-%m-%dT%H:%M:%S)"'+00:00","scope":{"model":{"display_name":"Fable"}}}'
run
expect "exit 0" "rc=$rc" "rc=0"
expect "5h renders" "$out" "5h 12%"; expect "7d renders" "$out" "7d 34%"; expect "scoped renders" "$out" "Fable  0%"
expect "host + commit segments" "$out" "⎇ 2"

echo "== 2. resets_at spellings of one instant must all render the same 7d segment"
mkhome ts; ref=""
i=0
for v in "\"$Z7\"" "\"$(fmt $E7 +%Y-%m-%dT%H:%M:%S).123456+00:00\"" "\"$(fmt $E7 +%Y-%m-%dT%H:%M:%S)+00:00\"" \
         "\"$(fmt $E7 +%Y-%m-%dT%H:%M:%S).500Z\"" "\"$(fmt $((E7+19800)) +%Y-%m-%dT%H:%M:%S)+05:30\"" \
         "\"$(fmt $((E7-14400)) +%Y-%m-%dT%H:%M:%S)-04:00\"" "\"$(fmt $((E7-14400)) +%Y-%m-%dT%H:%M:%S)-0400\"" \
         "\"$(fmt $E7 +%Y-%m-%dT%H:%M:%S)\"" "$E7" "$((E7*1000))"; do
  i=$((i+1)); doc "$S" "{\"kind\":\"weekly_all\",\"percent\":34,\"resets_at\":$v}"; run
  s="$(printf '%s' "$out" | seg7)"; [ -z "$ref" ] && ref="$s"
  [ "$rc" -eq 0 ] && [ "$s" = "$ref" ] && ok "spelling $i -> $s" || bad "spelling $i ($v): rc=$rc got [$s] want [$ref]"
done
for v in null '"garbage"' '""' '{}' '[]' true; do
  doc "$S" "{\"kind\":\"weekly_all\",\"percent\":34,\"resets_at\":$v}"; run
  [ "$rc" -eq 0 ] && [[ "$out" == *"7d 34%"* && "$out" == *"5h 12%"* ]] \
    && ok "unusable resets_at $v: window kept, pace unknown" || bad "unusable resets_at $v: rc=$rc out=$out"
done

echo "== 3. percent spellings"
mkhome pct
for pair in '7.5|7' '"7"|7' 'null|0' '"abc"|0' '-5|0' '250|250' '[]|0'; do
  v="${pair%|*}"; want="${pair#*|}"
  doc "$S" "{\"kind\":\"weekly_all\",\"percent\":$v,\"resets_at\":\"$Z7\"}"; run
  [ "$rc" -eq 0 ] && [[ "$out" == *"7d "*"$want%"* ]] && ok "percent $v -> $want%" || bad "percent $v: rc=$rc out=$out"
done
doc "$S" "{\"kind\":\"weekly_all\",\"resets_at\":\"$Z7\"}"; run
[ "$rc" -eq 0 ] && [[ "$out" == *"7d  0%"* ]] && ok "percent absent -> 0%" || bad "percent absent: $out"

echo "== 4. Hostile display_name is data, never code"
mkhome evil; rm -f "$T/PWNED"
doc "$S" "$W" "$(sco 8 "Opus \$(touch $T/PWNED) \`touch $T/PWNED\`")"; run
[ ! -e "$T/PWNED" ] && ok "no command executed" || bad "display_name executed a command"
expect "label shown as inert text" "$out" 'Opus $(touch'
doc "$S" "$W" "$(sco 8 'Op\u001b[31mus\u0007')"; run
refute "no injected ANSI escape" "$raw" $'\x1b[31mus'
refute "no BEL" "$raw" $'\x07'
doc "$S" "$W" "$(sco 8 '')"; run;  expect "empty name -> Scoped" "$out" "Scoped  8%"
doc "$S" "$W" '{"kind":"weekly_scoped","percent":8,"resets_at":"'$Z7'","scope":{"model":{"display_name":{"x":1}}}}'; run
expect "non-string name -> Scoped" "$out" "Scoped  8%"

echo "== 5. Shape drift"
mkhome shape
doc "$S" "$W" "$(sco 8 Opus)" "$(sco 61 Sonnet)"; run
expect "several scoped caps: tightest shown" "$out" "Sonnet 61%"; refute "loser hidden" "$out" "Opus"
doc "$S" "$W" '{"kind":"weekly_experimental","percent":99,"resets_at":"'$Z7'"}'; run
expect "unknown kind ignored, others render" "$out" "7d 34%"; refute "unknown kind not shown" "$out" "99%"
doc "$W"; run;  expect "no session limit: 7d still renders" "$out" "7d 34%"; refute "no phantom 5h" "$out" "5h"
doc "$S" 'null' '"str"' '7' '{"kind":"weekly_all","percent":34,"resets_at":"'$Z7'"}'; run
expect "junk entries in limits[] skipped" "$out" "7d 34%"
put "{\"five_hour\":{\"utilization\":12.0,\"resets_at\":\"$Z5\"},\"seven_day\":{\"utilization\":34.0,\"resets_at\":\"$Z7\"},\"seven_day_opus\":{\"utilization\":8.0,\"resets_at\":\"$Z7\"}}"; run
expect "legacy fields used when limits is gone (5h)" "$out" "5h 12%"; expect "legacy 7d" "$out" "7d 34%"
expect "legacy scoped labelled" "$out" "Opus  8%"

echo "== 6. Unreadable cache never blanks the line"
n=0
for body in '' '{}' '[]' 'null' 'not json' '{"limits":[{"kind":"sess' '<html>502 Bad Gateway</html>' '{"limits":"nope"}' '{"limits":[]}'; do
  n=$((n+1)); mkhome bad$n; put "$body"; run
  [ "$rc" -eq 0 ] && [[ "$out" == *"usage n/a"* && "$out" == *"cpu "* && "$out" == *"⎇ 2"* && "$out" != *$'\n'* ]] \
    && ok "bad cache #$n renders usage n/a + host + commits" || bad "bad cache #$n [$body]: rc=$rc out=$out"
done
grep -q "zero windows" "$C/statusline.log" && ok "failure is in the log" || bad "nothing logged"
[ ! -s "$H/stderr.txt" ] && ok "nothing on stderr" || bad "stderr not empty"
mkhome first; run
[ "$rc" -eq 0 ] && [[ "$out" == *"usage n/a"* && "$out" == *"⎇ 2"* ]] && ok "first run (no cache): usage n/a, exit 0" || bad "first run: $out"

echo "== 7. Staleness is visible; an unwritable cache dir does not matter"
mkhome old; doc "$S" "$W"; touch -d '2 hours ago' "$C/usage.json"; run
expect "2h-old cache still renders" "$out" "5h 12%"; expect "marked stale" "$out" "stale 2h"
mkhome recent; doc "$S" "$W"; touch -d '10 minutes ago' "$C/usage.json"; run
refute "10-min-old cache not flagged" "$out" "stale"
mkhome ro; doc "$S" "$W"; chmod 500 "$C"; run; chmod 700 "$C"
[ "$rc" -eq 0 ] && [[ "$out" == *"7d 34%"* ]] && ok "read-only cache dir: renders, exit 0" || bad "read-only cache dir: rc=$rc out=$out"
mkhome nl; doc "$S" "$W"; env HOME="$H" bash "$SL" > "$H/raw.sl" 2>/dev/null
[ "$(tail -c1 "$H/raw.sl" | wc -l)" -eq 0 ] && ok "no trailing newline" || bad "trailing newline"

echo "== 8. Fetch path (stub curl on PATH; fake credentials; no network)"
STUB="$T/stub"; mkdir -p "$STUB"
cat > "$STUB/curl" <<'STUBEOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$STUB_DIR/argv.log"; cat >> "$STUB_DIR/stdin.log"
url=""; for a in "$@"; do case "$a" in http*) url="$a" ;; esac; done
[ -n "$STUB_SLEEP" ] && sleep "$STUB_SLEEP"
case "$url" in
  *oauth/token) cat "$STUB_DIR/token.resp" 2>/dev/null; exit "${STUB_TOKEN_RC:-0}" ;;
  *oauth/usage) cat "$STUB_DIR/usage.resp" 2>/dev/null; exit "${STUB_USAGE_RC:-0}" ;;
esac
STUBEOF
chmod +x "$STUB/curl"
mkfetch() { # <name> <access-token-expiry-offset-seconds>
  mkhome "$1"; mkdir -p "$H/.claude"; rm -f "$STUB"/*.log
  printf '{"claudeAiOauth":{"accessToken":"FAKE-ACCESS-OLD","refreshToken":"FAKE-REFRESH-OLD","expiresAt":%s,"scopes":["a","b"],"subscriptionType":"max"}}' \
    "$(( (NOW + $2) * 1000 ))" > "$H/.claude/.credentials.json"
  chmod 600 "$H/.claude/.credentials.json"
  doc "$S" "$W"; touch -d '5 minutes ago' "$C/usage.json"          # stale => a fetch is due
  cp "$C/usage.json" "$T/cache.before"
}
frun() { env HOME="$H" PATH="$STUB:$PATH" STUB_DIR="$STUB" STUB_SLEEP="$STUB_SLEEP" STUB_USAGE_RC="$STUB_USAGE_RC" bash "$SL" 2>/dev/null; }
wait_attempt() { for _ in $(seq 1 50); do [ -e "$C/usage.attempt" ] && sleep 0.4 && return; sleep 0.1; done; }
GOOD='{"limits":[{"kind":"session","percent":55,"resets_at":"'$Z5'"},{"kind":"weekly_all","percent":34,"resets_at":"'$Z7'"}]}'

mkfetch fok 3600; printf '%s' "$GOOD" > "$STUB/usage.resp"; frun >/dev/null; wait_attempt
jq -e '.limits[0].percent == 55' "$C/usage.json" >/dev/null 2>&1 && ok "fetch replaced the cache" || bad "cache not replaced"
[ "$(stat -c %a "$C/usage.json")" = "600" ] && ok "cache is mode 600" || bad "cache mode $(stat -c %a "$C/usage.json")"
ls "$C" | grep -q '\.tmp\.' && bad "temp file left behind" || ok "no temp files left behind"
grep -q 'FAKE-ACCESS-OLD' "$STUB/argv.log" && bad "access token in curl argv" || ok "access token not in argv"
grep -q 'Authorization: Bearer FAKE-ACCESS-OLD' "$STUB/stdin.log" && ok "token delivered on curl's stdin" || bad "token not delivered"

mkfetch fgarbage 3600; printf '<html>200 OK</html>' > "$STUB/usage.resp"; frun >/dev/null; wait_attempt
cmp -s "$C/usage.json" "$T/cache.before" && ok "garbage 200: last good cache kept" || bad "garbage overwrote the cache"
[ -s "$C/usage.rejected.json" ] && grep -q 'shape check' "$C/statusline.log" && ok "garbage 200: kept aside + logged" || bad "rejected response not recorded"

mkfetch ffail 3600; printf '%s' "$GOOD" > "$STUB/usage.resp"; STUB_USAGE_RC=22 frun >/dev/null; wait_attempt
cmp -s "$C/usage.json" "$T/cache.before" && grep -q 'fetch failed (curl exit 22)' "$C/statusline.log" \
  && ok "HTTP error: cache kept, exit code logged" || bad "curl failure handling"

mkfetch fref -60; cp "$H/.claude/.credentials.json" "$T/creds.before"
printf '{"unexpected":"shape"}' > "$STUB/token.resp"; printf '%s' "$GOOD" > "$STUB/usage.resp"; frun >/dev/null; wait_attempt
cmp -s "$H/.claude/.credentials.json" "$T/creds.before" && ok "malformed refresh response: credentials byte-identical" || bad "credentials modified by a bad refresh"
grep -q 'credentials untouched' "$C/statusline.log" && ok "malformed refresh logged" || bad "malformed refresh not logged"

mkfetch fref2 -60
printf '{"accessToken":"FAKE-ACCESS-NEW","refreshToken":"FAKE-REFRESH-NEW","expiresAt":%s}' "$(( (NOW + 28800) * 1000 ))" > "$STUB/token.resp"
printf '%s' "$GOOD" > "$STUB/usage.resp"; frun >/dev/null; wait_attempt
jq -e '.claudeAiOauth | .accessToken == "FAKE-ACCESS-NEW" and .refreshToken == "FAKE-REFRESH-NEW" and .subscriptionType == "max" and (.scopes | length == 2)' \
   "$H/.claude/.credentials.json" >/dev/null 2>&1 && ok "valid refresh: tokens rotated, other fields preserved" || bad "refresh not applied correctly"
[ "$(stat -c %a "$H/.claude/.credentials.json")" = "600" ] && ok "credentials stay mode 600" || bad "credentials mode $(stat -c %a "$H/.claude/.credentials.json")"
grep -qE 'FAKE-(REFRESH|ACCESS)' "$STUB/argv.log" && bad "a token reached curl's argv" || ok "no token in any curl argv"
grep -q 'Bearer FAKE-ACCESS-NEW' "$STUB/stdin.log" && ok "refreshed token used for the usage call" || bad "new token not used"

echo "== 9. Rendering never waits on the network"
mkfetch slow 3600; printf '%s' "$GOOD" > "$STUB/usage.resp"
t0=$(date +%s.%N); STUB_SLEEP=5 frun >/dev/null; t1=$(date +%s.%N)
awk -v a="$t0" -v b="$t1" 'BEGIN{exit !(b-a < 2.0)}' && ok "render returned in $(awk -v a="$t0" -v b="$t1" 'BEGIN{printf "%.2f", b-a}')s with a 5s-slow API" || bad "render blocked on the network"
sleep 5.5

echo "-----"
rm -rf "$T"
[ "$fails" -eq 0 ] && echo "FORMAT-DRIFT: ALL PASS" || echo "FORMAT-DRIFT: $fails FAILURE(S)"
```

**Expected:** `FORMAT-DRIFT: ALL PASS`. Exact bars and `~`-times are not
pinned across spellings — only that every spelling of one instant renders the
*same* 7d segment. The fixtures pick instants far from any rounding boundary
(`now + 5 d`, `now + 4 h`), so the equality holds across the sub-second gaps
between runs.

## Functional Test (LLM in the loop, install path)

The script is tested above; the *skill* is the install-and-wire wrapper:

1. Run the skill against a machine (or scratch user account) without the
   statusline installed. Expected: dependency check (Step 1), copy to
   `~/.claude/usage-statusline.sh` + `chmod +x` (Step 2), a **merged**
   `statusLine` block in `~/.claude/settings.json` — existing top-level keys
   preserved (Step 3), real absolute path, no `USERNAME` placeholder.
2. `jq . ~/.claude/settings.json` parses after the edit (merge did not
   corrupt JSON).
3. New Claude Code session renders the line. On the very first run the quota
   segments read `usage n/a` (with cpu/ram and `⎇` still shown) for a few
   seconds until `usage.json` populates — that is the Case 1 behavior
   above, not a defect.
4. No-op idempotency: re-running the skill on an installed machine must not
   duplicate the `statusLine` key or clobber unrelated settings.

## Expected Behaviors

- **Always exits 0, always one line.** Any input the script cannot use costs
  the segment that needed it, not the line: quota data that is missing or
  unparseable renders `usage n/a`; an unreadable `/proc` drops cpu/ram; a
  failed commit scan renders `⎇ 0`. The harness draws nothing for a non-zero
  exit, so a non-zero exit is always a bug (Format-drift block).
- **Nothing from the API is eval'd or shell-expanded.** jq emits plain
  `US`-delimited records and `read` splits them; a hostile `display_name` is
  printable-ASCII-filtered, capped at 12 characters, and printed as text.
- **Writes**: only under `$HOME/.cache/claude-usage/` (usage cache, git count,
  locks, `usage.attempt`, `usage.rejected.json`, `statusline.log`) and — only
  when refreshing an expiring token — `~/.claude/.credentials.json`. Cache and
  credential writes are temp-file + `mv`, mode 600 (`umask 077`). A refresh
  response is validated before it may touch the credentials, and the file is
  only replaced if its refresh token is unchanged since it was read.
- **No credential on an argv.** The access token reaches `curl` as a stdin
  config line and the refresh token via stdin/environment — never a command
  line, so nothing shows in `ps`.
- **Stale beats blank, and says so**: an unreachable usage API renders the last
  cached values (Case 4). A cache older than 15 minutes adds a dim
  `stale <age>` segment; a response that fails the shape check is kept in
  `usage.rejected.json`, logged, and does NOT replace the last good cache.
- **Rendering never waits on the network.** The usage fetch and the commit scan
  run detached (stdout/stdin closed); a slow API delays the *next* render's
  data, not this one. Fetch attempts are rate-limited to one per 60 s by
  `usage.attempt` whether or not they succeed.
- **Diagnosis**: `~/.cache/claude-usage/statusline.log` (last ~200 lines; stderr
  is redirected there). Persistent parse problems log once per cache version.
- **Concurrency**: fetch and commit-scan are `flock -n` guarded where `flock`
  exists (skipped, not fatal, where it does not); a crashed run can leave a
  stale lock — SKILL.md troubleshooting says to delete `fetch.lock`/`git.lock`
  rather than the script retrying forever.
- **Commit scan scope**: only `.git` dirs at `$HOME` maxdepth 2; repos nested
  deeper or outside `$HOME` are not counted (pinned by construction: the
  fixture repo sits at exactly depth 2). Each repo scan is capped at 10 s.
- **Resets format**: `resets_at` may be ISO-8601 with or without fractional
  seconds and with `Z`, no zone, or any numeric UTC offset, or epoch
  seconds/milliseconds; anything else keeps the window with unknown pace
  (`~—`). The original parser accepted only `.<fraction>+00:00`, and the first
  whole-second offset the API sent blanked the statusline (2026-09-23) — the
  Format-drift block pins every spelling of one instant to the same render.
- **Scoped caps**: with several `weekly_scoped` limits the tightest (highest
  percent) is shown; unknown limit kinds are ignored; if `limits` disappears
  the legacy `five_hour` / `seven_day` / `seven_day_{opus,sonnet}` fields are
  used.
