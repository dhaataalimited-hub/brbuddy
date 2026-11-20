# BRBuddy roadmap

Decided 2026-11-20. Distributed outside the App Store (GitHub Releases, own Homebrew tap, Sparkle updates), not
sandboxed, MIT. Fresh repo that borrows from permissively licensed projects with credit, not a fork.

## Phase 0: Skeleton ✅
SwiftPM package, menu bar item, keep-awake toggle, bundling script, architecture map and docs test.

## Phase 1: BRB (Away mode) — ~1 day
- Full-screen away window on every display; Dock, app switcher and Force Quit blocked while it's up.
- Unlock with Touch ID or password (LocalAuthentication); any keypress or mouse move shows the unlock prompt.
- Keep-awake switches to "system and display" while away.
- Auto-start after N minutes without **physical** input (ignore input that software creates). Reference: Hammerspoon.
- Escalate to the real macOS lock screen after failed unlocks or a long time away. Reference: Hammerspoon's
  lock-screen call (private API; fine outside the App Store). Test on macOS 14, 15 and 26.
- Global hotkey (sindresorhus/KeyboardShortcuts) and launch at login (LaunchAtLogin-Modern).
- Warn if macOS's own screen saver or lock timer is shorter than BRB's.
- Known limits, stated in the app: the power button and fast user switching can't be blocked.

## Phase 2: Knows your agent — ~½–1 day
- Hooks into a local socket for Claude Code, Codex, Cursor, Gemini / Antigravity (borrow from AgentPet, MIT) and
  Grok, cursor-agent (borrow from codelight, MIT). One-click hook setup per tool.
- Process scan for desktop apps (Claude, ChatGPT, Cursor) and CLIs without hooks; CPU activity as a fallback.
- States: working, waiting for you, finished.

## Phase 3: Companions — ~½ day of code, art open-ended
- Pack format: Codex pet format (`pet.json` + spritesheet) plus BRBuddy fields for agent states and a required
  `license`. Runtime: OpenPetsKit (MIT) or our own.
- Five original starter characters (placeholder shapes first; Kenney CC0 parts or a contributor's art later).
- No vendor logos or mascots, ever.

## Phase 4: Terminal mirror — ~1 day
- Primary: tmux read-only control mode streamed into SwiftTerm (MIT). Works with any terminal app.
- Fallback without tmux: Accessibility text from Terminal, Ghostty, iTerm2 (plain text, no colour).

## Phase 5: Release — ~½ day
- Developer ID signing + notarization + DMG + Sparkle appcast in GitHub Actions (template: exelban/stats, MIT).
- Own Homebrew tap first; homebrew/cask once the repo has the stars and is 30+ days old.
- Before going public: trademark search, register brbuddy.app.

## Phase 6: Walk-away lock — ~1–2 days
- Start BRB when the iPhone or Apple Watch's Bluetooth signal fades. Learn from BLEUnlock (no license: study only),
  write our own CoreBluetooth code.
