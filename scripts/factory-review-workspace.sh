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

# Keep the child self-contained when it is invoked directly as well as through
# the generated systemd wrapper. The system path provides the Nix-installed
# claude command; the user paths provide the configured bead backend. Preserve
# the user-path precedence used by direct invocations and fixtures.
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:/run/current-system/sw/bin:$PATH"
WORKSPACES_CONFIG="${FACTORY_REVIEW_WORKSPACES_FILE:-$HOME/.config/factory-review/workspaces.txt}"

# The skill reports findings only. The runner owns the output boundary and
# files the captured findings in the reviewed workspace when they are
# actionable. A finding starts with FACTORY_REVIEW_FINDING and continues until
# the next finding marker or the result marker. Older reports without markers
# are treated as one finding so filing remains backwards-compatible.
REVIEW_PROTOCOL='After completing the requested review, end your response with exactly one line: FACTORY_REVIEW_RESULT: clean when there are no actionable findings, or FACTORY_REVIEW_RESULT: findings when there are actionable findings. Do not create beads; the timer runner files the captured report.'

# When the result is findings, emit each actionable finding as its own block:
#
#   FACTORY_REVIEW_FINDING: <stable short title>
#   <evidence and proposed fix>
#
# Do not emit this marker for clean reviews. The marker title is deliberately
# short and stable because legacy bf uses the resulting bead title for lookup.
REVIEW_PROTOCOL+=$'\nWhen there are actionable findings, begin each finding block with exactly one line of the form FACTORY_REVIEW_FINDING: <stable short title>, put the finding evidence and suggested fix on following lines, and emit one block per finding before the final result line.'

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
  local configured_backend=""

  REVIEW_BACKEND=none
  REVIEW_BACKEND_ERROR=""
  if [[ ! -d "$workspace/.beads" ]]; then
    REVIEW_BACKEND_ERROR="no bead store at $workspace/.beads"
    return
  fi

  if [[ -f "$workspace/.needle.yaml" ]]; then
    configured_backend="$(awk '$1 == "backend:" || $1 == "bead_cli.backend:" {print $2; exit}' \
      "$workspace/.needle.yaml" | tr -d "\"'")"
    if [[ -z "$configured_backend" ]]; then
      REVIEW_BACKEND_ERROR="no bead backend configured in $workspace/.needle.yaml"
      return
    fi
  else
    # Older workspaces predate .needle.yaml. Their store config is a safe,
    # local compatibility signal and avoids requiring a direct .beads write.
    if [[ -f "$workspace/.beads/config.json" ]]; then
      configured_backend=bead-rs
    elif [[ -f "$workspace/.beads/config.yaml" ]]; then
      configured_backend=bf
    else
      REVIEW_BACKEND_ERROR="no bead backend configuration in $workspace"
      return
    fi
  fi

  case "$configured_backend" in
    bead-rs|bead) REVIEW_BACKEND=bead-rs ;;
    bf|bead-forge) REVIEW_BACKEND=bf ;;
    *)
      REVIEW_BACKEND_ERROR="unsupported bead backend '$configured_backend' in $workspace"
      ;;
  esac
}

FINDING_FILES=()
FINDING_TITLES=()

extract_review_findings() {
  local report_file="$1"
  local findings_dir="$2"
  local line title current_file="" marker_count=0
  FINDING_FILES=()
  FINDING_TITLES=()

  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" =~ ^FACTORY_REVIEW_FINDING:[[:space:]]*(.*)$ ]]; then
      title="${BASH_REMATCH[1]}"
      marker_count=$((marker_count + 1))
      current_file="$findings_dir/finding-$(printf '%04d' "$marker_count").md"
      FINDING_FILES+=("$current_file")
      if [[ -n "$title" ]]; then
        FINDING_TITLES+=("$title")
      else
        FINDING_TITLES+=("Review finding $marker_count")
      fi
      printf '%s\n' "$line" >"$current_file"
    elif [[ "$line" =~ ^FACTORY_REVIEW_RESULT: ]]; then
      # The result is a protocol boundary, not finding content.
      current_file=""
    elif [[ -n "$current_file" ]]; then
      printf '%s\n' "$line" >>"$current_file"
    fi
  done <"$report_file"

  if [[ "$marker_count" -eq 0 ]]; then
    # Installed or hand-authored reports from before the marker protocol are
    # still actionable. Their complete report is one deduplicated finding.
    current_file="$findings_dir/finding-0001.md"
    cp "$report_file" "$current_file"
    FINDING_FILES=("$current_file")
    FINDING_TITLES=("Review findings")
  fi
}

