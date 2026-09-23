#!/usr/bin/env bash
#
# usage-statusline.sh - Claude Code statusLine command
#
# One line: 5h and 7d quota windows against elapsed-time pace, an optional
# model-scoped weekly cap, host cpu/ram, and the count of Claude-co-authored
# commits this week.
#
# ROBUSTNESS CONTRACT. This runs on every prompt and its stdout is the whole
# UI, so it degrades instead of failing as a unit. Each rule below exists
# because the previous version broke it (2026-09-23: the usage API started
# returning a whole-second timestamp, jq aborted, `set -u` killed the script,
# and the entire statusline went blank):
#
#   * No `set -e` / `set -u` / `pipefail`. Every input (usage JSON, /proc, git,
#     the cache) is untrusted: defaulted, and validated as a plain integer
#     before any arithmetic touches it.
#   * Each segment renders in its own subshell. Bash aborts the enclosing
#     command list on an arithmetic error; a subshell makes that cost one
#     segment, never the line.
#   * Always exits 0 (the harness draws nothing for a non-zero exit).
#   * Nothing from the API is eval'd or shell-expanded. jq emits plain
#     delimited records and `read` splits them. (The old eval executed a
#     `$(...)` inside a scoped limit's display_name.)
#   * Rendering never waits on the network: the usage fetch and the commit
#     scan run detached and land in the cache for the next render.
#   * Cache and credential writes are atomic (temp + mv). An API response is
#     shape-checked before it may replace the cache; a token-refresh response
#     is validated before it may touch ~/.claude/.credentials.json.
#   * Credentials never appear on an argv (visible in `ps`), umask is 077, and
#     the credentials file is only replaced if it is unchanged since we read it.
#   * Failures are logged to $CACHE_DIR/statusline.log, and stderr is
#     redirected there, so a bug is diagnosable without a repro and never
#     scribbles on the prompt. A stale cache is marked, and missing quota data
#     renders as `usage n/a` while the host and commit segments still show.
#
# Portability: bash 3.2+, GNU or BSD stat. flock and timeout are used when
# present and skipped when not.

umask 077

CACHE_DIR="$HOME/.cache/claude-usage"
CACHE_FILE="$CACHE_DIR/usage.json"
REJECT_FILE="$CACHE_DIR/usage.rejected.json"
ATTEMPT_FILE="$CACHE_DIR/usage.attempt"
LOCK_FILE="$CACHE_DIR/fetch.lock"
LOG_FILE="$CACHE_DIR/statusline.log"
CREDS="$HOME/.claude/.credentials.json"
CACHE_TTL=60
STALE_AFTER=900
LOG_MAX_BYTES=65536

GIT_CACHE="$CACHE_DIR/git_commits.txt"
GIT_LOCK="$CACHE_DIR/git.lock"
GIT_CACHE_TTL=300

USAGE_URL="https://api.anthropic.com/api/oauth/usage"
TOKEN_URL="https://platform.claude.com/v1/oauth/token"
USER_AGENT="claude-code/2.1.78"

mkdir -p "$CACHE_DIR" 2>/dev/null

# From here on stderr lands in the log. The probe avoids the failed-exec
# message reaching the terminal when the cache dir is unwritable.
if ( : >>"$LOG_FILE" ) 2>/dev/null; then exec 2>>"$LOG_FILE"; else exec 2>/dev/null; fi

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

have() { command -v "$1" >/dev/null 2>&1; }

