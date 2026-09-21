#!/usr/bin/env bash
set -euo pipefail

CACHE_DIR="$HOME/.cache/claude-usage"
CACHE_FILE="$CACHE_DIR/usage.json"
LOCK_FILE="$CACHE_DIR/fetch.lock"
CREDS="$HOME/.claude/.credentials.json"
CACHE_TTL=60

GIT_CACHE="$CACHE_DIR/git_commits.txt"
GIT_CACHE_TTL=300

mkdir -p "$CACHE_DIR"

maybe_fetch() {
    local age=999999
    if [[ -f "$CACHE_FILE" ]]; then
        age=$(( $(date +%s) - $(stat -c %Y "$CACHE_FILE") ))
    fi
    (( age <= CACHE_TTL )) && return 0

    exec 9>"$LOCK_FILE"
    flock -n 9 || return 0

    local token expires_at now_ms
    token=$(jq -r '.claudeAiOauth.accessToken' "$CREDS" 2>/dev/null) || { exec 9>&-; return 0; }
    expires_at=$(jq -r '.claudeAiOauth.expiresAt' "$CREDS" 2>/dev/null) || expires_at=0
    now_ms=$(( $(date +%s) * 1000 ))

    if (( now_ms + 300000 >= expires_at )); then
        local rt resp tmp
        rt=$(jq -r '.claudeAiOauth.refreshToken' "$CREDS" 2>/dev/null) || rt=""
        if [[ -n "$rt" ]]; then
            resp=$(curl -sf --max-time 5 -X POST \
                "https://platform.claude.com/v1/oauth/token" \
                -H "Content-Type: application/json" \
                -H "User-Agent: claude-code/2.1.78" \
                -d "{\"grantType\":\"refresh_token\",\"refreshToken\":\"$rt\"}" 2>/dev/null) || resp=""
            if [[ -n "$resp" ]]; then
                tmp="$CREDS.sl-tmp.$$"
                if jq --argjson r "$resp" '
                    .claudeAiOauth.accessToken = $r.accessToken |
                    .claudeAiOauth.refreshToken = $r.refreshToken |
                    .claudeAiOauth.expiresAt = $r.expiresAt
                ' "$CREDS" > "$tmp" 2>/dev/null; then
                    mv "$tmp" "$CREDS"
                else
                    rm -f "$tmp"
                fi
                token=$(echo "$resp" | jq -r '.accessToken' 2>/dev/null) || token=""
            fi
        fi
    fi

    if [[ -n "$token" ]]; then
        local result
        result=$(curl -sf --max-time 3 \
            -H "Authorization: Bearer $token" \
            -H "anthropic-beta: oauth-2025-04-20" \
            -H "User-Agent: claude-code/2.1.78" \
            "https://api.anthropic.com/api/oauth/usage" 2>/dev/null) || result=""
        [[ -n "$result" ]] && echo "$result" > "$CACHE_FILE"
    fi

    exec 9>&-
}

maybe_count_commits() {
    local age=999999
    if [[ -f "$GIT_CACHE" ]]; then
        age=$(( $(date +%s) - $(stat -c %Y "$GIT_CACHE") ))
    fi
    (( age <= GIT_CACHE_TTL )) && return 0

    local GIT_LOCK="$CACHE_DIR/git.lock"
    exec 8>"$GIT_LOCK"
    flock -n 8 || { exec 8>&-; return 0; }

    local total=0 c repo
    while IFS= read -r gitdir; do
        repo="${gitdir%/.git}"
        c=$(git -C "$repo" log --since="7 days ago" \
            --grep="Co-Authored-By: Claude" \
            --format="%H" 2>/dev/null | wc -l | tr -d ' ') || c=0
        total=$(( total + c ))
    done < <(find "$HOME" -maxdepth 2 -name ".git" -type d 2>/dev/null)

    echo "$total" > "$GIT_CACHE"
    exec 8>&-
}

maybe_fetch
maybe_count_commits &

[[ ! -f "$CACHE_FILE" ]] && exit 0

