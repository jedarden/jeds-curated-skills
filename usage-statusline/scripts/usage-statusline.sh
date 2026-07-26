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

win "5h" "$p5h" "$e5h" "$t5h"
printf '%b' " ${D}│${R} "
win "7d" "$p7d" "$e7d" "$t7d"
if (( p7f >= 0 )); then
    printf '%b' " ${D}│${R} "
    win "$lbl7f" "$p7f" "$e7f" "$t7f"
fi
printf '%b' " ${D}│${R} "
printf '\033[36m⎇ %d\033[0m' "$git_commits"
