#!/usr/bin/env bash
#
# validate-skills.sh - Static structural validation for Claude Code skill bundles
#
# Per ADR-1 (2026-07-20), this script validates every skill directory for:
# 1. Frontmatter schema (SKILL.md YAML frontmatter with required fields)
# 2. Reference integrity (files referenced in SKILL.md exist)
# 3. Shell syntax (bash -n on all scripts/*.sh; optional shellcheck)
# 4. Executable bit (scripts/*.sh have +x)
#
# Exit codes: 0 = all valid, 1 = validation failures, 2 = usage error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# Color output for readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

ERRORS=0
WARNINGS=0
CHECKED_SKILLS=0

# Log functions
log_error() {
    echo -e "${RED}✗ $1${NC}" >&2
    ((ERRORS++)) || true
}

log_warning() {
    echo -e "${YELLOW}⚠ $1${NC}" >&2
    ((WARNINGS++)) || true
}

log_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

log_info() {
    echo -e "${GREEN}  → $1${NC}"
}

# Check if directory is a skill (has SKILL.md)
is_skill_dir() {
    [[ -f "$1/SKILL.md" ]]
}

# Extract YAML frontmatter value
get_frontmatter() {
    local file="$1"
    local key="$2"
    local default="${3:-}"

    # Use grep and sed for simple YAML extraction (no Python dependency)
    # Extract lines between first and second --- markers
    awk '
        BEGIN { in_fm = 0 }
        /^---$/ {
            if (in_fm == 0) { in_fm = 1; next }
            else { exit }
        }
        in_fm == 1 { print }
    ' "$file" 2>/dev/null | grep "^${key}:" | sed "s/^${key}: *//" || echo "$default"
}

# Validate frontmatter schema
validate_frontmatter() {
    local skill_dir="$1"
    local skill_name="$2"
    local skill_file="$skill_dir/SKILL.md"

    log_info "Checking frontmatter schema..."

    # Check for YAML frontmatter block
    if ! grep -q '^---$' "$skill_file"; then
        log_error "Missing YAML frontmatter block (no --- markers)"
        return
    fi

    # Extract frontmatter values
    local fm_name
    local fm_description
    local fm_allowed_tools

    fm_name="$(get_frontmatter "$skill_file" 'name' '')"
    fm_description="$(get_frontmatter "$skill_file" 'description' '')"
    fm_allowed_tools="$(get_frontmatter "$skill_file" 'allowed-tools' '')"

    # Check required fields
    if [[ -z "$fm_name" ]]; then
        log_error "Missing 'name:' field in frontmatter"
    elif [[ "$fm_name" != "$skill_name" ]]; then
        log_error "Frontmatter name '$fm_name' does not match directory name '$skill_name'"
    else
        log_success "  name: $fm_name"
    fi

    if [[ -z "$fm_description" ]]; then
        log_error "Missing 'description:' field in frontmatter"
    else
        log_success "  description: present (${#fm_description} chars)"
    fi

    if [[ -z "$fm_allowed_tools" ]]; then
        log_error "Missing 'allowed-tools:' field in frontmatter"
    else
        log_success "  allowed-tools: $fm_allowed_tools"
    fi
}

