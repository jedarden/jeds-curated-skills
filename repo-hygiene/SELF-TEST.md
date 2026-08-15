# Self-Test: repo-hygiene

## Trigger Phrases

These should activate this skill:

| Phrase | Expected |
|--------|----------|
| "check repo hygiene" | Activates |
| "audit this repo" | Activates |
| "repo hygiene check" | Activates |
| "check for committed artifacts" | Activates |
| "clean up this repo" | Activates |
| "repo hygiene audit" | Activates |
| "/repo-hygiene" | Activates |
| "/repo-hygiene --fix" | Activates |
| "/repo-hygiene ~/path/to/repo" | Activates |

## Skill Structure Validation

```bash
SKILL_DIR="$HOME/.claude/skills/repo-hygiene"

echo "=== Skill Structure ==="
ls -1 "$SKILL_DIR/"
echo ""
echo "=== Scripts ==="
ls -la "$SKILL_DIR/scripts/"
echo ""
echo "=== Script executable ==="
test -x "$SKILL_DIR/scripts/repo_hygiene.sh" && echo "✓ Executable" || echo "✗ Not executable"
```

## Script Smoke Tests

```bash
SKILL_DIR="$HOME/.claude/skills/repo-hygiene"

# Test 1: Run against this repo (known clean as of 2026-07-20)
echo "=== Test 1: Clean repo (this repo) ==="
"$SKILL_DIR/scripts/repo_hygiene.sh" .
echo ""

# Test 2: JSON output against clean repo
echo "=== Test 2: JSON output (clean repo) ==="
"$SKILL_DIR/scripts/repo_hygiene.sh" --json . | head -5
echo ""

# Test 3: Scratch repo with seeded violations
cd /tmp
rm -rf test-hygiene-repo
git init test-hygiene-repo
cd test-hygiene-repo
git config user.email "test@example.com"
git config user.name "Test User"

# Create a package.json but don't ignore node_modules
cat > package.json <<EOF
{
  "name": "test-repo",
  "version": "1.0.0"
}
EOF
mkdir -p node_modules/lodash
echo "fake module" > node_modules/lodash/index.js
git add .
git commit -m "add package.json and committed node_modules"

# Create a large tracked file (>5MB)
dd if=/dev/zero of=large-blob.bin bs=1M count=6 2>/dev/null
git add large-blob.bin
git commit -m "add large tracked file"

# Create a dead GitHub Actions workflow
mkdir -p .github/workflows
cat > .github/workflows/test.yml <<EOF
name: Test
on: push
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - run: echo "dead workflow"
EOF
git add .
git commit -m "add dead CI workflow"

echo "=== Test 3: Repo with seeded violations ==="
"$SKILL_DIR/scripts/repo_hygiene.sh"
echo ""

# Cleanup
cd /
rm -rf /tmp/test-hygiene-repo
```

## Functional Test

To verify the full skill works end-to-end, run:

```
/repo-hygiene
```

Expected output:
- Audit report with category/severity/count/examples structure
- Exit code 0 if clean, 1 if findings
- For each finding category:
  - Severity level (high/medium/low/needs-review)
  - Count of findings
  - Up to 10 example paths
- Final line: "N finding categories/ies. Report only — nothing was modified."

Test with `--fix` mode (in a scratch repo only, never your working repo):

```
cd /tmp && mkdir test-fix && cd test-fix && git init
# ... create violations ...
/repo-hygiene --fix
```

Expected `--fix` behavior:
- Preconditions checked (no merge in progress, correct repo)
- Separate commits per category (`.gitignore` first, then build artifacts, then workflows, then README)
- Staging with explicit paths (never `git add -A`)
- Re-run audit to confirm categories cleared
- No push unless user asks

## Expected Behaviors

- **Report-only by default**: The script never modifies anything without explicit `--fix`.
- **Exit codes**: 0 = clean, 1 = findings, 2 = usage error / not a git repo.
- **Safe git access**: Uses `git --no-optional-locks` to avoid touching the index.
- **No credential reading**: Suspicious files (`.env`, `*.pem`, `*.key`) are flagged but never read.
- **Fleet-mode compatible**: The script alone is the cross-harness interface (no Claude Code machinery required).
- **Fix mode guards**: Preconditions checked, explicit path staging, one commit per category, never force-pushes or rewrites history.
