# User Guide

This guide explains how to run Codex Status Bar locally, install hooks, use the
menu, test states manually, and recover from common local failures.

## Install From Source

Build and launch the app:

```bash
./build.sh
open -g build/CodexStatusBar.app
```

Install or repair Codex hooks:

```bash
node scripts/install-codex-statusbar.js
```

Codex may ask you to review command hooks. If the menu bar icon appears but
status never changes, open Codex and check:

```text
/hooks
```

## Menu Options

| Option | Effect |
|---|---|
| Show timer | Shows elapsed time for active work such as thinking, tool use, and compacting. |
| Show status text | Shows labels such as `Thinking`, `Running command`, or `Awaiting permission`. |
| Play notification sounds | Plays a sound for permission requests and completed work. |
| Hide idle sessions | Controls how long resting sessions remain in the Sessions menu. |
| Use system icon color | Uses the adaptive macOS menu bar glyph color for non-permission states. |
| Icon Style | Switches between the Codex icon and local Codex Pets. |
| Pet | Chooses an installed local Codex pet when Pet mode is enabled. |
| Reveal State Directory | Opens the local status directory in Finder. |
| Reset Status | Clears local display state records. |

## Sessions Menu

The Sessions section groups tracked sessions by project. Each row shows:

- the latest thread name from local Codex metadata;
- `Side Chat` for Codex Side Chat sessions that do not have a formal thread name;
- an elapsed timer when the session is active;
- an `APP` or `CLI` badge when the session surface is known.

Clicking a Desktop session opens `codex://threads/<sessionId>` when available.
Clicking a CLI session focuses the terminal or editor app when a reliable target
is known. Exact terminal tab/window focus is not implemented.

Side Chat rows are grouped under the same project as the hook event that created
their status record. Their title is intentionally generic: Codex Status Bar uses
local Codex Global State only to recognize that the session is a Side Chat, not
to show the Side Chat prompt as the row name.

## Manual State Testing

The app polls local state records every 0.4 seconds. Use the development helper
to force a local `dev` session:

```bash
node scripts/dev-state.js idle
node scripts/dev-state.js thinking
node scripts/dev-state.js tool
node scripts/dev-state.js compacting
node scripts/dev-state.js permission
node scripts/dev-state.js waiting
node scripts/dev-state.js done
```

Run a short demo:

```bash
node scripts/dev-state.js demo
```

## Common Issues

### The icon does not appear

Run:

```bash
./script/build_and_run.sh --verify
```

If the command succeeds but no icon is visible, check:

- whether macOS has enough menu bar space;
- whether `CodexStatusBar` is running in Activity Monitor;
- whether `~/.codex/statusbar/app.log` has recent render lines;
- whether `node scripts/dev-state.js thinking` forces a visible state.

### Hooks are installed but status does not change

Run the installer again:

```bash
node scripts/install-codex-statusbar.js
```

Then check Codex hook trust with `/hooks`. Codex Status Bar can write hook
configuration, but it cannot bypass or reliably read Codex's private hook trust
state.

### Existing sessions do not show up

Codex may not reload hook configuration into sessions that were already running
when hooks were installed or repaired. Send a new prompt or start a new Codex
session after hooks are trusted.

### `hooks-discovery.jsonl` does not grow

`~/.codex/statusbar/hooks-discovery.jsonl` is a debug-only discovery log. It is
written only when hook commands run with:

```bash
CODEX_STATUSBAR_DEBUG=1
```

Normal status updates use `state.d` and `app.log`.

### A session looks stale

Use `Reset Status` from the menu. State files are display records, not permanent
storage. The app prunes corrupt, completed, idle, and inactive records according
to its local cleanup rules.

## Verify The Local Build

Run:

```bash
node scripts/replay-hook-fixtures.js
node scripts/verify-hook-manager.js
node scripts/verify-phase4-lifecycle.js
node scripts/verify-session-surface.js
node scripts/verify-menu-model.js
node scripts/verify-swift-state-rules.js
node scripts/verify-preference-migration.js
./build.sh
./script/build_and_run.sh --verify
```

## Uninstall

Remove only Codex Status Bar hooks:

```bash
node scripts/uninstall-codex-statusbar.js
```

Then quit the app and delete the app bundle if desired.

Local status files are stored under:

```text
~/.codex/statusbar/
```
