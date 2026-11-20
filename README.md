# BRBuddy

**BRB — my agent's got this.** 🐾

BRBuddy is a free, open-source Mac menu bar app for when you step away while an AI coding agent works. It keeps your
Mac awake, covers the screen with a cute companion (and, if you want, a read-only view of your terminal), and asks
for Touch ID or your password when someone touches the keyboard.

> **Status: early skeleton.** Today it only keeps your Mac awake from the menu bar. See [ROADMAP.md](ROADMAP.md).

## Planned
- **BRB (Away mode):** a full-screen away display on every screen, unlocked with Touch ID or your password. Starts on
  its own after a few minutes with no real keyboard or mouse input. Hands off to the real macOS lock screen after
  failed attempts or a long time away. Your agent keeps running.
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
| [AgentPet](https://github.com/ntd4996/agentpet) | Agent hooks and detection (planned) | MIT (code only) |
| [codelight](https://github.com/henrikekblad/codelight) | Grok and cursor-agent hooks (planned) | MIT |
| [Hammerspoon](https://github.com/hammerspoon/hammerspoon) | Idle detection, real lock screen (planned) | MIT |
| [LUCE](https://github.com/arinltte/LUCE) | Input blocking while away (planned) | MIT |
| [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) | Terminal rendering (planned) | MIT |
| [OpenPetsKit](https://github.com/alterhq/OpenPetsKit) and the Codex pet format | Companion packs (planned) | MIT |

## Contributing
Contributions and companion packs are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md).

## License
[MIT](LICENSE)
