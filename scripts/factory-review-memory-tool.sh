#!/usr/bin/env bash
# Run the host-wide memory-tool check and file one home-workspace bead on
# failure. This child deliberately does not read the workspace review list.

set -uo pipefail

usage() {
  echo "Usage: $0" >&2
}

if [[ $# -ne 0 ]]; then
  usage
  exit 2
fi

export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_REPO_ROOT="$(dirname "$SCRIPT_DIR")"
EXPLICIT_HOME_WORKSPACE="${FACTORY_REVIEW_HOME_WORKSPACE:-}"
if [[ -n "$EXPLICIT_HOME_WORKSPACE" ]]; then
  HOME_WORKSPACE="$EXPLICIT_HOME_WORKSPACE"
else
  HOME_WORKSPACE="$HOME/jeds-curated-skills"
fi

# When the installer was run from the home workspace itself, use that exact
# checkout even if HOME has a different directory name in a fixture or clone.
if [[ -z "$EXPLICIT_HOME_WORKSPACE" &&
  ( ! -f "$HOME_WORKSPACE/.needle.yaml" || ! -d "$HOME_WORKSPACE/.beads" ) ]]; then
  if [[ -f "$INSTALL_REPO_ROOT/.needle.yaml" && -d "$INSTALL_REPO_ROOT/.beads" ]]; then
    HOME_WORKSPACE="$INSTALL_REPO_ROOT"
  fi
fi

# Suppress diagnostics so a check cannot accidentally copy a token or other
# credential-bearing output into the systemd journal or the filed bead. The
# exit code is the durable finding; diagnostic detail is intentionally omitted.
check_rc=0
if (cd "$HOME_WORKSPACE" && memory-tool check) >/dev/null 2>&1; then
  check_rc=0
else
  check_rc=$?
fi

if [[ $check_rc -eq 0 ]]; then
  echo "memory-tool check passed; nothing to file."
  echo "No bead needed."
  exit 0
fi

echo "memory-tool check failed with exit $check_rc; attempting to file one bead."

backend=""
if [[ -f "$HOME_WORKSPACE/.needle.yaml" ]]; then
  backend="$(awk '$1 == "backend:" || $1 == "bead_cli.backend:" {print $2; exit}' \
    "$HOME_WORKSPACE/.needle.yaml" | tr -d "\"'")"
else
  # The store layout is a compatibility fallback for older workspaces that
  # predate .needle.yaml. Prefer the explicit workspace configuration above.
  if [[ -f "$HOME_WORKSPACE/.beads/config.json" ]]; then
    backend=bead-rs
  elif [[ -f "$HOME_WORKSPACE/.beads/config.yaml" ]]; then
    backend=bf
  fi
fi

if [[ ! -d "$HOME_WORKSPACE/.beads" || -z "$backend" ]]; then
  echo "memory-tool check failed; nothing to file: home workspace has no bead store/backend ($HOME_WORKSPACE)."
  exit "$check_rc"
fi

case "$backend" in
  bead-rs|bead)
    bead_cli=bead
    backend_kind=bead-rs
    ;;
  bf|bead-forge)
    bead_cli=bf
    backend_kind=bf
    ;;
  *)
    echo "memory-tool check failed; nothing to file: unsupported bead backend '$backend'."
    exit "$check_rc"
    ;;
esac

if ! command -v "$bead_cli" >/dev/null 2>&1; then
  echo "memory-tool check failed; unable to file bead: '$bead_cli' is not on PATH." >&2
  exit "$check_rc"
fi

title="memory-tool check failure"
description="memory-tool check failed in $HOME_WORKSPACE with exit $check_rc; command: memory-tool check; action: rerun memory-tool check in the selected workspace to investigate; diagnostic output is intentionally omitted to avoid credential disclosure."
unique_ref="factory-review:memory-tool-check"
create_rc=0
bead_output="$(mktemp "${TMPDIR:-/tmp}/factory-review-memory-bead.XXXXXX")" || {
  echo "memory-tool check failed; unable to capture bead identifier." >&2
  exit "$check_rc"
}
trap 'rm -f "$bead_output"' EXIT

# Successful bead creation prints an identifier (or `EXISTING ID` for an
# idempotent replay). Read only that identifier back. In particular, never
# replay complete backend output because a backend error or renderer may
# contain data that does not belong in the journal.
bead_id_from_output() {
  local line candidate
  while IFS= read -r line; do
    case "$line" in
      EXISTING\ *) candidate="${line#EXISTING }" ;;
      EXISTING_CLOSED\ *) candidate="${line#EXISTING_CLOSED }" ;;
      *) candidate="$line" ;;
    esac
    if [[ "$candidate" =~ ^[[:alnum:]_.:-]+$ ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done <"$bead_output"
  return 1
}

if [[ "$backend_kind" == bf ]]; then
  # Legacy bead-forge has no bead-rs --unique-ref flag. Its list operation is
  # the compatibility deduplication check; keep the query's output private as
  # well because backend renderers may include the full description.
  existing_beads=""
  if ! existing_beads="$(cd "$HOME_WORKSPACE" && "$bead_cli" list --status open 2>/dev/null)"; then
    echo "memory-tool check failed; unable to file bead: existing bead lookup failed in $HOME_WORKSPACE." >&2
    create_rc=1
  elif grep -qF -- "$title" <<<"$existing_beads"; then
    echo "An open memory-tool check failure bead already exists; nothing new to file."
  elif (cd "$HOME_WORKSPACE" && "$bead_cli" create \
      --title "$title" \
      --description "$description" \
      --priority p3 \
      --type task \
      --label factory-review \
      --label memory-tool >"$bead_output" 2>/dev/null); then
    if bead_id="$(bead_id_from_output)"; then
      echo "Filed memory-tool check failure bead $bead_id in $HOME_WORKSPACE."
    else
      echo "Filed memory-tool check failure bead in $HOME_WORKSPACE (identifier unavailable)."
    fi
  else
    create_rc=$?
  fi
else
  # bead-rs provides atomic idempotency, so concurrent timer retries and
  # repeated weekly failures resolve to one stable finding.
  if (cd "$HOME_WORKSPACE" && "$bead_cli" create \
      --title "$title" \
      --description "$description" \
      --priority 3 \
      --issue-type task \
      --label factory-review \
      --label memory-tool \
      --unique-ref "$unique_ref" >"$bead_output" 2>/dev/null); then
    if bead_id="$(bead_id_from_output)"; then
      if grep -q '^EXISTING' "$bead_output"; then
        echo "Memory-tool check failure bead $bead_id already exists in $HOME_WORKSPACE; nothing new to file."
      else
        echo "Filed memory-tool check failure bead $bead_id in $HOME_WORKSPACE."
      fi
    else
      echo "Filed memory-tool check failure bead in $HOME_WORKSPACE (identifier unavailable)."
    fi
  else
    create_rc=$?
  fi
fi

if [[ $create_rc -ne 0 ]]; then
  echo "memory-tool check failed; bead filing failed in $HOME_WORKSPACE (backend exit $create_rc)." >&2
  exit "$check_rc"
fi

exit "$check_rc"
