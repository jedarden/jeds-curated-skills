# Self-Test: release-readiness

## Trigger Phrases

| Phrase | Expected |
|--------|----------|
| "are we ready to release?" · "go/no-go for the release" | Activates |
| "release readiness check" · "can we cut 1.2.0?" | Activates |
| "final check before I tag" | Activates |
| "/release-readiness 1.2.0" · "/release-readiness" | Activates |
| "cut the release for me" | Does NOT activate — this skill gates a release; it does not perform one |

## Structure

```bash
REPO="${REPO:-$HOME/jeds-curated-skills}"   # repo checkout; installed copies lag (see note)
SKILL_DIR="$REPO/release-readiness"
ls -1 "$SKILL_DIR"                # 4 CHECKLIST-*.md, REPORT-TEMPLATE.md, SELF-TEST.md,
                                  # SKILL.md, runbooks/, scripts/, subagents/
ls -1 "$SKILL_DIR/runbooks"       # HOTFIX.md
ls -1 "$SKILL_DIR/scripts"        # scan-release.sh
ls -1 "$SKILL_DIR/subagents"      # release-auditor.md
test -x "$SKILL_DIR/scripts/scan-release.sh" && echo "ok: executable"
```

Run the script tests against a **repo checkout**. This script is self-contained today, but
it is in scope for the shared-lib extraction — keep the pins below green through it.

## `scan-release.sh` fixture test

The script gathers raw release facts from whatever git repo it runs **inside** (it takes no
path argument — `cd` to the repo first). The fixture repo below has a known shape — any
drift means a detection pattern or the range logic changed. Update this file deliberately,
never silently. The fixture uses the CI marker this workspace actually uses (`.forgejo/`) —
never seed a `.github/workflows/` directory anywhere.

```bash
REPO="${REPO:-$HOME/jeds-curated-skills}"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/rel" && cd "$WORK/rel"
git init -q
git config user.email "github@jedarden.com"
git config user.name "jedarden"
mkdir -p src .forgejo/workflows

printf '# Changelog\n\n## 1.0.0\n- initial\n' > CHANGELOG.md
printf 'def handle(evt):\n    return evt\n' > src/app.py
git add CHANGELOG.md src/app.py && git commit -qm "v1.0.0 baseline"
git tag v1.0.0

printf 'def handle(evt):\n    # TODO: wire retries with backoff\n    return evt\n' > src/app.py
git add src/app.py && git commit -qm "feat: mark retry work"
printf 'def validate(evt):\n    # FIXME: reject unknown event types\n    raise ValueError\n' > src/handler.py
git add src/handler.py && git commit -qm "feat: add handler skeleton"
printf '{"name":"digestsrv","version":"1.1.0"}\n' > package.json
printf '{"lockfileVersion":3}\n' > package-lock.json
printf 'name: ci\non: [push]\njobs:\n  build:\n    runs-on: linux\n    steps:\n      - run: echo ok\n' > .forgejo/workflows/ci.yml
git add package.json package-lock.json .forgejo/workflows/ci.yml && git commit -qm "chore: release metadata"

"$REPO/release-readiness/scripts/scan-release.sh"
echo "exit=$?"
```

**Expected** (commit hashes will differ — everything else is pinned):

```
Last release tag: v1.0.0
Range: v1.0.0..HEAD

Commits since last release: 3
--- recent commit subjects ---
  <hash> chore: release metadata
  <hash> feat: add handler skeleton
  <hash> feat: mark retry work

Changed files: 5
  .forgejo/workflows/ci.yml
  package-lock.json
  package.json
  src/app.py
  src/handler.py

Working tree: clean

--- Changelog ---
  found: CHANGELOG.md

--- Version files ---
  found: package.json

--- Lockfiles ---
  found: package-lock.json

--- CI config ---
  found: .forgejo/workflows/ci.yml

--- Leftover TODO / FIXME / debug markers in changed files ---
  src/app.py:2:    # TODO: wire retries with backoff
  src/handler.py:2:    # FIXME: reject unknown event types
  (2 marker(s) found — review before release)

=== End Scan ===
```

- The tag comes from `git describe --tags --abbrev=0 HEAD^` — the fixture needs ≥ 2
  commits for `HEAD^` to exist. With **no tags at all** the script says
  `Last release tag: (none found — treating as first release)` and ranges from the root.
- Marker scan skips `*test*`, `*spec*`, `*fixture*`, `*.md`, `*CHANGELOG*` paths — that is
  why CHANGELOG.md's version strings are not flagged and why the fixture's marker files
  live under `src/`. Renaming `src/app.py` to `src/test_app.py` would drop its TODO from
  the report (the skip is a filename glob, not a directory rule).
- Marker lines are `file:line:content` — grep -n output, indented two spaces.

```bash
# --- Dirty tree and usage error ---
printf 'x\n' >> src/app.py
"$REPO/release-readiness/scripts/scan-release.sh" | grep 'Working tree'
# → Working tree: DIRTY (uncommitted changes present)   — itself a CONDITIONAL at best
git -C "$WORK/rel" checkout -q -- src/app.py

cd "$WORK"   # outside any git repo
"$REPO/release-readiness/scripts/scan-release.sh"; echo "exit=$?"
# → Usage: scan-release.sh [target-ref]   (must be run inside a git repository)  exit=1
```

## Functional Test (LLM in the loop)

Run `/release-readiness` inside the fixture repo. Expected:

- Gates rated strictly on evidence: PRESENT only because a file/fact was shown by the scan
  (changelog exists but has no `## 1.1.0` entry yet → the versioning gate is not satisfied
  for cutting 1.1.0).
- The two marker hits are surfaced as blocking-or-acknowledged items, quoted with their
  `file:line`.
- Verdict for the fixture as-is: **NO-GO or CONDITIONAL** — version in package.json says
  1.1.0, changelog's top entry is 1.0.0, and the working tree must be clean at cut time.
- A target argument (`/release-readiness 1.1.0`) is treated as the version under
  evaluation; the report compares it against the evidence.
- Follows REPORT-TEMPLATE.md; the skill proposes nothing destructive and never tags.

## Expected Behaviors

- **Facts first**: the script is the evidence layer; the reviewer never rates a gate PRESENT
  without a scan line or a file it can cite.
- **Exit codes**: 0 on any successful scan (findings are report, not failure), 1 when not
  inside a git repo.
- **Run inside the repo**: no path argument — a common mistake is running it from the skill
  dir; the usage message is the tell.
- **First-release path**: no tags → range from root, all tracked files counted as changed;
  still a valid scan.
- **Debug-marker patterns** cover TODO/FIXME/XXX/HACK, `console.log`, `println!("DEBUG")`,
  `debugger;`, `binding.pry`, `import pdb`, `breakpoint()` — extend the list and re-pin the
  fixture count (2) deliberately.
