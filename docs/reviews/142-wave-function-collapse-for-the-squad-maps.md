# Review: wave/142-wave-function-collapse-for-the-squad-maps

T96 adds wave function collapse to `ai_constraints`. `WaveCollapse` is a
subclass of T95's `ConstraintSolver` that changes three of its choices:
the cell of least Shannon entropy goes first, the value is one tile drawn
by weight, and a contradiction restarts from the next seed instead of
backtracking. `TileGrid` declares a map from a hand-written tile set. The
Python twins and an independent `derive.py` write seven collapse vectors.
In the XCOM-style mode, `SquadMapBuild` builds 14 by 9 maps from
`spec/squad/tiles.json`. `SquadMapCheck` refuses maps the rules cannot
play. N builds a map, and B replays the build one cell per press. The
tactical scene gains a seam (`TacticalModeView.rows`, `pressed`,
`building`) to draw it.

A fresh context reviewed PR #90 at head f4d8328 (base origin/main
dcba8f5), in a throwaway worktree. It read the code and planted faults
one at a time, restoring each before the next and clearing `__pycache__`
after every Python plant. It made no commit, push or PR comment.

**Verdict: changes requested. No blocker, five should-fix findings and
five nits.** The algorithm is right and well held. Every fault planted in
`WaveCollapse` (restart count, weights, tie-break, entropy as a count) is
caught in both languages, by the vectors and by the suites. The weak part
is everything around it. Four weakened playability checks and three
broken scene seams all pass `squad_map_test`. And a built map outlives
the ruleset that built it, so a scene reopened from the menu plays on the
old built map while its status says "map: the tactical one".

## What was reviewed

- `CLAUDE.md` (invariants 2, 4, 6 and 13, "Readable by a person", the
  traps), the task file, the PR body with its 12 decisions, and the
  review record of wave 136 for shape.
- The diff against `origin/main`: `wave_collapse.gd` and `.py`,
  `tile_grid.gd` and `.py`, the solver's `gave_up` doc line,
  `constraint_draws.gd` (unchanged, read for decision 5), `derive.py`,
  the vector README and files, `collapse_vector.gd`,
  `collapse_vector_test.gd`, `wave_collapse_test.gd`, the runner change,
  `test_constraints_collapse.py`, `squad_map_build.gd`,
  `squad_map_check.gd`, `squad_map_words.gd`, `squad_ruleset.gd`,
  `squad_scenario.gd`, `squad_view.gd`, `squad_legend.gd`,
  `tactical.gd`, `tactical_mode_view.gd`, `squad_map_test.gd`, the
  locale rows, both manifests, `docs/techniques/ai_constraints{,.pt-BR}.md`
  and `docs/godot/squad.md`.
- For context: `godot/addons/ai_core/xorshift.gd`,
  `tasks/T109-one-seeded-generator-in-ai-core.md`,
  `godot/menu/catalogue.json` and `docs/techniques/catalogue*.md`.

## What was run (green at f4d8328 unless stated)

- `python3 -m unittest discover -s python/tests -t python -p "test_constraints*.py"`:
  37 tests, OK. `test_squad_vectors.py`: 8 tests, OK.
- `make test-constraints-vectors`: 9 constraint vectors and 7 collapse
  vectors, 0 failures.
- `make test-godot-some SUITES="test/ai_constraints test/squad"`: 137
  cases, 0 failures, no `SCRIPT ERROR`.
- `check_glossary.py`, `check_translations_docs.py`,
  `check_translations_game.py`, `check_readability.py`,
  `check_addon_deps.py`, `make lint-modules lint-tasks lint-status`: all
  exit 0.
- Twenty maps from seed 1, headless (`SquadMapBuild` in a loop): seeds 3
  and 21 refused for cover at (13, 3) and (0, 5), and seed 6 for "no walk
  from (1, 2) to (0, 5)". That is no contradiction and three refusals, as
  the PR and the page say.
- A two-ruleset probe for finding 2 (below).

### Planted faults

