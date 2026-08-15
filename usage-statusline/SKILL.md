---
name: usage-statusline
version: 1.0.0
description: >-
  Install a live Claude Code statusline showing 5h session and 7d weekly usage
  against elapsed-time pace, an optional scoped weekly cap, and a rolling count
  of Claude-co-authored commits. Use when the user wants usage/budget visibility
  in the prompt line, or asks to set up, fix, or explain the usage statusline.
allowed-tools: Bash, Read, Edit, Write
---

# Usage Statusline Skill

A `statusLine` command for Claude Code that renders live quota usage and pace
directly in the prompt — no need to run `/usage` or check a dashboard mid-session.
See `README.md` in this folder for the full visual walkthrough and legend.

The detection/rendering core is a plain, dependency-only bash script
(`scripts/usage-statusline.sh`) — this skill is a thin wrapper that installs and
wires it up. The script never mutates anything except its own on-disk cache and
(when refreshing an expiring OAuth token) `~/.claude/.credentials.json`.

## Step 1: Check Requirements

The script needs `bash`, `jq`, `curl`, `flock` (from `util-linux`), and `git` on
`PATH`, plus an active Claude Code OAuth login (`~/.claude/.credentials.json`
must exist). Verify before installing:

```bash
command -v jq curl flock git >/dev/null && echo "deps ok" || echo "missing a dependency"
test -f ~/.claude/.credentials.json && echo "credentials ok" || echo "not logged in"
```

If `flock` is missing (common on macOS), tell the user to install `util-linux`
(e.g. `brew install util-linux` and add its `bin` to `PATH`) before continuing.

## Step 2: Install the Script

```bash
mkdir -p ~/.claude
cp ~/.claude/skills/usage-statusline/scripts/usage-statusline.sh ~/.claude/usage-statusline.sh
chmod +x ~/.claude/usage-statusline.sh
```

## Step 3: Wire It Into `settings.json`

Add (merge — do not overwrite existing keys) a `statusLine` block to
`~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "/bin/bash /home/USERNAME/.claude/usage-statusline.sh",
    "padding": 0
  }
}
```

Use the real absolute path to the user's home directory, not a literal
`USERNAME` placeholder. If `settings.json` already has other top-level keys,
add `statusLine` alongside them — never replace the whole file.

## Step 4: Verify

Start a new Claude Code session (or resume one) and confirm the statusline
renders. On the very first run there may be no output for a few seconds until
the initial usage fetch populates `~/.cache/claude-usage/usage.json`.

## Troubleshooting

- **No statusline at all:** confirm `settings.json` is valid JSON (`jq . ~/.claude/settings.json`)
  and the `command` path is correct and executable.
- **Blank output:** `~/.cache/claude-usage/usage.json` doesn't exist yet — the
  script exits silently until the first successful fetch. Check
  `~/.claude/.credentials.json` is present and not corrupted.
- **Stuck/stale values:** delete `~/.cache/claude-usage/fetch.lock` and
  `~/.cache/claude-usage/git.lock` — a crashed run can leave a stale flock held
  (locks are `flock -n`, non-blocking, so this is rare but possible after a
  hard kill).
- **Weekly commit count is 0 or wrong:** it only scans `.git` directories two
  levels under `$HOME` for commits in the last 7 days with `Co-Authored-By: Claude`
  in the message — repos nested deeper, or outside `$HOME`, aren't counted.

## What It Shows

Two or three usage windows (`5h`, `7d`, and an optional scoped weekly cap for a
specific model), each rendered as `<label> <percent>% <bar> ~<time-to-exhaust>`,
followed by `⎇ <N>` — Claude-co-authored commits across the user's repos in the
last 7 days. Full legend and example output: see `README.md`.
