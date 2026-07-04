# Acknowledgements

Codex Status Bar was built by studying two reference projects and adapting
their ideas to Codex's hook and session model.

## Reference Projects

- [ilyastorunn/codex-status-bar](https://github.com/ilyastorunn/codex-status-bar)
  provided the original Codex-focused prototype, including the small menu bar
  surface, local hook writer direction, icon assets, and Codex-oriented
  installation flow.
- [m1ckc3s/claude-status-bar](https://github.com/m1ckc3s/claude-status-bar)
  provided a mature example of the local-file plus macOS menu-bar architecture,
  including the product README structure, hook lifecycle framing, multi-session
  menu direction, and small-app positioning.

## Adaptation

This project keeps the reference pattern intentionally small: Codex hooks write
local display records, and a macOS status item renders those records. The
implementation is Codex-specific: paths, hook names, state fields, Desktop
thread deeplinks, session grouping, archived-chat handling, and visual states are
adapted for Codex rather than copied from the reference projects.

## Assets

The download button image and early visual structure are adapted from the
reference projects. Codex pet artwork is not bundled by this project; Pet mode
reads pets already installed by the local Codex app.

## License Notices

This project's own source code is released under the MIT License. Third-party
MIT license notices for referenced or partially adapted material are preserved
in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
