"""Looks after the companion gallery on brbuddy.app (site/gallery/).

  python3 Tools/gallery/gallery.py add <pack folder> --creator "Name" [--made studio|ai|hand]
                                       [--license CC-BY-4.0] [--link https://...] [--submission <issue number>]
      Checks the pack against the spec in docs/making-a-companion.md, then copies it into
      site/gallery/packs/<id>/ as a preview sheet and a ready-to-add zip, and lists it in site/gallery/packs.json.
      Run it only after reviewing the submission by eye (original art, no logos, no other people's characters).

  python3 Tools/gallery/gallery.py remove <id>
      Takes a pack down (for a takedown request or at the creator's request).

  python3 Tools/gallery/gallery.py prompt
      Copies the AI prompt from docs/making-a-companion.md to site/gallery/prompt.txt, which the gallery page shows.

No third-party Python modules; the preview sheet is made with cwebp (brew install webp).
"""
import argparse
import datetime
import json
import re
import shutil
import struct
import subprocess
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GUIDE = ROOT / "docs/making-a-companion.md"
GALLERY = ROOT / "site/gallery"
INDEX = GALLERY / "packs.json"
SHEET_ROWS = {(1536, 1872): 9, (1536, 2288): 11}   # v1 and v2 Codex sheets
PREVIEW_WIDTH = 1152            # 3/4 size: 144 x 156 px cells on the page
MAX_SHEET_BYTES = 20 * 1024 * 1024
LICENSES = {"CC-BY-4.0", "CC0-1.0"}
MADE = {"studio": "Companion Studio", "ai": "Made with AI", "hand": "Hand drawn"}


def fail(message):
    sys.exit(f"gallery: {message}")


def signatures():
    text = GUIDE.read_text()
    match = re.search(r"boopSignature must be exactly one of: ([^.]+)\.", text)
    if not match:
        fail("couldn't find the boopSignature list in docs/making-a-companion.md")
    return {name.strip() for name in match.group(1).split(",")}


def png_size(path):
    with open(path, "rb") as f:
        head = f.read(24)
    if head[:8] != b"\x89PNG\r\n\x1a\n" or head[12:16] != b"IHDR":
        fail(f"{path.name} isn't a PNG")
    return struct.unpack(">II", head[16:24])


def check(folder):
    """Returns pet.json as a dict if the pack meets the spec; stops with the first problem otherwise."""
    manifest_path = folder / "pet.json"
    if not manifest_path.is_file():
        fail(f"no pet.json in {folder}")
    try:
        pet = json.loads(manifest_path.read_text())
    except json.JSONDecodeError as error:
        fail(f"pet.json isn't valid JSON: {error}")
    for key in ("id", "displayName", "spritesheetPath", "stillSpritesheetPath", "boopSignature", "boopBubble"):
        if not isinstance(pet.get(key), str) or not pet[key].strip():
            fail(f"pet.json needs {key}")
    if not re.fullmatch(r"[a-z0-9]+(-[a-z0-9]+)*", pet["id"]):
        fail(f"id {pet['id']!r} must be lowercase letters, digits and dashes")
    if pet["boopSignature"] not in signatures():
        fail(f"boopSignature {pet['boopSignature']!r} isn't one of BRBuddy's signature sounds")
    if len(pet["boopBubble"]) > 24:
        fail("boopBubble is longer than 24 characters")
    for key in ("spritesheetPath", "stillSpritesheetPath"):
        sheet = (folder / pet[key]).resolve()
        if folder.resolve() not in sheet.parents or not sheet.is_file():
            fail(f"{key} {pet[key]!r} isn't a file in the pack")
        if png_size(sheet) not in SHEET_ROWS:
            fail(f"{sheet.name} is {png_size(sheet)}, not 1536 x 1872 (or 1536 x 2288 for a v2 sheet)")
        if sheet.stat().st_size > MAX_SHEET_BYTES:
            fail(f"{sheet.name} is over 20 MB")
    if png_size(folder / pet["spritesheetPath"]) != png_size(folder / pet["stillSpritesheetPath"]):
        fail("the still sheet isn't the same size as the main sheet")
    return pet


