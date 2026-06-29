# Lifecycle And Self-Repair

Phase 4 makes Codex Status Bar a hook-launched local tool instead of a manually managed menu bar app.

## Startup Hook Repair

On app startup, Swift schedules a background hook repair. The repair runs the bundled installer:

```text
CodexStatusBar.app/Contents/Resources/install-codex-statusbar.js
```

The installer is idempotent and only removes hooks whose command contains Codex Status Bar marker scripts:

- `codex-status-writer.js`
- `codex-lifecycle-writer.js`
- `codex-hook-logger.js`

Unrelated user Codex hooks are preserved. Swift does not maintain a separate install-signature state file; the bundled installer is the single source of truth for hook generation and repair.

## Node Discovery

The shared hook manager resolves Node in this order:

1. current `process.execPath`
2. Volta
3. asdf
4. nvm
5. Homebrew Apple Silicon
6. Homebrew Intel
7. system Node
8. `PATH`

The standalone installer and app-triggered repair both execute the same installer, which uses `scripts/lib/hook-manager.js` for hook generation and repair. Swift only bootstraps enough Node discovery to run the bundled installer in the background.

## Hook App Launch

After `SessionStart` or any visible activity event writes a session state file, the hook writer calls the shared app launcher. The launcher opens:

```text
CodexStatusBar.app
```

The path is resolved from `CODEX_STATUSBAR_APP_PATH`, from bundled resources, or from the local `build/CodexStatusBar.app` development path. Before opening, the launcher checks whether that same app bundle is already running, so an old same-name process does not suppress launch of the current app.

This means a new CLI or Desktop hook can bring the status bar back after crash, force quit, or automatic exit. No LaunchAgent, login item, or background daemon is installed.

## Session Liveness

Swift treats `state.d/<session_id>.json` as display state, not as permanent storage.

- A session with a live `pid` is retained.
- A session with a dead `pid` is removed.
- A corrupt or unparsable session file is removed.
- Old `pid == 0` files are retained only temporarily and pruned after the orphan timeout.
- Live active sessions are not aged out by a short quiet timeout; `thinking` and `compacting` remain visible until an explicit next-state event, stop/end event, or process liveness says otherwise.

This keeps current sessions visible while preventing stale files from accumulating indefinitely.

## Auto Exit

The app exits after a delay when all conditions are true:

- no Codex Desktop app is running
- no live session exists
- no `permission`, `tool`, `thinking`, `compacting`, or `waiting` session is visible

The delay prevents short gaps between hook writes from causing premature exit. Active CLI sessions, permission prompts, and running tool/thinking/compacting sessions keep the status bar process alive.

## Uninstall Boundary

`scripts/uninstall-codex-statusbar.js` uses the same marker filtering as install/repair. It removes only Codex Status Bar hook commands and does not modify unrelated user hooks.
