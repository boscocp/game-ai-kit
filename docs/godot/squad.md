# The squad mode: XCOM's shot, cover and fog on the tactical board

<!-- doc-meta
half_life: practice
verified_on: 2026-11-05
tier: 1
source: https://ufopaedia.org/Gameplay_Mechanics_(EU2012) ; https://ufopaedia.org/index.php/Cover_(EU2012) ; book:Steve Rabin (ed.), "Game AI Pro 3", CRC Press, 2017 -- ch. 28 (Roelofs, MCTS for strategy and tactical games)
invalidated_if: spec/squad/rules.json changes, the tactical map changes, or a rule below stops being the code's
teaches: none
-->

> T84's rules. Not a new game: a second ruleset of the tactical game,
> played on its state, map, pieces and pictures. T85 made it something a
> person plays from the tactical scene, against a first enemy that weighs;
> T87 put Monte Carlo tree search behind a second, and T88 expectiminimax
> behind a third, and set the two searches against each other. This page is the rules, where each comes from,
> everything left out, and (below) how the mode is played and how its
> enemies decide.

## The seam

The tactical scene asks a `TacticalRuleset` (in `godot/game/tactical/`)
everything a mode decides: the starting state, what a walk and an attack
do and why one is refused, what happens as a turn opens, who has won,
whether a piece that walked may still attack, and the roster C cycles.
What the screen shows of a mode it asks the ruleset's `TacticalModeView`
(T126, below).

- `AdvanceWarsRuleset` wraps the classes that answered those questions
  before -- `TacticalScenario`, `BoardState`, `TacticalCombat`, `TurnStart`,
  `TacticalVictory`, `TacticalRoster` -- **unchanged**. It is the scene's
  default, and every tactical gate passes through it with the same seeds
  and the same results. `AdvanceWarsView` shows it: `ThreatMap`, the two
  points, the words of a win.
- `SquadRuleset` (module `squad`, `godot/game/squad/`) is this mode, and
  `SquadView` what the scene shows of it.

The scene is handed its ruleset by whoever opens it, as it is handed its
computer player, so `tactical` never names `squad`: the module edge runs
`squad -> tactical`. `BlueTurn` and `TacticalDecision.played_on` take the
ruleset too, so the computer's decisions are played by the same rules as
the person's. `board` did not change.

## The rules, and where each comes from

UFOpaedia, the series' community wiki, on XCOM: Enemy Unknown (2012),
opened on 2026-10-26:

| rule | UFOpaedia | here |
|---|---|---|
| two actions a turn | "Time Units have been removed and replaced with a two-part action system" | a piece's type has two actions of movement; `movement_points` carries both |
| a shot ends the turn | "a unit's turn automatically ends after the unit performs any action other than Move on its 1st Action" | a shot leaves the shooter no movement |
| the dash | (the same rule: Move, then Move) | a walk past one action spends the piece; it may not shoot |
| half cover | "conveys a -20% hit chance penalty" | trees beside the target: 20 |
| full cover | -40% | rock beside the target: 40 |
| only adjacent cover | "cover only grants a defence bonus if a unit is standing directly next to it" | only the four cells beside the target are read |
| flanking | from a flanking position "there will be no cover defence bonus applied" | a shooter on no side that cover protects gets the target's cover at 0 |

The numbers are in `spec/squad/rules.json` (ADR 0007), copied byte for byte
to `godot/game/squad/` and `python/gameaikit/squad/`; a Python test holds
the copies to the spec.

- **Hit chance** = the shooter's aim - the target's defence - cover,
  clamped to [0, 100]. One die from 0 to 99; the shot hits when the die is
  below the chance. A hit takes the shooter's damage off the target.
- **Which side cover faces.** A cell of cover one step `d` from the target
  protects it against a shooter whose offset from the target has a positive
  part along `d`. The best cover that faces the shooter counts. A target
  with cover beside it and none facing the shooter is **flanked**.
- **Sight.** Trees and rock block a line of sight, as `TacticalRules`
  promised for fog, except a cell beside either end of the line: a piece
  leans out past its own cover, and shoots at a target behind its cover at
  the cover's price. The line is Bresenham's, drawn from the end that sorts
  first, so the line is mutual; the reach is each piece's own (a runner
  sees 6 steps, a shield 5). Pieces never block it.
