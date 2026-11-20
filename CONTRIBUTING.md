# Contributing to BRBuddy

Thanks for helping. Issues, fixes and companion packs are all welcome.

## Code
- Build with `Tools/build-app.sh`, test with `swift test`. Tests must pass before a pull request is merged.
- Read `docs/architecture/README.md` first: it says where things live. If you add, move or rename a source file,
  add it to the map's file index (the docs test fails otherwise).
- Copying code from another project? Only from permissive licenses, and add its notice to `THIRD_PARTY_NOTICES.md`.

## Companion packs
Packs use the Codex pet format, so they work in other pet apps too: a folder with `pet.json` and an 8-column
spritesheet of 192×208 cells, 1536×1872 (v1, 9 rows) or 1536×2288 (v2, 11 rows, `"spriteVersionNumber": 2`). Rows:
0 idle, 1 running-right, 2 running-left, 3 waving, 4 jumping, 5 failed, 6 waiting, 7 running, 8 review (v2 adds
look directions in rows 9–10). BRBuddy plays idle, waving, jumping, failed, waiting and running. Add these optional
fields to `pet.json`:

```json
{
  "displayName": "Biscuit",
  "spritesheetPath": "spritesheet.webp",
  "license": "CC-BY-4.0",
  "author": "Your Name",
  "agents": ["claude", "codex"]
}
```

`agents` makes "Match my agent" pick your pack for those agents (`claude`, `codex`, `gemini`, `cursor`,
`antigravity`, `grok`). Packs submitted to this repo must:
- be **original art**, or art you have the right to share (CC0 or CC-BY with credit is fine);
- say its license in `pet.json`;
- **not** use any company's logo, mascot or trademark (no Claude crab, no OpenAI knot, no Gemini sparkle, and so on).
  Packs can nod to an agent's vibe with colour and personality, never its branding.
