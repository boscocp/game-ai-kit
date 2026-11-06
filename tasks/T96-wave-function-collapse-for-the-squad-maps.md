# T96 — Wave function collapse builds maps for the tactical game's XCOM mode

Size: S · Prereqs: T95, T85 · Files: `godot/addons/ai_constraints/`, `godot/test/ai_constraints/`, `python/gameaikit/constraints/`, `spec/vectors/constraints/`, `spec/squad/`, `godot/game/squad/`, `godot/test/squad/`, `docs/techniques/`, `Makefile`

## Goal

The owner, 2026-10-26: every entry of part A, "todos" -- CSP and wave
function collapse among them (T95's quote). T73's roadmap: "WFC as a
CSP", size S "on top" of the solver.

mxgmn's README says it in one line: "WFC translates a texture synthesis
problem into a constraint satisfaction problem"; its simple tiled model's
propagation "is just adjacency constraint propagation"; it observes "a
wave element with the minimal nonzero entropy", collapses it, and
propagates; and it can run into "a contradiction and can not continue",
"surprisingly rarely" in practice. It generates levels in *Bad North*,
*Caves of Qud* and *Townscaper*, among others the README lists.

## Decisions written down first (the owner confirms in review)

- **On T95's solver, not beside it**: WFC's simple tiled model as a
  problem `ai_constraints` already solves -- a variable per cell, a domain
  of tiles, adjacency constraints, the minimal-entropy cell as the
  variable order, a weighted random value order -- so the lesson is that
  WFC is a CSP with a particular order, not a separate algorithm.
  On a contradiction it restarts with the next seed, and says how often.
- **Home: the tactical game's XCOM mode** (T84). It plays on the tactical
  map today; WFC gives it more maps made of the same terrain -- plain,
  trees, rock, water, bridge, ford, the characters `TacticalRules` names --
  with adjacency rules learned from nothing but a table written in
  `spec/squad/tiles.json`. T84's rules then check a map is playable: both
  squads' starts connected, each start with cover (trees or rock) within
  one action.
- **No new pictures**: the tiles are the terrain the tactical game already
  draws, so a generated map looks like the game it belongs to.

## Steps

1. Python: the tile set, adjacency from it, the generator; vectors (a
   seed in, the map and the restart count out).
2. GDScript, held to the vectors.
3. The XCOM mode gains "new map" (a key free in the tactical scene, named
   on its legend) using the generator. Re-running T87's and T88's
   measurements on generated maps is left to whichever of them lands
   after this; it is not this task's.
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

Generate twenty maps in `make demo-tactical MODE=squad`: do they look like places --
walls that meet, cover in clusters -- rather than noise? Play two.

How invariant 13 is met: the map can be built step by step (a key): each
cell's remaining tiles as a count, the lowest-entropy cell highlighted
before it collapses, propagation shown as counts dropping -- and a
contradiction, when it happens, marked where it happened.

References, opened on 2026-10-26: mxgmn, *WaveFunctionCollapse*, README
<https://github.com/mxgmn/WaveFunctionCollapse>.

## Notes

- **Wave 142, where the code went beyond the Files line.** The scene had to
  learn the map's keys and draw a build, so `godot/game/tactical/`
  changed: `TacticalModeView` gained three answers (`rows`, `pressed`,
  `building`), and `tactical.gd` asks them, draws the terrain from
  `view().rows()`, and hands a key it does not use to the mode. The
  squad's manifest declares `ai_constraints`, and the technique's names its
  new Python test, so the change selects all of `make check`. The squad's
  words are in `godot/locale/squad.csv`, the glossary gained *wave function
  collapse*, *simple tiled* and *overlapping*, and the squad page
  (`docs/godot/squad.md`) its section. The vectors live in a folder of their
  own beside the solver's, read by the same runner and target, so no
  Makefile line was needed.
- **The review of wave 142 widened it again.** The menu's card
  (`godot/menu/catalogue.json`, `godot/locale/menu.csv`), the demo
  catalogue (`docs/techniques/games.json`, the generated pages and READMEs),
  `make demo-tactical`'s help line and `scripts/catalogue.py` now know the
  XCOM mode's N, B and wave function collapse. The catalogue walks from a
  mode's ruleset as `check_demos.py` already did. `ConstraintDraws`' header
  is corrected, and its fold into `GakXorshift` is T135. The review is in
  `docs/reviews/`.