| planted | where | caught by |
|---|---|---|
| `restarts` starts at 1 | `wave_collapse.py:58` / `.gd:77` | Py 7 failures; GD vectors 7, suites 8 |
| one attempt fewer (`range(attempts - 1)`) | `.py:59` / `.gd:79` | Py 1; GD vectors 2, suites 3 |
| uniform draw, weights ignored | `.py:95` / `.gd:146` | Py 3; GD vectors 6, suites 3 |
| tie-break to the last in the seeded order (`<=`) | `.py:84` / `.gd:130` | Py 7; GD vectors 15, suites 9 (+1 error) |
| entropy as a count (`log(count)`), weights ignored | `.py:35` / `.gd:112` | Py 3; GD vectors 4, suites 3 |
| `gave_up` dropped | `.py:108` / `.gd:160` | Py 1; GD vectors **pass**, suites 2 (as the PR says) |
| cover within one action **plus one** | `squad_map_check.gd:44` | **survives** `squad_map_test` |
| connectivity checked for red's four starts only | `squad_map_check.gd:31` | **survives** |
| cover checked for red's four starts only | `squad_map_check.gd:34` | **survives** (seed 3 is a blue-start refusal it would let through) |
| water beside a cell counted as cover | `squad_map_check.gd:53` | **survives** |
| clicks accepted while a build is shown | `tactical.gd:176` | **survives** |
| `_explained` reads `TacticalScenario.MAP` | `tactical.gd:638` | **survives** |
| terrain drawn from `TacticalScenario.MAP`, not the built map | `tactical.gd:908` | **survives** |

The squad and scene plants were run against `squad_map_test.gd` only, the
one suite that builds a map. Every other squad and tactical suite plays on
the tactical map, where the two maps in the scene plants are the same
map, so those suites cannot tell the difference either.

## Answers to the brief

**WFC as a CSP.** This matches mxgmn's description. Observe takes the
least entropy, which is Shannon's over the weights (`ln W - sum(w ln w) / W`),
and both the code and the page say so. Collapse is one weighted draw.
Propagate is the solver's own AC-3, run until its queue is empty, so it
reaches a fixed point. A contradiction is a domain emptied in `_revise`.
Ties are broken by the seeded `_order`, with a strict `<`, so the same
seed gives the same map in both languages. It is one shared solver: the
subclass overrides `_select`, `_values` and `_revise` and copies no AC-3.
There is no hidden fork. The one difference from mxgmn is noted as nit 1.

**The vectors.** `derive.py` imports nothing from the repo and has its own
shape: coordinates, an arc as a pair of cells, a `min` with an explicit
`(entropy, place)` key. It has to share the draw protocol, the tile order
and the arc queue order (`DIRECTIONS`), or it could not name the same
contradiction cell. That is a contract, not a copy of the code. The AC-3
fixed point is unique whatever the queue order, so the maps depend only
on selection and draws. The queue order matters only for which cell is
named. Vectors already pin seeds that hit contradictions: one restart
(`three-colours-restart`), two (`three-colours-two-restarts`), and every
attempt (`pinned-so-there-is-none`). The restart count is therefore held,
as the plants show.

**Invariant 13.** All four things the task asks for are shown and tested:
counts on the open cells (`show_odds`), the next cell in amber before it
collapses (`show_dashes`, with its entropy on the status), counts dropping
(`counts().size()` falls by one per step and pruning is replayed), and a
red 0 where a contradiction emptied a cell (`show_threat`, tested at
(8, 8) with the `CONTRARY` set). Whether it reads well is for the manual
check.

## Findings

1. **The playability check's tests would not notice it being weakened
   (should-fix, invariant 4).** `godot/test/squad/squad_map_test.gd:38-49`
   against `godot/game/squad/squad_map_check.gd:31-53`. The test has
   three maps: the tactical map, which passes; a map that walls in red's
   first start, which must fail with "no walk"; and an all-open map, which
   must fail with "no cover". All four weakened checks in the table pass
   them. That means an unplayable map can reach play the day someone
   loosens the check. Right now it cannot: the check is correct as
   written. Fix: pin the real refusals measured above. `SquadMapBuild.new(3)`
   keeps seed 4, and its `unplayable[0]` is "no cover within one action of
   (13, 3)". `new(6)` keeps 7, and its reason starts with "no walk from".
   `new(21)` keeps 22, for cover at (0, 5). Add three hand-made maps:
   (a) a blue start walled in, which catches the red-only connectivity
   check; (b) a start whose nearest cover is exactly one action plus one
   step away; (c) a start whose only neighbours are water.

