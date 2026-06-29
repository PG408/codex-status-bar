# Codex Status Bar

Codex Status Bar is a small macOS menu bar app that displays the live status of Codex sessions. The current baseline keeps the UI intentionally narrow: multiple local session state files, one visible menu bar item, and deterministic hook replay tests that can be used as the baseline for later session-menu work.

## Phase 0 Scope

In scope:

- Build a local `CodexStatusBar.app` from the project root.
- Render `idle`, `thinking`, `tool`, `compacting`, `permission`, and `done` states in the macOS menu bar.
- Write and read the single local state file at `~/.codex/statusbar/state.json`.
- Install Codex hooks into `~/.codex/hooks.json` without removing unrelated hooks.
- Provide local scripts for manual state testing and hook uninstall.

Out of scope:

- Multi-session state aggregation.
- Session dropdown rows.
- Automatic update checks.
- Developer ID signing, notarization, or full release packaging.
- Production distribution polish.

## Phase 1 Scope

Phase 1 adds a deterministic local verification layer for Codex hook events:

- Document the single-state-file hook event model.
- Replay `UserPromptSubmit`, `PreToolUse`, `PostToolUse`, `PermissionRequest`, `Stop`, `SubagentStart`, and `SubagentStop` from fixtures.
- Verify that background tool events cannot overwrite the active turn.
- Keep the runtime model as a single `state.json` file.

## Phase 2 Scope

Phase 2 upgrades the runtime model to Codex multi-session state:

- Write new status updates to `~/.codex/statusbar/state.d/<session_id>.json`.
- Use a lifecycle writer for `SessionStart` and `SessionEnd`.
- Aggregate multiple session files in Swift and render one lead session.
- Select the lead by `permission` first, then `tool/thinking/compacting`, then most-recent idle/done state.
- Keep old `state.json` as a read-only fallback when `state.d/` is empty.

Still out of scope: session dropdown UI, click-to-focus, automatic updates, signing, notarization, and release packaging.

## Phase 3 Scope

Phase 3 adds the Sessions Menu:

- `Sessions`, `Options`, `Icon`, and `Diagnostics` menu sections.
- Custom session rows with project name, state icon, elapsed timer, and CLI/APP badge.
- `Hide idle sessions` menu filtering that does not delete `state.d` files or affect lead-session aggregation.
- Row click focus for Codex Desktop and CLI terminal/editor apps.
- Standardized surface metadata: `entrypoint`, `entrypointSource`, `termProgram`, and `focusTarget`.

The detailed behavior and focus boundaries are documented in `docs/sessions-menu.md`.

## Phase 4 Scope

Phase 4 adds lifecycle automation:

- Startup self-check and hook repair for first launch, version/path changes, missing hooks, and stale hook paths.
- Shared Node/path/hook generation through `scripts/lib/hook-manager.js`.
- Hook-triggered launch of `CodexStatusBar.app` after `SessionStart` or visible session activity.
- PID-based liveness cleanup, corrupt state cleanup, old-format fallback pruning, and delayed auto-exit when no live Codex work remains.

The lifecycle behavior, Node discovery, launch boundaries, and uninstall boundary are documented in `docs/lifecycle.md`.

## Requirements

- macOS 12 or later.
- Xcode Command Line Tools with `swiftc`.
- Node.js for hook scripts.
- Codex with hook support.

## Build

Build the app:

```bash
./build.sh
```

The app bundle is written to:

```text
build/CodexStatusBar.app
```

Build a local DMG only when needed:

```bash
./build.sh --dmg
```

## Run

Use the project-local run entrypoint:

```bash
./script/build_and_run.sh
```

The same script backs the Codex app `Run` action in `.codex/environments/environment.toml`.

Verify that the app launches:

```bash
./script/build_and_run.sh --verify
```

## Manual State Testing

The app polls `~/.codex/statusbar/state.d/` every 0.4 seconds. Use the development helper to switch the default `dev` session manually:

```bash
node scripts/dev-state.js idle
node scripts/dev-state.js thinking
node scripts/dev-state.js tool
node scripts/dev-state.js compacting
node scripts/dev-state.js permission
node scripts/dev-state.js done
```

Additional helper modes:

```bash
node scripts/dev-state.js demo
node scripts/test-statusbar.js
```

## Hook Replay Testing

Run the deterministic hook replay suite:

```bash
node scripts/replay-hook-fixtures.js
node scripts/verify-hook-manager.js
node scripts/verify-session-surface.js
node scripts/verify-menu-model.js
```

Fixtures live under `fixtures/hook-events/`. The replay script runs `scripts/codex-status-writer.js` and `scripts/codex-lifecycle-writer.js` in an isolated temporary status directory, verifies `state.d/`, rejects legacy `state.json` writes, and checks the expected lead session.

The current event model and surface resolution rules are documented in `docs/hook-events.md`; lifecycle automation is documented in `docs/lifecycle.md`.

## Install Hooks

Install the Codex hooks:

```bash
node scripts/install-codex-statusbar.js
```

The installer:

- Reads and updates `~/.codex/hooks.json`.
- Creates a first-run backup at `~/.codex/hooks.json.bak-codex-status-bar` when a hooks file already exists.
- Removes only prior hooks that reference this status bar's own marker scripts.
- Adds hook commands for Codex lifecycle, tool, permission, and stop events.

## Uninstall Hooks

Remove only this app's hooks:

```bash
node scripts/uninstall-codex-statusbar.js
```

The uninstall script edits `~/.codex/hooks.json` and removes commands containing this project's hook markers. It does not remove unrelated Codex hooks.

## Local Files

- App state: `~/.codex/statusbar/state.d/<session_id>.json`
- Legacy fallback state: `~/.codex/statusbar/state.json`
- App render log: `~/.codex/statusbar/app.log`
- Hook discovery log, when enabled: `~/.codex/statusbar/hooks-discovery.jsonl`
- Installed hooks: `~/.codex/hooks.json`

## Design Baseline

This project starts from the Codex status bar reference and preserves the local-file plus menu-bar architecture. Later phases can add session rows, click-to-focus behavior, and stronger lifecycle handling without changing the Phase 2 `state.d/` contract.

The project is unofficial and is not affiliated with, endorsed by, or sponsored by OpenAI.

## License

MIT
