# T84 — An XCOM-style mode of the tactical game: a second ruleset on the same state

Size: M · Prereqs: T61, T63 · Files: `godot/game/tactical/`, `godot/test/tactical/`, `godot/game/squad/`, `godot/test/squad/`, `modules/squad.json`, `modules/tactical.json`, `godot/game/board/`, `godot/test/board/`, `spec/squad/`, `spec/vectors/squad/`, `python/gameaikit/squad/`, `python/tests/`, `Makefile`, `docs/godot/`

## Goal

The owner, 2026-10-26, answering T73's question 2 (where MCTS and a second
board game live): "será que pode ser estilo X-com?" -- confirmed as an
XCOM-style **mode** of the tactical game, on the same `board` module: a
small squad, cover, hit chances, action points and fog. **Not a new game,
and not a rewrite** of the Advance-Wars-style tactical game.

So this task does not build a second game beside the tactical one. It
gives the tactical game a **second ruleset** -- XCOM's shot, cover and fog
-- played on the tactical game's own state, map, pieces, pictures and
keys, entered from the tactical game itself. T85 makes it playable in the
tactical scene; T87 and T88 put search behind it.

What the game it borrows from does, checked on UFOpaedia on 2026-10-26
(the series' community wiki; XCOM: Enemy Unknown, 2012):

- "Time Units have been removed and replaced with a two-part action
  system": two actions a turn, and "a unit's turn automatically ends after
  the unit performs any action other than Move on its 1st Action"
  ([Gameplay Mechanics (EU2012)][mech]).
- Half cover "conveys a -20% hit chance penalty", full cover -40%; "cover
  only grants a defence bonus if a unit is standing directly next to it",
  and from a flanking position "there will be no cover defence bonus
  applied" ([Cover (EU2012)][cover]).
- Overwatch "takes a shot at the next enemy that moves through that unit's
  line of sight. A 20% Aim penalty applies"; hunker down "doubles cover
  bonus" ([mech]).

And why the mode suits search: Roelofs' chapter on MCTS for tactical games
is built on *Xenonauts 2*, "a tactical game akin to X-Com", where a unit
"can move to upwards of 50 different locations and select between 4
different weapons to attack 1 of 16 different targets" [GAP3 ch. 28].

## What is reused, what is extended, what changes in `board`

Read on 2026-10-26 in the code; the task checks it again before writing.

**Reused unchanged**

- `BoardState` (`godot/game/board/board_state.gd`): the graph, the units,
  `current_faction`, `turn_number`, `dice_seed` (a fight's dice already
  live in the state, so a shot replays), `tally`, `apply(Move)` (walks a
  unit and subtracts the route's cost from `movement_points`),
  `end_turn` (refills each unit's `movement_points` from its type).
- `Unit` (cell, health, movement points, faction, type), `UnitType`
  (`movement`, `attack_range`, and `sight` -- which `TacticalRules` says
  "nothing reads" until there is fog; this mode is the first reader),
  `Move`, `Attack`; `GridGraph` from `ai_core`.
- The tactical map and terrain (`TacticalScenario`'s river, bridge, fords,
  trees and rock; `TacticalRules`' ground costs), the walking pieces
  (runner, shield, mortar, wader, ram) and their Kenney pictures through
  `art.gd`, `board_view.gd`, `unit_view.gd`, `unit_walk.gd`,
  `TacticalTurn` (who is spent, undo back to the turn's start),
  `BlueController`'s interface, `intent_view.gd`, and the scene's keys.

**Mapped, not added**: XCOM's two actions are the tactical turn already --
a unit walks and may then attack, and is spent. A squad piece's type gets
twice its one-action range as `movement`; walking within one action's
range leaves it able to shoot, walking further (XCOM's dash) spends it,
and a shot spends it -- which is the "any action other than Move on its
1st Action" rule. `movement_points` carries it; nothing new on `Unit`.

**Extended, in `tactical`** -- a seam, not a rule change:

- `TacticalRuleset`, the interface for what `tactical.gd` today calls
  statically: the starting state (`TacticalScenario.build`), whether an
  attack may be made and what it does (`TacticalCombat.why_refused`,
  `apply`, `told`), the winner (`TacticalVictory.winner`), the board's
  tint (`ThreatMap`), and the roster C cycles. `AdvanceWarsRuleset` wraps
  the existing classes **unchanged**; the scene's default is it, and every
  tactical gate must pass with the same seeds and the same results.
- The menu's tactical card gains `modes`; the scene receives its rulesets
  from whoever opens it, so `tactical` never names `squad` (the edge is
  `squad -> tactical`, and `menu -> squad` as for every example).

**New, in module `squad`** (`godot/game/squad/`, its own manifest so its
gates select on its changes): `SquadRuleset`, `SquadCombat` (the shot),
`SquadCover` (cover read from the terrain around the target), `SideView`
(what a faction sees), `SquadVictory`, the squad scenario (where the two
squads start on the tactical map), `SquadRoster`, and the Python twin.

**`board`: no change is planned.** Cover is read from the terrain cells
next to the target, sight from the graph and the terrain, and the side's
view is a `BoardState` built with the units that side sees -- all in
`squad`. If the task finds `board` must change after all (a line-of-sight
query both rulesets want, say), the change is generic -- no squad word
enters `board`, ADR 0021 -- and it selects every module that depends on
`board`, which the review is told.

## Decisions written down first (confirmed by the owner, 2026-10-29)

The owner confirmed this design as written on 2026-10-29, as
recommended: the seam with `AdvanceWarsRuleset` unchanged, `SquadRuleset`
in module `squad`, the shot and its cover, fog by side, two actions, and
overwatch and hunker down left out. Step 1's reading can still correct a
detail; a change to what the owner confirmed goes back to the owner.

- **The rules, small on purpose**: four pieces a side, chosen from the
  tactical walkers (no workshop, towers, funds or building in this mode);
  hit chance = aim - defence - cover, clamped to [0, 100], one die per
  shot, a fixed damage per piece; aim, defence and damage per piece type
  in `spec/squad/rules.json` (ADR 0007), not on `UnitType`.
- **Cover from the terrain the map already has**: a target standing next
  to rock has full cover (40), next to trees half (20), on the side facing
  the shooter; a shooter outside the arc that cover protects has flanked
  it, and it gets none. Trees and rock block sight, as `TacticalRules`
  already promises for fog.
- **Overwatch and hunker down are left out**: overwatch interrupts the
  other side's turn, which every search in T87 and T88 would have to
  model. A later task can add them once the searches stand.
- **A decision is one unit's action**, not a whole squad's orders: Roelofs'
  "hierarchical expansion", the move split into actions, keeps a search's
  branching near one unit's options rather than their product [GAP3 ch. 28].
- **Fog by side**: a controller is given its side's view -- the enemies it
  sees and where it last saw the others -- never the state.
- **The squad roster is its own table**, not rows added to
  `TacticalRoster`: `League.schedule` seats teams by their place in that
  table, so rows added there would re-roll the league's dice (T63).

## What step 1's reading corrected (wave 113)

None of it changes what the owner confirmed; each is a detail.

- **The seam is wider than the list above.** The scene also called
  `state.apply` for a walk, `TurnStart.open` for a turn's opening,
  `TacticalVictory.rule` and `announcement`, and `TacticalScenario.POINTS`;
  all are on `TacticalRuleset`. `BlueTurn` and `TacticalDecision.played_on`
  take the ruleset too (default Advance Wars), or the computer's moves would
  have been played by the other mode's rules.
- **The menu's `modes` are T85's.** T85's Files line holds `godot/menu/`
  and its step 1 opens the scene with a mode; this task's does not. Here
  the scene takes a `ruleset` before it enters the tree, as it takes
  `computer`.
- **The squad's `UnitType`s are its own**, built from `rules.json` under
  the tactical names (so the pictures and words find them): movement two
  actions, `attack_range` the shot's range, `sight` the rules' -- the
  tactical types see 1-3 cells, too short for a shot across the river.
  `UnitType` gains no field.
- **Sight ignores cover beside either end of the line**, or trees beside a
  target would block every shot that its cover was meant to make harder.
- **`SquadRoster` has one row**, `random`, a seeded random mover on its
  side's view: a roster with no row cannot cycle, and the property check's
  seeded game needs a player. T85 adds the first enemy that weighs.
- **`board` did not change.**

## Steps

1. Read `board_state.gd`, `tactical.gd`, `tactical_combat.gd`,
   `tactical_rules.gd`, `tactical_turn.gd`, `tactical_roster.gd` and
   `check_demos.py`'s C9; confirm the list above or correct it in the task.
   If the reading finds the seam cannot go in without changing what the
   Advance Wars mode does -- its gates' results, its league -- the task
   stops there and puts the choice to the owner with the cost of each:
   the honest mode, paid for by that change; or a separate game on
   `board`, which is not what the owner asked for. It does not go on
   with a separate game on its own.
2. The seam: `TacticalRuleset` and `AdvanceWarsRuleset` in `tactical`; the
   scene reads everything through it; `make check-affected` shows the
   tactical gates and the league unchanged.
3. `spec/squad/rules.json`; `SquadCombat`, `SquadCover`, `SideView`,
   `SquadVictory` and the squad scenario in `godot/game/squad/`, as
   `SquadRuleset`.
4. `python/gameaikit/squad/`: the shot, cover and flanking; hand-checked
   vectors in `spec/vectors/squad/`, read by a gdUnit suite and a Python
   test (`make test-squad-vectors`).
5. A property check over 300 seeded positions on the tactical map: every
   legal action leaves a legal state, a shot or a dash spends the piece,
   no side's view holds an enemy it cannot see, a seeded game replays to
   its digest.
6. `modules/squad.json` (depends on `tactical`, `board`, `ai_core`), and
   `docs/godot/squad.md` with the rules, their sources and every
   simplification.

## Acceptance

```bash
make test-squad-vectors
make test-godot-some SUITES="test/squad test/tactical test/board"
python3 -m unittest discover -s python/tests -t python -p "test_squad*.py"
make test-decisions
python3 scripts/check_demos.py
make lint-modules
python3 scripts/check_readability.py
make lint-tasks lint-status
```

## Manual check

Read `spec/squad/rules.json` beside the two UFOpaedia pages: are the
numbers the ones the mode claims to borrow, and is every simplification
said in `docs/godot/squad.md`? Then play `make demo-tactical` as before:
is the Advance Wars mode exactly the game it was?

How invariant 13 is met: not yet -- T85 draws the decision; this task's
`SideView` and the hit chance with its reasons are what T85 draws from.

[mech]: https://ufopaedia.org/Gameplay_Mechanics_(EU2012)
[cover]: https://ufopaedia.org/index.php/Cover_(EU2012)

References, opened on 2026-10-26: [mech], [cover]; Roelofs, G.-J.
"Pitfalls and Solutions When Using Monte Carlo Tree Search for Strategy
and Tactical Games." Game AI Pro 3, 2017, ch. 28, sections 28.1-28.3
<http://www.gameaipro.com/GameAIPro3/GameAIPro3_Chapter28_Pitfalls_and_Solutions_When_Using_Monte_Carlo_Tree_Search_for_Strategy_and_Tactical_Games.pdf>.
