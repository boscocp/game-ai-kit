# T9 — Art that is not a coloured square

Size: M · Prereqs: T8, T10, T27, T28, T30 · Files: `godot/assets/`, `docs/adr/`

## Goal

Everything on screen is a flat colour generated in code. That was a deliberate
choice — no binary art nobody can diff — and it has reached its limit: five unit
types cannot be told apart by being five circles.

Bring in CC0 art, and record the decision properly, because it reverses
something this repository says about itself.

## The decision to record

`board_view.gd` says the tile set is built in code so "this repository stays
free of binary art nobody can diff". Committing sprites contradicts that, which
makes it an ADR rather than a commit.

What the ADR must say: that art is a **development-time** input and does not
move any lesson above tier 1 — the reader gets the committed PNGs and never
needs the GPU, which is the same shape as invariant 6, where Python trains and
GDScript only infers. And that generated art is deferred, not rejected: the
pipeline is T31, and this one buys the visual with hours instead of weeks.

**Which games it draws.** After the owner played the examples, they were
reworked around games people already know. So the art covers:
- the checkers board and pieces (T27);
- tic-tac-toe (T28);
- the tactical game's five unit types, towers, workshop and terrain (T30).

Pick the packs for those. Lay the art out so that T31 can replace any file
with a generated one without touching code: stable paths, one `TileSet`.

## Steps

1. Pick a CC0 set — Kenney's top-down and pixel packs are the obvious first
   stop — and commit only what is used. An unused asset is weight a reader pays
   for and nobody reads.
2. `godot/assets/` with a `LICENCES.md` naming every pack, its licence and where
   it came from. `check_license.py` does not look at assets yet; it should, and
   that is part of this task.
3. Replace the generated atlas in `BoardView` with a real `TileSet`. Keep the
   generated one as the fallback the tests use, or move the tests — do not leave
   two code paths pretending to be one.
4. Sprites for the units, so that five types are five silhouettes rather than
   five colours.
5. ADR: CC0 now, generation later, with the tier argument and the
   binary-art reversal written out.

## Acceptance

```bash
make check
python3 scripts/check_license.py
```

```bash
test -f godot/assets/LICENCES.md
grep -qi "cc0\|creative commons" godot/assets/LICENCES.md
```

`check_license.py` must gain a rule, with its planted case. It covers
**tracked** files only (`git ls-files`), so that a user's gitignored
generated art (T31) never trips it:
- every committed asset file is listed, by path, in `LICENCES.md` with its
  pack and licence;
- an asset file listed nowhere is a finding.

Listing files, not directories, is what lets T31 tell a CC0 file from a
generated one.

The suite must include a test that every path in the game's `TileSet` and
sprite table exists. Those paths are the stable contract T31 swaps files
behind.

## Manual check

In screenshots, by somebody who does not know which is which:
- the tactical game's five unit types are distinguishable at a glance;
- the checkers men and kings of both sides are distinguishable at a glance;
- tic-tac-toe's marks are distinguishable at a glance.

Colour alone does not count: a colour-blind reader is a reader.
