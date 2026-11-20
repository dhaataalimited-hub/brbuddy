# BRBuddy roadmap

Decided 2026-11-20. Distributed outside the App Store (GitHub Releases, own Homebrew tap, Sparkle updates), not
sandboxed, MIT. Fresh repo that borrows from permissively licensed projects with credit, not a fork.

## Phase 0: Skeleton ✅
SwiftPM package, menu bar item, keep-awake toggle, bundling script, architecture map and docs test.

## Phase 1: BRB (Away mode) ✅ (2026-11-20, except where noted)
- Full-screen away window on every display; Dock, app switcher and Force Quit blocked while it's up.
- Unlock with Touch ID or password (LocalAuthentication); any keypress or mouse move shows the unlock prompt.
- Keep-awake switches to "system and display" while away.
- Auto-start after N minutes without **physical** input (ignore input that software creates). Reference: Hammerspoon.
- Escalate to the real macOS lock screen after failed unlocks or a long time away. Reference: Hammerspoon's
  lock-screen call (private API; fine outside the App Store). Test on macOS 14, 15 and 26.
- Global hotkey (sindresorhus/KeyboardShortcuts) and launch at login (LaunchAtLogin-Modern).
- ~~Warn if macOS's own screen saver or lock timer is shorter than BRB's.~~ Solved instead: while keep-awake and
  auto-start are on, BRBuddy holds the display awake so macOS can't beat BRB to it.
- **Still open:** telling real input from software-posted input (listen-only event tap checking the event source,
  as Hammerspoon does). Today `IdleMonitor` uses HID idle time, which some remote-desktop tools and jigglers reset.
- **Still open:** hands-on test of Touch ID unlock, wrong-password escalation and the real lock on macOS 14 and 15
  (only checked on 26.6 so far; the lock call is verified to exist, not exercised).
- **Still open:** Mission Control / Spaces gestures and notification banners while BRB is up.
- Known limits, stated in the app: the power button and fast user switching can't be blocked.

## Phase 2: Knows your agent ✅ (2026-11-20, except where noted)
- Hooks into a local socket for Claude Code, Codex, Cursor, Gemini / Antigravity (borrow from AgentPet, MIT) and
  Grok, cursor-agent (borrow from codelight, MIT). One-click hook setup per tool.
- Process scan for desktop apps (Claude, ChatGPT, Cursor) and CLIs without hooks; CPU activity as a fallback.
- States: working, waiting for you, finished.
- Done: keeps the Mac awake by itself while an agent works or waits (setting, default on); BRB auto-start follows it;
  away screen and menu show agent status.
- **Still open:** live test with each real agent (only fake events through the real helper so far; Claude Code and
  Codex are installed on the dev Mac, the others aren't). ChatGPT/Claude/Cursor desktop apps: detected only, no
  status (no hooks). CPU-activity fallback for unhooked CLIs not built. "Waiting" could also push a notification
  to the phone.

## Phase 3: Companions ✅ (2026-11-20, except where noted)
- Pack format: Codex pet format (`pet.json` + spritesheet) plus BRBuddy fields for agent states and a required
  `license`. Runtime: our own (OpenPetsKit not needed).
- Six original starter characters drawn in code (Ember, Pebble, Prism, Comet, Drift, Gremlin), one per agent's
  vibe, each with six moods. "Match my agent" picks automatically.
- Community packs: any Codex pet (v1/v2) works; `license`, `author`, `agents` are optional BRBuddy fields. Checked
  against all 385 pets in the awesome-codex-pet catalogue (loaded locally, none bundled).
- **Still open:** a gallery/download of packs, a "make your own" guide with a template sheet, exporting built-ins as
  Codex packs, pixel-art (nearest-neighbour) scaling option.
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
