
<a href="../../releases"><img src="assets/download.png" alt="Download CodexStatusBar.dmg for macOS" width="260"></a>
<br>
## Codex Status Bar

A tiny macOS menu bar app that shows **Codex's live status**: thinking, running
tools, compacting context, waiting for permission, running subagents, or resting
after work is done. It has no window, no dock icon, no usage dashboard, and no
server component.

> Built so you can tab away during a long Codex turn and still see, at a
> glance, whether Codex is working, waiting on you, compacting, or done.
> 
<img width="710" alt="Codex Status Bar menu bar demo" src="assets/x-preview.gif" />
<br>


> [!WARNING]
> **Experimental software.** This project was built with Codex vibe coding and
> should be used at your own risk. It has not been exhaustively tested across all
> Codex surfaces, and Terminal / CLI scenarios are especially likely to vary by
> shell, terminal app, hook configuration, and Codex version.

> [!Important]
Codex Status Bar is strongly inspired by two reference projects [See acknowledgements](ACKNOWLEDGEMENTS.md):
>-  [ilyastorunn/codex-status-bar](https://github.com/ilyastorunn/codex-status-bar) provided the Codex-focused prototype and installation direction.
> - [m1ckc3s/claude-status-bar](https://github.com/m1ckc3s/claude-status-bar) provided the mature local-file plus macOS menu-bar architecture.
> 
---

## What it shows

- **Thinking** - the Codex icon animates with an elapsed timer.
- **Running a tool** - a short label such as `Running cmd`, `Editing`,
  `Reading`, `Searching`, or `Using tool`.
- **Compacting** - a dedicated compacting state while Codex compresses context.
- **Awaiting permission** - a red permission indicator when Codex needs approval.
- **Subagent** - a separate state for subagent activity inside a turn.
- **Idle / done** - a resting Codex icon when no active work is visible.

Everything is controlled from the menu:

- **Show timer:** toggle the elapsed `1m 1s` clock.
- **Show status text:** choose between icon-only mode and icon + label mode.
- **Play notification sounds:** toggle permission and completion sounds.
- **Hide idle sessions:** choose how long resting sessions stay in the menu.
- **Use system icon color:** use the adaptive macOS menu bar glyph color.
- **Icon Style:** switch between the Codex icon and Codex Pets.
- **Pet:** choose an installed local Codex pet for the menu bar icon.
- **Diagnostics:** reveal local state files or reset local display state.

## Where it works

| Surface | Tracked? | Notes |
|---|---:|---|
| Codex Desktop sessions | Yes | Desktop rows prefer `codex://threads/<sessionId>` for click focus. |
| Codex CLI sessions | Yes | CLI rows focus the terminal/editor app when a target is known. |
| Multiple simultaneous sessions | Yes | The menu bar selects one lead session; the menu lists all tracked sessions. |
| Permission requests | Yes | Permission state has the highest display priority. |
| Subagent activity | Yes | Subagent and subagent permission are shown separately. |
| Archived Desktop chats | Best effort | Archived or missing threads may only bring Codex forward. |
| Exact terminal tab focus | No | Terminal tab/window precision is not implemented. |
| ChatGPT or unrelated OpenAI apps | No | Only Codex hook events are tracked. |

## Known issues

### Goal continuation may not show live activity

Codex `/goal` continuation may keep working without dispatching the same hooks
as a normal prompt. In that case, Codex Status Bar may keep showing the previous
state, such as `done`, until a normal prompt or a later hook event arrives.

## Requirements

- macOS 12+
- Codex with hook support
- Node.js
- Xcode Command Line Tools when building from source

## Install

### Option A - Download the release DMG

Download the latest `CodexStatusBar.dmg` from [Releases](../../releases), open
the disk image, and copy `CodexStatusBar.app` to `/Applications` or another
local app folder.

> [!CAUTION]
> Release DMGs are preview artifacts. They are not currently signed with a
> Developer ID certificate and are not notarized by Apple. On first launch,
> macOS Gatekeeper may require you to right-click the app and choose **Open**, or
> allow it from **System Settings -> Privacy & Security**.

After launching the app, install or repair Codex hooks from the repository:

```bash
node scripts/install-codex-statusbar.js
```

Then complete the first-run hook authorization step below.

### Option B - Build from source

Use this path if you prefer to inspect and build the app locally.

```bash
git clone https://github.com/PG408/codex-status-bar.git
cd codex-status-bar
./build.sh
open -g build/CodexStatusBar.app
node scripts/install-codex-statusbar.js
```

Then complete the first-run hook authorization step below.

### First-run hook authorization

After installing or updating, open Codex and approve the Codex Status Bar hooks
Then start a new Codex session, or send a new prompt in an existing session, so
status updates can begin.

You can also create a local unsigned DMG:

```bash
./build.sh --dmg
```

### Updating

Replace the app from a newer release DMG or rebuild it from source, then run the
hook installer again:

```bash
./build.sh
open -g build/CodexStatusBar.app
node scripts/install-codex-statusbar.js
```

Sessions that were already open may not reload changed hook commands until they
send a new prompt or a new Codex session starts.

## How it works

Codex fires hook events as it works. The hook writers convert those events into
small display records under:

```text
~/.codex/statusbar/state.d/<session_id>.json
```

The menu bar app polls those local records, derives the visible state for each
session, then chooses the lead session for the menu bar. It also reads local
Codex metadata for thread names and best-effort archived-chat handling. The app
does not store prompts, command output, transcripts, API keys, or model
responses.

The installer merges Codex Status Bar hooks into `~/.codex/hooks.json`, preserves
unrelated user hooks, and removes only prior hook commands that belong to this
project.

## User Guide

See [User Guide](USER_GUIDE.md) for menu options, manual testing commands,
common troubleshooting steps, and uninstall instructions.

## Privacy

Codex Status Bar is local-first and has no server component. See
[Privacy](PRIVACY.md) for the full local data and network statement.


## Trademark / Not Affiliated

This is an unofficial, open-source side project. **It is not affiliated with,
endorsed by, or sponsored by OpenAI.** "OpenAI", "ChatGPT", and "Codex" are
trademarks of OpenAI, used here nominatively. This project is MIT licensed, but
that covers the source code only and conveys no rights to OpenAI trademarks or
brand assets.

If this project violates or impedes any trademark or brand usage, please open an
issue.

## License

MIT. Third-party MIT notices for referenced or partially adapted material are
preserved in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
