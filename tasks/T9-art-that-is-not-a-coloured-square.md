# T9 — Art that is not a coloured square

Size: M · Prereqs: T8 · Files: `godot/assets/`, `docs/adr/`

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
pipeline is a later task, and this one buys the visual with hours instead of
weeks.

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

`check_license.py` must gain a rule, with its planted case: an asset directory
with files and no `LICENCES.md` naming their origin is a finding.

## Manual check

The five unit types are distinguishable at a glance, in a screenshot, by
somebody who does not know which is which. Colour alone does not count — a
colour-blind reader is a reader.
