# BRBuddy

Free, open-source (MIT) macOS menu bar app: keeps the Mac awake while an AI agent works, shows an away screen with a
companion, unlocks with Touch ID. Distributed outside the App Store, not sandboxed. Plan: `ROADMAP.md`.

## Commands
- Build the app: `Tools/build-app.sh` (→ `build/BRBuddy.app`, ad-hoc signed)
- Test: `swift test`
- Release dry run: `SIGN_IDENTITY=- SPARKLE_PUBLIC_KEY=dry-run SKIP_NOTARIZE=1 Tools/release.sh 0.1.0`; real releases: tag `vX.Y.Z` (see `docs/releasing.md`)

## Working rules
- **Where things live:** read `docs/architecture/README.md` first (surfaces, object ownership, file index), then the
  `docs/architecture/flows/` page for the journey you're changing. It names types and files, not functions: read the
  current code before relying on details. When you add, move, rename or rewire a type, update the map and its flow
  page (`ArchitectureDocsTests` fails on stale names and unindexed files), then regenerate
  `docs/architecture/map.html` and republish its artifact (once it exists). Customer-facing answers:
  `docs/support-guide.md` (before first release).
- Logic and system wrappers go in `BRBuddyCore` (testable); SwiftUI and app state in `BRBuddy`.
- Never add company logos, mascots or brand names to the app name or art. The app may *mention* agents by name.
- Copy code only from permissive licenses (MIT, Apache-2.0, BSD, ISC, zlib) and record it in
  `THIRD_PARTY_NOTICES.md`. GPL/AGPL/unlicensed projects are study only.
