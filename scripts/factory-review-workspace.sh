#!/usr/bin/env bash
# Run one report-only factory review skill across configured workspaces.
#
# This is deliberately the workspace-review child only. It does not install
# systemd units and it does not run host-wide checks. The timer installer
# invokes it from each generated workspace-review service wrapper.

set -uo pipefail

usage() {
  echo "Usage: $0 {plan-vs-built|find-stubs|repo-hygiene}" >&2
}

if [[ $# -ne 1 ]]; then
  usage
  exit 2
fi

SKILL_NAME="$1"
case "$SKILL_NAME" in
  plan-vs-built|find-stubs|repo-hygiene) ;;
  *)
    usage
    exit 2
    ;;
esac

export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
WORKSPACES_CONFIG="${FACTORY_REVIEW_WORKSPACES_FILE:-$HOME/.config/factory-review/workspaces.txt}"

# The skill reports findings only. The runner owns the output boundary and
# files the captured report in the reviewed workspace when it is actionable.
REVIEW_PROTOCOL='After completing the requested review, end your response with exactly one line: FACTORY_REVIEW_RESULT: clean when there are no actionable findings, or FACTORY_REVIEW_RESULT: findings when there are actionable findings. Do not create beads; the timer runner files the captured report.'

review_is_clean() {
  local report_file="$1"

  # The protocol is authoritative. These fallbacks keep older installed skill
  # copies useful when they emit documented clean text without the protocol.
  if grep -Eqi '^FACTORY_REVIEW_RESULT:[[:space:]]*clean[[:space:]]*$' "$report_file"; then
    return 0
  fi
  if grep -Eqi '^FACTORY_REVIEW_RESULT:[[:space:]]*findings[[:space:]]*$' "$report_file"; then
    return 1
  fi
  [[ ! -s "$report_file" ]] && return 0

  case "$SKILL_NAME" in
    plan-vs-built)
      grep -Eqi 'no (actionable )?findings|nothing to file|0 gaps|all .*BUILT' "$report_file"
      ;;
    find-stubs)
      grep -Eqi '(^|[^[:digit:]])0 findings([^[:digit:]]|$)|no findings|nothing to file' "$report_file"
      ;;
    repo-hygiene)
      grep -Eqi 'clean[[:space:]]*[-—][[:space:]]*no findings|no findings|nothing to file' "$report_file"
      ;;
  esac
}

review_backend() {
  local workspace="$1"
  local backend=""

  [[ -d "$workspace/.beads" && -f "$workspace/.needle.yaml" ]] || {
    echo none
    return
  }

  backend="$(awk '$1 == "backend:" || $1 == "bead_cli.backend:" {print $2; exit}' "$workspace/.needle.yaml")"
  case "$backend" in
    bead-rs|bead) echo bead-rs ;;
    bf|bead-forge) echo bf ;;
    *) echo none ;;
  esac
}

