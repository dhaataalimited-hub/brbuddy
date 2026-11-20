# BRB (Away mode)

## What the user does
Walks away from the Mac while an agent works. BRB starts one of four ways: "BRB now" in the menu, the global
shortcut (default ⌃⌥⌘B), by itself after the set idle minutes while keep-awake is on, or when their phone or watch
walks away (see `flows/walk-away.md`). Every display shows the
companion, "BRB — my agent's got this." and how long they've been away. When they come back and press a key or move
the mouse, the main display shows Touch ID and a password field. A good fingerprint or password takes BRB down.
Too many failed tries, or being away too long, shows a message and switches to the real macOS lock screen.

## Types involved, in order
Start: `MenuContent` / KeyboardShortcuts / `AppState`'s idle check (`IdleMonitor` + `AwayPolicy`) → `AppState` →
`AwayController` → `AwayWindow` per display hosting `AwayView` (`CompanionView`) → `KeepAwake` switches to
system-and-display.
Unlock: `AwayWindow` reports input → `AwayController` (phase unlocking, new `LAContext`) → `UnlockPanel` (embedded
LocalAuthentication view; `PasswordVerifier` on a detached task) → `AwayController` ends BRB → `AppState` resets
keep-awake mode.
Escalate: `AwayController` asks `AwayPolicy` each second and after each failure → `ScreenLocker` → BRB ends behind
the lock screen.

```mermaid
sequenceDiagram
  participant S as AppState
  participant A as AwayController
  participant W as AwayWindow
  participant U as UnlockPanel
  participant P as AwayPolicy
  S->>A: start with current AwaySettings
  A->>W: one window per screen, presentation options locked down
  W-->>A: key, click or mouse move
  A-->>U: phase unlocking, fresh LAContext
  U->>A: Touch ID result or password check result
  A->>P: failures and time away
  P-->>A: none / too many tries / away too long
  A->>A: success ends BRB; escalation locks for real, then ends BRB
  A-->>S: ended (escalated or not)
```

## States and edge cases
- Auto-start only while the Mac is kept awake (by hand, or because an agent is working or waiting) and auto-start
  is enabled. Idle is checked every 5 seconds against `IdleMonitor`.
- While keep-awake is on with auto-start enabled, `AppState` holds the display awake too, so macOS's screen saver or
  display sleep can't kick in before BRB.
- Locked down while up: Dock and menu bar hidden; app switching, Force Quit, log out/restart and hiding disabled;
  every Command shortcut swallowed by `AwayWindow`; `AppDelegate` cancels quitting. If another app activates (an
  agent opening a browser), `AwayController` takes focus back.
- The away screen shows `AgentMonitor`'s headline under the tagline ("Claude Code is working on brbuddy", orange
  "… needs you in …" when waiting); the companion's mood follows `CompanionMood` (see `flows/companions.md`). With the terminal mirror on, the
companion shrinks and `TerminalMirrorView` sits below the text (see `flows/terminal-mirror.md`).
- Displays plugged in or out: windows are rebuilt. Unlock UI is only on the first screen; others say "Unlock on your
  main display".
- Unlock prompt goes back to the resting companion after 30 seconds without input.
- Touch ID failures that return "authentication failed" and wrong passwords both count as failed tries. Cancelled
  Touch ID doesn't count.
- Escalation: shows the reason for 2 seconds, locks for real, waits 1.5 seconds, then removes the away screen so the
  user lands on their desktop after unlocking macOS. Keep-awake drops back to its normal mode.
- Can't be blocked: holding the power button, fast user switching. Stated in Settings.

## Gotchas
- `IdleMonitor` reads HID-level idle time; software posting HID-level events (remote desktop, mouse jigglers) resets
  it. An event-tap check for real input is on the roadmap. A 2026-11-20 test on the owner's Mac was inconclusive
  because input was arriving every second.
- `ScreenLocker` uses a private symbol; the tests check it resolves (it did on macOS 26.6) but never call it.
  Re-check on each new macOS.
- Each wrong password counts toward the account's own failed-login policy, so tests never check a password.
- Embedded Touch ID needs the `LAAuthenticationView` to exist before evaluation starts; `UnlockPanel` starts it on
  the next run-loop turn after making the view.

## Code to check
Function names change: read the current code in these files before relying on any detail above.
- `AwayController.swift`, `AwayWindow.swift`, `AwayView.swift`, `UnlockPanel.swift`, `CompanionView.swift`,
  `AppState.swift`, `AppDelegate.swift`, `AwayPolicy.swift`, `AwaySettings.swift`, `IdleMonitor.swift`,
  `ScreenLocker.swift`, `PasswordVerifier.swift`
- Types: `AwayController`, `AwayWindow`, `AwayView`, `UnlockPanel`, `CompanionView`, `AppState`, `AppDelegate`,
  `AwayPolicy`, `AwaySettings`, `IdleMonitor`, `ScreenLocker`, `PasswordVerifier`
- Tests: `AwayPolicyTests`, `AwaySettingsTests`, `SystemHookTests`