eval "$(jq -r '
    def ts: sub("\\.[0-9]+\\+00:00$"; "Z") | fromdateiso8601;
    def exhaust($u; $r; $w):
        if $r == null then -1 else
        ($r | ts) as $reset |
        (now | floor) as $n |
        (($reset - $n) / 3600) as $left |
        ($w - $left) as $elapsed |
        if $elapsed > 0.1 and $u > 0.5 then
            ((100 - $u) * $elapsed / $u) | floor
        else -1 end
        end;
    def timepct($r; $w):
        if $r == null then 0 else
        ($r | ts) as $reset |
        (now | floor) as $n |
        ((($w - (($reset - $n) / 3600)) / $w) * 100) |
        if . < 0 then 0 elif . > 100 then 100 else . end | floor
        end;
    (.limits // []) as $lims |
    ($lims[] | select(.kind == "session"))          as $sess |
    ($lims[] | select(.kind == "weekly_all"))       as $wall |
    (($lims[] | select(.kind == "weekly_scoped")) // null) as $wsco |
    "p5h=\($sess.percent) e5h=\(exhaust($sess.percent; $sess.resets_at; 5)) t5h=\(timepct($sess.resets_at; 5))",
    "p7d=\($wall.percent) e7d=\(exhaust($wall.percent; $wall.resets_at; 168)) t7d=\(timepct($wall.resets_at; 168))",
    if $wsco != null then
        "p7f=\($wsco.percent) e7f=\(exhaust($wsco.percent; $wsco.resets_at; 168)) t7f=\(timepct($wsco.resets_at; 168)) lbl7f=\($wsco.scope.model.display_name // "Scoped")"
    else
        "p7f=-1 e7f=-1 t7f=0 lbl7f=F7"
    end
' "$CACHE_FILE" 2>/dev/null)" || exit 0

R='\033[0m'
D='\033[2m'

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

win() {
    color "$2"
    printf '%s %2d%% ' "$1" "$2"
    bar "$2" "$4"
    printf ' ~'
    dur "$3"
    printf '%b' "$R"
}

git_commits=0
[[ -f "$GIT_CACHE" ]] && git_commits=$(cat "$GIT_CACHE" 2>/dev/null || echo 0)
git_commits=$(( git_commits + 0 ))

# ---------------------------------------------------------------------------
# Host load and memory.
#
# Read straight out of /proc instead of shelling out to top/free/vmstat: this
# renders on every prompt, so it has to stay cheap. Everything below is pure
# bash string work plus one `nproc`.
#
# Assignment form `x=$(( ... ))` is used throughout rather than bare
# `(( ... ))`, deliberately: this script runs under `set -euo pipefail`, and a
# bare arithmetic command whose value is zero returns exit status 1, which
# would kill the whole statusline the moment load rounded down to 0%.
#
# host_ok gates rendering, so an unreadable /proc (a container, a kernel
# change) drops these two segments instead of blanking the line.
# ---------------------------------------------------------------------------
host_ok=1

cpu_cores=$(nproc 2>/dev/null || echo 0)
cpu_cores=$(( cpu_cores + 0 ))
(( cpu_cores > 0 )) || cpu_cores=1

load_disp="?"
cpu_pct=0
if [[ -r /proc/loadavg ]]; then
    read -r load1 _ < /proc/loadavg || load1="0.00"
    load_int=${load1%%.*}
    load_frac=${load1#*.}00
    # centi-load = load x 100, so the percentage divides without floats.
    load_centi=$(( 10#${load_int:-0} * 100 + 10#${load_frac:0:2} ))
    cpu_pct=$(( load_centi / cpu_cores ))
    load_disp="${load_int:-0}.${load_frac:0:1}"
else
    host_ok=0
fi

mem_disp="?"
mem_pct=0
if [[ -r /proc/meminfo ]]; then
    mem_total_kb=0
    mem_avail_kb=0
    while read -r mk mv _; do
        case "$mk" in
            MemTotal:)     mem_total_kb=$mv ;;
            MemAvailable:) mem_avail_kb=$mv ;;
        esac
    done < /proc/meminfo
    if (( mem_total_kb > 0 )); then
        # MemAvailable, not MemFree: free excludes reclaimable page cache and
        # would report this box as ~95% used while 20G+ is actually available.
        mem_used_kb=$(( mem_total_kb - mem_avail_kb ))
        mem_pct=$(( mem_used_kb * 100 / mem_total_kb ))
        mem_disp="$(( mem_used_kb / 1048576 ))/$(( mem_total_kb / 1048576 ))G"
    else
        host_ok=0
    fi
else
    host_ok=0
fi

# used/total with its own percentage, coloured on the same 50/80 thresholds as
# the quota windows so one glance reads the whole line the same way.
hostseg() {
    color "$3"
    printf '%s %s %d%%' "$1" "$2" "$3"
    printf '%b' "$R"
}

win "5h" "$p5h" "$e5h" "$t5h"
printf '%b' " ${D}│${R} "
win "7d" "$p7d" "$e7d" "$t7d"
if (( p7f >= 0 )); then
    printf '%b' " ${D}│${R} "
    win "$lbl7f" "$p7f" "$e7f" "$t7f"
fi
if (( host_ok )); then
    printf '%b' " ${D}│${R} "
    hostseg "cpu" "${load_disp}/${cpu_cores}" "$cpu_pct"
    printf '%b' " ${D}│${R} "
    hostseg "ram" "$mem_disp" "$mem_pct"
fi
printf '%b' " ${D}│${R} "
printf '\033[36m⎇ %d\033[0m' "$git_commits"