2. **A built map outlives the ruleset that built it (should-fix).**
   `godot/game/squad/squad_scenario.gd:30,57` (`static var _built`)
   against `godot/game/squad/squad_ruleset.gd:36,41`, which hold
   `map_build` and `_next_map_seed` on the instance. Probe: make a
   `SquadRuleset`, call `build_map(false)`, then make a second
   `SquadRuleset`. The second one's `map_build` is null and its status line
   says "map: the tactical one -- N builds a new one ...", but
   `SquadScenario.rows() == TacticalScenario.MAP` is **false**. Escape
   goes back to the menu (`menu.gd:296`), and opening the tactical scene
   again makes a new ruleset. So the next session draws and plays the old
   built map under words that say it is the tactical one. That also breaks
   decision 10's promise that the third map built is always the same map.
   The test suite resets the map in `after_test`, which is why no test
   sees this. Fix: call `SquadScenario.use_map([])` in `SquadRuleset._init`,
   or better, keep the rows on the ruleset and let `SquadScenario` read
   them from there. Add a test that builds a map, makes a fresh ruleset,
   and asserts the tactical rows and the tactical status line.

3. **The scene seam is mostly untested (should-fix).**
   `godot/game/tactical/tactical.gd:176,638,908`. Three plants survive:
   drawing terrain from the tactical map instead of the built one,
   explaining a blocked cell from the tactical map, and accepting clicks
   during a build. The first is the one that would mislead the person
   most: the pieces play on one map while the scene draws another.
   Decision 8 is right to accept the seam, but it needs tests. Fix: in
   `test_n_plays_a_new_game_on_a_new_map_and_b_shows_one_built`, after N,
   assert that `scene._terrain()` places each built map's `T`, `#`, `~`,
   `=` and `f` where the built rows have them. Pick a seed whose map
   differs from the tactical one at a known cell. During B, send an
   `InputEventMouseButton` through `_unhandled_input` and assert that
   `state` and the piece in hand are unchanged. Assert that `_explained`
   on a built-map rock cell names rock.

4. **`ConstraintDraws`' header is now wrong twice (should-fix, invariant
   1).** `godot/addons/ai_constraints/constraint_draws.gd:11,14` and
   `python/gameaikit/constraints/draws.py:8`. It says the addon "cannot
   import" the shared generator. T109 put that generator in `ai_core`
   (`GakXorshift`) exactly so that addons could stop copying it, and
   invariant 2 allows `ai_core`. It also says "the solver draws only to
   shuffle, once, before it searches". `WaveCollapse` now draws during the
   search, once per collapse. Fix in this wave: correct both sentences.
   Leave the actual fold into `GakXorshift` to the follow-up recommended
   under decision 5.

