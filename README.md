# BRBuddy

**BRB — my agent's got this.** 🐾

BRBuddy is a free, open-source Mac menu bar app for when you step away while an AI coding agent works. It keeps your
Mac awake, covers the screen with a cute companion (and, if you want, a read-only view of your terminal), and asks
for Touch ID or your password when someone touches the keyboard.

Website: **[brbuddy.app](https://brbuddy.app)** · Companion gallery: **[brbuddy.app/gallery](https://brbuddy.app/gallery/)**

> **Status: early (v0.1).** Keep-awake, BRB (Away mode), agent status, companions, the terminal mirror and the
> walk-away lock work. See [ROADMAP.md](ROADMAP.md).

## Using it
- Open **Settings…** and press **Set up** for the agents you use (Claude Code, Codex, Gemini CLI, Cursor,
  Antigravity, Grok). BRBuddy then keeps your Mac awake by itself while an agent works or needs you, and shows
  what it's doing in the menu and on the away screen. Or click the 🐾 and turn on **Keep Mac awake** yourself.
- Walk away. After 3 minutes with no keyboard or mouse, BRB covers the screen. Or start it yourself with
  **BRB now** or **⌃⌥⌘B**.
- Come back, press any key, and unlock with Touch ID or your password.
- Three wrong tries, or an hour away, and BRBuddy hands off to the real macOS lock screen. Your agent keeps running.
- BRB is an **away screen, not a lock**: it keeps passers-by off your keyboard and screen, but anything running as
  you (including your agent) can close it, and a restart ends it. When you need real security, lock the Mac (or let
  BRBuddy hand off to the macOS lock screen).
- Pick a companion in **Settings…**: six original critters (one per agent's vibe), or add any Codex pet with
  **Add companion pack…** (or make your own with any AI: [docs/making-a-companion.md](docs/making-a-companion.md)). Download
  ones other people made, and share yours, in the [companion gallery](https://brbuddy.app/gallery/).
  Change everything else there too.
- Want to see your agent from across the room? Turn on **Terminal on the away screen**: a read-only view of the
  tmux pane or Terminal window your agent runs in, or a feed of what it's doing. Off by default, since anyone at
  your Mac can read it.
- **Walk-away lock:** in Settings, choose your iPhone or Apple Watch. When it leaves (near the desk, the room, or
  further), BRBuddy starts BRB or locks the Mac. Bluetooth signal is rough, so try it a few times and adjust.

BRBuddy is an independent project. It isn't affiliated with or endorsed by Anthropic, OpenAI, Anysphere, Google or
xAI, and it never uses their logos or mascots.

## Install
Download the latest `BRBuddy-<version>.dmg` from [Releases](https://github.com/dhaataalimited-hub/brbuddy/releases),
open it and drag BRBuddy to Applications. Or with Homebrew:

```bash
brew install dhaataalimited-hub/tap/brbuddy
```

Releases are signed and notarized by Apple and update themselves (menu → **Check for Updates…**).

## Build and run
Needs macOS 14 or later and Xcode 16 or later (Swift 6).

```bash
Tools/build-app.sh
```

```bash
open build/BRBuddy.app
```

Run the tests:

```bash
swift test
```

You can also open `Package.swift` in Xcode.

## Built on
BRBuddy borrows ideas and code from these open-source projects, with thanks. Licenses for any code we copy are kept
in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

| Project | What we use | License |
|---|---|---|
| [KeepingYouAwake](https://github.com/newmarcel/KeepingYouAwake) | Keep-awake approach | MIT |
| [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) | Global BRB shortcut (dependency) | MIT |
| [Sparkle](https://github.com/sparkle-project/Sparkle) | Automatic updates (dependency) | MIT-style |
| [exelban/stats](https://github.com/exelban/stats) | Reference for the release workflow | MIT |
| [AgentPet](https://github.com/ntd4996/agentpet) | Agent hook formats, event meanings, Codex config (adapted) | MIT (code only) |
| [codelight](https://github.com/henrikekblad/codelight) | Reference for agent hook capabilities | MIT |
| [Hammerspoon](https://github.com/hammerspoon/hammerspoon) | Real lock screen call; idle detection approach | MIT |
| [LUCE](https://github.com/arinltte/LUCE) | Input blocking while away (planned) | MIT |
| The Codex pet format, as documented by [awesome-codex-pet](https://github.com/legeling/awesome-codex-pet) | Companion pack format (format only; no art) | MIT (docs/code) |

## Support
Bugs and feature ideas: [GitHub Issues](https://github.com/dhaataalimited-hub/brbuddy/issues). Anything else:
[hello@dhaataa.com](mailto:hello@dhaataa.com). Security problems: see [SECURITY.md](SECURITY.md).

## Contributing
Contributions and companion packs are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md).

## License
Code: [MIT](LICENSE). The name "BRBuddy" and the app icon aren't covered by the licence: forks are welcome,
but please ship yours under its own name and icon. See [TRADEMARKS.md](TRADEMARKS.md).

**Using BRBuddy at work?** Go for it: the MIT licence covers companies too, free. If your team relies on it, we'd
love to hear from you at hello@dhaataa.com, whether that's feedback, a feature your team needs, or support for
keeping it going.
