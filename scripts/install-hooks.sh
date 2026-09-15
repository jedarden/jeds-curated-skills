#!/usr/bin/env bash
#
# install-hooks.sh - Install git hooks for jeds-curated-skills repository
#
# Installs a git pre-commit hook that runs scripts/validate-skills.sh (skill
# bundle validation, per ADR-1) and scripts/test-root-scripts.sh (contract
# tests for check-installed.sh's exit codes and install.sh's flag behavior)
# before each commit, catching structural issues early.
#
# Per ADR-1 (2026-07-20), hooks are not versioned by git, so this script is the
# install step for local repo checkouts.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
HOOKS_DIR="$REPO_ROOT/.git/hooks"
PRE_COMMIT_HOOK="$HOOKS_DIR/pre-commit"

# Color output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}✓ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠ $1${NC}" >&2
}

log_error() {
    echo -e "${RED}✗ $1${NC}" >&2
}

# Check we're in a git repo
if [[ ! -d "$HOOKS_DIR" ]]; then
    log_error "Not in a git repository (no .git/hooks directory)"
    exit 1
fi

# Check both hook scripts exist
VALIDATE_SCRIPT="$SCRIPT_DIR/validate-skills.sh"
if [[ ! -f "$VALIDATE_SCRIPT" ]]; then
    log_error "validate-skills.sh not found at $VALIDATE_SCRIPT"
    exit 1
fi
CONTRACT_TEST="$SCRIPT_DIR/test-root-scripts.sh"
if [[ ! -f "$CONTRACT_TEST" ]]; then
    log_error "test-root-scripts.sh not found at $CONTRACT_TEST"
    exit 1
fi

# Check if pre-commit hook already exists
if [[ -f "$PRE_COMMIT_HOOK" ]]; then
    # Check if it's our hook
    if grep -q "validate-skills.sh" "$PRE_COMMIT_HOOK" 2>/dev/null; then
        if grep -q "test-root-scripts.sh" "$PRE_COMMIT_HOOK" 2>/dev/null; then
            log_info "pre-commit hook already installed (validate-skills.sh + test-root-scripts.sh)"
            echo "Run: $PRE_COMMIT_HOOK"
            exit 0
        fi
        log_info "pre-commit hook found (validate-skills.sh only) — adding test-root-scripts.sh"
    else
        log_warning "Existing pre-commit hook found. Backing up to pre-commit.backup"
        cp "$PRE_COMMIT_HOOK" "$PRE_COMMIT_HOOK.backup"
    fi
fi

# Create the pre-commit hook
cat > "$PRE_COMMIT_HOOK" <<'EOF'
#!/usr/bin/env bash
#
# Git pre-commit hook for jeds-curated-skills
# Runs validate-skills.sh (skill bundles) and test-root-scripts.sh (root
# script contracts) before each commit

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Run validation against any changed skill directories
# If either fails, the commit is aborted

bash "$REPO_ROOT/scripts/validate-skills.sh" || exit 1
bash "$REPO_ROOT/scripts/test-root-scripts.sh" || exit 1
EOF

chmod +x "$PRE_COMMIT_HOOK"

log_info "Installed pre-commit hook"
echo ""
echo "Hook installed: $PRE_COMMIT_HOOK"
echo "This will run scripts/validate-skills.sh and scripts/test-root-scripts.sh"
echo "before each commit."
echo ""
echo "To test it manually:"
echo "  bash .git/hooks/pre-commit"
echo ""
echo "To remove the hook:"
echo "  rm .git/hooks/pre-commit"