- **A shot** needs the shooter itself to see the target -- within its own
  sight, with the line clear -- and the target within its range, in steps;
  and the shooter must still hold a whole action. A mortar reaches 7 and
  sees 6, so it shoots at 7 only at what it sees; a shot never names an
  enemy its side's view does not hold, and a refused shot at an unseen
  enemy says nothing of where it is.
- **Fog, by side.** A side sees an enemy when one of its pieces is within
  its sight, in steps, with the line clear. `SideView` is a side's board --
  its own pieces and the enemies it sees, with the dice seed taken out --
  and the cells where it last saw the others. A controller in this mode
  decides on that view, never on the state.
- **The squads.** Four a side, one each of the runner, the shield, the
  mortar and the wader, on their own bank by their own map edge, mirrored
  through the board's centre. No workshop, towers, funds, points or
  building. The wader still wades.
- **The end.** A side with no piece left has lost. At the round limit (20)
  the side with more health left, summed, wins; equal health is a draw.
- **A decision is one unit's action.** `SquadRuleset.actions` lists every
  walk and every shot of the side to move, each one unit's: Roelofs'
  hierarchical expansion, which keeps a search's branching near one unit's
  options rather than their product [GAP3 ch. 28].

The squad roster (`SquadRoster`) is its own table, not rows added to
`TacticalRoster`: `League.schedule` seats the league's teams by their place
in that table, and a row added there would re-roll the league's dice. Its
rows, in the order C cycles them: `weighed` (T85), `mcts` (T87), `expecti`
(T88) and `random`, a seeded random mover on its side's view -- the floor
T85's first enemy has to beat.

## What is left out, and why

Every simplification, so nobody reads the mode as more of XCOM than it is:

- **Overwatch and hunker down.** Overwatch shoots in the other side's
  turn, and every search in T87 and T88 would have to model an interrupt;
  hunker down doubles cover and is only worth having beside overwatch. A
  later task can add both once the searches stand.
- **Aim, defence, damage, health, range and sight** are this kit's numbers,
  chosen to make the four pieces different. Only the cover values and the
  two-action turn are borrowed.
- **No range modifier, no critical hit, no graze, no damage spread.** XCOM
  has all four; flanking there also raises the critical chance. Here a
  shot hits or misses, and a hit does a fixed damage.
- **No high ground, no destructible cover, no wall cover.** The tactical
  map has neither height nor walls, and its trees and rock never break.
- **Cover from the map's own letters.** Nothing new is drawn on the map.
  Standing *on* trees gives no cover; only standing beside them does.
- **Sight is a line per pair**, not a field of view: fine for eight pieces.
- **A seen enemy is seen whole.** XCOM hides an enemy's kind and health
  until it is seen; here an unseen enemy is an id and a remembered cell.
- **No squad sight, no abilities, no items, no grenades, no psionics.**
- **One guess at the fog, for the search** (T87). `MctsSquad` searches one
  board: each unseen enemy where it was last seen. Sampling several
  guesses and searching each -- determinization, or information-set MCTS
  -- is the honest treatment of hidden information, and the step after
  this one.

## How it is held

- `make test-squad-vectors`: twelve hand-checked shots in
  `spec/vectors/squad/` -- cover facing and not, a shooter level with the
  cover, the shooter's own cell, flanking, the clamp, a die equal to the
  chance -- against the GDScript and the Python twin.
