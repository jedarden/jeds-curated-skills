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

The script needs `bash`, `jq`, `curl`, and `git` on `PATH`, plus an active
Claude Code OAuth login (`~/.claude/.credentials.json` must exist). `flock`
(from `util-linux`) and `timeout` are used when present and skipped when not —
they only prevent duplicate background fetches and cap runaway commit scans.
Verify before installing:

```bash
command -v jq curl git >/dev/null && echo "deps ok" || echo "missing a dependency"
test -f ~/.claude/.credentials.json && echo "credentials ok" || echo "not logged in"
```

On macOS, `brew install util-linux coreutils` (and adding their `bin` to `PATH`)
restores the locking and timeouts, but the statusline works without them.

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
renders. On the very first run the quota segments read `usage n/a` for a few
seconds (cpu/ram and `⎇` still show) until the initial usage fetch populates
`~/.cache/claude-usage/usage.json`.

## Troubleshooting

- **No statusline at all:** confirm `settings.json` is valid JSON (`jq . ~/.claude/settings.json`)
  and the `command` path is correct and executable.
- **Any error, first:** read `~/.cache/claude-usage/statusline.log`. Every
  failure the script survives (a fetch that failed, an API response it
  rejected, a cache it could not parse, a refresh it refused to apply) is
  logged there with a timestamp; stderr is redirected into it, so nothing is
  ever printed to the prompt.
- **`usage n/a` in place of the quota windows:** the cache is missing or
  unparseable — normal for a few seconds on first run. If it persists, the log
  says why: a parse problem (the API changed shape — inspect
  `~/.cache/claude-usage/usage.json`, and `usage.rejected.json` if the fetch
  was refused), or a fetch problem (`fetch skipped` / `fetch failed (curl exit
  N)` — check `~/.claude/.credentials.json` is present and the token is valid).
- **`stale 2h` next to the windows:** the fetch has been failing; the numbers
  shown are the last good ones. Same log, same causes. Fetches are attempted at
  most once a minute regardless of outcome (`usage.attempt`).
- **No statusline at all** even though `settings.json` and the path are right:
  that should no longer happen from bad *data* — the script always exits 0 —
  so run it by hand (`bash ~/.claude/usage-statusline.sh </dev/null; echo " rc=$?"`)
  and look at the log.
- **Stuck values with no `stale` marker:** delete
  `~/.cache/claude-usage/fetch.lock` and `~/.cache/claude-usage/git.lock` — a
  crashed run can leave a stale flock held (locks are `flock -n`,
  non-blocking, so this is rare but possible after a hard kill).
- **Weekly commit count is 0 or wrong:** it only scans `.git` directories two
  levels under `$HOME` for commits in the last 7 days with `Co-Authored-By: Claude`
  in the message — repos nested deeper, or outside `$HOME`, aren't counted.

## What It Shows

Two or three usage windows (`5h`, `7d`, and an optional scoped weekly cap for a
specific model — the tightest one if several exist), each rendered as
`<label> <percent>% <bar> ~<time-to-exhaust>`, then `cpu <load>/<cores> <pct>%`
and `ram <used>/<total>G <pct>%` for the host, then `⎇ <N>` — Claude-co-authored
commits across the user's repos in the last 7 days. If the quota data is
missing or unreadable the windows are replaced by `usage n/a`; if the cache has
gone more than 15 minutes without a successful refresh a dim `stale <age>`
follows them. Full legend and example output: see `README.md`.
