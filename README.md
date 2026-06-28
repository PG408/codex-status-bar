# Codex Status Bar

Codex Status Bar is a small macOS menu bar app that displays the live status of a Codex session. The current baseline keeps the runtime scope intentionally narrow: one status file, one visible menu bar item, and deterministic hook replay tests that can be used as the baseline for later multi-session work.

## Phase 0 Scope

In scope:

- Build a local `CodexStatusBar.app` from the project root.
- Render `idle`, `thinking`, `tool`, `permission`, and `done` states in the macOS menu bar.
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

The app polls `~/.codex/statusbar/state.json` every 0.4 seconds. Use the development helper to switch states manually:

```bash
node scripts/dev-state.js idle
node scripts/dev-state.js thinking
node scripts/dev-state.js tool
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
```

Fixtures live under `fixtures/hook-events/`. The replay script runs `scripts/codex-status-writer.js` in an isolated temporary status directory and verifies the resulting `state.json` after each hook event.

The current event model is documented in `docs/hook-events.md`.

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

- App state: `~/.codex/statusbar/state.json`
- App render log: `~/.codex/statusbar/app.log`
- Hook discovery log, when enabled: `~/.codex/statusbar/hooks-discovery.jsonl`
- Installed hooks: `~/.codex/hooks.json`

## Design Baseline

This project starts from the single-session Codex status bar reference and preserves the local-file plus menu-bar architecture. Later phases can replace the single `state.json` file with a per-session `state.d/` model, add session rows, and introduce stronger lifecycle handling.

The project is unofficial and is not affiliated with, endorsed by, or sponsored by OpenAI.

## License

MIT