- `make test-godot-some SUITES=test/squad`: the rules one at a time, the
  tactical scene handed this ruleset, and the property check over 300
  seeded positions on the tactical map: every legal action leaves a legal
  state, a shot or a dash spends the piece, no side's view holds an enemy
  it cannot see (nor misses one it can), no listed shot names an enemy
  outside its side's view, and a seeded game replays to its
  digest. Each of the first three was shown to fail on a planted mutation
  (no dash rule, a view that sees everything, a shot that does not spend,
  a shot that needs only the line and not the shooter's sight).
- Every tactical gate, unchanged, through `AdvanceWarsRuleset`.
- T85: `make test-squad-match` (above); `weighed_squad_test.gd` -- over
  60 seeded positions, changing what the side cannot see (every unseen
  enemy moved to another unseen cell, its health changed, one taken off
  the board, the dice re-seeded) changes none of its decisions, each
  asked of a controller that has already looked at the side's turn before;
  the same check catches a planted controller that reads the whole board
  (42 of 60, floor 30) and one that reads only the unseen enemies' health
  (40 of 60, floor 30);
  `squad_scene_test.gd` -- the modes, M, C, the fog, the dash, the odds and
  their reasons, T under the cursor, V, a walk that reveals; the menu's
  modes in `test/menu/menu_modes_test.gd`; the mode stepped by
  `make test-demo-overlays` and read in pt-BR by `make test-locale-screen`;
  `check_demos.py` holds each mode's controllers to its roster (C9).
- T87: `make test-squad-search-vectors` -- the three positions in
  `spec/squad/positions.json`, the root's visits after a fixed number of
  iterations from a fixed seed, equal in GDScript and in Python
  (`gameaikit.squad.search_game`); `squad_search_test.gd` -- the search's
  walks are the board's at the same cost, a shot is a hit and a miss at
  the chance shown, a question with one answer is passed over, the turn
  passes after the last piece, the score is in [-1, 1]; `mcts_squad_test.gd`
  -- T85's does-not-cheat check (moved to `SquadUnseenCheck`) over 24
  positions, catching a searcher that believes the whole board (20 of 24,
  floor 14) and one that believes the unseen enemies' health (20 of 24,
  floor 14); what it believes of an enemy out of sight, never seen, or
  destroyed; the most visited played; a frame at a time to the same answer
  as all at once; and a seeded game against the weighed enemy pinned to its
  digest. `squad_scene_test.gd` -- C reaches it, and the scene draws its
  search growing a frame at a time, stopped by space.
- T88: `expecti_squad_test.gd` -- the 30 positions of `spec/squad/duel.json`,
  every answer's expected value at depth 2 the file's within 1e-9, equal in
  Python (`test_squad_duel.py`); a planted game that sees no dice missing
  most of the shot positions; the evaluation's terms in [-1, 1] and the
  score below a win, the same from either side; T85's does-not-cheat check,
  catching both planted searchers (20 of 24 each, floor 14); the answer
  worth most played, every answer shown, a shot's hit and miss in the
  status, a hold said while depth 1 is unfinished, a frame at a time to the
  answer it gives at once, a refused walk answered, and a seeded game
  against the weighed enemy pinned to its digest. `squad_duel_test.gd` --
  what the duel refuses, each with a planted row -- a short run included.
  `make test-squad-duel`, in `make check`: the 30 positions searched by both
  on counted budgets (100 iterations, 400 positions) and one seeded match a
  pairing a seat (40 iterations, 150 positions a decision), about 30 s,
  the same on any machine; it fails on an answer not the position's, a
  search that finished nothing, a match with no end or a lost decision,
  and on fewer rows or matches than it set out for -- a `SCRIPT ERROR`
  leaves a run short, and the count says so (T88's review planted one in
  each half).
  `make test-adversarial-vectors` -- the addon's expectiminimax on the dice
  race, depths 2 and 3, equal to `derive.py`'s exact fractions in both
  languages.

## Playing it (T85)

**One card, one scene, two modes.** The menu's tactical card lists
`modes` -- Advance Wars, the default, and XCOM -- each with the ruleset
script the menu builds it from and its own controllers and roster. M, or
the mode button, chooses on the menu; the scene is handed both rulesets
(`TacticalGame.play_in_modes`) and starts in the one chosen, and M in the
scene plays the other, a new game with that mode's first controller.
`make demo-tactical MODE=squad` opens the menu straight into the card in
that mode. `make demo-tactical` alone still opens the scene in Advance
Wars, and M does nothing there: the scene names no mode.

**What the scene asks the mode's view (T126).** T85 added these to the
ruleset; T126 moved them to a `TacticalModeView` of their own, which the
ruleset hands the scene (`mode_view`). Each has an answer that leaves
Advance Wars as it was: the title and the line saying what the game is,
how to win and the words of a win, the tint and the tint under the
cursor, the points marked, the fog of a side (`TacticalFog`), the dash
cells of a reach, a label of odds on each target, the two statuses, the
legend, whether a walk revealed an enemy, and what a piece that has walked
is told. Whether it may still attack stayed with the rules.

