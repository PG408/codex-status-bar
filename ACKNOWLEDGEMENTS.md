# Acknowledgements

Codex Status Bar was built by studying two local reference projects in this
workspace and adapting their ideas to Codex's hook and session model.

## Reference Projects

- `reference/codex-status-bar` provided the original Codex-focused prototype,
  including the small menu bar surface, local hook writer direction, icon assets,
  and Codex-oriented installation flow.
- `reference/claude-status-bar` provided a mature example of the local-file plus
  macOS menu-bar architecture, including the product README structure, hook
  lifecycle framing, multi-session menu direction, and small-app positioning.

## Adaptation

This project keeps the reference pattern intentionally small: Codex hooks write
local display records, and a macOS status item renders those records. The
implementation is Codex-specific: paths, hook names, state fields, Desktop
thread deeplinks, session grouping, archived-chat handling, and visual states are
adapted for Codex rather than copied from the reference projects.

## Assets

The download button image and early visual structure are adapted from the
reference materials in this repository. Codex pet artwork is not bundled by this
project; Pet mode reads pets already installed by the local Codex app.
