# T84 — An XCOM-style mode of the tactical game: the rules

Size: M · Prereqs: T61 · Files: `godot/game/squad/`, `godot/test/squad/`, `modules/squad.json`, `spec/squad/`, `spec/vectors/squad/`, `python/gameaikit/squad/`, `python/tests/`, `Makefile`, `docs/godot/`

## Goal

The owner, 2026-10-26, answering T73's question 2 (where MCTS and a second
board game live): "será que pode ser estilo X-com?" -- confirmed as an
XCOM-style **mode** of the tactical game, on the same `board` module: a
small squad, cover, hit chances, action points and fog. Not a new game, and
not a rewrite of the Advance-Wars-style tactical game, which stays as it is.

It is the home of three later tasks: MCTS (T86), expectiminimax facing the
same positions (T87, roadmap B.2), and generated maps (T95). This task is
the rules alone, headless, with a Python twin of the numbers that decide a
shot; T85 makes it playable.

What the game it builds on does, checked on UFOpaedia on 2026-10-26 (the
community wiki of the series; XCOM: Enemy Unknown, 2012):

- "Time Units have been removed and replaced with a two-part action
  system": each soldier has two actions a turn, and "a unit's turn
  automatically ends after the unit performs any action other than Move on
  its 1st Action" ([Gameplay Mechanics (EU2012)][mech]).
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

## Decisions written down first (the owner confirms in review)

- **A mode on `board`, in its own example module `squad`**, beside
  `tactical`, not inside it: `godot/game/squad/`, `modules/squad.json`
  depending on `board` and `ai_core`. The tactical module's controllers,
  roster and league are untouched; the menu gets a second card (T85).
  Alternative: a switch inside `tactical` -- rejected, it would make every
  tactical gate select on squad changes.
- **What the board must add, and only that**: a cover value per edge
  between cells (none, half, full) and a line-of-sight query. If `board`
  needs a change, ADR 0021's kernel rule applies: the change is generic
  (a cell's edges, a sight line), and no squad word enters `board`.
- **The rules, small on purpose**: four soldiers against four aliens on a
  12 x 12 map; two actions a turn, a shot as the first action ends the
  turn; hit chance = aim - defence - cover (half 20, full 40, none when
  flanked), clamped to [0, 100], and a fixed damage per weapon; a soldier
  dies at 0 health. **Overwatch and hunker down are left out** of this
  task: overwatch interrupts the other side's turn, which every search in
  T86 and T87 would have to model. A later task can add them once the
  searches stand.
- **A turn is one unit's action, not a whole squad's order.** The side to
  move keeps moving until its soldiers have spent their actions, then the
  turn passes. This is Roelofs' "hierarchical expansion" -- the move split
  into actions -- and it is what keeps the branching per node near one
  unit's options rather than their product [GAP3 ch. 28].
- **Fog: each side sees what its units see**, by the board's sight line.
  The state a controller is given is its side's view: enemies it sees and
  the last place it saw each of the others. A search that read the true
  state would cheat; T85's gate holds that it cannot.
- **The dice are the board's**: one seeded generator, as ADR 0008's
  combat; a shot's result is a draw against its hit chance, so a replay
  from the seed and the orders is exact.

## Steps

1. Read the `board` module (`godot/game/board/`) and ADR 0021; write the
   cover-and-sight addition there, generic, with its own gdUnit cases.
2. `spec/squad/rules.json`: the numbers above (actions, aim, defence,
   cover, damage, health, sight radius), the one file both languages read
   (ADR 0007).
3. `godot/game/squad/`: the state, the legal actions of the unit to move
   (move to a reachable cell within one action's range, shoot a seen
   enemy, end its turn), applying an action, the side's view under fog,
   and the end of the game (one side has no one left, or a turn limit).
4. `python/gameaikit/squad/`: the same rules, the same numbers. Hit-chance
   and flanking vectors in `spec/vectors/squad/`, hand-checked, read by a
   gdUnit suite and a Python test (`make test-squad-vectors`).
5. A property check over 300 generated positions: every legal action
   leaves a legal state, the two actions are spent then the turn passes,
   no view contains an enemy its side cannot see, and a seeded game
   replays to the same digest.
6. `modules/squad.json` owns the folders, declares its gates; a short
   `docs/godot/squad.md` with the rules and their sources.

## Acceptance

```bash
make test-squad-vectors
make test-godot-some SUITES="test/squad test/board"
python3 -m unittest discover -s python/tests -t python -p "test_squad*.py"
make lint-modules
python3 scripts/check_readability.py
make lint-tasks lint-status
```

## Manual check

Read `spec/squad/rules.json` beside the two UFOpaedia pages: are the
numbers the ones the mode claims to borrow, and is every simplification
said in `docs/godot/squad.md`?

How invariant 13 is met: not yet -- this task has no screen. T85 draws the
decision; this task's `view` is what T85 draws from.

[mech]: https://ufopaedia.org/Gameplay_Mechanics_(EU2012)
[cover]: https://ufopaedia.org/index.php/Cover_(EU2012)

References, opened on 2026-10-26: [mech], [cover]; Roelofs, G.-J.
"Pitfalls and Solutions When Using Monte Carlo Tree Search for Strategy
and Tactical Games." Game AI Pro 3, 2017, ch. 28, sections 28.1-28.3
<http://www.gameaipro.com/GameAIPro3/GameAIPro3_Chapter28_Pitfalls_and_Solutions_When_Using_Monte_Carlo_Tree_Search_for_Strategy_and_Tactical_Games.pdf>.
