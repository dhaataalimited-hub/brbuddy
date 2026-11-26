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

## Phase 8: Desktop companion (planned 2026-11-23)
The companion can come out of the away screen and live on the unlocked desktop, as a small live status light you can
see from any app. **Off by default**: you add it to the screen, or take it away, from the menu bar menu.

- **The window:** a small, frameless, see-through window about one sprite cell in size. It floats above other apps
  and shows on every Space. It never takes keyboard focus, and clicks go through it, so it never blocks what's
  underneath. Hold ⌥ and drag to move it; ⌥-click to boop it. It draws with the same code as the
  away screen (`CompanionView`), so every pack works, gallery ones included.
- **Modes**, picked from the menu bar menu:
  - **Go for a wander:** it walks back and forth along the top of the Dock (running row, flipped for direction),
    stopping now and then to idle. It follows the Dock to the bottom, left or right edge, and stays still if the Dock
    is hidden.
  - **Party mode:** it dances (jumping and waving rows on a beat-like bob) with headphones on. The headphones are
    drawn over the companion, so they fit any pack, not only Studio ones.
  - **Naughty corner:** it sits in a corner you pick and stays there.
- **Its own sound**, separate from the system volume: an on/off switch (and volume) in the menu bar menu and
  Settings, used for boops and reactions. Off never mutes anything else.
- **Feedback it gives:**
  - **Your agent (Claude and others):** runs while the agent works, waves when it's done, looks worried when
    something fails, waits when the agent needs you. Uses the agent events BRBuddy already receives.
  - **Battery:** the same reactions the away screen uses for low battery and charging.
  - **Drive space:** it gets fatter as the startup drive fills up, in a few steps (say 70%, 85%, 95% full), drawn as
    a sideways stretch so it works on any pack. Back to normal when space is freed. Hovering (with ⌥) shows how much
    space is left.
- **Staying out of the way:** hides while a full-screen app or video call is in front, and is left out of screen
  sharing and recordings (so it never shows up in someone's meeting). Pauses its animation on
  battery power when nothing is happening; about 8 frames a second when it moves.
- **Which display:** with more than one, you pick its screen in the menu bar menu (the one with the Dock until
  you choose). If that display is unplugged, it moves to the main one and goes back when it returns.
- **Only while an agent is working:** an option in Settings, off by default. When it's on, the companion appears
  when an agent starts work and leaves a little after it finishes (after its wave or worried look).

## Phase 9: First-launch tour ✅ built 2026-11-26 (ships first, on its own)
A new install is hard to spot: BRBuddy only has a menu bar icon. On **first launch only**, the buddy hangs on a little
string just under the BRBuddy icon and says "I live up here. Click me." Clicking it starts a short tour, every step
skippable:

1. **Connect your agent:** installs the hooks for the agents it finds.
2. **Try BRB now:** starts BRB for real, so the user also learns how to come back (Touch ID or password); the tour
   picks up again after unlocking. (Planned as a 5-second demo; a real BRB avoids adding a way to end BRB without
   unlocking.)
3. **Pick a companion:** the built-ins, Companion Studio, and a link to the gallery.
4. **Optional extras:** launch at login, keep awake while an agent works, and the walk-away lock (Phase 6). The
   desktop companion joins this step when Phase 8 is built.

- **Show tour again** in the menu bar menu brings it back.
- If the icon is hidden (behind the notch, or by a menu bar organiser), the buddy and the tour show in the middle of
  the screen instead.
- Permissions (Accessibility, Bluetooth) are asked for only at the step that needs them.
- The hanging buddy is drawn over any pack (string and swing added on top), and is the same piece Phase 8's
  **Hang out** mode uses.

Phase 8 gains a fourth mode, **Hang out:** the buddy dangles under its menu bar icon, sways when the mouse comes near,
drops down to wave when the agent finishes, and climbs back up.

## Phase 10: Token usage (planned 2026-11-26)
How many tokens your agents are using, read **on the Mac** from the agents' own logs (nothing is sent anywhere).
**Claude Code** first (its session logs record input, output and cache tokens per reply, with the model), then
**Codex** (its session logs).

- **Tokens and an estimated cost** at each model's API prices, labelled as an estimate (on a subscription plan the
  real cost is the plan). Plan limits (Claude's 5-hour and weekly windows) aren't in the logs, so they're not shown.
- **Menu bar:** the day's total next to the icon (e.g. "1.2M"), on by default with a switch to hide it. The menu gets
  a Usage section: today and this week, by agent and model, with a small chart.
- **The buddy:** it munches while tokens are flowing, and you can set a **daily budget**: it gets full and sleepy as
  you near it, and does a little "whoa" at a big burst. (Fatter stays reserved for drive space.)
- **Away screen:** a card when you come back: "While you were away: 840K tokens over 23 minutes, 3 tasks finished."
- Not possible: drawing on the macOS lock screen. BRBuddy's away screen is where it shows instead.
