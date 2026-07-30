---
name: repo-hygiene
description: >-
  Audit a repository for hygiene debt — committed build artifacts, dead GitHub Actions
  workflows, README version drift, dirty working trees, stash pileups, missing .gitignore
  coverage, suspicious tracked files — and optionally fix it with one commit per category.
  Use to check, audit, or clean up repo hygiene.
argument-hint: "[repo-path] [--fix]"
allowed-tools: Bash, Read, Edit, Write, Glob, Grep, AskUserQuestion
---

# Repo Hygiene Skill

Detect (and optionally fix) systemic repository hygiene debt. The detection core is a
plain, dependency-free bash script — the skill is a thin wrapper around it. The script
is **report-only**: it never modifies anything. All mutation lives in this skill's fix
mode and only runs when the user explicitly asks for it.

## Step 1: Run the Audit (Always Report First)

Run the core script against the target repo (argument, or the current repo if none given):

```bash
~/.claude/skills/repo-hygiene/scripts/repo_hygiene.sh [repo-path]
```

Exit codes: `0` clean, `1` findings, `2` usage error / not a git repo.
Add `--json` for machine-readable output.

Run this first **even when the user asked for `--fix`** — fixes are always driven from a
fresh report.

## Step 2: Present Findings

Summarize each category with its severity, count, and a few example paths. Categories:

| Category | Severity | Meaning |
|----------|----------|---------|
| `tracked-build-artifacts` | high | `target/`, `node_modules/`, `dist/`, `build/`, `__pycache__/`, `*.pyc`, `.DS_Store` under version control |
| `large-tracked-files` | high | tracked blobs > 5 MB |
| `dead-ci-workflows` | medium | tracked `.github/workflows/*.yml\|yaml` (GH Actions are disabled estate-wide — CI is Argo Workflows) |
| `readme-dead-ci-badges` | medium | GitHub Actions badge URLs in the README (dead by policy) |
| `readme-version-drift` | low | version-looking badge strings that don't match the latest git tag |
| `dirty-working-tree` / `stash-pileup` | low | uncommitted changes / accumulated stashes |
| `gitignore-gaps` | medium | language detected (Cargo.toml, package.json, Python sources) but its build dir is not ignored |
| `suspicious-tracked-files` | needs-review | `.env`, `*.pem`, `*.key`, `id_rsa*` — **never read or print their contents**; flag for the human to decide |
| `root-ad-hoc-files` | medium | `test_*.sh` / `test_*.py` / `test_*.rs` and ELF binaries tracked **directly in the repo root** — legit tests live under `tests/`; root-level scratch regenerates if unchecked |

## Step 3: Fix Mode (Only on Explicit `--fix`)

If — and only if — the user passed `--fix` or explicitly asked for fixes, apply them.

**Preconditions — abort fix mode entirely if any fails:**

- No merge/rebase/cherry-pick in progress: none of `.git/MERGE_HEAD`,
  `.git/rebase-merge`, `.git/rebase-apply`, `.git/CHERRY_PICK_HEAD` may exist.
- The repo must be the one the user pointed at — never fix a repo the user only asked
  to audit.

**Apply fixes as SEPARATE commits, one per category, strictly limited to:**

1. **`.gitignore` entries** — append the missing entries reported by `gitignore-gaps`.
2. **Build artifacts** — `git rm -r --cached <paths>` only. **Never delete from disk.**
   Requires the matching `.gitignore` entry to land first (commit 1) so the files don't
   immediately reappear as untracked noise.
3. **Dead CI workflows** — `git rm` the tracked `.github/workflows/*.yml|yaml` files
   (these are policy-dead; deleting the file from disk is the fix).
4. **README drift** — correct version badge strings to match the latest tag and remove
   GitHub Actions badges.

Stage with explicit paths only (never `git add -A`), so unrelated dirty-tree changes are
never swept into a hygiene commit.

**Never:** touch source code, force-push, rewrite history, drop stashes, delete
non-workflow files from disk, or "fix" suspicious tracked files — those are report-only.
`dirty-working-tree` and `stash-pileup` have no automated fix; just report them.

Do not push unless the user asks. Re-run the script after fixing to confirm the
categories cleared.

## Fleet Mode (Cross-Harness)

**The script is the cross-harness interface.** NEEDLE-dispatched agents on any harness
(claude-code, opencode, codex, aider) should invoke it directly and parse the JSON —
no Claude Code machinery required:

```bash
~/.claude/skills/repo-hygiene/scripts/repo_hygiene.sh --json /path/to/repo
```

Output shape:

```json
{"repo": "...", "findings": [{"category": "...", "severity": "...", "count": 0, "examples": []}], "clean": true}
```

The script needs only `git`, coreutils, and `awk` (no jq), so it runs identically under
every harness. The SKILL.md you are reading only adds presentation and the guarded fix
workflow on top.

## Optional: SessionEnd Hook (Default OFF)

For an automatic hygiene report when a Claude Code session ends, a user can opt in by
adding this to their `settings.json`. It is **not installed by default** — report-only,
and `|| true` keeps a findings exit code from being treated as a hook failure:

```json
{
  "hooks": {
    "SessionEnd": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/skills/repo-hygiene/scripts/repo_hygiene.sh . || true"
          }
        ]
      }
    ]
  }
}
```

Do not add this hook yourself; only mention it if the user asks about automation.