file_one_review_bead() {
  local workspace="$1"
  local finding_file="$2"
  local finding_title="$3"
  local backend="$4"
  local bead_cli title description finding_hash workspace_hash unique_ref
  local backend_output rc=0

  if [[ "$backend" == bead-rs ]]; then
    bead_cli=bead
  else
    bead_cli=bf
  fi
  if ! command -v "$bead_cli" >/dev/null 2>&1; then
    echo "Review findings in $workspace could not be filed: '$bead_cli' is not on PATH." >&2
    return 1
  fi

  # The marker title is the finding's stable identity. Evidence can gain a
  # line number or timestamp on a later review without creating a duplicate.
  finding_hash="$(printf '%s' "$finding_title" | sha256sum | awk '{print substr($1,1,16)}')"
  workspace_hash="$(printf '%s' "$workspace" | sha256sum | awk '{print substr($1,1,16)}')"
  unique_ref="factory-review:${SKILL_NAME}:${workspace_hash}:${finding_hash}"
  title="Factory review: ${SKILL_NAME}: ${finding_title} in ${workspace}"
  description="$(printf 'Factory review %s reported this finding in %s.\n\n' "$SKILL_NAME" "$workspace"; cat "$finding_file")"

  if ! backend_output="$(mktemp "${TMPDIR:-/tmp}/factory-review-bead.XXXXXX")"; then
    echo "Review findings in $workspace could not be filed: unable to capture backend result." >&2
    return 1
  fi

  if [[ "$backend" == bf ]]; then
    # Legacy bf has no --unique-ref flag. An open-title lookup is the
    # compatibility deduplication path used by its installed skill contract.
    if ! (cd "$workspace" && "$bead_cli" list --status open >"$backend_output" 2>/dev/null); then
      rm -f "$backend_output"
      echo "Review findings in $workspace could not be filed: '$bead_cli list' failed." >&2
      return 1
    fi
    if grep -qF -- "$title" "$backend_output"; then
      rm -f "$backend_output"
      echo "Review finding already filed in $workspace: $finding_title"
      return 0
    fi
    if (cd "$workspace" && "$bead_cli" create \
        --title "$title" \
        --description "$description" \
        --priority p3 \
        --type task \
        --label factory-review \
        --label "$SKILL_NAME" >"$backend_output" 2>/dev/null); then
      rm -f "$backend_output"
      echo "Filed review finding in $workspace: $finding_title"
      return 0
    else
      rc=$?
    fi
  else
    if (cd "$workspace" && "$bead_cli" create \
        --title "$title" \
        --description "$description" \
        --priority 3 \
        --issue-type task \
        --label factory-review \
        --label "$SKILL_NAME" \
        --unique-ref "$unique_ref" >"$backend_output" 2>/dev/null); then
      if grep -qE '^EXISTING([[:space:]]|$)' "$backend_output"; then
        rm -f "$backend_output"
        echo "Review finding already filed in $workspace: $finding_title"
      else
        rm -f "$backend_output"
        echo "Filed review finding in $workspace: $finding_title"
      fi
      return 0
    else
      rc=$?
    fi
  fi

  rm -f "$backend_output"
  echo "Review finding in $workspace could not be filed (backend exit $rc): $finding_title" >&2
  return 1
}

