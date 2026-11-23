# Contributing to BRBuddy

Thanks for helping. Issues, fixes and companion packs are all welcome.

BRBuddy is a side project kept up by one person, so a few expectations:
- **Small fixes** (bugs, typos, docs) are welcome as pull requests straight away.
- **Bigger changes or new features:** open an issue first so we can agree on the idea before you spend time on it.
  Not everything will fit, and a "no thanks" isn't a judgement on your work.
- Replies can take a while. There's no guaranteed support or timeline.
- **Security problems:** report them privately, never in a public issue. See [SECURITY.md](SECURITY.md).
- Forking to make your own version is fine too; please give it its own name and icon ([TRADEMARKS.md](TRADEMARKS.md)).

## Code
- Build with `Tools/build-app.sh`, test with `swift test`. Tests must pass before a pull request is merged.
- Read `docs/architecture/README.md` first: it says where things live. If you add, move or rename a source file,
  add it to the map's file index (the docs test fails otherwise).
- Copying code from another project? Only from permissive licenses, and add its notice to `THIRD_PARTY_NOTICES.md`.

## Companion packs
The quickest way to make one is [docs/making-a-companion.md](docs/making-a-companion.md): a prompt you paste into
any AI that builds the whole pack. To share one, use the **Share a companion** form (it's on
[brbuddy.app/gallery](https://brbuddy.app/gallery/#share)); reviewed packs go up in the gallery, added with
`Tools/gallery/gallery.py`. The details:

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
  "agents": ["claude", "codex"],
  "stillSpritesheetPath": "spritesheet-still.png",
  "boopSignature": "plink",
  "boopBubble": "hi there!"
}
```

`stillSpritesheetPath` is a second sheet of the same size where the body holds still and only the face moves; it's
shown on battery. `boopSignature` picks the pack's own boop sound (names listed in the guide) and `boopBubble` what
it says then.

`agents` makes "Match my agent" pick your pack for those agents (`claude`, `codex`, `gemini`, `cursor`,
`antigravity`, `grok`). Packs submitted to this repo must:
- be **original art**, or art you have the right to share (CC0 or CC-BY with credit is fine);
- say its license in `pet.json`;
- **not** use any company's logo, mascot or trademark (no Claude crab, no OpenAI knot, no Gemini sparkle, and so on).
  Packs can nod to an agent's vibe with colour and personality, never its branding.
