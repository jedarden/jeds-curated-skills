---
name: find-stubs
description: >-
  Sweep a repo for stub/mock/placeholder/incomplete code — leftover TODOs, explicit
  unimplemented!()/NotImplementedError markers, placeholder/fake-data comments, silently
  swallowed errors — the class of AI-generated incompleteness that passes lint/type-check
  but is silently fake. Report-only by default; can convert findings into tracked beads.
  Use periodically across repos, or when asked to check for incomplete/fake/stub code.
argument-hint: "[repo-path] [--create-beads]"
allowed-tools: Bash, Read, Grep, Glob
---

# Find Stubs Skill

Detects leftover stub/mock/placeholder code — the pattern where a coding agent (or a human
under deadline pressure) leaves behind a `todo!()`, a hardcoded fake value, or a silently
swallowed error that satisfies the type checker and lint but does nothing real. This class
of defect is specifically the kind that passes CI, because nothing about it is syntactically
wrong — it just isn't finished.

The detection core is a dependency-light bash script (ripgrep + optional ast-grep) — this
skill is a thin wrapper. The script is **report-only**: it never modifies anything.

## Step 1: Run the sweep

```bash
~/.claude/skills/find-stubs/scripts/find_stubs.sh [repo-path]
# machine-readable:
~/.claude/skills/find-stubs/scripts/find_stubs.sh [repo-path] --json
```

Exit codes: `0` clean, `1` findings, `2` usage error / not a git repo / ripgrep missing.

Categories checked:

| Category | What it catches |
|----------|------------------|
| `leftover-todo` | `TODO`, `FIXME`, `XXX`, `HACK` |
| `explicit-unimplemented` | `unimplemented!()`, `todo!()`, `NotImplementedError`, "not implemented" |
| `placeholder-marker` | "placeholder", "stub implementation", "fake data", "hardcoded for now/placeholder/temp" |
| `empty-catch-swallow` | bare `except: pass`, empty `catch (...) {}` |

This is text-pattern matching (ripgrep), not structural analysis — it has false positives
(a comment *documenting* a placeholder-reference feature, like `@0`/`@1` batch syntax, isn't
a stub) and it has false negatives (a function that's fake but doesn't say so anywhere).
**Structural detection (ast-grep — flagging suspiciously short function bodies, or bodies
that are just a bare literal) is not implemented yet** — `ast-grep`/`sg` isn't installed on
this box as of 2026-07. If it's ever installed, extending this script to flag
short/single-statement function bodies per-language would catch the false-negative class
this text-only pass misses. Until then, treat this as a fast first pass, not exhaustive.

## Step 2: Present findings

Group by category, show file:line + the matched snippet. Use judgment on the false positives
above — a hit on the word "placeholder" inside a docstring describing a real, implemented
feature (e.g. bead-forge's own `@0`/`@1` placeholder-reference syntax) is not a finding to
act on; only flag things that look like genuinely incomplete/fake code.

## Step 3: Convert real findings into tracked work (only if asked, or `--create-beads`)

**Ground the bead backend first — detect, never assume.** Repos migrate one at a time,
and running the wrong CLI against a store does not fail cleanly: it reports a generic
SQLite column error, and applying the other tool's own recovery recipe to that silently
reinitializes the store with the wrong schema and destroys live data.

- `.beads/config.json` + `.beads/checkpoint/` → **bead-rs** (`bead`) — canonical for
  active work as of 2026-08-14.
- `.beads/config.yaml` + a flat `.beads/issues.jsonl` → legacy `bf` — decommissioned on
  this box; if a target repo is still in this shape, stop and report it blocked rather
  than improvising.
- No `.beads/` directory → nothing to file into; print the finding and skip filing.

**Dedup first.** Check `bead list --json --limit 2000` for an existing bead already
referencing the same file:line before creating a new one — a duplicate bead is two
workers doing the same fix and racing on the same file, not just a tracking nit.

For each finding that survives Step 2's judgment pass and isn't already tracked, create a
bead with a reproducible acceptance check, not just a location:

```bash
bead create --issue-type task --priority 3 --label stub-finder --label human \
  --title "Stub: <short description>" --description "$(cat <<'EOF'
Found by find-stubs sweep: <file>:<line>

<snippet>

## Done when
<the real behavior that should exist, as a command and its expected output someone
else can reproduce — not "implemented">
EOF
)"
```

`--label human` is in NEEDLE's default Pluck exclude list, so the bead stays out of the
ready frontier until a human reviews it — a sweep's own findings are proposals, not
admitted work, until someone looks at them.

Don't create beads for false positives, and don't create duplicate beads for a finding
that's already tracked.

## Notes

- Run this periodically across the ~24+ repos NEEDLE roams, not just once — stubs accumulate
  silently over many sessions and this only catches what's currently in the tree.
- This is deliberately tolerant of false positives, unlike a human-facing linter: an agent
  (or you) can cheaply dismiss noise, so the patterns above err toward over-matching rather
  than under-matching.
