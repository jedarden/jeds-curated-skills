# Self-Test: plan-vs-built

## Trigger Phrases

| Phrase | Expected |
|--------|----------|
| "what's left to build" | Activates |
| "is this project really done" | Activates |
| "check the plan against what's built" | Activates |
| "/plan-vs-built" | Activates (sweeps every repo with a plan under cwd) |
| "/plan-vs-built ~/path/to/repo --create-beads" | Activates (single repo) |

## Skill Structure Validation

```bash
SKILL_DIR="$HOME/.claude/skills/plan-vs-built"

echo "=== Skill Structure ==="
ls -1 "$SKILL_DIR/"
echo ""
echo "=== Scripts ==="
ls -la "$SKILL_DIR/scripts/"
echo ""
echo "=== Executable bits ==="
for f in sweep.sh collect-evidence.sh check-phantom-refs.py; do
  test -x "$SKILL_DIR/scripts/$f" && echo "✓ $f executable" || echo "✗ $f not executable"
done
```

## Script Smoke Tests

**`check-phantom-refs.py`** is self-contained (one git repo, no external
service, no `declarative-config` dependency) and its fixture runs
automatically via `scripts/test-script-fixtures.sh`, wired into the
pre-commit hook. The steps below are the manual equivalent.

**`sweep.sh` and `collect-evidence.sh` are not automated here — honestly, not
by oversight.** Both require a real `$HOME/declarative-config` checkout, Argo
CI template references, a live (or at least plausible) bead store, and
container `VERSION` files to produce a meaningful snapshot; a mktemp sandbox
fixture would either fake those externalities (false confidence) or exercise
only the trivial "not a git repo" exit path (no real coverage). They're
`FIXTURE_EXEMPT` in `scripts/test-script-fixtures.sh` with this reasoning
inline. Exercise them manually against a real repo with a plan:

```bash
SKILL_DIR="$HOME/.claude/skills/plan-vs-built"
"$SKILL_DIR/scripts/collect-evidence.sh" ~/some-real-repo --out /tmp/pvb-manual
cat /tmp/pvb-manual/*/snapshot.txt
```

### `check-phantom-refs.py` fixture

Two bugs were found and fixed while building this fixture (2026-10-10):

1. The relative-import branch of `py_refs()` (`from .x import y`) had a
   misplaced `continue` that skipped the yield loop entirely, so relative
   Python imports were silently never checked — only absolute
   (`from pkg.x import y` / `import pkg.x`) imports worked. Fixed by making
   the two `ImportFrom` branches properly `if`/`elif` exclusive instead of
   `if` + `continue`.
2. The documented contract ("Exit: 0 always … 2 on usage error") wasn't
   actually implemented: a missing path crashed with an uncaught
   `subprocess.run` `FileNotFoundError` (exit 1, a raw traceback, no usage
   message), and an existing-but-non-git directory fell through to an
   *empty* tracked-file set and silently reported a false-clean "no
   dangling refs" for a directory that was never scanned at all. Fixed with
   explicit upfront validation (`Path(repo).is_dir()`, then a non-empty
   `git rev-parse --show-toplevel`) returning 2 with a clear stderr message
   in both failure cases.

The fixture below exercises the now-fixed relative-import path, the
already-working absolute-import path, and both corrected usage-error cases,
so a regression in any of them shows up here.

