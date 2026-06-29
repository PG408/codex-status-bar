# Phase 4 Lifecycle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Codex Status Bar self-repairing and lifecycle-aware so hooks can launch it, sessions are cleaned by process liveness, and the app exits when no live Codex work remains.

**Architecture:** Add one shared JavaScript hook manager that owns Node discovery, hook command generation, install/repair, uninstall filtering, and app launch paths. Swift startup runs the bundled installer when version/path checks require repair, while writer scripts ensure the app is running after session writes. Swift owns runtime liveness cleanup and idle auto-exit.

**Tech Stack:** macOS AppKit/Swift compiled by `swiftc`, Node.js CommonJS hook scripts, local JSON fixtures and shell-first verification.

---

### Task 1: Shared Hook Manager And Tests

**Files:**
- Create: `scripts/lib/hook-manager.js`
- Create: `scripts/verify-hook-manager.js`
- Modify: `scripts/install-codex-statusbar.js`
- Modify: `scripts/uninstall-codex-statusbar.js`
- Modify: `build.sh`

- [ ] Write `scripts/verify-hook-manager.js` that imports `scripts/lib/hook-manager.js` and verifies Node candidate ordering, generated hook commands for lifecycle/status events, old-path repair, preservation of unrelated user hooks, and package resource copying expectations.
- [ ] Run `rtk node scripts/verify-hook-manager.js`; expected initial failure is `Cannot find module './lib/hook-manager'`.
- [ ] Implement `scripts/lib/hook-manager.js` with `findNode`, `resolveScriptPaths`, `desiredHookSettings`, `repairHooks`, `removeOwnHooks`, and `needsRepair`.
- [ ] Refactor installer/uninstaller to call the shared manager.
- [ ] Update `build.sh` to copy `scripts/lib` into `Contents/Resources/lib`.
- [ ] Run `rtk node scripts/verify-hook-manager.js`.

### Task 2: Hook-Launched App

**Files:**
- Modify: `scripts/codex-status-writer.js`
- Modify: `scripts/codex-lifecycle-writer.js`
- Modify: `scripts/lib/hook-manager.js`
- Create or extend: `scripts/verify-hook-manager.js`

- [ ] Add tests proving `SessionStart` and activity hooks call an app launcher after successful state writes.
- [ ] Implement `ensureStatusBarRunning()` in the shared manager, using `CODEX_STATUSBAR_APP_PATH`, bundled app path inference, repo build path fallback, and `/usr/bin/open -g`.
- [ ] Call `ensureStatusBarRunning()` after `SessionStart` and each visible status write.
- [ ] Run hook-manager verification and replay fixtures.

### Task 3: Swift Startup Repair, Liveness, Cleanup, Auto-Exit

**Files:**
- Modify: `Sources/main.swift`
- Extend: `scripts/verify-menu-model.js`

- [ ] Add source checks for startup self-repair, version record keys, pid liveness cleanup, corrupted JSON cleanup, and idle auto-exit markers.
- [ ] Implement startup cleanup of corrupt/stale/dead-pid sessions before the first render.
- [ ] Implement `pidAlive`-based liveness in `evaluate`.
- [ ] Implement launch self-check that compares bundle version/path and runs bundled `install-codex-statusbar.js` when first launch, version changed, or hooks are missing/stale.
- [ ] Implement delayed auto-exit when no Codex Desktop process and no live sessions remain.
- [ ] Run menu model verification and build.

### Task 4: Docs And Full Verification

**Files:**
- Modify: `README.md`
- Modify: `docs/hook-events.md`
- Create or modify: `docs/lifecycle.md`

- [ ] Document lifecycle self-repair, Node discovery, hook app launch, liveness cleanup, auto-exit, and uninstall boundaries.
- [ ] Run `rtk node scripts/verify-hook-manager.js`.
- [ ] Run `rtk node scripts/replay-hook-fixtures.js`.
- [ ] Run `rtk node scripts/verify-menu-model.js`.
- [ ] Run `rtk ./build.sh`.
- [ ] Run `rtk ./script/build_and_run.sh --verify`.
