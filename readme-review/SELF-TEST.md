# Self-Test: readme-review

## Trigger Phrases

| Phrase | Expected |
|--------|----------|
| "review this README" · "is my README any good?" | Activates |
| "can a stranger install this from the docs?" | Activates |
| "check the README before we open-source it" | Activates |
| "/readme-review README.md" | Activates |
| "write me a README from scratch" | Does NOT activate — this skill reviews and redrafts sections of an existing README |

## Structure

```bash
REPO="${REPO:-$HOME/jeds-curated-skills}"   # repo checkout; installed copies lag (see note)
SKILL_DIR="$REPO/readme-review"
ls -1 "$SKILL_DIR"                # 4 CHECKLIST-*.md, REPORT-TEMPLATE.md, SELF-TEST.md,
                                  # SKILL.md, references/, scripts/, subagents/
ls -1 "$SKILL_DIR/references"     # README-PATTERNS.md
ls -1 "$SKILL_DIR/scripts"        # score-readme.sh
test -x "$SKILL_DIR/scripts/score-readme.sh" && echo "ok: executable"
```

Run the script tests against a **repo checkout**: the script sources
`../../lib/common.sh`, and an installed copy without `lib/` fails to source at all.

## `score-readme.sh` fixture tests

The script runs 14 rubric checks (13 greps + 3 sibling-file checks counted as 4.1b/4.2/4.6),
detects the project type from sibling files, and scans for placeholders. The fixture below
is built to pass exactly 12 of 14. Any drift means a pattern or the shared
`check()`/`print_failures()` changed — update this file deliberately, never silently.

````bash
REPO="${REPO:-$HOME/jeds-curated-skills}"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/repo" && cd "$WORK/repo"
touch Cargo.toml LICENSE        # library signal (no [[bin]]) + a present LICENSE file

cat > README.md <<'EOF'
# digestsrv

[![status](https://shields.io/badge/release-beta-blue)](https://example.invalid)

Delivery digest service that batches notification events into scheduled emails.

```bash
cargo install digestsrv
digestsrv --version
# You should see: digestsrv 0.4.1
```

## Prerequisites

You will need a Rust toolchain (1.75+) and a reachable SMTP relay.

## Installation

Install from source: `cargo install --path .`

## Quickstart

See the getting started example above, then send your first digest.

## Configuration

| Environment variable | Default | Meaning |
|---|---|---|
| `DIGESTSRV_SMTP_HOST` | — | relay hostname |

<!-- TODO: document the retry policy knobs -->

## API Reference

Endpoints exposed by the scheduler are documented in docs/api.md.

## Troubleshooting

Common issues: relay auth failures and clock skew.

## License

MIT. Copyright 2026 jedarden.
EOF
"$REPO/readme-review/scripts/score-readme.sh" README.md
echo "exit=$?"
````

**Expected:**

```
Detected project type: library (package manifest, no bin — confirm)
Repo signals: Cargo.toml

Word count: 117
Top-level/section headings: 9

Heuristic score: 12 / 14 (85%)

Status: STRONG (run the full review to catch depth/type gaps)
```

- Section inventory lists **9 headings** — 8 real ones **plus line 10 inside the bash
  fence** (`# You should see: digestsrv 0.4.1`). The inventory greps `^#{1,3} ` and does
  not know about code fences — pinned here so a fence-awareness fix is a *visible,
  deliberate* change.
- `--- Missing (heuristic) ---` lists exactly: `MISSING: 4.2 CONTRIBUTING` and
  `MISSING: 4.6 Changelog` (no CONTRIBUTING/CHANGELOG file exists in the fixture dir).
  Everything else passes, 4.1b on the touched `LICENSE` file.
- Placeholder scan (4.7) reports the line-numbered hit:
  `31:<!-- TODO: document the retry policy knobs -->` under
  `--- Placeholder / TODO links found (item 4.7) ---`.
- Final two lines are the NOTE pair ("heuristics only — grep cannot judge…"). Successful
  runs always `exit=0` — a weak README is a report, not a failure.

### Known trap: leading-dash patterns in `check()`

`score-readme.sh` check 2.7 includes the literal pattern `--version`. A `check()` that
passes patterns to grep without `-e`/`--` makes grep parse it as a *flag*: grep prints its
own version banner into the output and the check "passes" without reading the file. HEAD's
inline helper used `grep -qiE -e "$pattern"`; if a banner appears above the
`=== README Score ===` line, the shared lib dropped the `-e` — restore it before trusting
any pin above. The fixture is built so 2.7 also passes legitimately (`You should see`), so
the score above is identical either way.

### Type-detection ladder

```bash
cd "$WORK" && mkdir -p t-cli t-svc t-unk
printf '{"name":"x","version":"0.1.0","bin":{"x":"cli.js"}}' > t-cli/package.json
printf '# x\n\nA tool.\n' > t-cli/README.md
touch t-svc/Dockerfile && printf '# x\n\nA service.\n' > t-svc/README.md
printf '# x\n\nSomething.\n' > t-unk/README.md
for d in t-cli t-svc t-unk; do
  "$REPO/readme-review/scripts/score-readme.sh" "$d/README.md" | grep '^Detected project type:'
done
```

Expected, in precedence order (docker > bin > library manifest > unknown):

```
Detected project type: CLI (bin entry detected — confirm)
Detected project type: service (Dockerfile/compose present — confirm)
Detected project type: unknown
```

```bash
# --- Usage errors ---
"$REPO/readme-review/scripts/score-readme.sh"; echo "exit=$?"                   # exit=1
"$REPO/readme-review/scripts/score-readme.sh" "$WORK/nope.md"; echo "exit=$?"   # exit=1
```

## Functional Test (LLM in the loop)

Run `/readme-review` on this repo's own README.md. Expected:

- Project type judged by the reviewer (a skills collection — the library/CLI buckets fit
  poorly), with the script's detection used as input, not verdict.
- The zero-to-running test is actually executed: follow the README's install instructions
  in a scratch dir and report whether a newcomer would succeed.
- Weak sections are redrafted (with consent) per the CHECKLIST-04 maintenance items —
  e.g. an uninstall story and a troubleshooting section.
- Report follows REPORT-TEMPLATE.md; the README is not modified without asking.

## Expected Behaviors

- **Heuristics are half the review**: the script covers presence; the subagent judges
  depth (does the quickstart actually run?) against the type profile in
  `references/README-PATTERNS.md`.
- **Sibling-file awareness**: LICENSE/CONTRIBUTING/CHANGELOG are checked as *files*, not
  README mentions — a README that only talks about its missing CHANGELOG still fails 4.6.
- **Exit codes**: 0 on any successful scan, 1 on usage error.
- **Placeholder scan is line-numbered** so a redraft can quote and fix each one.
