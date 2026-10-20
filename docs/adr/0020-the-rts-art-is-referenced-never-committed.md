# 0020 — The RTS's art is referenced, never committed

Status: accepted · 2026-10-20 (T20; the owner's decision of 2026-10-19)

## Context

The RTS needs a worker, three fighters, five buildings and two deposits,
and a person reads a board of sprites more easily than one of shapes. The
owner asked for open RTS art "like StarCraft, else Age of Empires", and
ruled on 2026-10-19: **referenced, kept out of the repository, with a link
for whoever wants it** -- not even crops, unlike the fighters (ADR 0015).

The one free set found with every piece the minimum game needs, animated,
is **Bos Wars 2.8**, which is GPL-2.0-or-later. This repository is
Apache-2.0 (ADR 0003). Nothing of a GPL set may be redistributed inside it
without the GPL reaching the whole -- which is a second reason, beyond the
owner's, for keeping every byte of it out.

Rejected on 2026-10-19 and recorded in T20: Wyrmsun's CC0 collection (its
units are 46 x 38 icons, not sprites), Kenney's two RTS packs (no
animation), Tiny Swords (no redistribution at all).

## Decision

- **`godot/game/rts/art_sources.json` is the reference**: the licence, the
  project, the base URL in Debian's source archive, and for each of the
  eleven kinds the sheet's path, sha256, frame size (from the unit's own
  `.lua`) and number of directions. All eleven hashes were checked on
  2026-10-20 against the files as downloaded; the four T20 named on
  2026-10-19 matched what it recorded.
- **`make rts-art` downloads, and refuses a mismatch.**
  `scripts/fetch_rts_art.py` puts each sheet in `build/rts-art/`, which git
  ignores, and deletes and reports any whose sha256 is not the manifest's.
  Its `--self-test` plants a mismatched sheet and must see it removed;
  `python/tests/test_fetch_rts_art.py` runs that self-test in `make check`
  and holds the manifest to every kind the game draws.
- **The game reads the sheets from outside the project.** `RtsArt` loads
  them with `Image.load_from_file` from `../build/rts-art`, so Godot never
  imports them, no `.import` file is written, and `make export` cannot
  carry them. Team colour is Bos Wars' own scheme -- palette entries 208 to
  211, read from the PNG's `PLTE` chunk -- painted in each side's colour.
- **Without the sheets, shapes.** `RtsArt.found` is false on a fresh
  checkout and in CI, and `RtsView` draws a dot, a triangle, a square, a
  diamond and lettered blocks. No test depends on the art.

| kind | Bos Wars sheet | frame |
|---|---|---|
| worker | `engineer/unit_engineer.png` | 56 x 56, 5 directions |
| runner | `assault/unit_assault.png` | 64 x 64, 5 directions |
| shield | `grenadier/unit_grenadier.png` | 64 x 64, 5 directions |
| mortar | `bazoo/unit_bazoo.png` | 64 x 64, 5 directions |
| base | `vault/vault.png` | 236 x 208 |
| barracks | `camp/training_camp.png` | 224 x 224 |
| lab | `vehiclefactory/vehicle_factory.png` | 256 x 254 |
| depot | `powerplant/powerplant.png` | 128 x 128 |
| tower | `radar/radar.png` | 64 x 64 |
| rocks | `rocks/rock_1.png` | 96 x 96 |
| vent | `hotspot/hotspot.png` | 64 x 64 |

The sha256 of each is in the manifest, the one place it is written.

## Alternatives considered

- **Commit crops, as ADR 0015 does for the fighters.** Ruled out by the
  owner, and by the GPL: a crop is still a copy.
- **Import the sheets into the project** (`godot/assets/`, gitignored). An
  imported picture leaves an `.import` file and an imported copy under
  `.godot/`, and an export would carry the copy into a release. Reading
  from outside the project keeps the release clean by construction.
- **Draw shapes only.** Kept as the fallback, and it is what CI sees. A
  person playing gets the sprites for one command.

## Consequences

- A person who wants the pictures runs `make rts-art` once. The download
  is from Debian's archive, which keeps old versions, so the hashes should
  hold; if one changes upstream, the script refuses it and says which.
- `RtsArt` recolours each unit sheet per side once, at start: a few
  hundred thousand pixels in GDScript, under a second. Building sheets are
  cut to their first frame first -- the lab's whole sheet is 1.3 million
  pixels.
- Licence: the repository's `NOTICE` names nothing of Bos Wars, because
  nothing of it is here. The manifest names the licence for the person who
  downloads.
