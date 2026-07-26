# 📊 usage-statusline

A live Claude Code statusline that shows your **usage** and your **pace** — at a
glance, on every prompt, with zero clicks.

No more finding out you're at 95% weekly quota by hitting a wall mid-task. This
puts the number (and whether you're burning faster or slower than time is
passing) right where you're already looking.

## ✨ What it looks like

```
5h 42% ▓▓▓▓░░░░░░ ~6h │ 7d 68% ██████▒▒▒▒ ~2d │ ⎇ 14
```

Reading left to right:

| Segment | Meaning |
|---|---|
| `5h 42%` | 🕐 42% of your rolling 5-hour session limit used |
| `▓▓▓▓░░░░░░` | the pace bar — see legend below |
| `~6h` | ⏳ estimated time until this window's quota is exhausted at current burn rate |
| `7d 68% ██████▒▒▒▒ ~2d` | 📅 same shape, for the rolling 7-day weekly limit |
| `⎇ 14` | 🌿 Claude-co-authored commits across your repos in the last 7 days |

If your plan has a **scoped weekly cap** (e.g. a model-specific limit), a third
segment appears between the 7-day block and the commit counter, labeled with
that model's display name.

## 🎨 Color & bar legend

Each window's percentage is colored — 🟢 **green** under 50%, 🟡 **yellow**
50–79%, 🔴 **red** 80%+.

The bar compares **usage consumed** against **time elapsed** in the window, ten
cells at 10% each:

| Cell | Meaning |
|---|---|
| `█` | both usage and time are past this mark — expected, on pace |
| `▓` | usage is **ahead** of time — you're burning faster than the window is passing ⚠️ |
| `▒` | time is ahead of usage — you're under-pacing, quota to spare 👍 |
| `░` | neither has reached this mark yet |

A bar that's mostly `▓` early in a window is your signal to slow down before
the `5h`/`7d` reset.

## 🚀 Install

1. **Check dependencies** — `bash`, `jq`, `curl`, `flock` (util-linux), `git`,
   and an active Claude Code login (`~/.claude/.credentials.json` must exist).

   ```bash
   command -v jq curl flock git && echo ok
   ```

2. **Copy the script:**

   ```bash
   cp scripts/usage-statusline.sh ~/.claude/usage-statusline.sh
   chmod +x ~/.claude/usage-statusline.sh
   ```

3. **Wire it into `~/.claude/settings.json`** (merge into your existing
   settings — don't clobber other keys):

   ```json
   {
     "statusLine": {
       "type": "command",
       "command": "/bin/bash /home/YOU/.claude/usage-statusline.sh",
       "padding": 0
     }
   }
   ```

4. **Start a new session** — the first render may take a few seconds while the
   initial usage fetch populates the cache. 🎉

Full step-by-step (with an agent walking you through it) is in `SKILL.md` — just
ask Claude Code to "set up the usage statusline."

## ⚙️ How it works (short version)

- 🔄 Fetches `api.anthropic.com/api/oauth/usage` at most once every 60s,
  refreshing your OAuth token first if it's about to expire.
- 🔒 Everything is `flock`-guarded so concurrent statusline renders never race.
- 🌿 Separately (and in the background), scans `.git` dirs two levels under
  `$HOME` for commits in the last 7 days carrying `Co-Authored-By: Claude`,
  cached for 5 minutes.
- 🧮 A small `jq` program turns the raw usage payload into percent-used,
  percent-of-window-elapsed, and an extrapolated hours-to-exhaustion for each
  window.

No data leaves your machine beyond the existing Anthropic API calls Claude Code
already makes — this just reads and displays what's already available.

## 🩹 Troubleshooting

| Symptom | Likely cause |
|---|---|
| Nothing renders | `settings.json` invalid, or `command` path/perms wrong |
| Blank for a while | first fetch hasn't completed yet — wait a few seconds |
| Stale forever | a stale `flock` lock — safe to delete `~/.cache/claude-usage/*.lock` |
| `⎇ 0` unexpectedly | your repos are nested deeper than 2 levels under `$HOME`, or live elsewhere |

## 🗑️ Uninstall

Remove the `statusLine` key from `~/.claude/settings.json` and delete
`~/.claude/usage-statusline.sh` and `~/.cache/claude-usage/`.
