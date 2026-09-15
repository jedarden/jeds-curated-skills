# Self-Test: test-plan-review

## Trigger Phrases

| Phrase | Expected |
|--------|----------|
| "what isn't tested?" · "audit my test suite" · "review my tests" | Activates |
| "which tests would pass even if the code is broken?" | Activates |
| "review this TESTING.md / test plan" | Activates |
| "/test-plan-review tests/" | Activates |
| "write a unit test for this function" | Does NOT activate — that is ordinary implementation work; this skill reviews suites, it does not author tests |

## Structure

```bash
REPO="${REPO:-$HOME/jeds-curated-skills}"   # repo checkout; installed copies lag (see note)
SKILL_DIR="$REPO/test-plan-review"
ls -1 "$SKILL_DIR"                # 4 CHECKLIST-*.md, REPORT-TEMPLATE.md, SELF-TEST.md,
                                  # SKILL.md, references/, scripts/, subagents/
ls -1 "$SKILL_DIR/references"     # MISSING-TEST-PATTERNS.md
ls -1 "$SKILL_DIR/scripts"        # scan-tests.sh
ls -1 "$SKILL_DIR/subagents"      # test-reviewer.md
test -x "$SKILL_DIR/scripts/scan-tests.sh" && echo "ok: executable"
```

Run the script tests against a **repo checkout**. This script is self-contained today, but
it is in scope for the shared-lib extraction — keep the pins below green through it.

## `scan-tests.sh` fixture test

The script inventories test files, counts test functions per file, detects frameworks, and
flags source directories with no co-located tests. The fixture below has known counts — any
drift means the file classification, count patterns, prune list, or co-location rule
changed. Update this file deliberately, never silently.

```bash
REPO="${REPO:-$HOME/jeds-curated-skills}"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/proj/src" "$WORK/proj/lib" "$WORK/proj/tests" \
         "$WORK/proj/node_modules/pkg" "$WORK/proj/vendor"

cat > "$WORK/proj/main.go" <<'EOF'
package main

func Sum(a, b int) int { return a + b }
EOF
cat > "$WORK/proj/main_test.go" <<'EOF'
package main

import "testing"

func TestSum(t *testing.T) {
	if Sum(1, 2) != 3 {
		t.Fail()
	}
}

func TestNegative(t *testing.T) {
	if Sum(-1, -1) != -2 {
		t.Fail()
	}
}
EOF
cat > "$WORK/proj/src/app.py" <<'EOF'
def run(digest):
    return digest.render()
EOF
cat > "$WORK/proj/src/helper.py" <<'EOF'
def pad(s):
    return " " + s
EOF
cat > "$WORK/proj/lib/parse.py" <<'EOF'
def parse(line):
    return line.split(",")
EOF
cat > "$WORK/proj/lib/parse_test.py" <<'EOF'
from parse import parse

def test_simple():
    assert parse("a,b") == ["a", "b"]

def test_spaces():
    assert parse(" a , b ") == [" a ", " b "]

def test_empty():
    assert parse("") == [""]
EOF
cat > "$WORK/proj/tests/test_api.py" <<'EOF'
def test_status():
    assert True

def test_list():
    assert True

def test_create():
    assert True

def test_delete():
    assert True
EOF
printf 'module.exports = 1;\n' > "$WORK/proj/node_modules/pkg/index.js"  # pruned
printf 'package main\n\nfunc TestVendored(t *testing.T) {}\n' > "$WORK/proj/vendor/v_test.go"  # pruned

"$REPO/test-plan-review/scripts/scan-tests.sh" "$WORK/proj"
echo "exit=$?"
```

**Expected:**

```
Files: 3    Test functions: 9
```

Per-file counts (order may vary — find order is not sorted):

```
     3  lib/parse_test.py
     2  main_test.go
     4  tests/test_api.py
```

- `Files: 3` — `node_modules/pkg/index.js` and `vendor/v_test.go` are **pruned from the
  inventory** (the `.git/node_modules/target/dist/build/.venv/venv/__pycache__/vendor`
  prune list) even though both filenames look like test files. If that vendored test file
  appears in the listing, the prune broke.
- Frameworks detected: exactly `go test (Go)` and `pytest / unittest (Python)` (sorted).
  Python matches on `def test_`; go on `func Test[A-Z]` — `main.go` itself has no test
  functions and must not add anything.
- Co-location: `src` is the **only** flagged source dir (its two .py files have no
  `*_test.py` beside them). `lib` is cleared by `parse_test.py`; the repo root is cleared
  by `main_test.go` (the check is one directory level deep); `tests/` itself is never
  flagged (all its files are test files).

```
Source dirs lacking co-located tests: 1
```

followed by the NOTE pair about parallel test trees ("coverage SUSPECTS, not proof").
Successful runs always `exit=0`.

```bash
# --- Sharp edge: framework detection does NOT honor the prune list ---
printf "test('adds', () => { expect(1).toBe(1); });\n" \
  > "$WORK/proj/node_modules/pkg/index.js"
"$REPO/test-plan-review/scripts/scan-tests.sh" "$WORK/proj" | sed -n '/Detected/,/^$/p'
# → the framework list now ALSO shows "jest / mocha / vitest (JS/TS)", while the file
#   inventory stays "Files: 3" — detect() greps recursively without the prune list.
#   A framework "found" only under node_modules/ is noise; judge it before acting on it.
rm "$WORK/proj/node_modules/pkg/index.js"

# --- Usage errors ---
"$REPO/test-plan-review/scripts/scan-tests.sh"; echo "exit=$?"            # exit=1
"$REPO/test-plan-review/scripts/scan-tests.sh" "$WORK/nope"; echo "exit=$?"  # exit=1
```

## Functional Test (LLM in the loop)

Run `/test-plan-review` on the fixture project above. Expected:

- The review starts from the scan (3 files, 9 functions, `src` untested) and goes beyond
  it: the four `test_api.py` tests are `assert True` stubs — tests that **pass for the
  wrong reasons**, which is CHECKLIST-02-FAILURE territory, not just coverage.
- Coverage gaps are named as behaviors, not files: e.g. `parse()`'s whitespace handling is
  tested but its error path (no comma) is not; `Sum` has no overflow/negative-boundary
  test named as such.
- Non-functional gaps from CHECKLIST-03 (performance, concurrency) are raised or explicitly
  N/A'd — not silently skipped.
- Report follows REPORT-TEMPLATE.md; findings are suspects with evidence, never verdicts.

## Expected Behaviors

- **Inventory before judgment**: the scan is the evidence base; the reviewer's value is
  what the counts *conceal* (stub tests, wrong-reason passes, missing failure paths).
- **Exit codes**: 0 on any successful scan, 1 on usage error.
- **File classification is name-and-path based**: `*_test.go`, `test_*.py`, `*.test.ts`,
  anything under `tests/`, `spec/`, `__tests__/`, etc. — a test in an odd location
  (`check_regressions.py`) is invisible to the scan and must be caught by the reviewer.
- **Co-location is one level deep**: a `src/` with tests only in a parallel `tests/` tree
  still gets flagged — by design; the NOTE says to confirm, not to fix the flag.
