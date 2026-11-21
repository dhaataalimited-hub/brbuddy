# Making a companion with any AI

Paste the prompt below into any AI with your character idea filled in, and it builds a companion pack BRBuddy can
load: a folder with `pet.json` and two spritesheets.

## How to use it

1. Copy the prompt in the next section.
2. Replace the three lines under **MY CHARACTER** with your own: what it is, its colours and personality, and the
   one thing it says when booped.
3. Paste it into an AI that can run code and make files (Claude, ChatGPT with code, Gemini). Image-only tools
   can't hit the exact pixel grid, so the prompt asks the AI to draw the character in code.
4. Download the folder it gives you, then in BRBuddy open **Settings → Companion → Add companion pack…** and pick
   the folder.
5. Choose it in the Companion picker and click the preview to boop it.

Use only art you made or are allowed to use. Packs you share must follow [CONTRIBUTING.md](../CONTRIBUTING.md): no
company logos, mascots or other people's characters.

## The prompt

Copy everything in the box. Only the MY CHARACTER lines need changing.

```text
You are making a companion character pack for BRBuddy, a macOS app that shows an animated companion on its away screen. Build the pack exactly to the spec below.

MY CHARACTER
- What it is: [e.g. a sleepy toaster with stubby legs]
- Look and personality: [colours, shape, mood, e.g. chrome body, rosy cheeks, cheerful but dozy]
- Its signature boop line and sound: [e.g. "pop!" and the plink sound]

HOW TO MAKE IT
Draw the character in code, not with an image generator, so every frame lands exactly on the grid. Write one script (Python with Pillow, or Swift/SwiftUI on a Mac, or HTML canvas) with a function draw(mood, phase, still) that draws one 192 x 208 px frame. Run it to produce the files, check the sizes, and give me the folder, the script and a preview image showing one frame of each mood on a dark background.

STYLE
- A cute character with a big, expressive face like a cartoon animal: two eyes, a mouth, optional blush cheeks. It must read clearly at about 170 px tall on a dark purple background (#17121F).
- If it is an object (a gadget, a plant, food), put the face on its most face-like part (a screen, the front) and give it stubby arms and legs.
- Original art only: no company logos, mascots or existing characters.
- Transparent background everywhere outside the character.

THE SPRITESHEET (spritesheet.png)
- A PNG atlas of 8 columns x 9 rows of 192 x 208 px cells: 1536 x 1872 px in total. Row 0 is the top row.
- Each row is one animation of 8 frames that loops at 8 frames a second. Frame i is at phase i/8 of the loop, so frame 7 flows back into frame 0.
- Rows and what the face and body do:
  0 idle (resting): eyes closed as lines, tiny mouth, slow gentle breathing (scale height by about 1.5%), a fading "z z z" in the top-left.
  1 running right: BRBuddy doesn't use it; copy row 7.
  2 running left: copy row 7.
  3 waving (greeting): open eyes, smile, one arm waving, a slight sway, a "hi!" bubble top-left.
  4 jumping (finished): happy closed eyes (upside-down U), big smile, hops about 24 px up and lands, small stars circling.
  5 failed (oops): X eyes, wavy mouth, a quick side-to-side shake, an orange "?!" bubble top-left.
  6 waiting (needs you): wide open eyes, small O mouth, bouncing, an orange "!" bubble top-left.
  7 running (working): focused eyes that glance left and right, small flat mouth, a little trot, a "..." bubble top-left that grows from 1 to 3 dots.
  8 review: copy row 0.
- Placement: the character is about 110 to 150 px tall, centred slightly right, feet near y = 196. Leave about 24 px of headroom so jumps stay inside the cell.
- Keep the top-right corner of every cell (x above 130, y below 50) empty. BRBuddy draws its own speech bubbles there.
- Nothing may cross a cell's edge.

THE STILL SHEET (spritesheet-still.png)
- Same size and rows as spritesheet.png, used when the Mac is on battery: the body holds completely still (no hop, sway, shake, breathing or arm waving) and only the face moves.
- In the still sheet, open eyes glance slowly left and right across the 8 frames and blink on frame 5; the idle mouth gently widens and narrows. Speech bubbles and small effects (stars, dots) may still animate.

pet.json
Write this file next to the two sheets, filling in the values:
{
  "id": "[folder-name-in-lowercase-with-dashes]",
  "displayName": "[Character Name]",
  "description": "[one line about it]",
  "spriteVersionNumber": 1,
  "spritesheetPath": "spritesheet.png",
  "stillSpritesheetPath": "spritesheet-still.png",
  "boopSignature": "[one name from the list below]",
  "boopBubble": "[its signature line, 24 characters at most]",
  "license": "[e.g. CC-BY-4.0, or Personal use only]",
  "author": "[your name]"
}
boopSignature must be exactly one of: sparkle, fwoosh, plink, shimmer, zoom, breeze, cackle, chord, clickWheel, glassTap, bleeps, marimba, whirr, clack, fanfare, blueBox. Pick the one that best fits the character.

CHECKS BEFORE YOU HAND IT OVER
- Both PNGs are exactly 1536 x 1872 px, have transparent backgrounds and are under 20 MB.
- Every row has 8 frames and loops smoothly from frame 7 back to frame 0.
- The top-right corner of every cell is empty and nothing is cut off at a cell edge.
- The still sheet's body is pixel-for-pixel in the same place in every frame of a row; only the face changes.
- pet.json is valid JSON and its paths match the file names.
- Give me a folder named after the id containing pet.json, spritesheet.png, spritesheet-still.png and the script.
```

## Signature sounds

Every companion shares five boops (squish, giggle, spin, love, grumpy) and gets one of its own, set by
`boopSignature`. All sounds are made in code (`BoopSound`).

| boopSignature | Sounds like | Suits |
| --- | --- | --- |
| sparkle | Rising bell arpeggio (the default) | Anything magical |
| fwoosh | Whoosh of air with a low rumble | Fire, speed, dragons |
| plink | Two bright drops | Stones, water, small things |
| shimmer | Fast crystal arpeggio | Gems, ice, fairies |
| zoom | Falling whistle, like something flying past | Rockets, comets, cars |
| breeze | Soft wavering wind | Clouds, ghosts, leaves |
| cackle | Quick buzzy "heh heh" | Gremlins, villains, pranksters |
| chord | Big warm major chord | Computers, robots, royalty |
| clickWheel | Seven tiny ticks | Music players, clocks, dials |
| glassTap | Two glassy taps | Tablets, phones, windows |
| bleeps | Six 8-bit bleeps | Retro computers, robots, games |
| marimba | Short marimba tune | Phones, tropical things |
| whirr | Servo whirr up and back | Machines, lamps, robots |
| clack | A clack and a bloop | Laptops, boxes, doors |
| fanfare | "Ta-da" and a chord | Showmen, heroes, trophies |
| blueBox | A 2600 Hz tone and two blips | Phones, hackers, tinkerers |

## If it doesn't load

- **"The spritesheet is 1024×1024…"**: the sheet isn't 1536 × 1872. Ask the AI to fix the size, not to resize the
  art.
- **It loads but stands still on battery**: `stillSpritesheetPath` is missing or the still sheet's size differs from
  the main sheet's.
- **The signature boop plays a sparkle**: `boopSignature` isn't one of the names above (check the spelling and
  capitals).
- **Parts are cut off or overlap BRBuddy's bubbles**: the character crosses a cell edge or the top-right corner.
  Ask the AI to shrink it or move it down and left.
- Packs live in `~/Library/Application Support/BRBuddy/Companions/`. **Show companions folder** in Settings opens it.
