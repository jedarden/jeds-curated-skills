#!/usr/bin/env bash
#
# check-push-ci.sh - Heartbeat for the push-triggered CI path
#
# README.md's Testing section claims the three suites run "on every push to
# main (via the skills-validate Argo WorkflowTemplate, which triggers on push
# through the Forgejo webhook sensor)". Until now nothing checked that claim:
# the webhook path (eventsource -> JetStream -> sensor -> workflow submit) has
# no health signal of its own. The sensor's liveness probe only proves the
# process is up, not that events flow — its pod passed healthz for over two
# weeks (2026-08-29..09-16) with a wedged JetStream connection while every
# push landed unvalidated, the same failure class as the 2026-08-18 telemetry
# blackout. This script turns the README's claim into a checked invariant:
#
#   For the newest pushable commit on origin/main, a skills-validate workflow
#   submitted by the sensor must exist in iad-ci, created at or after that
#   commit's committer date.
#
# Matching rules:
#   - Only workflows whose generateName is exactly "skills-validate-" count.
#     The sensor's trigger template uses that generateName; a manual run
#     ("skills-validate-manual-...") proves the template works but says
#     nothing about the webhook path, so it must not silence this check.
#     (No other sensor in declarative-config submits that generateName, so
#     the name identifies this repo's webhook path unambiguously.)
#   - The workflow does not carry the pushed SHA (the sensor passes only
#     git-repo and branch), so matching is by time: the workflow must have
#     been created at or after the reference commit's committer date. Any
#     workflow created after that date proves the path delivered *a* push
#     event; for a single-writer repo that is the push of the reference
#     commit itself. This assumes both clocks are sane — the committer's
#     and the Kubernetes API server's are NTP-synced across the fleet; the
#     grace window covers webhook delivery latency, not skew.
#   - The reference commit skips the tip while its author is "Argo Workflows
#     CI", mirroring the sensor's own filter
#     (body.head_commit.author.name != "Argo Workflows CI"): those pushes get
#     no workflow by design, and counting them would false-alarm.
#
# Usage:
#   scripts/check-push-ci.sh [--grace-minutes N] [--help]
#
# Options:
#   --grace-minutes N  Judge only pushes older than N minutes (default 15).
#                      A younger push may legitimately have no workflow yet —
#                      the webhook is delivered asynchronously.
#
# Environment:
#   SKILLS_CI_KUBECTL_SERVER  kubectl --server endpoint for iad-ci
#                             (default: http://traefik-iad-ci:8001 — the
#                             credential-free read-only proxy)
#
# Exit codes:
#   0  Verified — a sensor-submitted skills-validate workflow was created at
#      or after the reference commit's committer date
#   1  Heartbeat FAILURE — the reference push is older than the grace window
#      and no matching workflow exists; the push-triggered CI path is dead
#      and pushes are landing unvalidated. Alert (file a bead / fail the
#      timer unit) on this code and no other.
#   2  Environmental — cannot judge: not a git repo, no origin/main, fetch
#      failed, kubectl/jq unusable, or the API query failed. Not a CI alarm.
#   3  Too recent — the reference push is younger than the grace window; a
#      workflow may still be in flight. Re-run later; not an alarm.
#
# Cost note: the credential-free proxy has no server-side name filter and
# skills-validate workflows carry no template label, so this scans every
# workflow object in the namespace and filters client-side (~3 minutes against
# the live cluster; fine for a weekly timer, noticeable by hand).
#
# Deliberately NOT part of the pre-commit hook or the skills-validate
# template itself: it needs network and the cluster, and wiring the check
# into the pipeline it monitors would not catch that pipeline's death.

set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

GRACE_MINUTES=15
KUBECTL_SERVER="${SKILLS_CI_KUBECTL_SERVER:-http://traefik-iad-ci:8001}"
# The sensor drops pushes whose head commit author is this name (see the
# jeds-curated-skills-sensor.yml filter) — they never get a workflow.
CI_AUTHOR="Argo Workflows CI"
# Exact generateName the sensor's trigger template submits under. Prefix-
# matching would let the manual "skills-validate-manual-" runs through.
SENSOR_GENERATE_NAME="skills-validate-"
# How far down origin/main to walk looking for a non-CI-authored tip.
LOG_WALK_LIMIT=50

