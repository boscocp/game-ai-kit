# T89 — Art for the XCOM mode, if the tactical pieces are not enough: open packs, referenced

Size: S · Prereqs: T85 · Files: `godot/game/squad/art_sources.json`, `godot/game/squad/`, `scripts/fetch_squad_art.py`, `scripts/check_no_assets.py`, `python/tests/`, `docs/adr/`, `Makefile`, `.gitignore`

## Goal

The owner, 2026-10-26: "se precisar veja assets open ou free pra demo
x-com" -- **if it needs them**, look for open or free assets for the XCOM
demo. The XCOM mode is a mode of the tactical game (T84), so it already
draws the tactical game's committed Kenney pieces and terrain (ADR 0012).
This task runs only if, after T85's manual check, the owner finds that
look wrong for the mode -- no soldier that reads as a soldier, no cover
that reads as cover. Then it finds open art for a top-down or isometric
squad-tactics look -- soldiers, aliens or enemies, cover pieces (walls,
crates, low cover), floor tiles -- and wires it the way the repository's
art rules say, with the Kenney pieces as the fallback instead of shapes.

**Which rule applies.** Three art records are in force, and they differ:

- ADR 0012 (T9): CC0 pictures from packs, committed byte for byte, listed
  in `godot/assets/LICENCES.md`. That is how the tactical game's Kenney art
  is held today.
- ADR 0015 (T35): crops committed, the sheets referenced by URL and sha256.
- ADR 0020 (T20, the owner's decision of 2026-10-19) and ADR 0018 (3D,
  2026-10-21): **referenced by URL and sha256, never committed, not even
  crops**; a script downloads into an ignored folder and refuses a
  mismatch; without the files, shapes. ADR 0018 left open "whether the
  assets rule reaches back to the 2D art".

The owner's latest rule is ADR 0020's, and this task follows it: nothing of
a pack is committed. That settles ADR 0018's open question for this mode
only; extending it to all 2D art stays the owner's.

## Decisions written down first (the owner confirms in review)

- **ADR 0020's rule, not ADR 0012's**, for this mode (above). A short ADR
  records it and names the mode's manifest, so the next 2D game does not
  have to guess.
- **Prefer downloading open packs over generating** (the owner's standing
  preference); the local generator (T31) is a complement for a missing
  piece, never the first source.
- **Licences**: CC0 or CC-BY (with the attribution the manifest carries for
  the person who downloads) or OFL for a font. GPL art is acceptable only
  under ADR 0020's reasoning -- never a byte in the repository. A pack
  whose terms forbid redistribution is acceptable only if the person
  downloads it themselves from its page; it is listed as such. Invariant 9
  holds: what ships carries LICENSE and NOTICE, and since nothing of a
  pack ships, NOTICE names none of them -- the manifest names each licence.

## Steps

1. **The survey, written into this task's review and the ADR**: for each
   candidate -- Kenney's packs, OpenGameArt.org, itch.io's CC0 and CC-BY
   filters, and any pack the RTS (ADR 0020) or T9 already rejected for a
   reason that does not apply here -- its page URL, its licence as the
   page states it, what it has (soldiers, enemies, cover, tiles, facing
   directions, animation) and its fit to a top-down or isometric squad
   view. Opened, not remembered; a pack whose page cannot be opened is
   listed as such and not used.
2. The owner picks from the survey (or says to fall back to shapes).
3. `godot/game/squad/art_sources.json`: per kind the pack, page, archive
   URL, path inside it, sha256, licence -- the shape of
   `godot/game/rts/art_sources.json`.
4. `make squad-art` downloads into `build/squad-art/` (gitignored), checks
   every sha256 and deletes and reports a mismatch; `--self-test` plants a
   mismatched file and must see it removed (invariant 4); a Python test runs
   the self-test and holds the manifest to every kind the mode draws.
5. The mode reads the files from outside the project, as `RtsArt` does
   (`Image.load_from_file`), so nothing is imported and nothing exported;
   `found` false means the tactical game's Kenney pieces. No test depends
   on the art.
6. **A gate that a picture was not committed.** `check_no_assets.py`'s A2
   reads only `godot/game3d/assets.json` today, and the RTS's sheets are
   held by nothing but `.gitignore` and their GPL. Teach A2 to read every
   `art_sources.json` too (the RTS's and this one), with a planted case: a
   tracked file whose sha256 is in the squad manifest must be refused.

## Acceptance

```bash
python3 scripts/fetch_squad_art.py --self-test
python3 -m unittest discover -s python/tests -t python -p "test_fetch_squad_art.py"
python3 scripts/check_no_assets.py
python3 scripts/check_license.py
make test-godot-some SUITES="test/squad"
make lint-tasks lint-status
```

## Manual check

Run `make squad-art`, then `make demo-tactical MODE=squad`: can you tell a
soldier from an alien and half cover from full cover at a glance? Then
delete `build/squad-art/` and play again: does the Kenney fallback still
read?

How invariant 13 is met: unchanged from T85 -- the decision overlay is
drawn over the art, and this task must not hide it (the overlay stays on
top and legible over every tile).