```bash
SKILL_DIR="$HOME/.claude/skills/plan-vs-built"
cd /tmp
rm -rf test-phantom-fixture
mkdir -p test-phantom-fixture/pkg
cd test-phantom-fixture
git init -q
git config user.email "test@example.com"
git config user.name "Test User"
touch pkg/__init__.py
cat > pkg/helper.py <<'EOF'
def run():
    return 1
EOF
cat > pkg/main.py <<'EOF'
from .helper import run
from .untracked_sibling import thing
from .ghost_missing import other
EOF
git add pkg/__init__.py pkg/helper.py pkg/main.py
git commit -qm "relative-import baseline: one resolves, two dangle"
echo "existing but untracked" > pkg/untracked_sibling.py

echo "=== Test 1: text output ==="
python3 "$SKILL_DIR/scripts/check-phantom-refs.py" .
echo "exit: $?"
echo ""

echo "=== Test 2: JSON output ==="
python3 "$SKILL_DIR/scripts/check-phantom-refs.py" . --json
echo "exit: $?"
echo ""

echo "=== Test 3: clean repo (no dangling refs) ==="
cd /tmp
rm -rf test-phantom-clean
mkdir -p test-phantom-clean/pkg
cd test-phantom-clean
git init -q
git config user.email "test@example.com"
git config user.name "Test User"
touch pkg/__init__.py
cat > pkg/helper.py <<'EOF'
def run():
    return 1
EOF
cat > pkg/main.py <<'EOF'
from .helper import run
from pkg.helper import run as run2
EOF
git add -A && git commit -qm "clean: both refs resolve"
python3 "$SKILL_DIR/scripts/check-phantom-refs.py" .
echo "exit: $?"

echo "=== Test 4: usage errors ==="
python3 "$SKILL_DIR/scripts/check-phantom-refs.py" /tmp/definitely-does-not-exist-xyz
echo "exit: $?"
mkdir -p /tmp/test-phantom-not-a-repo
python3 "$SKILL_DIR/scripts/check-phantom-refs.py" /tmp/test-phantom-not-a-repo
echo "exit: $?"

cd /
rm -rf /tmp/test-phantom-fixture /tmp/test-phantom-clean /tmp/test-phantom-not-a-repo
```

**Pinned expected output (Test 1, text mode):**

```
  1 PHANTOM reference(s) -- tracked code points at an UNTRACKED file.
    Works in this checkout only; a fresh clone breaks, and deleting this
    working tree destroys the only copy.
      pkg/main.py:2 -> pkg/untracked_sibling.py
  1 MISSING reference(s) -- target is not on disk at all.
      pkg/main.py:3 -> pkg/ghost_missing
exit: 0
```

(`pkg/main.py:1`'s `from .helper import run` correctly produces no finding —
`pkg/helper.py` is tracked, so it's a resolved reference, not a gap. Exit is
always 0 for both verdicts; findings are data, not a script failure — a
usage error is the only `exit 2`.)

**Pinned expected output (Test 2, JSON mode):** `"phantom": 1, "missing": 1`,
with `findings` carrying both entries (`verdict`, `source`, `line`, `target`).

**Pinned expected output (Test 3, clean repo):**

```
  no tracked file references an untracked or missing local path
exit: 0
```

**Pinned expected output (Test 4, usage errors):**

```
error: not a directory: /tmp/definitely-does-not-exist-xyz
exit: 2
error: not a git repository: /tmp/test-phantom-not-a-repo
exit: 2
```

## Functional Test

To verify the full skill end-to-end:

```
/plan-vs-built
```

Expected: sweeps every repo under cwd with a `docs/plan/plan.md` or root
`plan.md` by default (never asks which one), writes a per-repo ledger,
produces a verdict table (`BUILT`/`UNPROVEN`/`PARTIAL`/`STUB`/`ABSENT`/
`DIVERGENT`/`PLAN-STALE`) backed by an observation per deliverable, audits
closed beads against those verdicts for false closures, and states the
coverage line (`Swept N repos; full audit on M; triage-only on N−M`) before
anything else.

## Expected Behaviors

- **Read-only and side-effect-free collection**: `sweep.sh`/`collect-evidence.sh`
  never build, never run tests, never touch a bead store or a cluster — they
  only read.
- **`check-phantom-refs.py` always exits 0 on a successful scan** (findings are
  data); exit 2 is usage error only.
- **A flag is not a verdict** — `sweep.sh`'s SCORE/FLAGS rank where to look;
  only a per-deliverable observation (Steps 4–6) settles anything.
- **Bead backend detection before writing** — same bead-rs/bf detection
  discipline as `find-stubs` and `plan-to-bead`; a MISMATCH or bf-shaped store
  stops the run rather than improvising.
- **`--label human`** on every filed gap bead, alongside `--label plan-gap` —
  stays out of the ready frontier until a human admits it.
- **`DIVERGENT`/`PLAN-STALE` ask before writing** — a gap can mean the code is
  behind the plan or the plan is behind the code; beading phantom work is worse
  than missing a gap.