usage() {
  # Print the leading comment block: every "#" line after the shebang, up
  # to the first non-comment line. Counting lines (sed -n '2,60p') rots
  # every time the header is edited.
  awk 'NR == 1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "$0"
}

die_usage() {
  echo -e "${RED}Error: $1${NC}" >&2
  echo "Usage: scripts/check-push-ci.sh [--grace-minutes N]" >&2
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --grace-minutes)
      [[ $# -ge 2 ]] || die_usage "--grace-minutes needs a value"
      GRACE_MINUTES="$2"
      shift 2
      ;;
    --grace-minutes=*)
      GRACE_MINUTES="${1#*=}"
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      die_usage "unknown option '$1'"
      ;;
  esac
done

case "$GRACE_MINUTES" in
  ''|*[!0-9]*) die_usage "--grace-minutes must be a non-negative integer" ;;
esac

for tool in git jq kubectl; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo -e "${RED}Error: required tool '$tool' not found on PATH${NC}" >&2
    exit 2
  fi
done

# --- reference commit: newest pushable commit on origin/main -----------------

if ! git rev-parse --verify --quiet 'origin/main^{commit}' >/dev/null 2>&1; then
  echo -e "${RED}Error: no origin/main here — run from a clone of the repo${NC}" >&2
  exit 2
fi

# origin/main must be fresh or the reference commit goes stale and a months-
# old workflow satisfies the check forever. A failed fetch is an environmental
# problem (this box offline), not evidence the CI path died.
if ! git fetch --quiet origin; then
  echo -e "${RED}Error: git fetch origin failed — cannot refresh origin/main${NC}" >&2
  exit 2
fi

# Walk newest-first past any CI-authored tip (mirrors the sensor filter).
ref_sha="" ref_epoch="" ref_author=""
while IFS=$'\t' read -r sha epoch author; do
  if [[ "$author" != "$CI_AUTHOR" ]]; then
    ref_sha="$sha" ref_epoch="$epoch" ref_author="$author"
    break
  fi
done < <(git log origin/main --max-count="$LOG_WALK_LIMIT" --format='%H%x09%ct%x09%an')

if [[ -z "$ref_sha" ]]; then
  echo -e "${RED}Error: no non-CI-authored commit in the last $LOG_WALK_LIMIT on origin/main${NC}" >&2
  exit 2
fi

ref_iso="$(date -u -d "@$ref_epoch" '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date -u -r "$ref_epoch" '+%Y-%m-%dT%H:%M:%SZ')"
echo "Reference commit: ${ref_sha:0:12} by $ref_author at $ref_iso"

# --- grace window -------------------------------------------------------------

now_epoch="$(date +%s)"
age_seconds=$((now_epoch - ref_epoch))
age_minutes=$((age_seconds / 60))
if (( age_seconds < GRACE_MINUTES * 60 )); then
  echo -e "${YELLOW}Push is $age_minutes minute(s) old, within the $GRACE_MINUTES-minute grace window.${NC}"
  echo "A workflow may still be in flight — not judgeable yet. Re-run later."
  exit 3
fi

# --- query iad-ci --------------------------------------------------------------

# The proxy offers no server-side name filter and these workflows carry no
# template label (workflows.argoproj.io/workflow-template is absent repo-wide,
# see CLAUDE.md's known issue), so pull the namespace and filter client-side.
wf_tmp="$(mktemp "${TMPDIR:-/tmp}/push-ci-workflows.XXXXXX.json")"
trap 'rm -f "$wf_tmp"' EXIT
# --request-timeout bounds the whole listing (the full namespace scan takes
# ~3.5 minutes against the live proxy) so a hung proxy cannot hang a timer
# unit until systemd gives up.
if ! kubectl --server="$KUBECTL_SERVER" --request-timeout=600s get workflows \
    -n argo-workflows --chunk-size 500 -o json >"$wf_tmp"; then
  echo -e "${RED}Error: kubectl query against $KUBECTL_SERVER failed — cannot judge${NC}" >&2
  exit 2
