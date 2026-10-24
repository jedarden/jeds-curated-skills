#!/usr/bin/env bash
# Install the plan skills that have been adapted for both Claude and Codex.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/inline.sh"
if [[ ! -f "$SCRIPT_DIR/lib/common.sh" ]]; then
    printf 'Missing shared Bash helpers: %s\n' "$SCRIPT_DIR/lib/common.sh" >&2
    exit 1
fi

CODEX_ROOT="${CODEX_HOME:-$HOME/.codex}"
TARGET_DIR="$CODEX_ROOT/skills"
PLAN_SKILLS=(plan-author plan-review plan-gap-review plan-idea-gen plan-to-bead plan-vs-built)
REPLACE=false

usage() {
    cat <<'EOF'
Usage: install-codex.sh [--replace] [plan-skill ...]
       install-codex.sh --list

Without names, install all six Codex-ready plan skills. Existing differing
installations are left untouched unless --replace is given. --replace works
only for copies installed by this script and backs them up outside skills/.
EOF
}

known_skill() {
    local name="$1" item
    for item in "${PLAN_SKILLS[@]}"; do
        [[ "$item" == "$name" ]] && return 0
    done
    return 1
}

if [[ "${1:-}" == "--list" ]]; then
    printf '%s\n' "${PLAN_SKILLS[@]}"
    exit 0
fi
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    usage
    exit 0
fi
if [[ "${1:-}" == "--replace" ]]; then
    REPLACE=true
    shift
fi
if [[ $# -eq 0 ]]; then
    set -- "${PLAN_SKILLS[@]}"
fi

for skill in "$@"; do
    if ! known_skill "$skill"; then
        printf 'Unknown Codex-ready plan skill: %s\n' "$skill" >&2
        exit 2
    fi
done

mkdir -p "$TARGET_DIR"
for skill in "$@"; do
    source_dir="$SCRIPT_DIR/$skill"
    dest_dir="$TARGET_DIR/$skill"
    stage_dir="$(mktemp -d "$TARGET_DIR/.jcs-install.XXXXXX")"
    cp -a "$source_dir/." "$stage_dir/"

    # Reuse the Claude installer's shared-library format so copied scripts
    # remain runnable without a sibling lib/ directory.
    while IFS= read -r -d '' script; do
        if grep -qF '../../lib/common.sh' "$script"; then
            temp_script="$(mktemp "$stage_dir/.inline.XXXXXX")"
            emit_inlined_script "$script" "$SCRIPT_DIR/lib/common.sh" > "$temp_script"
            chmod --reference="$script" "$temp_script"
            mv "$temp_script" "$script"
        fi
    done < <(find "$stage_dir" -type f -name '*.sh' -print0)

    printf 'Installed from jeds-curated-skills\n' > "$stage_dir/.jcs-codex-install"
    if [[ -e "$dest_dir" || -L "$dest_dir" ]]; then
        if diff -qr "$stage_dir" "$dest_dir" >/dev/null; then
            rm -rf "$stage_dir"
            printf '%s: already current\n' "$skill"
            continue
        fi
        if [[ "$REPLACE" != true || ! -f "$dest_dir/.jcs-codex-install" ]]; then
            rm -rf "$stage_dir"
            printf '%s: existing installation differs; inspect it before using --replace\n' "$skill" >&2
            exit 1
        fi
        backup_dir="$CODEX_ROOT/skill-backups"
        mkdir -p "$backup_dir"
        mv "$dest_dir" "$backup_dir/$skill.$(date -u +%Y%m%dT%H%M%SZ).$$"
    fi
    mv "$stage_dir" "$dest_dir"
    printf '%s: installed to %s\n' "$skill" "$dest_dir"
done
