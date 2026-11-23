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
- Added 2026-11-21/22: the away screen shows the battery and companions react to it (cheer on plug-in, sweat when
  low, slow motion in Low Power Mode); on battery the body holds still and only the face moves (packs can ship a
  still sheet); clicking a companion "boops" it: five shared reactions plus a signature one with its own
  synthesised sound and line (packs name theirs in `pet.json`).
- Added 2026-11-22: Shuffle mode, a different companion each time BRB starts.
- **Still open:** pixel-art (nearest-neighbour) scaling option; choosing which companions Shuffle uses. Making and
  sharing packs moved to Phase 7.
- No vendor logos or mascots, ever.

## Phase 4: Terminal mirror ✅ (2026-11-20, except where noted)
- Primary: tmux read-only control mode streamed into SwiftTerm (MIT). Works with any terminal app.
- Fallback without tmux: Accessibility text from Terminal, Ghostty, iTerm2 (plain text, no colour).
- Built instead of tmux control mode + SwiftTerm: `tmux capture-pane -e` once a second through our own colour
  parser (no dependency, never attaches a client). Added a third source, the agent activity feed from hook events,
  which needs no tmux and no permissions. Off by default; Settings has a live preview and a warning.
- **Still open:** live test with real tmux (not installed on the dev Mac; covered by fixture tests) and with
  Accessibility (needs the owner to allow it). A `brb run <agent>` wrapper that tees a PTY would cover VS Code and
  Warp. Pixel-exact fallback via ScreenCaptureKit not built.

## Phase 5: Release ✅ pipeline built (2026-11-20); first release waiting on one-time setup
- Developer ID signing + notarization + DMG + Sparkle appcast in GitHub Actions (template: exelban/stats, MIT).
- Own Homebrew tap first; homebrew/cask once the repo has the stars and is 30+ days old.
- Before going public: trademark search, register brbuddy.app.
- Built: Sparkle 2.10.1 updater (release builds only) and Check for Updates; `Tools/build-app.sh` embeds Sparkle,
  versions from tags, signs inside out (Developer ID + hardened runtime when given); `Tools/release.sh` makes the
  universal notarized DMG, signed appcast and cask; GitHub Actions `tests.yml` and `release.yml`; `docs/releasing.md`.
  Dry run passed locally (ad hoc, unnotarized).
- **Waiting on the owner:** Developer ID Application certificate (only an Apple Development one is on the Mac),
  App Store Connect API key, Sparkle keys, GitHub secrets, making the repo public, creating the homebrew-tap repo.
  CI hasn't run yet (first push of this branch).

## Phase 6: Walk-away lock ✅ (2026-11-20, except where noted)
- Start BRB when the iPhone or Apple Watch's Bluetooth signal fades. Learn from BLEUnlock (no license: study only),
  write our own CoreBluetooth code.
- Built: device picker (nearby Apple devices by manufacturer ID), connection with RSSI every 2 s plus advertisement
  readings, median smoothing, 10 s weak / 60 s silent → away, 6 dB hysteresis, three ranges, action BRB or real lock.
- **Still open:** hands-on tuning with a real iPhone and Watch (needs the owner at the Mac to allow Bluetooth and
  walk around). Whether a locked iPhone keeps the connection reliably varies by iOS version. A "returned" action
  (e.g. show the unlock prompt) isn't built.

## Phase 7: Make and share companions (planned 2026-11-22)
Three steps, smallest first. No server and no money: sharing goes through GitHub, reviewed by hand.

1. **"Make one with any AI" guide** ✅ `docs/making-a-companion.md`: a copy-paste prompt with the full pack spec
   (grid, rows, still sheet, `pet.json`, signature sounds) and troubleshooting. Linked from the README and
   CONTRIBUTING.
2. **Companion Studio** ✅ (2026-11-22), opened from Settings → Companion. Build a critter from the parts `CritterDesign` already has
   (body shape, colours, ears, accent, blush, lopsided eyes, floating), pick a signature sound and line, and watch
   it react in the live preview, boops included. **Save as pack** renders both spritesheets with the same drawing
   code the built-ins use and writes a normal Codex-format folder that works in other pet apps too. Original by
   construction: no AI or drawing skills needed.
   - Built: a design is saved as `design.json` beside the sheets, so BRBuddy draws it live with every reaction
     and it can be edited again. Mouths added the same day: six styles (standard, cat, grin, tongue out, fangs, beak)
     and a size; blush colour too. **Still open:** more parts (tails, hats, patterns).
3. **Community gallery** ✅ (2026-11-23) on the website: [brbuddy.app/gallery](https://brbuddy.app/gallery/).
   People submit with the **Share a companion** issue form (zip, credit, CC BY 4.0 or CC0, originality checkboxes);
   Andy reviews each one and publishes it with `Tools/gallery/gallery.py add`, which checks the pack and makes its
   animated preview and download. Takedowns: `gallery.py remove` (see the support guide). The page also carries the
   AI prompt with a Copy button.
   - **Still open:** **Browse packs…** in BRBuddy, listing `site/gallery/packs.json` and installing a chosen pack
     through the same checks as **Add companion pack…**, with downloads pinned to reviewed commits.
   - Not planned: a paid marketplace (needs a server, payments, moderation at scale). Revisit if the gallery takes
     off.
