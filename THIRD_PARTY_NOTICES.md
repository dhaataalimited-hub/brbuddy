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
### AgentPet (https://github.com/ntd4996/agentpet), commit 1b5c0df
Adapted in `AgentKind.swift` (event names and their meanings), `AgentHookInstaller.swift` (config locations and
shapes; the Codex `[features] hooks = true` transform) and `AgentEvent.swift` (payload key names). Rewritten for
BRBuddy, but derived from AgentPet's `AgentHooks`, `StateMapper`, `HookInstaller`, `CodexHookConfig` and payload types.
AgentPet's art is not used.

```
MIT License

Copyright (c) 2026 Nguyễn Thành Đạt

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

### Others `ScreenLocker.swift` calls the same private macOS function as Hammerspoon's lock-screen code, written
from scratch. `KeepAwake.swift` follows KeepingYouAwake's approach but is written from scratch.
