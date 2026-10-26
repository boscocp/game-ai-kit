# T95 — Wave function collapse builds the squad mode's maps

Size: S · Prereqs: T94, T85 · Files: `godot/addons/ai_constraints/`, `godot/test/ai_constraints/`, `python/gameaikit/constraints/`, `spec/vectors/constraints/`, `spec/squad/`, `godot/game/squad/`, `godot/test/squad/`, `docs/techniques/`, `Makefile`

## Goal

The owner, 2026-10-26: every entry of part A, "todos" -- CSP and wave
function collapse among them (T94's quote). T73's roadmap: "WFC as a
CSP", size S "on top" of the solver.

mxgmn's README says it in one line: "WFC translates a texture synthesis
problem into a constraint satisfaction problem"; its simple tiled model's
propagation "is just adjacency constraint propagation"; it observes "a
wave element with the minimal nonzero entropy", collapses it, and
propagates; and it can run into "a contradiction and can not continue",
"surprisingly rarely" in practice. It generates levels in *Bad North*,
*Caves of Qud* and *Townscaper*, among others the README lists.

## Decisions written down first (the owner confirms in review)

- **On T94's solver, not beside it**: WFC's simple tiled model as a
  problem `ai_constraints` already solves -- a variable per cell, a domain
  of tiles, adjacency constraints, the minimal-entropy cell as the
  variable order, a weighted random value order -- so the lesson is that
  WFC is a CSP with a particular order, not a separate algorithm.
  On a contradiction it restarts with the next seed, and says how often.
- **Home: the squad mode's maps** (T84), a tile grid with cover pieces;
  each tile's edges carry the cover T84's rules read. T84's rules then
  check the map is playable: both squads' starts connected, each start
  with cover within one move.
- **The tiles are ours, drawn in shapes**: the art (T88) is referenced and
  may be absent, so the tile set is data in `spec/squad/tiles.json`, and a
  map is valid without pictures.

## Steps

1. Python: the tile set, adjacency from it, the generator; vectors (a
   seed in, the map and the restart count out).
2. GDScript, held to the vectors.
3. The squad mode gains "new map" (a key) using the generator; T86's and
   T87's searches play on generated maps too, so their claims are not one
   map's.
4. The `ai_constraints` page, both languages, gains WFC.

## Acceptance

```bash
python3 -m unittest discover -s python/tests -t python -p "test_constraints*.py"
make test-constraints-vectors
make test-godot-some SUITES="test/ai_constraints test/squad"
python3 scripts/check_translations_docs.py
make lint-modules
python3 scripts/check_readability.py
make lint-tasks lint-status
```

## Manual check

Generate twenty maps in `make demo-squad`: do they look like places --
walls that meet, cover in clusters -- rather than noise? Play two.

How invariant 13 is met: the map can be built step by step (a key): each
cell's remaining tiles as a count, the lowest-entropy cell highlighted
before it collapses, propagation shown as counts dropping -- and a
contradiction, when it happens, marked where it happened.

References, opened on 2026-10-26: mxgmn, *WaveFunctionCollapse*, README
<https://github.com/mxgmn/WaveFunctionCollapse>.