def load_index():
    return json.loads(INDEX.read_text()) if INDEX.exists() else []


def save_index(packs):
    INDEX.write_text(json.dumps(packs, indent=2, ensure_ascii=False) + "\n")


def add(args):
    folder = Path(args.folder).expanduser()
    pet = check(folder)
    pack_id = pet["id"]
    packs = [p for p in load_index() if p["id"] != pack_id]
    out = GALLERY / "packs" / pack_id
    if out.exists():
        shutil.rmtree(out)
    out.mkdir(parents=True)

    # What people download: the pack folder, named after its id, with the credit and licence written in.
    pet["author"] = args.creator
    pet["license"] = args.license
    files = {"spritesheet.png": folder / pet["spritesheetPath"],
             "spritesheet-still.png": folder / pet["stillSpritesheetPath"]}
    pet["spritesheetPath"], pet["stillSpritesheetPath"] = "spritesheet.png", "spritesheet-still.png"
    design = pet.get("studioDesign")
    if design and (folder / design).is_file():
        files["design.json"] = folder / design
        pet["studioDesign"] = "design.json"
    else:
        pet.pop("studioDesign", None)
    with zipfile.ZipFile(out / f"{pack_id}.zip", "w", zipfile.ZIP_DEFLATED) as z:
        z.writestr(f"{pack_id}/pet.json", json.dumps(pet, indent=2, sort_keys=True, ensure_ascii=False) + "\n")
        for name, source in files.items():
            z.write(source, f"{pack_id}/{name}")

    if not shutil.which("cwebp"):
        fail("needs cwebp for the preview sheet: brew install webp")
    subprocess.run(["cwebp", "-quiet", "-q", "88", "-alpha_q", "100", "-resize", str(PREVIEW_WIDTH), "0",
                    str(files["spritesheet.png"]), "-o", str(out / "preview.webp")], check=True)

    entry = {
        "id": pack_id,
        "name": pet["displayName"],
        "description": (pet.get("description") or "").strip(),
        "creator": args.creator,
        "made": MADE[args.made],
        "boop": pet["boopBubble"],
        "license": args.license,
        "rows": SHEET_ROWS[png_size(files["spritesheet.png"])],
        "added": datetime.date.today().isoformat(),
    }
    if args.link:
        entry["link"] = args.link
    if args.submission:
        entry["submission"] = args.submission
    packs.insert(0, entry)
    save_index(packs)
    print(f"added {pet['displayName']} ({pack_id}) to the gallery: {out.relative_to(ROOT)}")


def remove(args):
    packs = load_index()
    if not any(p["id"] == args.id for p in packs):
        fail(f"no pack {args.id!r} in the gallery")
    save_index([p for p in packs if p["id"] != args.id])
    shutil.rmtree(GALLERY / "packs" / args.id, ignore_errors=True)
    print(f"removed {args.id}")


def prompt(_args):
    text = GUIDE.read_text()
    match = re.search(r"## The prompt\n.*?```text\n(.*?)```", text, re.S)
    if not match:
        fail("couldn't find the prompt block in docs/making-a-companion.md")
    (GALLERY / "prompt.txt").write_text(match.group(1))
    print("wrote site/gallery/prompt.txt")


parser = argparse.ArgumentParser(description="Look after the companion gallery on brbuddy.app.")
commands = parser.add_subparsers(required=True)
p = commands.add_parser("add", help="add or replace a reviewed pack")
p.add_argument("folder")
p.add_argument("--creator", required=True, help="the name to credit, as the creator asked")
p.add_argument("--made", choices=sorted(MADE), default="studio")
p.add_argument("--license", choices=sorted(LICENSES), default="CC-BY-4.0")
p.add_argument("--link", help="the creator's own page, if they gave one")
p.add_argument("--submission", type=int, help="the GitHub issue it was submitted in")
p.set_defaults(run=add)
p = commands.add_parser("remove", help="take a pack down")
p.add_argument("id")
p.set_defaults(run=remove)
p = commands.add_parser("prompt", help="refresh the prompt the page shows")
p.set_defaults(run=prompt)
args = parser.parse_args()
args.run(args)
