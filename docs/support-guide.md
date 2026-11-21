# BRBuddy support guide

Plain-English answers about what BRBuddy does and how to help someone using it. Everything above "For the team
(internal)" avoids internal detail and can be shared as is. BRBuddy is free and open source; questions and bug
reports go to the project's GitHub Issues page.

## What BRBuddy is
BRBuddy is a free menu bar app for Mac. When you step away while an AI coding agent (Claude Code, Codex, Cursor,
Gemini CLI, Antigravity or Grok) is working, it keeps your Mac awake and covers the screen with a friendly companion
that shows what your agent is doing. Anyone who touches the keyboard has to use Touch ID or your password to get
back in. BRBuddy isn't made by or affiliated with any of those AI companies.

## Features
| Feature | Where | Notes |
|---|---|---|
| Keep Mac awake | Menu bar paw → Keep Mac awake | The paw fills in while the Mac is being kept awake |
| Keep awake while an agent works | Settings → Agents | On by default once an agent is set up; turns off by itself when the agent finishes |
| BRB (the away screen) | Menu → BRB now, or ⌃⌥⌘B | Covers every display; shows your companion, how long you've been away and what your agent is doing |
| Start BRB on its own | Settings → General → Starting BRB | After 3 minutes with no keyboard or mouse (1–120), while the Mac is being kept awake |
| Unlock | Press any key on the away screen | Touch ID, or type your Mac login password |
| Lock for real | Settings → General → Locking for real | After 3 wrong tries (1–10) or an hour away (or never), BRBuddy switches to the normal macOS lock screen. Your agent keeps running |
| Agent status | Settings → Agents → Set up | One button per agent; the menu and away screen then show "working", "needs you" or "done" |
| Jump to an agent | Click the agent in the menu | Opens the terminal window it's running in; in Terminal and iTerm2, the exact tab. macOS asks once to let BRBuddy control Terminal/iTerm2 |
| Companions | Settings → Companion | Six built-in characters (Ember, Pebble, Prism, Comet, Drift, Gremlin), or "Match my agent" |
| Companion packs | Settings → Companion → Add companion pack… | Any pet made for Codex works (a folder with pet.json and a spritesheet) |
| Battery on the away screen | Settings → Away Screen → Battery | On by default on MacBooks. Shows charge and time left; the companion cheers when you plug in, sweats when the battery's low and moves in slow motion in Low Power Mode |
| Terminal on the away screen | Settings → Away Screen | Off by default. Shows a tmux pane, a Terminal/iTerm2/Ghostty window, or a feed of what your agent is doing. View-only |
| Walk-away lock | Settings → Walk-away | Pair your iPhone with the Mac, then pick it; when it moves away, BRBuddy starts BRB or locks the Mac |
| Open at login | Settings → General | |
| Updates | Menu → Check for Updates… | Downloaded releases check once a day and offer new versions; builds made from source don't update themselves |

Requires macOS 14 or later.

## Plans and purchases
BRBuddy is completely free, with no account, subscription or in-app purchase. It's open source under the MIT
licence.

## Privacy
- BRBuddy collects nothing and has no server. Everything stays on your Mac.
- Your password is only checked by macOS; BRBuddy never stores or logs it.
- **Agent setup** adds one small entry to that agent's own settings file and saves a backup copy next to it first.
  The entry only tells BRBuddy what the agent is doing (for example "running swift test"). It can't change or block
  anything the agent does, and it never sends your prompts.
- **Terminal on the away screen** shows text from your terminal or agent to anyone standing at your Mac. That's why
  it's off until you turn it on.
- Permissions BRBuddy may ask for, only when you turn on the feature that needs it:
  - **Accessibility**: to read the text of a Terminal, iTerm2 or Ghostty window for the away screen.
  - **Bluetooth**: for the walk-away lock, to sense how far your phone or watch is.

## Troubleshooting

**My Mac still went to sleep.**
Check the paw in the menu bar is filled in. If you're relying on your agent to keep it awake, make sure that agent
is set up in Settings → Agents and "Keep the Mac awake while an agent is working" is on. Closing the lid on battery
still sleeps the Mac; that's macOS, not BRBuddy.

**The away screen doesn't show the battery.**
Check Settings → Away Screen → "Show the battery on the away screen" is on; the change applies the next time BRB
starts. Desktop Macs (iMac, Mac mini, Mac Studio, Mac Pro) have no battery, so there's nothing to show.

**BRB didn't start on its own.**
It only starts by itself while the Mac is being kept awake (by you, or because an agent is working) and when
"Start BRB on its own" is on. It waits the number of minutes set there with no keyboard or mouse use. Something that
moves the mouse for you (a "mouse jiggler" or remote-desktop tool) can stop it starting.

**How do I get past the away screen?**
Press any key or move the mouse, then touch the Touch ID sensor or type your Mac login password and press Unlock.
If nobody types for 30 seconds the prompt goes away again; press a key to bring it back.

**The Mac locked itself while I was away.**
That's the "Locking for real" setting: after too many wrong tries or a long time away, BRBuddy hands over to the
normal macOS lock screen. Log in as usual. Your agent kept working the whole time.