5. **The menu and the demo catalogue do not know about N, B or the
   technique (should-fix).** `godot/menu/catalogue.json:208-232`: the
   tactical entry's `controls` do not mention N or B, its `techniques`
   have no `constraints` row, and its `watch` text says nothing about the
   build. `docs/techniques/catalogue{,.pt-BR}.md`, written by `make
   catalogue`, therefore still shows `ai_constraints` only for the
   infiltration demo. A person who opens the demo from the menu is not
   told that the keys exist, which is half of invariant 13 ("a person
   opens it and sees"). Fix: add N and B to `controls`; add
   `{"technique": "constraints", "part": "XCOM's maps: wave function
   collapse builds them, B a cell at a time ..."}` with a pt-BR row; run
   `make catalogue`. This is outside the Files line, so note it in the
   task file as the wave already did for `godot/game/tactical/`.

6. **Forced cells are "observed" too, unlike mxgmn (nit).**
   `wave_collapse.gd:11-17,126-133`. mxgmn observes "the minimal
   *nonzero* entropy": in his model, a cell with one tile left is already
   decided. Here it is an unassigned variable of entropy 0 and goes first.
   The map is the same either way, but B spends a press on each of the
   eight pinned starts and on every cell propagation forced, each showing
   "1 tile(s) left, entropy 0.00". The header says entropy-0 cells go
   first, but the page does not say this differs from the source it
   quotes. Fix: one sentence on the page, in both languages: "in CSP
   terms a cell down to one tile is still unassigned, so it is chosen
   (with no draw); mxgmn counts it as already observed". Or have the
   replay apply forced cells in one step.

7. **The draws for the values replay the shuffle's draws (nit).**
   `wave_collapse.gd:93`, `wave_collapse.py:51,72`. `_picks` is
   `ConstraintDraws(seed)`, the same seed and therefore the same sequence
   that `ConstraintSolver.solve` has just used to shuffle the cells. The
   first tile drawn uses the same number that placed the last cell in the
   order. That does no visible harm at this size, but a reader learning
   seeded generators should not copy it. Fix: say so in the header, or
   seed the picks from a derived seed (for example `seed ^ 0x9E3779B9`)
   and regenerate the vectors in the same commit.

8. **Adjacency is symmetric, and the page does not say so (nit).**
   `tile_grid.gd:5-16`. `left_right` lists the tiles allowed on *either*
   side, so a table cannot say "the cliff's high ground is only on its
   left". mxgmn's simple tiled model has directed neighbour pairs. Fix: a
   line under "when not to use it" (a tile set with a direction needs
   `left`/`right` and `up`/`down` lists).

9. **A contradiction before the first collapse is retried for nothing
   (nit).** `wave_collapse.gd:76-85`. When the first AC-3 empties a cell,
   only the pins can be at fault and no seed will help. `solve` still
   runs every attempt (`pinned-so-there-is-none`: `0,0` three times). Fix:
   stop after one attempt when the trace holds no `assign` before the
   contradiction, or say on the page why it retries anyway. Either way
   the vector changes with it.

10. **Small things (nit).** `squad_map_build.gd:21` says "about 50 ms" a
    collapse, and the PR measured about 28 ms; say "tens of ms". The
    vectors could also hold `backtracks: 0` as a claim, so that dropping
    `gave_up` fails in the GDScript runner too, not only in the unit
    tests. The PR is right that the map does not change; the count would.

## The owner's decisions

1. **On T95's solver: agree.** Three overrides and a `_revise` hook, with
   no copied AC-3. Every planted fault in the changed choices is caught.
   This is the lesson the task asked for.
2. **XCOM mode with fixed starts: agree.** The rules, the evaluation and
   the enemy's memory all read `RED_CELLS`. Pinning those cells to open
   ground is the smallest honest change, and the checks then run on
   exactly those cells.
3. **No new pictures: agree.**
4. **Restart at two levels: agree.** Both are counted on screen. Nit 9
   is the one case where the inner restart cannot help.
5. **`ConstraintDraws`, not `GakXorshift`: agree for this wave, and
   recommend a follow-up.** The copy is T95's, not this wave's, and
   swapping it here would mean regenerating both vector families in a
   wave about something else. But the stated reason ("depends on nothing,
   not even `ai_core`") is not what invariant 2 or ADR 0021 asks for.
   `ai_core` is the allowed kernel, and T109 moved the generator there
   precisely to end these copies. Recommendation: a small task makes
   `ConstraintDraws` (keeping `shuffle`, which is this addon's own) draw
   from `GakXorshift`, and declares `ai_core` in
   `modules/ai_constraints.json`. The draws agree number for number, so
   the vectors should not move, and the existing runners prove it. Fix
   the header now (finding 4).
6. **Maps not mirrored: agree** to leave it to the manual check. Building
   half a map and mirroring it is cheap enough to try if games feel
   lopsided.
7. **They may look like noise: agree** to judge after the manual check
   and tighten the table first. The overlapping model is a separate
   decision.
8. **The scene beyond the Files line: agree**. The seam is small and
   readable, and Advance Wars keeps the defaults. It needs the tests in
   finding 3.
9. **Map line as the status's first line: agree.**
10. **N counts from 1 each time the scene opens: agree with the intent,
    but it does not hold today.** Finding 2 shows that reopening the scene
    keeps the previous built map. Fix that and the promise holds.
11. **Collapse vectors under `test-constraints-vectors`: agree.** One
    target, named by the acceptance, and the runner reports the two
    families separately and fails on either.
12. **T87/T88 measurements stay on the tactical map: agree.** Finding 2
    matters here too: a headless measurement in a process that has built
    a map would silently run on it. Reset the map with the ruleset.

## What was done about them

Applied on the same branch. Main had not moved (dcba8f5).

1. **Should-fix, fixed.** `squad_map_test.gd` now pins the three measured refusals: seed 3 is refused at (13, 3) and kept at 4, seed 6 for "no walk from (1, 2) to (0, 5)" and kept at 7, and seed 21 at (0, 5) and kept at 22. It also adds three maps made by hand. In the first, blue's shield at (12, 6) is walled in, giving "no walk from (1, 2) to (12, 6)". In the second, the runner's nearest cover is exactly one action away, then one step more. In the third, a cell has only water beside it, and then rock. The four weakened checks were planted again, one at a time, and each turns `squad_map_test` red. The table is below.
2. **Should-fix, fixed.** The map now belongs to the ruleset. `SquadRuleset.map_rows` is empty for the tactical map. `_init` hands it to `SquadScenario`, so a new ruleset plays on the tactical map. `start` hands it over again, so the game being played reads its own ruleset's map. `test_a_built_map_belongs_to_the_ruleset_that_built_it` reproduces the probe: build with one ruleset, make a second, and the rows and the status line are the tactical ones. A second ruleset's first map is also the first ruleset's first map, so decision 10 holds. The plant (`_init` without the reset) turns it red.
3. **Should-fix, fixed.** `test_the_scene_draws_explains_and_holds_clicks_on_the_built_map` presses N, then checks three things. `_terrain()` draws every tree, water and bridge cell of the built rows and nothing else. `_explained` names rock on a built-map rock cell that is not rock on the tactical map. And during B, a left click sent through `_unhandled_input` leaves `state` the same object, while the same click after N walks the piece. All three plants turn it red.
4. **Should-fix, fixed.** `ConstraintDraws`' header (GDScript) and `draws.py` now say that T109 put the generator in `ai_core` as `GakXorshift`, which the addon may use. They also say that `WaveCollapse` draws during the search, from a second generator with the same seed. Folding the copy in is T135 (`tasks/T135-constraint-draws-from-gak-xorshift.md`, with a STATUS row).
5. **Should-fix, fixed.** `godot/menu/catalogue.json` gets a new algorithm, `wave-function-collapse` (evidence `WaveCollapse`), on the tactical card. The card's controls gain N and B, and its watch text gains the build. The rows are in `menu.csv` in both languages. `docs/techniques/games.json` gains the short names, and the tactical keys gain N and B, and so does `make demo-tactical`'s help line (C8). The catalogue still did not mark the tactical demo, because `scripts/catalogue.py` walked from the scene alone, while `check_demos.py` also walks from each mode's ruleset. It now walks from the rulesets as well, and its self-test plants "a mode's ruleset now reaching a technique, not regenerated". That plant passes with the old walk and fails with the new one. So the tactical row now marks `ai_adversarial`, `ai_constraints` and `ai_utility`: the XCOM mode's three techniques, which were already on the card. `make catalogue` regenerated both pages and both READMEs. MCTS and expectiminimax gained short names in both languages (C7).
6. **Nit, documented.** The class header and the page, in both languages, say that a cell down to one tile is still unassigned in CSP terms, so it is chosen first with no draw, where mxgmn counts it as observed. The map is the same.
7. **Nit, documented.** The draw's comment in both languages says why sharing the shuffle's stream is harmless here, and that an independent stream should get a seed of its own. No vector changed for it.
8. **Nit, documented.** `tile_grid.gd`, `tile_grid.py` and the page's "When not to use it", in both languages, say that adjacency is symmetric within an axis.
9. **Nit, fixed.** A contradiction before the first collapse now ends the build after that one attempt, in both languages and in `derive.py` (README rule 7). `pinned-so-there-is-none` was regenerated: 1 restart, `["0,0"]`. It is the only vector that moved. C5 is now "a map with no attempt left".
10. **Nit, fixed.** "About 50 ms" is now "tens of milliseconds -- about 28 ms each over twenty maps". The `backtracks: 0` claim was not added: the final attempt of every vector is a successful one or a contradiction before any collapse, so the claim would still pass with `gave_up` dropped. The unit tests in both languages hold it.

| plant, after the fixes | caught by |
|---|---|
| cover within one action plus one | `squad_map_test` (1 failure) |
| connectivity for red's starts only | `squad_map_test` (1) |
| cover for red's starts only | `squad_map_test` (2) |
| water counted as cover | `squad_map_test` (4) |
| clicks taken while a build is shown | `squad_map_test` (1) |
| `_explained` reads the tactical map | `squad_map_test` (1) |
| terrain drawn from the tactical map | `squad_map_test` (9) |
| a built map outlives its ruleset | `squad_map_test` (1) |
| the catalogue walks from the scene alone | `catalogue.py --self-test` (1) |
| most entropy first / propagation skipped / contradiction not detected | Python, GDScript vectors and suites |
| `gave_up` dropped | Python (1) and GDScript suites; vectors pass, as above |