file_review_beads() {
  local workspace="$1"
  local report_file="$2"
  local findings_dir="$3"
  local backend finding_index filed=0 failed=0

  review_backend "$workspace"
  backend="$REVIEW_BACKEND"
  if [[ "$backend" == none ]]; then
    echo "Review findings in $workspace could not be filed: ${REVIEW_BACKEND_ERROR:-no supported bead backend/store}." >&2
    return 1
  fi

  extract_review_findings "$report_file" "$findings_dir"
  for finding_index in "${!FINDING_FILES[@]}"; do
    if file_one_review_bead "$workspace" "${FINDING_FILES[$finding_index]}" \
      "${FINDING_TITLES[$finding_index]}" "$backend"; then
      filed=$((filed + 1))
    else
      failed=1
    fi
  done

  if [[ "$failed" -ne 0 ]]; then
    return 1
  fi
  echo "Filed or confirmed $filed review finding(s) in $workspace."
  return 0
}

# A missing list is equivalent to an empty list. This lets an unconfigured
# machine run the service safely and gives operators an explicit outcome.
if [[ ! -f "$WORKSPACES_CONFIG" ]]; then
  echo "No configured workspaces; nothing to file."
  exit 0
fi

if [[ ! -r "$WORKSPACES_CONFIG" ]]; then
  echo "Configured workspace list could not be read; review skipped." >&2
  exit 1
fi

processed=0
failed=0
while IFS= read -r workspace || [[ -n "$workspace" ]]; do
  # Ignore blank/whitespace-only lines, comments, and CRLF line endings.
  workspace="${workspace%$'\r'}"
  if [[ "$workspace" =~ ^[[:space:]]*$ || "$workspace" =~ ^[[:space:]]*# ]]; then
    continue
  fi

  # Only the current user's ~ and ~/path forms are supported. Do not invoke a
  # shell parser here: a literal path such as $(touch /tmp/marker) must stay a
  # path and must never become executable input.
  if [[ "$workspace" == "~"* && "$workspace" != "~" && "$workspace" != "~/"* ]]; then
    echo "Skipping malformed workspace entry (unsupported home expansion): $workspace" >&2
    continue
  fi

  # Expand ~ to the service user's home, then resolve relative paths there.
  workspace="${workspace/#\~/$HOME}"
  if [[ "$workspace" != /* ]]; then
    workspace="$HOME/$workspace"
  fi

  # A path that exists but is not a directory is malformed for this list.
  # Keep missing paths distinct so a stale checkout is reported differently
  # from an invalid workspace target.
  if [[ -e "$workspace" && ! -d "$workspace" ]]; then
    echo "Skipping malformed workspace entry (not a directory): $workspace" >&2
    continue
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
  if (cd "$workspace" && claude --append-system-prompt "$REVIEW_PROTOCOL" --print /${SKILL_NAME} .) \
      >"$review_output" 2>&1; then
    :
  else
    claude_rc=$?
  fi

  if [[ $claude_rc -ne 0 ]]; then
    # Do not replay a failed tool's output. It may contain credentials or
    # backend diagnostics that do not belong in the service journal.
    echo "${SKILL_NAME} failed in $workspace (claude exit $claude_rc)" >&2
    [[ $failed -eq 0 ]] && failed=$claude_rc
    rm -f "$review_output"
    continue
  fi

  # Successful review output is the report that is both journaled and, when
  # actionable, passed to the configured bead backend.
  cat "$review_output"

  finding_dir="$(mktemp -d "${TMPDIR:-/tmp}/factory-review-findings.XXXXXX")" || {
    echo "Unable to create a finding directory for $workspace" >&2
    [[ $failed -eq 0 ]] && failed=1
    rm -f "$review_output"
    continue
  }

  if review_is_clean "$review_output"; then
    echo "${SKILL_NAME} clean in $workspace; nothing to file."
  elif ! file_review_beads "$workspace" "$review_output" "$finding_dir"; then
    [[ $failed -eq 0 ]] && failed=1
  fi
  rm -f "$review_output"
  rm -rf "$finding_dir"
done < "$WORKSPACES_CONFIG"

if [[ $processed -eq 0 ]]; then
  echo "No configured workspaces; nothing to file."
fi

exit "$failed"
