# T57 — The RTS seat bias: a gate on the mirror match

Size: S · Prereqs: T20 · Files: `godot/addons/ai_rts_core/`, `godot/game/rts/`

## Goal

T20's map is its own half-turn, yet during its review the priority queues
played against themselves won 15 of 20 from the west seat. After the
review's fixes -- an attack now ends when its target leaves sight -- the
same pairing went 9 - 11 (`make rts-measure`, 2026-10-20). Nothing holds
that: a person always plays west, and every pairing measured "from both
seats" would average a bias back in without anyone seeing it. Make the
mirror match a gate, and if it fails, find the asymmetry.

## Steps

1. **Suspects, each tested on its own**, the queues against themselves
   over the same seeds: tie-breaks that are not mirror images -- the
   order `EconomyQueue._ring_cells` and `Squad._nearest_first` scan cells
   in, `GridGraph.DIRECTIONS`' order in a flow field's arrows, the lower id
   pushed west by `RtsWorld._keep_apart`, ids handed out top row first (so
   east's start units have the lower ids and act first in a tick), and the
   lower side deciding first in `RtsMatch`.
2. **Fix each that moves the record**, by making the tie-break a mirror
   image (decide by the side, not by the screen's direction) rather than by
   handicapping a seat.
3. **A gate**: `rts_match.gd` plays the queues against themselves over a
   handful of seeds and fails when one seat wins more than an agreed share.

## Acceptance

```bash
make check
```

```bash
make rts-measure
```

`rts-measure` prints the mirror match within the bound the gate sets.

## Manual check

None: the record is the check.
