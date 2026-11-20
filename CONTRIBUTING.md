# Contributing to BRBuddy

Thanks for helping. Issues, fixes and companion packs are all welcome.

## Code
- Build with `Tools/build-app.sh`, test with `swift test`. Tests must pass before a pull request is merged.
- Read `docs/architecture/README.md` first: it says where things live. If you add, move or rename a source file,
  add it to the map's file index (the docs test fails otherwise).
- Copying code from another project? Only from permissive licenses, and add its notice to `THIRD_PARTY_NOTICES.md`.

## Companion packs
The pack format is still being designed. It will build on the Codex pet format (`pet.json` plus a spritesheet) so
packs work in other pet apps too. Every pack must:
- be **original art**, or art you have the right to share (CC0 or CC-BY with credit is fine);
- say its license in `pet.json`;
- **not** use any company's logo, mascot or trademark (no Claude crab, no OpenAI knot, no Gemini sparkle, and so on).
  Packs can nod to an agent's vibe with colour and personality, never its branding.