| | before T126 | after |
|---|---|---|
| `TacticalRuleset`'s answers | 28 | 14 (13, and `mode_view`) |
| `TacticalModeView`'s answers | -- | 15 |
| `tactical_ruleset.gd` lines | 178 | 99, and 119 in `tactical_mode_view.gd` |
| `advance_wars_ruleset.gd` lines | 109 | 84, and 46 in `advance_wars_view.gd` |
| `squad_ruleset.gd` lines | 308 | 188, and 150 in `squad_view.gd` |
| `tactical.gd` lines | 860 | 872 |

Why two objects and not one: a search asks the ruleset about thousands of
states and never what the screen shows; a mode added to the scene had
added its drawing to the rules (T85's review, finding 4). Why the ruleset
hands the scene its view, rather than the opener handing both: the menu,
the demo overlays and the tests open the scene with rulesets, and still
do, unchanged -- and `tactical` still never names `squad`. The scene grew
by its `view()`, which asks the ruleset again whenever M, an opener or a
test sets another, so the two cannot drift apart -- `squad_scene_test.gd`
holds it, asking after each M which view draws. 12 lines more: its
`view()` and the paragraph saying so, less the Advance Wars header line,
which moved to `AdvanceWarsView`. Every hook it asked the ruleset is one
call it now asks `view()`, and none stayed behind; the map is still the
scene's, since every mode plays on `TacticalScenario.MAP` -- a mode with a
map of its own would add it to the view. The scene is not
shorter; what changed is that each call now says which of the two it asks,
a rule or a picture. One test changed, and only in what it asks:
`squad_scene_test.gd` asks the view for `fog`, `dashes`, `tint_at` and
`reveals`, with the same arguments and the same assertions. Wave 128's
review planted twelve faults; six survived the suites. The tests it asked
for (`test/tactical/mode_view_test.gd`, and in `squad_scene_test.gd` the
view after M, the ghosts, the legend and the "shoot" wording) now catch
all six (`docs/reviews/128-the-xcom-mode-has-its-own-view.md`).

**What the person meets.**

- The board is drawn as the person's side sees it: the cells no red piece
  sees are dark, a faded picture with a `?` marks where an enemy was last
  seen, and only the enemies red sees are drawn.
- Click a piece and its reach lights up in two tints: light where the
  walk keeps the shot, amber where it is a dash and ends the piece's turn.
  The reach is planned on what red sees. A walk that would cross or end on
  a piece red cannot see is refused in the words any blocked walk gets --
  "unit 1 cannot walk there" -- naming no cell, no piece, and not that the
  cell is taken (wave 119's review: the board's own words had named the
  hidden piece). Whether the walk should instead stop at the last free
  cell and show the piece, as XCOM does, is the owner's to say.
- Before any shot, each enemy the piece in hand may shoot carries its hit
  chance on the board, and the status gives the sum that made it:
  `65% = aim 65 - defence 0 - cover 0, flanked`.
- Z takes back a walk, as in Advance Wars -- not after a shot, and not
  after a walk that brought an enemy into sight: that would let a person
  look round a corner for free. Either one seals the turn, so nothing
  walked before it this turn can be taken back either, and Z says so.
- T, with the cursor on a cell: each enemy red sees that could shoot there,
  with its chance against the piece standing there (or the piece in hand).
- On the computer's turn the board shows what the computer sees, its fog
  and its ghosts, and on every cell or target it weighed for the piece
  about to act, the score above and the best hit chance below, the one it
  takes framed -- before space plays it. V turns that off: the board is
  then the person's, a piece the person cannot see acts unseen -- the
  status says only that one does -- and a seen piece walking into the dark
  is drawn as far as the last cell the person sees, its reason left out.

## The first enemy: `WeighedSquad`

An AIMA agent in the plainest form the mode allows. **It perceives** its
side's view, `SideView`, remembering where it last saw each enemy, and
reads nothing else of the state it is handed but the turn's number and
its own piece's cell when asked to build. **It weighs** every walk open to the
piece about to act, holding included, and then every shot from where the
walk left it. **It acts** on the best, the first of equal scores.

Each option is scored by `ActionChoice` (`ai_utility`), with the
considerations in `godot/game/squad/weighing.json`, one action asked once
per option with that option's percepts:

| option | percept | curve | why |
|---|---|---|---|
| a walk | expected damage of the best shot it leaves (0 after a dash) | 0.25 + 0.25 x | a shot is what a turn is for |
| | danger: what the enemies it sees could expect to do to it there | 1 - 0.1 x | cover and flanks are in the chance |
| | steps, by its own ground, to the nearest enemy it knows of | 1 - 0.025 x | with nobody seen, it goes looking |
| a shot | expected damage, no more than the target has left | 0.25 x | a 0% shot is never taken |
| | destroys it | 1, else 0.6 | a piece gone shoots no more |

The answers multiply, as `ActionChoice` does. With nobody in sight, the
nearest enemy it knows of is the other squad's starting cells, which the
map tells everybody; a cell with no route to any is counted 40 steps away,
past the end of the curve. It is the baseline the searches of T87 and T88
must beat, as `LeveledBlue` is in Advance Wars.

The curves saturate, on purpose and with a cost the owner may not want:
- every shot it leaves worth 3 expected damage or more scores the same
  offence (1.0);
- a cell with danger 10 or more is vetoed, holding included. When every
  option is vetoed, nothing scores above zero and the first listed --
  holding -- is taken;
- a shot's 0.25 x saturates at 4, which a 5-damage mortar reaches at 80%.

A walk the board refuses -- it ran into a piece its side cannot see -- is
answered with the next best (`after_refusal`, which `BlueTurn` asks): the
refused route's cells are avoided, and the piece weighs again. Holding is
never refused, so no action is lost.

**Measured** (wave 119, `make test-squad-match`, 100 seeded matches a
seat against `RandomSquad`): 100 won as red, 100 won as blue, no draws.
The bar is 80. Its walks refused by a piece it could not see: 4 as red, 4
as blue, each answered with another, so no action lost; the gate holds
"none lost" and "at most 15 refused for each 100 games". A seeded game of it against itself (dice seed 11) ends in
round 8, blue winning, and is pinned to its digest.

**The defence values** (owner's item 3 from wave 113, still open): the
chance against a target in full cover (40), with the defences as they are.

| shooter (aim) | runner, wader (10) | shield (20) | mortar (0) |
|---|---|---|---|
| runner, wader (65) | 15% | 5% | 25% |
| shield (60) | 10% | 0% | 20% |
| mortar (70) | 20% | 10% | 30% |

The shield behind rock is nearly unhittable, as wave 113's review said.
The recommendation (0-10) is to be measured in the manual check's play;
the numbers are unchanged here, and the match gate cannot tell the two
apart -- the weighed enemy wins every game either way.

## The enemy that searches: `MctsSquad` (T87)

Monte Carlo tree search from `ai_adversarial` (T86), handed the mode
through an adapter, `SquadSearchGame`, that lives here: the addon learns
nothing about squads. Each of these was a decision written into the task
before the code, for the owner to confirm.

**The game the search reads.** A position is one question -- T84's one-unit
decision, which keeps the branching near one piece's options rather than
their product (Roelofs, Game AI Pro 3, ch. 28): the piece about to act,
whether it is to walk or to shoot, and the pieces of its side still to act
after it, in `BlueTurn`'s order. Its answers are hold, then every cell the
piece can reach row by row; or hold, then every enemy it may shoot by id.
`SquadRuleset.actions` has neither the hold nor the one-piece view; the
adapter adds both. A question whose only answer is hold -- after a dash,
with nobody in sight -- is passed over, and after the side's last piece the
turn passes. A shot has two outcomes, hit and miss, at the hit chance the
person is shown; the search keeps a child for each. A playout plays at most
`playout_limit` random answers and is scored on health: +1 or -1 once a
squad is gone or the round limit has come, and before that each side's
health left, the difference over a full squad's (33), so always in
[-1, 1]. The numbers are `rules.json`'s `search`.

**What it perceives** (`MctsSquad.believe`). The search needs a whole
board, and fog gives a side less. So it searches the board it believes in:
every enemy it sees, where it is; every enemy it has lost sight of, where
it last saw it and as hurt as it was then; every enemy it never saw, where
the scenario starts it, whole -- which the map tells everybody. An enemy
believed on a cell its side now sees empty, or that something stands on,
is moved to the nearest cell its side does not see. An enemy it saw and
then lost from memory was destroyed: a side is told of that. One guess,
not several sampled (above, what is left out).

**The budget, a frame at a time.** In the scene it searches
`iterations_per_frame` iterations each frame (`keep_thinking`, which the
scene's `_process` asks of any controller; every other one answers no),
and the decision drawn is rewritten in place each frame, so the board keeps
drawing while it thinks. Space plays what it believes now: anytime. Built
anywhere else -- a match, a test -- it runs the whole budget at once.

**What it shows** (invariant 13). For the piece about to act, every answer
at the root on the board: its mean above, a shot's hit chance below, the
most visited framed. In the status, a bar of visits for the six most
visited answers, each with its mean and UCB1 bound, all growing while it
thinks, and after them the line of play it expects
(`MonteCarloSearch.principal_line`, added to the addon for this): the most
visited answer, its most drawn outcome, that position's most visited
answer, and on.

**Tuned, a little** (wave 125, 200 iterations, 8 matches a seat against the
weighed enemy, a sample too small to rank by more than a wide margin):

| exploration | playout 8 | playout 16 | playout 30 |
|---|---|---|---|
| 1.41, the addon's | 1 of 16 | 5 of 16 | 2 of 16 |
| 0.5 | 9 of 16 | 2 of 16 | 5 of 16 |
| 0.2 | 5 of 16 | 6 of 16 | 4 of 16 |

The values a playout ends on are small -- a few points of health over 33 --
so the square root of two, chosen for outcomes between 0 and 1, spends the
iterations evenly and the means never get to count. 0.5 and a playout of 8
were kept: the best of the grid, and the cheapest.

**Measured** (wave 125, `make measure-squad-mcts`: against `WeighedSquad`,
match `n` of a seat on dice seed `n`, the searcher seeded `1000 + n`; a
decision searched as the scene searches it, 4 iterations a frame):

| iterations a decision | won as red | won as blue | a decision, on average | at most | worst frame |
|---|---|---|---|---|---|
| 200 | 34 of 100 | 37 of 100 | 0.23 s | 0.45 s | 24 ms |
| 1,000 | 56 of 100 | 63 of 100 | 1.3 s | 2.7 s | 122 ms |
| 5,000 | 12 of 20 | 12 of 20 | 6.1 s | 9.8 s | 202 ms |

No draws, and no action lost to a refused walk in any of them. "A
decision" here is the search's own time, its frames added up, with ten
matches running at once on a 12-core machine and other work beside them.
Two matches a seat at 1,000 iterations on a quieter machine (load about 5):
0.8 s of searching a decision on average, 1.1 s at most.

What a person waits is longer. In the scene the search runs 4 iterations a
frame, so 1,000 iterations is 250 frames: about 4.2 s at 60 frames a
second before the decision has its whole budget (space plays it sooner).
A steady frame costs about 5 ms -- 4.2 ms of search and 1.1 ms of redraw,
measured in the scene by the review -- inside the 16.7 ms a frame has. The
worst frame, 15.6 to 21.6 ms in the scene and 22 ms in the quieter run, is
the one where space plays a decision and the next one starts: the board is
looked at, the guess made, the piece's routes found and the first four
iterations run, then all of it is drawn. That is about one dropped frame
a decision, in a turn-based game; the 122 and 202 ms in the table are that
frame under the load above. 5,000 was measured at 20 matches a seat, not
100: at 6 s of searching a decision and some fifty decisions a match,
2 x 100 matches would have taken most of a day of one core's time.

What it says: at 200 iterations, about five for each of a piece's forty
options, the search is mostly noise, and it loses two games in three. At
1,000 it beats the one-action-ahead baseline more often than not, from
both seats. At 5,000, on a sample a fifth the size, 24 of 40 is no clear
gain over 1,000 for five times the wait. That is why the scene's default is
1,000.

## The enemy that works out the odds: `ExpectiSquad` (T88)

Expectiminimax from `ai_adversarial` (`ExpectiminimaxSearch`), over
`SquadEvaluatedGame`: the same game the MCTS reads, the same question at
the root, and below it the rest of the turn and the other side's -- its own
side's pieces as MAX, the other side's as MIN -- with every shot's hit and
miss as a chance node, weighed by the chance the person is shown. Each of
these was written into the task before the code, for the owner to confirm.

**What the two share** (`SearchingSquad`). Everything that is not the
search moved out of `MctsSquad` into a base both extend: what it believes
of the fog (one guess, as above), how the question is asked, how a refused
walk is answered, how the answer is shown and played, and how the work is
spread over frames. So the two are compared on the same information. The
MCTS's suite, digest included, passed unchanged through the move.

**The evaluation, by hand.** Where expectiminimax stops before the game
ends it has to score the position; MCTS plays on and scores health alone.
Three terms, each in [-1, 1], weighed by `rules.json`'s `evaluation` --
health 0.6, cover 0.2, flanked 0.2:

| term | for the side | why |
|---|---|---|
| health | its health left less the other's, over a full squad's (33) | what a win is made of |
| cover | the cover its pieces hold against each enemy, over a full cover's worth, less the enemy's | a piece in cover is shot at 20 or 40 less |
| flanked | the share of enemies one of its pieces could shoot with no cover facing it, less the share of its own the enemy could | a flank is cover taken away |

The weights add up to 1 and health is below 1 until a squad is gone, so no
estimate reaches a win. Nothing is fitted (invariant 6): the weights are a
guess, and the point of the comparison is that MCTS needs none of it.
Python's `gameaikit.squad.evaluation` is the same arithmetic.

**The budget, a frame at a time.** Iterative deepening -- depth 1, 2, 3 --
`positions_per_frame` positions a frame (20, about 4 ms here, MCTS's 4
iterations' share), to `positions` a decision (5,000, about a second, as
MCTS's 1,000 iterations). Space plays the deepest finished depth's answer;
before depth 1 is done -- two or three frames on a walk -- it holds, and
says so.

**What it shows** (invariant 13). On the board, every answer's expected
value above and a shot's hit chance below, the best framed. In the status:
the depth finished, of how deep it may go, and the positions searched; a
bar for each of the six answers worth most; and for a shot, its two
branches -- in `03 flank` below, `5 shoots 4: expected +0.021 -- hit
55%: +0.045, miss 45%: -0.009` -- so a person can see the dice being
weighed.

## The duel (T88)

`make measure-squad-duel`, kept out of `make check` because the clock and
the machine's load move it. Thirty positions in `spec/squad/duel.json`, drawn by
`godot/test/squad/squad_duel_draw.gd` from six seeded matches of the
weighed enemy against itself, on the board the side to move believes in --
the guess at the fog both searches would make: the opening, four flanks,
four long shots (25% or less, or 6 steps or more), four retreats to cover
(a hurt piece shot at in the open, with a walk to where it would not be),
and the rest spread through the questions left. Both searches are handed
the same board, the same guess already in it, for the same time on the
wall clock: 50, 200 and 1,000 ms. MCTS from seed `1000 + n` for position
`n`. Measured on 2026-11-05, a 12-core machine, load about 3 from other
work:

| a decision | the two agree | MCTS iterations, fewest-most | expectiminimax finished |
|---|---|---|---|
| 50 ms | 16 of 30 | 45-184 | depth 1 on 16, depth 2 on 14 |
| 200 ms | 16 of 30 | 179-1,018 | depth 1 on 7, 2 on 21, 3 on 2 |
| 1,000 ms | 15 of 30 | 891-6,638 | depth 2 on 22, 3 on 8 |

They agree on the shots -- 14 of the 16 shot questions at 50 and 200 ms,
15 at 1,000 -- and almost never on the walks: 2, 2 and 0 of 14.

**One disagreement, worked through: `03 flank`.** Blue's runner, 5 health
at (10, 4), may shoot red's shield at (5, 4) -- 10 health, 45% -- or red's
wader at (7, 2) -- 8 health, 55% -- or hold. Expectiminimax, two
plies deep at 50 ms, worth: hold -0.009, the shield +0.015, the wader
+0.021, so it shoots the wader. Either hit is worth +0.045 and either
miss -0.009 to the evaluation, so the choice is the chance alone: 55%
against 45%. MCTS, with 51 and then 198 iterations -- some 17 to 66 playouts a
shot, each eight random answers long and scored on health -- shoots the
shield. The two shots' expected values are 0.005 apart, a gap far below
what a few dozen noisy playouts can measure. At 1,000 ms, 972 iterations,
its most visited shot is the wader too. The dice are what expectiminimax
does best: it does not sample them, it weighs them.

**And the walks.** A walk question has some forty answers. In 200 ms MCTS
gives each about five playouts, and its most visited walk is close to
chance; expectiminimax, at a ply or two, sees the walk, the shot after it,
and what its evaluation says of the cell -- cover against the enemies, a
flank on them.

**What a ply is here, and what it hides.** A ply is one piece's answer --
a walk, or a shot -- and a side's turn is up to eight of them, four pieces
each walking and shooting. Following the first answer from each of the 30
roots, the other side is to move after 1 ply on five positions (05, 09,
15, 18 and 30, all shots), after 2 on four, and after 3 to 8 on the rest
(T88's review counted them). MIN chooses only above the cutoff, so at
depth 2 -- the gate's depth, and what the clock mostly buys -- the enemy
chooses in 5 of the 30 positions and in none of the 14 walks; at depth 3,
in 2 of the walks. **On a walk, this expectiminimax plays against an enemy
that stands still**: it is expectimax, one side's dice and choices only.
MCTS's playouts do reach the other side's turn. That is the likeliest
reason the two part on the walks, and for the losses to the weighed enemy
below. The next step is a ply counted as a whole side's turn, or a cutoff
counted in turns (a later task). Neither search is right by construction.
The matches say which plays better. Match `n` of a seat on dice seed `n`, each searcher seeded
`1000 + n`, every decision searched for the time shown:

| every decision 50 ms, 100 matches a seat | as red: won, lost, drawn | as blue: won, lost, drawn |
|---|---|---|
| expectiminimax against MCTS | 9, 5, 86 | 53, 43, 4 |
| expectiminimax against the weighed enemy | 2, 98, 0 | 1, 99, 0 |
| MCTS against the weighed enemy | 4, 96, 0 | 3, 97, 0 |

| every decision 200 ms, 20 matches a seat | as red: won, lost, drawn | as blue: won, lost, drawn |
|---|---|---|
| expectiminimax against MCTS | 3, 17, 0 | 4, 16, 0 |
| expectiminimax against the weighed enemy | 0, 20, 0 | 1, 19, 0 |
| MCTS against the weighed enemy | 8, 12, 0 | 9, 11, 0 |

Measured on 2026-11-05 alongside other worktrees' tests, load between 3
and 15 on 12 cores: 100 matches a seat at 50 ms, matches 1 to 100 in four
runs at once; 20 a seat at 200 ms, matches 101 to 120 in two. Not at
1,000 ms: some fifty decisions a side a match make each match a minute and
a half, and 600 of them most of a day. At 50 ms both searches lose almost
every match to the first enemy, which weighs one action ahead in about a
millisecond; between them, expectiminimax wins more than it loses, and as
red most games end drawn at the round limit (not looked into further). At
200 ms the order turns over: MCTS beats expectiminimax 33 to 7, and starts
taking games from the first enemy, as T87 measured -- MCTS gains from every
iteration, expectiminimax only from a whole ply more, forty times dearer.

## Manual check

From `make menu`, open the tactical card in XCOM mode, and play a match in
English and in PT-BR; press M and play a few turns of Advance Wars. Does it
read as one game with two modes? Is the hit chance shown before every shot,
and its reason readable? With the decision view on, can you say before the
enemy acts which option it will take? Does it ever seem to know where an
unseen piece is? And: is the shield behind rock too hard to hit?

T87: give the enemy to MCTS (C) and keep the decision view on. While it
thinks, do the bars grow on the piece's options, and is the one it plays
the one with the most visits? Press space early: is there still a move,
and is it a worse one? Does the expected line read as a plan you can
follow on the board, or as noise?

T88: give the enemy to expecti (C). While it thinks, does the depth in the
status grow, and does the board's framed option change only when a depth
finishes? At a shot, do the hit and miss lines make the choice readable?
Then play a position where the two disagree -- `03 flank` in
`spec/squad/duel.json` is the one worked through above -- with MCTS and
then with expecti: do the two overlays, expected values against visits,
make it clear why each chose what it chose? There is no position picker in
the scene yet: reach a similar shot in play.

Read `spec/squad/rules.json` beside the two UFOpaedia pages: are the
numbers the ones the mode claims to borrow, and is every simplification
said above? Then play `make demo-tactical` as before: is the Advance Wars
mode exactly the game it was?
