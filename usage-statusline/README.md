# 📊 usage-statusline

A live Claude Code statusline that shows your **usage** and your **pace** — at a
glance, on every prompt, with zero clicks.

No more finding out you're at 95% weekly quota by hitting a wall mid-task. This
puts the number (and whether you're burning faster or slower than time is
passing) right where you're already looking.

## ✨ What it looks like

```
5h 42% ▓▓▓▓░░░░░░ ~6h │ 7d 68% ██████▒▒▒▒ ~2d │ cpu 3.9/20 19% │ ram 25/62G 41% │ ⎇ 14
```

Reading left to right:

| Segment | Meaning |
|---|---|
| `5h 42%` | 🕐 42% of your rolling 5-hour session limit used |
| `▓▓▓▓░░░░░░` | the pace bar — see legend below |
| `~6h` | ⏳ estimated time until this window's quota is exhausted at current burn rate |
| `7d 68% ██████▒▒▒▒ ~2d` | 📅 same shape, for the rolling 7-day weekly limit |
| `cpu 3.9/20 19%` | 🖥️ this host: 1-minute load average / core count, and that as a percentage (overload is shown, not clamped) |
| `ram 25/62G 41%` | 🧠 this host: memory in use (excluding reclaimable cache) / total |
| `⎇ 14` | 🌿 Claude-co-authored commits across your repos in the last 7 days |

If your plan has a **scoped weekly cap** (e.g. a model-specific limit), a third
segment appears between the 7-day block and the host segments, labeled with
that model's display name. If there are several, the tightest one is shown.

Two more segments appear only when something is off, and are the point of the
next section:

| Segment | Meaning |
|---|---|
| `usage n/a` | quota data is missing or unreadable — the rest of the line still renders |
| `stale 2h` | the last successful usage fetch was that long ago; the windows show the last good numbers |

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

1. **Check dependencies** — `bash`, `jq`, `curl`, `git`, and an active Claude
   Code login (`~/.claude/.credentials.json` must exist). `flock` (util-linux)
   and `timeout` are used when present and skipped when not.

   ```bash
   command -v jq curl git && echo ok
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

4. **Start a new session** — for the first few seconds the quota segments read
   `usage n/a` while the initial usage fetch populates the cache. 🎉

Full step-by-step (with an agent walking you through it) is in `SKILL.md` — just
ask Claude Code to "set up the usage statusline."

## ⚙️ How it works (short version)

- 🔄 Fetches `api.anthropic.com/api/oauth/usage` in the background at most once
  every 60s (whether or not the last attempt worked), refreshing your OAuth
  token first if it's about to expire. Rendering never waits on the network.
- 🔒 Fetches are `flock`-guarded so concurrent statusline renders never race,
  and the cache and credentials are only ever replaced atomically. A usage
  response that doesn't look like a usage document, or a token-refresh response
  that is missing its tokens, is refused — the last good data keeps serving.
- 🛡️ Built to degrade rather than break: it always exits 0, each segment
  renders independently, nothing the API sends is ever executed, and your
  tokens never appear on a command line. Every failure it survives is written
  to `~/.cache/claude-usage/statusline.log`.
- 🌿 Separately (and in the background), scans `.git` dirs two levels under
  `$HOME` for commits in the last 7 days carrying `Co-Authored-By: Claude`,
  cached for 5 minutes.
- 🧮 A small `jq` program turns the raw usage payload into percent-used,
  percent-of-window-elapsed, and an extrapolated hours-to-exhaustion for each
  window. It tolerates the reset time arriving as ISO-8601 with or without
  fractional seconds and any UTC offset, or as epoch seconds/milliseconds, and
  falls back to the older `five_hour`/`seven_day` fields if `limits` goes away.

No data leaves your machine beyond the existing Anthropic API calls Claude Code
already makes — this just reads and displays what's already available.

## 🩹 Troubleshooting

| Symptom | Likely cause |
|---|---|
| Nothing renders | `settings.json` invalid, or `command` path/perms wrong |
| `usage n/a` for a few seconds | first fetch hasn't completed yet — normal |
| `usage n/a` that stays | cache unparseable or fetch failing — read `~/.cache/claude-usage/statusline.log` |
| `stale 2h` | fetches have been failing; same log |
| Frozen with no `stale` marker | a stale `flock` lock — safe to delete `~/.cache/claude-usage/*.lock` |
| `⎇ 0` unexpectedly | your repos are nested deeper than 2 levels under `$HOME`, or live elsewhere |

## 🗑️ Uninstall

Remove the `statusLine` key from `~/.claude/settings.json` and delete
`~/.claude/usage-statusline.sh` and `~/.cache/claude-usage/`.
