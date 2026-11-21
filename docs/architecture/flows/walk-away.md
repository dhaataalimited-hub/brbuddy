# Walk-away lock

## What the user does
In Settings → Walk-away they press **Choose device…**. BRBuddy lists nearby iPhones and Apple Watches,
strongest signal first, with dBm and bars. Apple devices advertise anonymously, so to find theirs they hold it next to
the Mac: it rises to the top and is marked **Closest** (8 dB ahead of the next). They press **Use** next to it, which also turns the feature on. They
choose what "away" means (Near: walk away from the desk; Room; Far) and what happens (Start BRB, or Lock the Mac).
The status line and the menu say whether the device is nearby, away, or being looked for. When they walk off with
their phone, BRB covers the screen (or the Mac locks) after about 10 seconds.

## Types involved, in order
Picking: `SettingsView` (walk-away section) → `ProximityMonitor` (scans, lists `Device`s) → `ProximitySettings`.
Watching: `ProximityMonitor` (connects, reads RSSI every 2 s, plus advertisement readings) → `ProximityTracker`
(near / away) → `AppState` (start BRB via `AwayController`, or `ScreenLocker`).

```mermaid
sequenceDiagram
  participant S as SettingsView
  participant P as ProximityMonitor
  participant T as ProximityTracker
  participant A as AppState
  S->>P: picker open: scan for Apple devices
  S->>P: use this device (saves ProximitySettings)
  P->>P: connect; read RSSI every 2 s
  P->>T: each reading (and a tick every second)
  T-->>P: near / away when it changes
  P->>A: device left
  A->>A: start BRB, or lock the Mac
```

## States and edge cases
- Bluetooth is only touched while walk-away is on or the picker is open, so there's no permission prompt until the
  user opts in. Statuses: Bluetooth off, not allowed, unsupported, pick a device, looking for…, listening…, nearby
  (with the median signal), away.
- Picker: devices whose advertisement has Apple's company ID (0x004C) and signal above -90 dBm; unnamed ones show
  as "Apple device XXXX"; entries not heard for 15 s drop off.
- `ProximityTracker`: median of the last 8 s of readings; thresholds -62 (near), -74 (room), -86 (far) dBm; away
  after 10 s below threshold or 60 s with no reading; back only at threshold + 6 dB. Never "away" for a device not
  heard since monitoring started. Readings of 127 or ≥ 0 are ignored.
- On disconnect it reconnects (and scans) automatically; a connected device is read even when it stops advertising.
- Away fires once per departure; coming back does nothing (unlocking BRB still needs Touch ID or the password).
- "Lock the Mac" does nothing if BRB is already up.
- Running without an app bundle (`swift run`) disables the feature: macOS would kill the app on Bluetooth use with no
  usage description.

## Gotchas
- RSSI varies a lot with bodies, pockets and walls; thresholds are starting points from BLEUnlock-style apps, not
  measured on the owner's devices yet. Expect to tune them.
- CoreBluetooth's device identifier for an iPhone is stable on the Mac that saw it, but can change after unpairing
  or a macOS reinstall; the user then picks the device again.
- Not live-tested on 2026-11-20 (needs the owner to allow Bluetooth and walk around). Logic covered by
  `ProximityTrackerTests`; the app launches without touching Bluetooth.

## Identifying devices in the picker
- Only advertisements whose Apple Continuity messages include Nearby Info, Handoff or Nearby Action (0x10, 0x0C,
  0x0F) are listed; AirPods (0x07), AirTags/Find My (0x12) and AirPlay (0x09) are skipped (`AppleDeviceInfo`).
- Up to three devices at a time are connected for at most 6 s to read the Device Information model number
  (0x180A/0x2A24): iPhone or Watch rows get the right name and icon; Macs and iPads are hidden. Devices that won't
  answer stay as "Apple device · 1A2B". If a device shares its name after connecting, that's shown instead.
- Signal is smoothed (70/30) so rows don't jump about; rows not heard for 15 s drop off; six rows at most.

## Code to check
Function names change: read the current code in these files before relying on any detail above.
- `ProximityMonitor.swift`, `SettingsView.swift`, `AppState.swift`, `MenuContent.swift`, `ProximityTracker.swift`,
  `AppleDeviceInfo.swift`
- Types: `ProximityMonitor`, `ProximityTracker`, `ProximitySettings`, `AppleDeviceInfo`, `AppState`, `ScreenLocker`
- Tests: `ProximityTrackerTests`, `AppleDeviceInfoTests`
