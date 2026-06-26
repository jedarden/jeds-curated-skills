# Runbook: Author a Plan From Existing Code

Use for **Improvement** and **Port** plans. The plan must describe what actually exists, not a
guess. Scan the real codebase first, then feed the findings to the drafter so its components,
schemas, and gap inventory are grounded in reality.

---

## When This Applies

- **Improvement** — you are evolving a running system; the plan needs a gap inventory and an
  explicit "what we are NOT changing", both of which require knowing the current shape.
- **Port** — you are reimplementing existing code elsewhere; the plan needs a parity matrix and
  source metrics, both of which require measuring the source.

For a true Greenfield plan, skip this runbook — there is no code to scan.

---

## Step 1: Locate the Codebase

If the brief names a path or repo, use it. Otherwise scan the working tree for the project root
(the directory holding the build manifest — `package.json`, `Cargo.toml`, `pyproject.toml`,
`go.mod`, etc.). Confirm with AskUserQuestion only if multiple unrelated roots exist.

## Step 2: Map the Structure

Build a factual picture with read-only tools. Examples (adapt to the language):

```bash
# Top-level layout and entry points
find . -maxdepth 2 -type f \( -name '*.rs' -o -name '*.ts' -o -name '*.py' -o -name '*.go' \) | head -50

# Module/component names
grep -rEn '^(pub mod|mod|export (class|function)|def |class |func )' --include='*.rs' \
  --include='*.ts' --include='*.py' --include='*.go' . | head -80

# Size of the source (for Port: feeds the source-metrics / LOC estimate)
find . -name '*.rs' -o -name '*.ts' -o -name '*.py' -o -name '*.go' | xargs wc -l | tail -1
```

Record: the component/module names, the entry points, and (for Port) total and per-area LOC.

## Step 3: Extract the Data Model

Find the durable shapes so §7 of the plan reflects reality, not invention:

```bash
# SQL schemas / migrations
grep -rEin 'create table|alter table' --include='*.sql' . | head -40
# In-code models / structs / schemas
grep -rEn 'struct |interface |@dataclass|class .*\(.*Model' . | head -40
```

## Step 4: Inventory Current Behavior and Pain

For Improvement plans, find what is broken or weak — this becomes the Gap Inventory:

```bash
grep -rEn 'TODO|FIXME|HACK|XXX|deprecated' . | head -60
```

Also note: existing tests (what is already protected), config/flags (the current interface
surface), and anything the brief flags as the motivating pain point.

## Step 5: Assemble the Findings Packet

Hand the drafter a concise factual packet — no speculation:

```
## Codebase Findings
- Root: <path>   Language/build: <…>   Total LOC: <n>
- Components (real names): <list with one-line responsibilities>
- Entry points: <list>
- Data model (real): <entities/tables with fields>
- Existing tests: <what they cover>
- Current interface: <flags/endpoints>
- Gaps / pain (Improvement): <numbered, from TODOs + brief>
- Source metrics (Port): <per-area LOC table>
```

## Step 6: Hand Off

Pass the findings packet to the `plan-drafter` as input #6. The drafter MUST use only these
facts when describing the existing system — and must place anything it could not verify into
§16 Open Questions rather than asserting it.

---

## Constraints

- Read-only. This runbook never modifies the scanned codebase.
- Never assert a component, schema, or behavior you did not observe — unverified items become
  Open Questions.
- Keep the findings packet factual and terse; analysis and decisions are the drafter's job.
