---
name: readme-review
description: >-
  Reviews a project's README and top-level docs against a quality rubric, judged against the
  project type (library / CLI / service / app), then optionally redrafts weak sections. Tests
  whether a stranger can go zero-to-running from the README alone. Use when a README needs a
  fitness check before release, onboarding, or open-sourcing.
argument-hint: "[path/to/README.md]"
allowed-tools: Agent, Bash, Read, Write, Edit, Glob, Grep, AskUserQuestion
---

# README Review Skill

Review a project's README (and top-level documentation) against a quality rubric, then
optionally redraft weak sections. The rubric is judged against the project TYPE — a library
README and a CLI README have different obligations. The central test: could a newcomer who
has never seen this project install it and run it successfully from the README alone?

## Step 1: Locate the README

If the user provided a file path as an argument, use that. Otherwise glob for:
`README*`, `readme*`, `README.md`, `README.rst`, `README.txt`

Prefer the one at the repository root. If multiple candidates exist at the same depth,
use AskUserQuestion.

Read the full README. Also glob for adjacent top-level docs that the README's quality
depends on: `CONTRIBUTING*`, `LICENSE*`, `CHANGELOG*`, `docs/`, `INSTALL*`, `USAGE*`.
Note which exist — their presence or absence feeds the checklists.

## Step 2: Infer Project Type

Determine the project type from repository signals. This sets the expectations the README
is judged against — load the matching profile from `~/.claude/skills/readme-review/references/README-PATTERNS.md`.

Detect signals:
```bash
~/.claude/skills/readme-review/scripts/score-readme.sh <readme-file>
```
The script reports detected signals, but confirm the type yourself:
- **Library / package** — `package.json` with no `bin`, `Cargo.toml` `[lib]`, `pyproject.toml`
  with a package, `go.mod` importable. Consumers write code against it. Expects: install,
  import snippet, API reference, versioning.
- **CLI tool** — a `bin` entry, `[[bin]]`, console_scripts, a `cmd/` main. Consumers run
  commands. Expects: install, command synopsis, flags/subcommands, examples, exit codes.
- **Service / server** — `Dockerfile`, `docker-compose.yml`, a listening port, deployment
  manifests. Consumers deploy it. Expects: config/env vars, run instructions, ports,
  health check, deployment notes.
- **Application** — end-user GUI/web/desktop app. Consumers use it. Expects: what-it-does,
  screenshot, install/run, feature overview, status.

If signals are ambiguous or conflicting, use AskUserQuestion to confirm the type.

## Step 3: Quick Triage (Optional Fast Path)

For a fast go/no-go before the full review, read the score output from Step 2. The script
prints a heuristic percentage and a missing-items list. If score < 30%, the README needs
fundamental work — tell the user and offer to draft from scratch rather than reviewing.

## Step 4: Load Checklists

Read ALL of the following checklist files from this skill's directory
(`~/.claude/skills/readme-review/`). They contain the full review criteria:

- `CHECKLIST-01-ORIENTATION.md` — first-screen clarity: what it is, the problem, who it's for
- `CHECKLIST-02-GETTING-STARTED.md` — zero-to-running: prerequisites, install, quickstart
- `CHECKLIST-03-REFERENCE.md` — configuration, options, usage examples, API/CLI reference
- `CHECKLIST-04-MAINTENANCE.md` — license, contributing, troubleshooting, links, badges

Also load the project-type profile from `references/README-PATTERNS.md` matching Step 2.

## Step 5: Spawn the Review Agent

Spawn the specialized readme-reviewer subagent. Read
`subagents/readme-reviewer.md` for the full agent prompt. Pass it:
1. The README path (and paths of adjacent docs found in Step 1)
2. The project type
3. All checklist file contents
4. The matching project-type profile from `references/README-PATTERNS.md`

The agent rates each checklist item: **PRESENT** / **PARTIAL** / **MISSING** with a
one-line note for anything PARTIAL or MISSING. It must specifically attempt the
"zero-to-running" walkthrough and flag any command it cannot verify is complete.

## Step 6: Generate Report

Use `REPORT-TEMPLATE.md` to structure the output. The report must include:
- Summary scorecard (counts of PRESENT / PARTIAL / MISSING per category)
- Zero-to-running gap analysis (can a stranger install and run it?)
- Missing sections in priority order
- 3–5 genuine strengths
- Top quick wins (cheap fixes with high payoff)

## Step 7: Offer to Draft

After delivering the report, ask: "Would you like me to draft the missing or weak sections?"

If yes: write the sections directly into the README (or a copy if the user prefers),
following the section ordering for the project type in `references/README-PATTERNS.md`.
Prioritize Orientation and Getting Started gaps before Reference and Maintenance —
a newcomer who cannot install and run the project is blocked by nothing else.
