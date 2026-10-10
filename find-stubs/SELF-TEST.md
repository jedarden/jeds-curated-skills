# Self-Test: find-stubs

## Trigger Phrases

| Phrase | Expected |
|--------|----------|
| "check for stub code" | Activates |
| "find incomplete/fake code" | Activates |
| "sweep for TODOs and placeholders" | Activates |
| "/find-stubs" | Activates |
| "/find-stubs ~/path/to/repo --create-beads" | Activates |

## Skill Structure Validation

```bash
SKILL_DIR="$HOME/.claude/skills/find-stubs"

echo "=== Skill Structure ==="
ls -1 "$SKILL_DIR/"
echo ""
echo "=== Script executable ==="
test -x "$SKILL_DIR/scripts/find_stubs.sh" && echo "✓ Executable" || echo "✗ Not executable"
```

## Script Smoke Tests

The deterministic parts of this section (all four categories detected, exact
text/JSON output, exit codes) run automatically via
`scripts/test-script-fixtures.sh` at the repo root — wired into the pre-commit
hook, so a detector or exit-code drift fails before it ships. The steps here
are the manual equivalent.

```bash
SKILL_DIR="$HOME/.claude/skills/find-stubs"

# Test 1: Fixture repo with one planted finding per category
cd /tmp
rm -rf test-find-stubs-repo
git init -q test-find-stubs-repo
cd test-find-stubs-repo
git config user.email "test@example.com"
git config user.name "Test User"

cat > clean.py <<'EOF'
def add(a, b):
    return a + b
EOF

cat > stubby.rs <<'EOF'
fn compute() -> i32 {
    todo!()
}
EOF

# empty-catch-swallow needs the bare `except: pass` form on one line — a
# two-line try/except with a typed exception does NOT match the pattern
# (`except\s*:\s*pass\s*$` is single-line, by design: a typed except clause
# with a real pass body is a much weaker signal of a swallowed error).
printf 'def risky():\n    try:\n        do_thing()\n    except: pass\n' > swallow.py

cat > notes.py <<'EOF'
# TODO: wire real auth
def placeholder_config():
    return {"key": "hardcoded for now"}
EOF

git add -A && git commit -qm "seed fixture"

echo "=== Test 1: text output (expect 4 findings, exit 1) ==="
"$SKILL_DIR/scripts/find_stubs.sh" .
echo "exit: $?"
echo ""

echo "=== Test 2: JSON output ==="
"$SKILL_DIR/scripts/find_stubs.sh" . --json
echo "exit: $?"
echo ""

# Test 3: clean repo, exit 0
cd /tmp
rm -rf test-find-stubs-clean
git init -q test-find-stubs-clean
cd test-find-stubs-clean
git config user.email "test@example.com"
git config user.name "Test User"
cat > ok.py <<'EOF'
def add(a, b):
    return a + b
EOF
git add -A && git commit -qm "clean"
echo "=== Test 3: clean repo (expect 0 findings, exit 0) ==="
"$SKILL_DIR/scripts/find_stubs.sh" .
echo "exit: $?"

# Cleanup
cd /
rm -rf /tmp/test-find-stubs-repo /tmp/test-find-stubs-clean
```

**Pinned expected output (Test 1, text mode):**

```
=== find-stubs report: . ===
4 findings

--- leftover-todo (1) ---
  ./notes.py:1: # TODO: wire real auth

--- explicit-unimplemented (1) ---
  ./stubby.rs:2: todo!()

--- empty-catch-swallow (1) ---
  ./swallow.py:4: except: pass

--- placeholder-marker (1) ---
  ./notes.py:3: return {"key": "hardcoded for now"}

exit: 1
```

**Pinned expected output (Test 3, clean repo):**

```
=== find-stubs report: . ===
0 findings

exit: 0
```

**A bug was found and fixed while building this fixture (2026-10-10):** the
bare `cd "$REPO"` at the top of the script had no error guard, so a
genuinely missing path crashed on the bash builtin's own stderr message with
exit 1 — not the documented `2` usage error, and inconsistent with an
*existing*-but-non-git path, which already correctly exited 2. Fixed by
checking `cd`'s own exit status and emitting a matching usage error.

## Functional Test

To verify the full skill works end-to-end:

```
/find-stubs
```

Expected output:
- Report grouped by category, file:line + matched snippet
- Exit code 0 if clean, 1 if findings, 2 on usage error / not a git repo / ripgrep missing
- With `--create-beads` against a repo with a `.beads/` store: one bead per
  surviving finding, backend-detected first (bead-rs `bead create` with
  `--label stub-finder --label human` — never bare-forge `bf create`), deduped
  against `bead list --json` before creating

## Expected Behaviors

- **Report-only by default**: beads are only filed on explicit `--create-beads` or ask.
- **Exit codes**: 0 = clean, 1 = findings, 2 = usage error / not a git repo / ripgrep missing.
- **Text-pattern matching, not structural analysis**: false positives (a docstring
  mentioning "placeholder") and false negatives (fake code with no telltale marker)
  are both expected; judgment is applied before filing, not inside the script.
- **Bead backend detection before filing**: `.beads/config.json` → bead-rs (canonical);
  `.beads/config.yaml` → legacy bf (stop and report blocked, don't improvise); no
  `.beads/` → print and skip, no error.
- **`--label human`** on every filed bead — stays out of NEEDLE's default Pluck
  ready frontier until a human reviews it; a sweep's findings are proposals, not
  admitted work.
