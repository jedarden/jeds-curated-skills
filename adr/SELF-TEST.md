# Self-Test: adr

Prose-only skill — the surface is the review checklist
(`CHECKLIST-QUALITY.md`, 12 items) and the author flow (template + sequence
numbering + reciprocal supersession). The regression shape below is a fixture
ADR built so each item lands on a known rating; a checklist edit that silently
changes what counts as PRESENT shows up as a changed inventory.

## Trigger Phrases

| Phrase | Expected |
|--------|----------|
| "write an ADR for this" | Activates, author mode |
| "record this design decision" | Activates, author mode |
| "review our ADRs for quality" | Activates, review mode |
| "/adr author cursor pagination" | Activates, author mode |
| "/adr review docs/adr" | Activates, review mode |
| "write a migration runbook" | Does NOT activate — migration-runbook skill |

## Structure

```bash
REPO="${REPO:-$HOME/jeds-curated-skills}"
SKILL_DIR="$REPO/adr"
ls -1 "$SKILL_DIR"              # ADR-TEMPLATE.md, CHECKLIST-QUALITY.md,
                                # REPORT-TEMPLATE.md, SELF-TEST.md, SKILL.md,
                                # references/, subagents/
ls -1 "$SKILL_DIR/subagents"    # adr-author.md, adr-reviewer.md
ls -1 "$SKILL_DIR/references"   # EXAMPLES.md
```

## Review-mode fixture

One deliberately weak ADR. Planted defects, item by item:

```bash
T="$(mktemp -d)"
mkdir -p "$T/docs/adr"
cat > "$T/docs/adr/0004-pagination.md" <<'EOF'
# Pagination

Status: Accepted
Date: 2026-09-01

## Context

The dashboard list endpoints need pagination. Pagination is needed because
the tables are growing and we need pagination for the list endpoints.

## Decision

We should probably look at moving toward some form of pagination support in
the API layer.

## Alternatives

### Cursor-based pagination

Not chosen — too complex.

### Offset-based pagination

Offset pagination uses LIMIT/OFFSET, is simple to implement, works with any
SQL backend, and every engineer already knows it. It degrades on deep pages
because the database still scans skipped rows, which we accept for now.

## Consequences

- Engineers can page through list results.
- Clients get a stable API surface.
- The dashboard renders faster.

EOF
echo "$T" > /tmp/adr-selftest-dir
```

**Expected inventory — `/adr review <dir>` rates the fixture like this:**

| Item | Rating | Because (the planted defect) |
|------|--------|------------------------------|
| 1.1 Title is a Decision | MISSING | "Pagination" is the topic; no verdict in the title |
| 1.2 Status lifecycle-correct | PRESENT | `Status: Accepted` |
| 1.3 Date present | PRESENT | 2026-09-01 |
| 1.4 Context states forces | PARTIAL | Restates the decision; no constraints/tensions |
| 1.5 Decision specific/actionable | PARTIAL | "should probably look at moving toward" — no mechanism |
| 1.6 Two real alternatives | PARTIAL + **STRAWMAN flag** | Cursor alternative dismissed in one line, zero pros |
| 1.7 Specific why-not per alternative | MISSING | "too complex" — generic, not tied to a Context force |
| 1.8 Consequences include negatives | MISSING | All three bullets are positive |
| 1.9 Follow-on work | MISSING | Nothing named |
| 1.10 Reversibility / blast radius | MISSING | Nothing named |
| 1.11 Supersession links | PRESENT | No supersession applies — PRESENT by default |
| 1.12 Scoped to one decision | PRESENT | One decision only |

Hard pins (mechanical, must not flex): 1.1 MISSING (topic title), 1.6 carries
an explicit STRAWMAN flag on the cursor alternative, 1.8 MISSING (zero
negative consequences), 1.11 PRESENT-by-default, totals **4 PRESENT /
3 PARTIAL / 5 MISSING**. Judgment items 1.4/1.5/1.7 may flex one step if the
reviewer argues it — a flex of more than one step, or any moved hard pin,
means the checklist or reviewer prompt changed deliberately.

Report shape (REPORT-TEMPLATE.md): per-ADR ratings with one-line notes on
every non-PRESENT, strawman/missing-negative callouts, then the offer to
draft strengthened versions.

## Author-mode checks

Mechanical, no judgment involved:

```bash
T="$(cat /tmp/adr-selftest-dir)"
mkdir -p "$T/docs/adr2"
: > "$T/docs/adr2/0001-first.md"; : > "$T/docs/adr2/0003-third.md"
# Highest existing prefix is 0003 ⇒ next number must be 0004 (4-digit zero-padded).
echo "expect next sequence: 0004 (from 0001, 0003)"
# No ADR dir ⇒ create docs/adr/ and start at 0001.
```

Then, LLM in the loop, `/adr author "<brief>"` in a scratch repo with an
existing `docs/adr/0001-*.md`:

- Writes `docs/adr/0002-<slug>.md` — correct next number, decision-style title.
- All ADR-TEMPLATE.md sections present, in order.
- ≥ 2 alternatives, each with honest pros and a Context-tied "why not".
- Consequences name at least one negative.
- Supersede test: author a replacement for the 0001 decision. Expected:
  reciprocal links — new ADR carries `Supersedes: 0001`, old ADR's status
  becomes `Superseded by 0002` with a `Superseded-by:` link. One-directional
  links are a defect (SKILL.md Step 5).
- The plan file / existing ADRs are not modified beyond the supersession
  status line.

## Expected Behaviors

- **Mode inference**: a `.md` path ⇒ review; a decision description ⇒ author;
  genuinely ambiguous ⇒ AskUserQuestion, never a guess.
- **Directory scan skips** `README.md` and `template.md` when collecting ADRs
  from a directory.
- **Calibration comes from references/EXAMPLES.md** — the strong/weak pair,
  not the reviewer's own taste; ratings cite it.
- **Review offers, never applies**: the strengthened-version rewrite happens
  only after the user says yes, and preserves the ADR's number and date.