**Can someone get around the away screen?**
It blocks app switching, Force Quit, quitting and other shortcuts, but it's a deterrent, not a vault. Holding the
power button still restarts the Mac. For full security, keep "Locking for real" on.

**An agent's "Set up" button is greyed out.**
BRBuddy didn't find that agent on this Mac. Run the agent once (so it creates its settings folder), then open
Settings again.

**Setting up an agent showed an error about its file.**
That agent's settings file isn't readable as settings, so BRBuddy left it untouched. Fix or remove the file (the
agent's own docs explain it), then press Set up again.

**The menu doesn't show my agent working.**
Start a new session of the agent after pressing Set up; sessions that were already open only start reporting from
their next step. Desktop apps (Claude, ChatGPT, Cursor's editor) can't report their status; only their command-line
agents can.

**Clicking an agent in the menu doesn't go to its tab.**
In Terminal or iTerm2, allow BRBuddy under System Settings → Privacy & Security → Automation. In other apps BRBuddy
brings the app forward; to pick the right window it needs Accessibility (System Settings → Privacy & Security →
Accessibility). Sessions started before this update, and agents running inside tmux or over SSH, show as plain text
until their next session.

**How do I remove BRBuddy from an agent?**
Settings → Agents → Remove next to the agent. A backup of the agent's original settings file stays next to it,
ending in ".brbuddy-backup".

**My companion pack wasn't added.**
The message under the button says why: it needs a pet.json file and a spritesheet of the standard Codex pet size
(1536×1872 or 1536×2288 pixels), under 20 MB, inside the same folder.

**The terminal panel says "Nothing to show".**
It lists the reasons. Usually: tmux isn't installed or not running, BRBuddy isn't allowed to read terminal windows
(use the "Allow BRBuddy to read terminal windows…" button, then switch BRBuddy on under Privacy & Security →
Accessibility), or no agent has reported anything yet.

**BRBuddy forgot its Accessibility permission after an update.**
macOS ties the permission to the exact app build. Switch BRBuddy off and on again under System Settings → Privacy &
Security → Accessibility.

**Which device in the walk-away list is mine?**
iPhones and watches don't broadcast their names, so press Choose device… and hold your phone (unlocked) right next to
the Mac. Within a few seconds it moves to the top of the list and is marked Closest; press Use next to it. Rows say
iPhone or Apple Watch once BRBuddy has asked the device its model.

**Walk-away says my iPhone isn't paired. How do I pair it?**
Walk-away only works with an iPhone paired with your Mac: unpaired iPhones change their Bluetooth identity about every
15 minutes, so BRBuddy would lose track of yours. On the iPhone, open Settings → Bluetooth and leave it open. On the
Mac, open System Settings → Bluetooth, find your iPhone under Nearby Devices and click Connect; accept the code on both.
It may then say Not Connected; that's fine, it stays paired. Back in BRBuddy, press Check again and choose your phone:
it now shows its own name. (To undo: System Settings → Bluetooth → ⓘ next to the iPhone → Forget This Device.)

**Why do other phones in the list say "iPhone" and "Not paired"?**
iPhones keep their name private unless they're paired with your Mac, so strangers' phones all show as "iPhone". The
four characters after a name are this Mac's short ID for it, not its Bluetooth address.

**My paired iPhone shows "Needs a name".**
It's called just "iPhone", the same as every unpaired phone. Rename it on the iPhone (Settings → General → About →
Name), then choose it again.

**How do I check walk-away is watching the right phone?**
Settings → Walk-away → Test…. Hold the phone next to the Mac (the signal number jumps up), walk away with it until
the panel says Away, then come back. Each step gets a tick; BRB won't start during the test. If the number doesn't
change when you move the phone, choose the device again.

**The walk-away lock triggers too early, too late, or not at all.**
Bluetooth signal varies a lot with walls, pockets and bodies. Try "Away means": Near, Room or Far, and test a few
times. Keep Bluetooth on on your phone or watch. If the status says BRBuddy isn't allowed to use Bluetooth, allow it
under System Settings → Privacy & Security → Bluetooth. After resetting or re-pairing your phone, choose it again.

---

## For the team (internal)
- How the app is built: `docs/architecture/README.md` and `docs/architecture/flows/`; the visual version is
  `docs/architecture/map.html` (published as a private artifact; link in the README).
- Plans, what's done and what's still open: `ROADMAP.md`. Licences of borrowed code: `THIRD_PARTY_NOTICES.md`.
- Verified on the owner's Mac (macOS 26.6) on 2026-11-20: Touch ID unlock, agent hooks with Claude Code, the
  Accessibility terminal mirror. Not yet verified with real hardware: walk-away lock tuning, tmux mirror, the
  "lock for real" hand-off on macOS 14 and 15.
- Files to ask a user for: `~/Library/Application Support/BRBuddy/` (hook helper, socket, companion packs) and the
  agent settings file plus its `.brbuddy-backup` when setup misbehaves.
- Escalate first: anything that damaged an agent's settings file (restore from the backup), or the away screen not
  unlocking with the correct password (force quit isn't possible; restart the Mac).
