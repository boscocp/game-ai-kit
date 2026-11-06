# Conformance vectors: wave function collapse

<!-- doc-meta
half_life: structure
verified_on: 2026-11-06
tier: 1
source: https://github.com/mxgmn/WaveFunctionCollapse
invalidated_if: the solver's AC-3 queue, the order TileGrid declares a map in, the entropy, the weighted draw, the restart rule or the xorshift generator changes
teaches: none
-->

> One wave function collapse, two languages, and the files that say they
> built the same maps.

`ai_constraints`'s `WaveCollapse` (GDScript) and
`gameaikit.constraints.wave_collapse` (Python) are T95's constraint solver
with three choices changed (T96). Each vector is one `.json` file: a tile
set (`tiles`, each with its `tile`, `weight`, `left_right` and `up_down`), a
`width` and a `height`, the cells `pinned` to some tiles, the first `seed`
and how many `attempts` to make; and the claims -- the `map` as rows (or
`null` when no attempt reached one), every cell `collapsed` in order with
its tile, the `restarts`, and the cell each failed attempt ran out of tiles
in (`contradictions`). Both sides check every claim against the file, never
against each other: `make test-constraints-vectors` on the GDScript side,
`make test-python` on the Python side.

The rules the two follow, and that a third implementation must follow to
agree:

1. the map is declared row by row, a cell "x,y" each with every tile, in
   the tile set's order, or only its pinned ones; then, cell by cell in the
   same order, a constraint with the cell to its right and then one with
   the cell below. Two tiles may stand side by side when each lists the
   other in `left_right`, one above the other when each lists the other in
   `up_down`;
2. one generator seeded with the attempt's seed shuffles the cells, in the
   order declared -- Fisher and Yates from the last place down to the
   second, each swapped with place `next() % (place + 1)`. (The solver then
   shuffles each cell's tiles with the same generator; nothing below reads
   that order, so a third implementation may skip it.) A second generator,
   seeded the same, draws the tiles;
3. AC-3 runs once on every arc -- the constraint solver's rule 2 in
   `../README.md`: for each constraint in the order declared, its first
   cell revised against its second, then the second against the first; a
   queue, first in first out; when a cell loses a tile, every arc that
   revises one of its neighbours against it goes on the end, in the order
   the cell's constraints were declared -- above, left, right, below --
   except the one just revised against, and not when it is waiting already;
4. the next cell is the first, in the shuffled order, of those not yet
   collapsed with the least entropy: `ln(W) - sum(w ln w) / W` over the
   weights w of the tiles it has left, W their sum, the sums taken in the
   tile set's order; a cell with one tile left has entropy 0, exactly;
5. its tile: with one left, that one and no draw; otherwise the tiles
   left, in the tile set's order, laid end to end by weight, and the one
   that `next() % W` lands in;
6. the cell is collapsed to that tile, and AC-3 runs from the arcs that
   revise each of its neighbours not yet collapsed against it, in the order
   of rule 3;
7. a cell left with no tile, in any AC-3 run, is a contradiction: the
   attempt ends there, nothing is undone or tried again, and the next
   attempt starts from the next seed, at rule 2 -- unless no cell had been
   collapsed yet: then only the tiles and the pins were in play, no seed
   changes them, and there is no map after that one attempt. After
   `attempts` failed ones there is no map either, and `restarts` equals
   `attempts`.

The draws are Marsaglia's 32-bit xorshift, `ConstraintDraws`; seed 1 starts
270369, and seed 0 is seed 1.

## Where the numbers came from

From neither implementation: `derive.py`, a script importing nothing from
this repository, wrote them, in a shape of its own -- cells as coordinates,
an arc a pair of cells, the neighbours by direction, no constraint objects
-- where the two twins declare a `ConstraintProblem` and run the solver's
AC-3 over constraint indices. One can be checked by hand:
`checkers-decided-by-one-cell`, two tiles that may only stand beside each
other, on three by three. AC-3 alone crosses out nothing. Every cell has
the same entropy, ln 2, so the first collapses is the first in seed 1's
order, (2,0); its tile is drawn, b; and propagation then leaves every other
cell one tile -- the board alternates. The eight that are left have
entropy 0 and are collapsed in the shuffled order with no draw: nine
collapses, no restart, the map `bab / aba / bab`, as the file claims.

The others: `heavy-and-light` draws one tile nine times in ten and shows
the light one once in eight cells; `pinned-so-there-is-none` pins two
neighbouring cells to the same checkers tile, so AC-3 empties (0,0) before
anything collapses, and the build stops after that one attempt (rule 7);
`three-colours-restart` has three tiles, none beside itself, and seed 30 runs out at (6,4) before seed 31 builds
eight by eight; `three-colours-two-restarts` runs out twice on the squad's
14 by 9; and `squad-map-seed-1` and `-2` are the XCOM-style mode's own tile
set (`spec/squad/tiles.json`; `python/tests/test_squad_vectors.py` holds the two equal) with the
eight starts pinned to open ground. Those two restart no times: across the
first sixty seeds the squad's tile set never ran into a contradiction, as
mxgmn's README says of most tile sets.

`derive.py` wrote them; run it again to check:

    python3 spec/vectors/constraints/collapse/derive.py spec/vectors/constraints/collapse

## What is refused

A vector with a key nobody reads (C1), tiles that are not a tile set (C2),
a pin off the map or to a tile not in the set (C3), restarts that do not
count the contradictions (C4), a map with no attempt left or no map with
attempts to spare that did not stop at the first (C5), or a map finished
without collapsing every cell (C6), is refused rather than half-checked. Three planted collapses must
fail, in both languages: one that takes the cell of most entropy (rule 4),
one that skips propagation (rules 3 and 6), and one blind to a
contradiction, which goes back as the solver would (rule 7).
