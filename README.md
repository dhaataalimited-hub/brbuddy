# BRBuddy

**BRB — my agent's got this.** 🐾

BRBuddy is a free, open-source Mac menu bar app for when you step away while an AI coding agent works. It keeps your
Mac awake, covers the screen with a cute companion (and, if you want, a read-only view of your terminal), and asks
for Touch ID or your password when someone touches the keyboard.

> **Status: early.** Keep-awake and BRB (Away mode) work. Agent detection, companion packs and the terminal mirror
> are next. See [ROADMAP.md](ROADMAP.md).

## Using it
- Click the 🐾 in the menu bar and turn on **Keep Mac awake** while your agent works.
- Walk away. After 3 minutes with no keyboard or mouse, BRB covers the screen. Or start it yourself with
  **BRB now** or **⌃⌥⌘B**.
- Come back, press any key, and unlock with Touch ID or your password.
- Three wrong tries, or an hour away, and BRBuddy hands off to the real macOS lock screen. Your agent keeps running.
- Change all of this in **Settings…**.

## Planned
- **Knows your agent:** detects Claude Code, Codex, Cursor, Gemini / Antigravity and Grok, and shows whether it's
  working, waiting for you or finished.
- **Companions:** original animated characters, one per agent's "vibe", plus community packs anyone can make.
- **Terminal mirror:** a live, read-only view of the terminal your agent runs in.
- **Walk-away lock:** starts BRB when your phone or Apple Watch leaves the room.

BRBuddy is an independent project. It isn't affiliated with or endorsed by Anthropic, OpenAI, Anysphere, Google or
xAI, and it never uses their logos or mascots.

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
| [AgentPet](https://github.com/ntd4996/agentpet) | Agent hooks and detection (planned) | MIT (code only) |
| [codelight](https://github.com/henrikekblad/codelight) | Grok and cursor-agent hooks (planned) | MIT |
| [Hammerspoon](https://github.com/hammerspoon/hammerspoon) | Real lock screen call; idle detection approach | MIT |
| [LUCE](https://github.com/arinltte/LUCE) | Input blocking while away (planned) | MIT |
| [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) | Terminal rendering (planned) | MIT |
| [OpenPetsKit](https://github.com/alterhq/OpenPetsKit) and the Codex pet format | Companion packs (planned) | MIT |

## Contributing
Contributions and companion packs are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md).

## License
[MIT](LICENSE)