log() { printf '%s %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*" >&2; }

# Keep only the tail of the log. Truncate in place (not mv) so detached jobs
# still holding the append descriptor keep logging to the live file.
trim_log() {
    local sz tmp
    sz=$(stat -c %s "$LOG_FILE" 2>/dev/null || stat -f %z "$LOG_FILE" 2>/dev/null || echo 0)
    if (( $(int "$sz" 0) > LOG_MAX_BYTES )); then
        tmp="$LOG_FILE.tmp.$$"
        tail -n 200 "$LOG_FILE" >"$tmp" 2>/dev/null && cat "$tmp" >"$LOG_FILE" 2>/dev/null
        rm -f "$tmp"
    fi
}

# int <value> [default] - echo value if it is a plain integer, else default.
# Leading zeros are stripped via 10# ("08" is an octal error in arithmetic),
# and the length cap keeps the result inside 64-bit range.
int() {
    local v="$1" d="${2:-0}" neg=""
    if [[ "$v" == -* ]]; then neg="-"; v="${v#-}"; fi
    if [[ "$v" =~ ^[0-9]{1,15}$ ]]; then
        printf '%s%d' "$neg" "$((10#$v))"
    else
        printf '%s' "$d"
    fi
}

mtime() { stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || echo 0; }

run_timeout() { if have timeout; then timeout "$@"; else shift; "$@"; fi; }

# Log a message once per cache-file version: a statusline re-renders many
# times a minute, and one persistent problem must not fill the log.
log_once() { # <marker-name> <version-key> <message...>
    local mark="$CACHE_DIR/$1.logged" key="$2"
    shift 2
    [[ "$(cat "$mark" 2>/dev/null)" == "$key" ]] && return 0
    log "$*"
    printf '%s\n' "$key" >"$mark" 2>/dev/null
}

# ---------------------------------------------------------------------------
# Detached refreshers. Each is launched in the background with stdout/stdin
# closed so the harness never waits on them; stderr is the log.
# ---------------------------------------------------------------------------

# Renew the OAuth token. Prints the new access token on success. The refresh
# token travels to curl on stdin and to jq through the environment, never
# argv. The response is validated first (a 200 with an unexpected body would
# otherwise write null tokens over the credentials and log the user out), and
# the file is only replaced if its refresh token is still the one we read.
refresh_token() {
    local rt resp rc cur tmp new
    rt=$(jq -r '.claudeAiOauth.refreshToken // empty' "$CREDS" 2>/dev/null)
    [[ -n "$rt" ]] || { log "refresh skipped: no refresh token"; return 1; }

    resp=$(RT="$rt" jq -nc '{grantType: "refresh_token", refreshToken: env.RT}' 2>/dev/null \
        | curl -sf --max-time 5 -X POST "$TOKEN_URL" \
            -H "Content-Type: application/json" -H "User-Agent: $USER_AGENT" \
            --data-binary @- 2>/dev/null)
    rc=$?
    if ! jq -e '(.accessToken | type == "string" and length > 0)
                and (.refreshToken | type == "string" and length > 0)
                and (.expiresAt | type == "number" and . > 0)' <<<"$resp" >/dev/null 2>&1; then
        log "refresh failed: response missing accessToken/refreshToken/expiresAt (curl exit $rc); credentials untouched"
        return 1
    fi

    cur=$(jq -r '.claudeAiOauth.refreshToken // empty' "$CREDS" 2>/dev/null)
    if [[ "$cur" != "$rt" ]]; then
        log "refresh discarded: credentials changed while refreshing"
        return 1
    fi

    tmp="$CREDS.sl-tmp.$$"
    if R="$resp" jq '(env.R | fromjson) as $r
                     | .claudeAiOauth.accessToken = $r.accessToken
                     | .claudeAiOauth.refreshToken = $r.refreshToken
                     | .claudeAiOauth.expiresAt = $r.expiresAt' "$CREDS" >"$tmp" 2>/dev/null \
        && [[ -s "$tmp" ]] && mv -f "$tmp" "$CREDS"; then
        # -n: this job's stdin is /dev/null, and jq without it would wait on that.
        new=$(R="$resp" jq -nr 'env.R | fromjson | .accessToken' 2>/dev/null)
        printf '%s' "$new"
    else
        rm -f "$tmp"
        log "refresh failed: could not rewrite credentials"
        return 1
    fi
}

fetch_usage() {
    local now token expires_at now_ms result rc tmp
    if ! have jq || ! have curl; then
        log "fetch skipped: jq and curl are required"
        return 0
    fi

    if have flock; then
        exec 9>"$LOCK_FILE" || return 0
        flock -n 9 || return 0
    fi

    # Re-check under the lock: another render may have just fetched.
    now=$(int "$(date +%s)" 0)
    (( now - $(int "$(mtime "$CACHE_FILE")" 0) > CACHE_TTL )) || return 0
    (( now - $(int "$(mtime "$ATTEMPT_FILE")" 0) > CACHE_TTL )) || return 0
    : >"$ATTEMPT_FILE"

    [[ -r "$CREDS" ]] || { log "fetch skipped: $CREDS is not readable"; return 0; }
    token=$(jq -r '.claudeAiOauth.accessToken // empty' "$CREDS" 2>/dev/null)
    expires_at=$(int "$(jq -r '.claudeAiOauth.expiresAt // 0' "$CREDS" 2>/dev/null)" 0)
    now_ms=$(( now * 1000 ))
    if [[ -z "$token" ]] || (( now_ms + 300000 >= expires_at )); then
        token=$(refresh_token) || token=""
    fi
    [[ -n "$token" ]] || return 0

    # The token is handed to curl as a stdin config line, not -H, so it is
    # never in argv; and it must be header-safe to be embedded in that line.
    if [[ ! "$token" =~ ^[A-Za-z0-9._~+/=-]+$ ]]; then
        log "fetch skipped: access token has unexpected characters"
        return 0
    fi
    result=$(printf 'header = "Authorization: Bearer %s"\n' "$token" \
        | curl -sf --max-time 3 -K - \
            -H "anthropic-beta: oauth-2025-04-20" -H "User-Agent: $USER_AGENT" \
            "$USAGE_URL" 2>/dev/null)
    rc=$?
    if (( rc != 0 )) || [[ -z "$result" ]]; then
        log "fetch failed (curl exit $rc)"
        return 0
    fi

    # Only a recognisable usage document may replace the cache. Anything else
    # is kept aside for diagnosis and the last good cache keeps serving (and
    # goes visibly stale) rather than being overwritten with garbage.
    if ! jq -e 'type == "object"
                and ((.limits | type == "array") or (.five_hour | type == "object"))' \
            <<<"$result" >/dev/null 2>&1; then
        log "fetch: response failed the shape check; kept previous cache, response saved to $REJECT_FILE"
        printf '%s\n' "$result" >"$REJECT_FILE"
        return 0
    fi
    tmp="$CACHE_FILE.tmp.$$"
    if printf '%s\n' "$result" >"$tmp" && mv -f "$tmp" "$CACHE_FILE"; then
        :
    else
        rm -f "$tmp"
        log "fetch: could not write $CACHE_FILE"
    fi
}

count_commits() {
    local now total=0 c gitdir repo tmp
    have git || { log "commit scan skipped: git not found"; return 0; }

    if have flock; then
        exec 8>"$GIT_LOCK" || return 0
        flock -n 8 || return 0
    fi
    now=$(int "$(date +%s)" 0)
    (( now - $(int "$(mtime "$GIT_CACHE")" 0) > GIT_CACHE_TTL )) || return 0

    while IFS= read -r gitdir; do
        repo="${gitdir%/.git}"
        c=$(run_timeout 10 git -C "$repo" log --since="7 days ago" \
            --grep="Co-Authored-By: Claude" --format="%H" 2>/dev/null | wc -l | tr -d ' ')
        total=$(( total + $(int "$c" 0) ))
    done < <(run_timeout 20 find "$HOME" -maxdepth 2 -name ".git" -type d 2>/dev/null)

    tmp="$GIT_CACHE.tmp.$$"
    if printf '%s\n' "$total" >"$tmp" && mv -f "$tmp" "$GIT_CACHE"; then :; else rm -f "$tmp"; fi
}

NOW=$(int "$(date +%s)" 0)
CACHE_MTIME=$(int "$(mtime "$CACHE_FILE")" 0)

if (( NOW - CACHE_MTIME > CACHE_TTL )) \
    && (( NOW - $(int "$(mtime "$ATTEMPT_FILE")" 0) > CACHE_TTL )); then
    fetch_usage >/dev/null </dev/null &
fi
if (( NOW - $(int "$(mtime "$GIT_CACHE")" 0) > GIT_CACHE_TTL )); then
    count_commits >/dev/null </dev/null &
fi

# ---------------------------------------------------------------------------
# Parse the cached usage document.
#
# One jq program turns whatever the API returned into at most three records:
#     <tag> US <label> US <percent> US <hours-to-exhaust> US <elapsed-window-%>
# (US = ASCII unit separator; a non-whitespace IFS char keeps empty fields).
# Every value is coerced and every limit is wrapped in try, so an odd field
# drops that one window, not the parse. Timestamps may be ISO-8601 with or
# without fractional seconds and with Z or any numeric UTC offset, or epoch
# seconds/milliseconds. If `.limits` is ever renamed or dropped, the legacy
# five_hour/seven_day/seven_day_{opus,sonnet} fields still present in the
# payload are used instead. When several scoped caps exist, the tightest shows.
# ---------------------------------------------------------------------------

JQ_PROG=$(cat <<'EOF'
# `capture` yields NO output (not an error) on a non-matching string, so the
# try/catch alone would let `empty` escape and silently drop the window; the
# trailing `// null` turns "no output" into "unknown reset".
def epoch:
  (try (
    if type == "number" then (if . > 100000000000 then . / 1000 else . end)
    elif type == "string" then
      capture("^(?<d>[0-9]{4}-[0-9]{2}-[0-9]{2})[T ](?<t>[0-9]{2}:[0-9]{2}:[0-9]{2})(\\.[0-9]+)?(?<z>Z|[+-][0-9]{2}:?[0-9]{2})?$") as $m
      | (($m.d + "T" + $m.t + "Z") | fromdateiso8601) as $t
      | ($m.z // "Z") as $z
      | (if $z == "Z" then 0
         else ($z | capture("^(?<s>[+-])(?<h>[0-9]{2}):?(?<m>[0-9]{2})$")) as $o
              | (($o.h | tonumber) * 3600 + ($o.m | tonumber) * 60)
                * (if $o.s == "-" then -1 else 1 end)
         end) as $off
      | $t - $off
    else null end
  ) catch null) // null;

def num:
  try (if type == "string" then tonumber else . end
       | if type == "number" then . else null end) catch null;

def cpct: ((num // 0) | if . < 0 then 0 elif . > 999 then 999 else . end | floor);

def timepct($reset; $w):
  if $reset == null then 0
  else ((((($w - ((($reset - (now | floor)) / 3600))) / $w) * 100)
        | if . < 0 then 0 elif . > 100 then 100 else . end) | floor)
  end;

def exhaust($u; $reset; $w):
  if $reset == null then -1
  else (($w - ((($reset - (now | floor)) / 3600)))) as $elapsed
       | if $elapsed > 0.1 and $u > 0.5
         then (((100 - $u) * $elapsed / $u) | floor)
         else -1 end
  end;

def pctof: (.percent // .utilization);

def scope_label:
  (try (.scope.model.display_name // .scope.surface // "Scoped") catch "Scoped")
  | (if type == "string" then . else "Scoped" end)
  | gsub("[^ -~]"; "") | gsub("^ +| +$"; "") | .[0:12]
  | if . == "" then "Scoped" else . end;

def row($tag; $lbl; $lim; $w):
  ($lim | .resets_at | epoch) as $r
  | (($lim | pctof | num) // 0) as $p
  | [$tag, $lbl, ($p | cpct), exhaust($p; $r; $w), timepct($r; $w)]
  | map(tostring) | join("\u001f");

def limits($k):
  (.limits | if type == "array" then . else [] end)
  | map(select(type == "object" and .kind == $k));

# Each "as" source ends in `// null`: a binding to `empty` would silently drop
# every later row, so one missing limit would blank the others.
(limits("session")[0]      // (.five_hour | select(type == "object")) // null) as $s
| (limits("weekly_all")[0] // (.seven_day | select(type == "object")) // null) as $w
| ((limits("weekly_scoped") | sort_by(-((pctof | num) // 0)) | .[0])
   // ([{k: "Opus", v: .seven_day_opus}, {k: "Sonnet", v: .seven_day_sonnet}]
       | map(select(.v | type == "object") | .v + {scope: {model: {display_name: .k}}})
       | sort_by(-((pctof | num) // 0)) | .[0])
   // null) as $f
| ( (if $s != null then (try row("S"; ""; $s; 5) catch empty) else empty end),
    (if $w != null then (try row("W"; ""; $w; 168) catch empty) else empty end),
    (if $f != null then (try row("F"; ($f | scope_label); $f; 168) catch empty) else empty end) )
EOF
)

s_ok=0 w_ok=0 f_ok=0
s_p=0 s_e=-1 s_t=0 w_p=0 w_e=-1 w_t=0 f_p=0 f_e=-1 f_t=0 f_lbl="Scoped"
usage_state="missing"

if [[ -f "$CACHE_FILE" ]]; then
    usage_state="unreadable"
    if have jq; then
        parsed=$(jq -r "$JQ_PROG" "$CACHE_FILE" 2>/dev/null)
        jq_rc=$?
        while IFS=$'\x1f' read -r tag lbl p e t; do
            case "$tag" in
                S) s_ok=1; s_p=$(int "$p" 0); s_e=$(int "$e" -1); s_t=$(int "$t" 0) ;;
                W) w_ok=1; w_p=$(int "$p" 0); w_e=$(int "$e" -1); w_t=$(int "$t" 0) ;;
                F) f_ok=1; f_lbl="${lbl:-Scoped}"; f_p=$(int "$p" 0); f_e=$(int "$e" -1); f_t=$(int "$t" 0) ;;
            esac
        done <<<"$parsed"
        if (( s_ok + w_ok + f_ok > 0 )); then
            usage_state="ok"
        else
            log_once parse "$CACHE_MTIME" "usage cache parsed to zero windows (jq exit $jq_rc); showing usage n/a"
        fi
    else
        log_once parse "$CACHE_MTIME" "jq not found; cannot read usage cache"
    fi
fi

# ---------------------------------------------------------------------------
# Rendering
# ---------------------------------------------------------------------------

R=$'\033[0m'
D=$'\033[2m'
SEP=" ${D}│${R} "

color() {
    if (( $1 >= 80 )); then printf '\033[31m'
    elif (( $1 >= 50 )); then printf '\033[33m'
    else printf '\033[32m'; fi
}

bar() {
    local u=$(( $1 * 10 / 100 )) t=$(( $2 * 10 / 100 ))
    (( $1 > 0 && u == 0 )) && u=1
    (( $2 > 0 && t == 0 )) && t=1
    (( u > 10 )) && u=10
    (( t > 10 )) && t=10
    local s=""
    for ((i=1; i<=10; i++)); do
        if (( i <= u && i <= t )); then   s+="█"   # both consumed
        elif (( i <= u ));          then   s+="▓"   # over-pacing
        elif (( i <= t ));          then   s+="▒"   # under-pacing
        else                               s+="░"   # both free
        fi
    done
    printf '%s' "$s"
}

dur() {
    if (( $1 < 0 )); then printf '—'
    elif (( $1 == 0 )); then printf '<1h'
    elif (( $1 >= 48 )); then printf '%dd' "$(( $1 / 24 ))"
    else printf '%dh' "$1"; fi
}

# <label> <percent> <hours-to-exhaust> <elapsed-window-%>
win() {
    color "$2"
    printf '%s %2d%% ' "$1" "$2"
    bar "$2" "$4"
    printf ' ~'
    dur "$3"
    printf '%s' "$R"
}

# used/total with its own percentage, coloured on the same 50/80 thresholds as
# the quota windows so one glance reads the whole line the same way.
hostseg() {
    color "$3"
    printf '%s %s %d%%' "$1" "$2" "$3"
    printf '%s' "$R"
}

# Age in seconds -> "12m" / "3h" / "2d".
agefmt() {
    local s=$1
    if (( s < 3600 )); then printf '%dm' "$(( s / 60 ))"
    elif (( s < 172800 )); then printf '%dh' "$(( s / 3600 ))"
    else printf '%dd' "$(( s / 86400 ))"; fi
}

# Host load and memory, read straight from /proc rather than shelling out to
# top/free/vmstat: this renders on every prompt. Each segment is its own
# function, called in a command substitution, so an unreadable /proc (a
# container, a kernel change) drops that segment and nothing else.
#
# centi-load = load x 100, so the percentage divides without floats. 10# stops
# bash reading the "04" of a 0.04 load as octal. Overload is rendered rather
# than clamped (load 41.2 on 20 cores prints 206%): clamping would hide the
# difference between busy and wedged.
cpu_segment() {
    local cores load1 li lf centi
    cores=$(int "$(nproc 2>/dev/null)" 0)
    (( cores > 0 )) || cores=1
    read -r load1 _ </proc/loadavg || return 1
    [[ "$load1" =~ ^([0-9]+)(\.([0-9]+))?$ ]] || return 1
    li="${BASH_REMATCH[1]}"
    lf="${BASH_REMATCH[3]}00"
    centi=$(( 10#$li * 100 + 10#${lf:0:2} ))
    hostseg "cpu" "${li}.${lf:0:1}/${cores}" "$(( centi / cores ))"
}

# MemAvailable, not MemFree: free excludes reclaimable page cache and would
# report this box as ~95% used while 20G+ is actually available.
ram_segment() {
    local mk mv total=0 avail=0 used
    while read -r mk mv _; do
        case "$mk" in
            MemTotal:)     total=$(int "$mv" 0) ;;
            MemAvailable:) avail=$(int "$mv" 0) ;;
        esac
    done </proc/meminfo
    (( total > 0 )) || return 1
    used=$(( total - avail ))
    hostseg "ram" "$(( used / 1048576 ))/$(( total / 1048576 ))G" "$(( used * 100 / total ))"
}

segs=()
add() { [[ -n "$1" ]] && segs+=("$1"); }

if [[ "$usage_state" == "ok" ]]; then
    (( s_ok )) && add "$(win "5h" "$s_p" "$s_e" "$s_t")"
    (( w_ok )) && add "$(win "7d" "$w_p" "$w_e" "$w_t")"
    (( f_ok )) && add "$(win "$f_lbl" "$f_p" "$f_e" "$f_t")"
    if (( NOW - CACHE_MTIME > STALE_AFTER )); then
        add "${D}stale $(agefmt "$(( NOW - CACHE_MTIME ))")${R}"
    fi
else
    add "${D}usage n/a${R}"
fi

add "$(cpu_segment)"
add "$(ram_segment)"

git_commits=$(int "$(cat "$GIT_CACHE" 2>/dev/null)" 0)
add "$(printf '\033[36m⎇ %d\033[0m' "$git_commits")"

out=""
for seg in "${segs[@]}"; do
    if [[ -z "$out" ]]; then out="$seg"; else out="${out}${SEP}${seg}"; fi
done
printf '%s' "$out"

trim_log
exit 0
