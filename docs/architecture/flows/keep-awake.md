# Keep awake

## What the user does
Clicks the paw in the menu bar and ticks "Keep Mac awake". The paw fills in. Unticking it (or quitting BRBuddy) lets
the Mac sleep normally again.

## Types involved, in order
`MenuContent` → `AppState` → `KeepAwake` → IOKit power assertion.

```mermaid
sequenceDiagram
  participant V as MenuContent
  participant M as AppState
  participant S as KeepAwake
  V->>M: toggle changed
  M->>S: activate system-only, or release (main actor)
  S-->>M: whether macOS accepted the assertion
  M-->>V: isKeepingAwake updates the toggle and paw icon
```

## States and edge cases
- Which mode `AppState` holds: while BRB is up, "system and display". Otherwise, with keep-awake on and BRB
  auto-start enabled, also "system and display", so macOS's screen saver or display sleep can't beat BRB to it.
  With auto-start off, "system only": the Mac stays awake but the screen may turn off.
- When BRB ends (unlocked or handed off to the real lock), `AppState` re-applies the mode above.
- If macOS refuses the assertion, `AppState` leaves keep-awake off, so the toggle falls back to unticked.
- Quitting or crashing releases the assertion (macOS drops a process's assertions when it exits).
- Lid closed on battery: macOS still sleeps. Not handled yet.

## Gotchas
- Switching mode releases the old assertion before creating the new one, so there's never more than one.

## Code to check
Function names change: read the current code in these files before relying on any detail above.
- `MenuContent.swift`, `AppState.swift`, `KeepAwake.swift`
- Types: `MenuContent`, `AppState`, `KeepAwake`, `AwaySettings`
- Tests: `KeepAwakeTests`