file_review_bead() {
  local workspace="$1"
  local report_file="$2"
  local backend bead_cli title description report_hash workspace_hash unique_ref
  local result rc=0 existing

  backend="$(review_backend "$workspace")"
  if [[ "$backend" == none ]]; then
    echo "Review findings in $workspace could not be filed: no supported bead backend/store." >&2
    return 1
  fi

  if [[ "$backend" == bead-rs ]]; then
    bead_cli=bead
  else
    bead_cli=bf
  fi
  if ! command -v "$bead_cli" >/dev/null 2>&1; then
    echo "Review findings in $workspace could not be filed: '$bead_cli' is not on PATH." >&2
    return 1
  fi

  report_hash="$(sha256sum "$report_file" | awk '{print substr($1,1,16)}')"
  workspace_hash="$(printf '%s' "$workspace" | sha256sum | awk '{print substr($1,1,16)}')"
  unique_ref="factory-review:${SKILL_NAME}:${workspace_hash}:${report_hash}"
  title="Factory review: ${SKILL_NAME} findings in ${workspace}"
  description="$(printf 'Factory review %s reported findings in %s.\n\nCaptured claude --print output:\n' "$SKILL_NAME" "$workspace"; cat "$report_file")"

  if [[ "$backend" == bf ]]; then
    # Legacy bf has no --unique-ref flag. An open-title lookup is the
    # compatibility deduplication path used by its installed skill contract.
    if ! existing="$(cd "$workspace" && "$bead_cli" list --status open 2>/dev/null)"; then
      echo "Review findings in $workspace could not be filed: '$bead_cli list' failed." >&2
      return 1
    fi
    if grep -qF -- "$title" <<<"$existing"; then
      echo "Review findings already filed in $workspace; nothing new to file."
      return 0
    fi
    if result="$(cd "$workspace" && "$bead_cli" create \
        --title "$title" \
        --description "$description" \
        --priority p3 \
        --type task \
        --label factory-review \
        --label "$SKILL_NAME" 2>&1)"; then
      echo "Filed review findings bead in $workspace: $result"
      return 0
    else
      rc=$?
    fi
  else
    if result="$(cd "$workspace" && "$bead_cli" create \
        --title "$title" \
        --description "$description" \
        --priority 3 \
        --issue-type task \
        --label factory-review \
        --label "$SKILL_NAME" \
        --unique-ref "$unique_ref" 2>&1)"; then
      if [[ "$result" == EXISTING* ]]; then
        echo "Review findings already filed in $workspace; nothing new to file."
      else
        echo "Filed review findings bead in $workspace: $result"
      fi
      return 0
    else
      rc=$?
    fi
  fi

  echo "Review findings in $workspace could not be filed (backend exit $rc): $result" >&2
  return 1
}

# A missing list is equivalent to an empty list. This lets an unconfigured
# machine run the service safely and gives operators an explicit outcome.
if [[ ! -f "$WORKSPACES_CONFIG" ]]; then
  echo "No configured workspaces; nothing to file."
  exit 0
fi

processed=0
failed=0
while IFS= read -r workspace || [[ -n "$workspace" ]]; do
  # Ignore blank/whitespace-only lines, comments, and CRLF line endings.
  workspace="${workspace%$'\r'}"
  if [[ "$workspace" =~ ^[[:space:]]*$ || "$workspace" =~ ^[[:space:]]*# ]]; then
    continue
  fi

  # Expand ~ to the service user's home, then resolve relative paths there.
  workspace="${workspace/#\~/$HOME}"
  if [[ "$workspace" != /* ]]; then
    workspace="$HOME/$workspace"
  fi

  if [[ ! -d "$workspace" ]]; then
    echo "Skipping non-existent workspace: $workspace"
    continue
  fi

  processed=$((processed + 1))
  echo "Running ${SKILL_NAME} on $workspace..."

  review_output="$(mktemp "${TMPDIR:-/tmp}/factory-review.XXXXXX")" || {
    echo "Unable to create a review output file for $workspace" >&2
    failed=1
    continue
  }

  # Run in a subshell so every invocation has the target checkout as PWD and
  # the next configured workspace cannot inherit the previous directory.
  claude_rc=0
  if (cd "$workspace" && claude --append-system-prompt "$REVIEW_PROTOCOL" --print /${SKILL_NAME} . \
      >"$review_output" 2>&1); then
    :
  else
    claude_rc=$?
  fi
  cat "$review_output"

  if [[ $claude_rc -ne 0 ]]; then
    echo "${SKILL_NAME} failed in $workspace (claude exit $claude_rc)" >&2
    [[ $failed -eq 0 ]] && failed=$claude_rc
    rm -f "$review_output"
    continue
  fi

  if review_is_clean "$review_output"; then
    echo "${SKILL_NAME} clean in $workspace; nothing to file."
  elif ! file_review_bead "$workspace" "$review_output"; then
    [[ $failed -eq 0 ]] && failed=1
  fi
  rm -f "$review_output"
done < "$WORKSPACES_CONFIG"

if [[ $processed -eq 0 ]]; then
  echo "No configured workspaces; nothing to file."
fi

exit "$failed"
