# Third-party notices

When code is copied or adapted from another project, its copyright and license notice goes here, next to the files
it was used in. Projects we only learned from (no code copied) are credited in the README's "Built on" section.

## Rules
- Only copy code from permissively licensed projects (MIT, Apache-2.0, BSD, ISC, zlib). Keep their notice here.
  Apache-2.0 code also needs its NOTICE file contents, if it has one.
- GPL, AGPL, non-commercial or unlicensed projects are **study only**: read them, never copy code from them.
  Examples: BLEUnlock (no license), Buddi, notchi, Ice, iTerm2 (GPL).
- Art is licensed separately from code. Never bundle a project's pet art unless its art license allows it.

## Package dependencies (shipped inside the app)
- **KeyboardShortcuts** by Sindre Sorhus — MIT — https://github.com/sindresorhus/KeyboardShortcuts
  (global BRB shortcut and its recorder). Its license text must ship with release builds (Phase 5 pipeline).

## Copied or adapted code
_None yet._ `ScreenLocker.swift` calls the same private macOS function as Hammerspoon's lock-screen code, written
from scratch. `KeepAwake.swift` follows KeepingYouAwake's approach but is written from scratch.