fi

# Last (newest) sensor-submitted workflow as three lines: name, ISO time,
# epoch; plus a fourth line with the total count of sensor-submitted runs.
# fromdateiso8601 accepts exactly the RFC3339 "Z" shape the API server
# emits; fractional seconds (which the API server occasionally stamps)
# would break both the parse and the string sort, so they are stripped
# first. Captured with error handling on purpose: a jq failure must be
# environmental (exit 2), not a fall-through into an empty array that a
# later unbound-variable death would report as exit 1 — a heartbeat alarm.
wf_data="$(jq -r --arg gen "$SENSOR_GENERATE_NAME" '
  [.items[]
   | select((.metadata.generateName // "") == $gen)
   | {name: .metadata.name,
      created: (.metadata.creationTimestamp | sub("\\.[0-9]+Z$"; "Z"))}]
  | sort_by(.created | fromdateiso8601)
  | {total: length, last: last}
  | .total,
    (if .last == null then "" else .last.name end),
    (if .last == null then "" else .last.created end),
    (if .last == null then "" else (.last.created | fromdateiso8601) end)
' "$wf_tmp")" || {
  echo -e "${RED}Error: parsing the workflow listing failed — cannot judge${NC}" >&2
  exit 2
}
# Command substitution strips trailing newlines, so when the newest-workflow
# fields are empty (total 0) the four-line output collapses to one line and
# the array is shorter than 4 — every index after [0] must default via :-.
# A total that is not a number means the listing or the parse is malformed:
# that is environmental (exit 2), NOT a heartbeat alarm (exit 1).
mapfile -t last_wf <<< "$wf_data"
wf_total="${last_wf[0]:-}"
if [[ ! "$wf_total" =~ ^[0-9]+$ ]]; then
  echo -e "${RED}Error: unexpected workflow-listing parse (total='$wf_total') — cannot judge${NC}" >&2
  exit 2
fi

if (( wf_total == 0 )); then
  echo -e "${RED}No sensor-submitted '$SENSOR_GENERATE_NAME' workflow is on record in iad-ci${NC}."
  echo -e "${RED}✗ Push-CI heartbeat FAILED:${NC} the webhook trigger path has delivered"
  echo -e "nothing the cluster still lists (the listing covers the cluster's"
  echo -e "workflow retention window). Check the Forgejo webhook for this repo,"
  echo -e "then the eventsource and sensor in declarative-config"
  echo -e "k8s/iad-ci/argo-events/."
  exit 1
fi

last_name="${last_wf[1]:-}"
last_iso="${last_wf[2]:-}"
last_epoch="${last_wf[3]:-}"
if [[ ! "$last_epoch" =~ ^[0-9]+$ ]]; then
  echo -e "${RED}Error: newest workflow has an unparseable creation time — cannot judge${NC}" >&2
  exit 2
fi

if (( last_epoch >= ref_epoch )); then
  echo -e "${GREEN}✓ Push-CI heartbeat verified${NC}"
  echo "  newest sensor workflow: $last_name created $last_iso"
  echo "  (at/after reference commit $ref_iso)"
  exit 0
fi

echo -e "${RED}✗ Push-CI heartbeat FAILED${NC}"
echo "  reference commit : ${ref_sha:0:12} at $ref_iso (author $ref_author)"
echo "  newest workflow  : $last_name at $last_iso — BEFORE the push"
echo "  sensor-submitted workflows on record: $wf_total"
echo ""
echo "The push-triggered CI path did not deliver a workflow for the newest push:"
echo "pushes are landing unvalidated while the README claims push CI. Check the"
echo "sensor pod and eventbus in declarative-config k8s/iad-ci/argo-events/."
exit 1