# Validate referenced files exist
validate_references() {
    local skill_dir="$1"
    local skill_file="$skill_dir/SKILL.md"

    log_info "Checking file references..."

    local missing_count=0

    # Check for CHECKLIST files
    for checklist in "$skill_dir"/CHECKLIST-*.md; do
        [[ -f "$checklist" ]] || continue
        log_success "  ✓ CHECKLIST file: $(basename "$checklist")"
    done

    # Check REPORT-TEMPLATE.md if referenced
    if grep -q 'REPORT-TEMPLATE' "$skill_file" && [[ ! -f "$skill_dir/REPORT-TEMPLATE.md" ]]; then
        log_error "Missing REPORT-TEMPLATE.md"
        ((missing_count++)) || true
    elif [[ -f "$skill_dir/REPORT-TEMPLATE.md" ]]; then
        log_success "  ✓ REPORT-TEMPLATE.md"
    fi

    # Check subagents directory
    if grep -q 'subagents/' "$skill_file"; then
        if [[ ! -d "$skill_dir/subagents" ]]; then
            log_warning "References subagents/ but directory does not exist"
        else
            local agent_count=0
            for agent in "$skill_dir"/subagents/*.md; do
                [[ -f "$agent" ]] || continue
                ((agent_count++)) || true
            done
            log_success "  ✓ subagents/ ($agent_count files)"
        fi
    fi

    # Check scripts directory
    if [[ -d "$skill_dir/scripts" ]]; then
        local script_count=0
        for script in "$skill_dir"/scripts/*.sh; do
            [[ -f "$script" ]] || continue
            ((script_count++)) || true
        done
        log_success "  ✓ scripts/ ($script_count files)"
    fi

    # Check references directory
    if [[ -d "$skill_dir/references" ]]; then
        local ref_count=0
        for ref in "$skill_dir"/references/*.md; do
            [[ -f "$ref" ]] || continue
            ((ref_count++)) || true
        done
        log_success "  ✓ references/ ($ref_count files)"
    fi

    if [[ $missing_count -eq 0 ]]; then
        log_success "  All referenced files present"
    fi
}

# Validate shell scripts
validate_shell_syntax() {
    local skill_dir="$1"

    if [[ ! -d "$skill_dir/scripts" ]]; then
        return
    fi

    log_info "Checking shell script syntax..."

    local found_scripts=0
    for script in "$skill_dir"/scripts/*.sh; do
        [[ -f "$script" ]] || continue

        ((found_scripts++)) || true
        local script_name
        script_name="$(basename "$script")"

        # Check bash syntax
        if bash -n "$script" 2>/dev/null; then
            log_success "  $script_name: bash syntax OK"
        else
            log_error "$script_name: bash syntax check failed"
        fi

        # Check shellcheck if available (report only, don't fail)
        if command -v shellcheck &>/dev/null; then
            if shellcheck "$script" &>/dev/null; then
                log_success "  $script_name: shellcheck clean"
            else
                log_warning "$script_name: shellcheck warnings (run manually for details)"
            fi
        fi
    done

    if [[ $found_scripts -eq 0 ]]; then
        log_info "  No shell scripts to check"
    fi
}

# Validate executable bits
validate_executable_bits() {
    local skill_dir="$1"

    if [[ ! -d "$skill_dir/scripts" ]]; then
        return
    fi

    log_info "Checking executable bits..."

    for script in "$skill_dir"/scripts/*.sh; do
        [[ -f "$script" ]] || continue

        local script_name
        script_name="$(basename "$script")"

        if [[ -x "$script" ]]; then
            log_success "  $script_name: executable"
        else
            log_error "$script_name: not executable (chmod +x needed)"
        fi
    done
}

# Validate a single skill
validate_skill() {
    local skill_dir="$1"
    local skill_name
    skill_name="$(basename "$skill_dir")"

    echo ""
    echo "=== Validating skill: $skill_name ==="

    if ! is_skill_dir "$skill_dir"; then
        log_error "Not a skill directory (missing SKILL.md)"
        return 1
    fi

    ((CHECKED_SKILLS++)) || true

    validate_frontmatter "$skill_dir" "$skill_name"
    validate_references "$skill_dir"
    validate_shell_syntax "$skill_dir"
    validate_executable_bits "$skill_dir"

    log_success "Skill '$skill_name' validation complete"
}

# Main
main() {
    local skills_to_check=()

    if [[ $# -eq 0 ]]; then
        # Find all skill directories (any dir with SKILL.md)
        for dir in "$REPO_ROOT"/*/; do
            if is_skill_dir "$dir"; then
                skills_to_check+=("$dir")
            fi
        done
    else
        # Validate specific directories
        for arg in "$@"; do
            local skill_dir
            if [[ "$arg" = /* ]]; then
                skill_dir="$arg"
            else
                skill_dir="$REPO_ROOT/$arg"
            fi

            if [[ ! -d "$skill_dir" ]]; then
                echo "Error: Not a directory: $skill_dir" >&2
                exit 2
            fi

            skills_to_check+=("$skill_dir")
        done
    fi

    if [[ ${#skills_to_check[@]} -eq 0 ]]; then
        echo "No skill directories found to validate."
        exit 0
    fi

    echo "Validating ${#skills_to_check[@]} skill(s)..."
    echo "Repo root: $REPO_ROOT"
    echo ""

    for skill_dir in "${skills_to_check[@]}"; do
        validate_skill "$skill_dir"
    done

    echo ""
    echo "========================================"
    echo "Validation Summary"
    echo "========================================"
    echo "Skills checked: $CHECKED_SKILLS"
    echo "Errors:          $ERRORS"
    echo "Warnings:        $WARNINGS"
    echo "========================================"

    if [[ $ERRORS -gt 0 ]]; then
        echo -e "${RED}FAILED: $ERRORS error(s) found${NC}"
        exit 1
    else
        echo -e "${GREEN}PASSED: All skills valid${NC}"
        exit 0
    fi
}

main "$@"
