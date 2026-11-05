# T87 — MCTS plays the XCOM-style mode

Size: M · Prereqs: T85, T86 · Files: `godot/game/squad/`, `godot/test/squad/`, `spec/squad/`, `python/gameaikit/squad/`, `python/tests/`, `modules/squad.json`, `docs/godot/squad.md`, `Makefile`

## Goal

The owner, 2026-10-26: MCTS first, its home the tactical game's XCOM-style
mode ("será que pode ser estilo X-com?"; T84, T86 quote it). T86 put MCTS
in `ai_adversarial` on Nim; this task makes it the squad mode's enemy and
measures it against T85's one-action baseline.

## Decisions written down first (the owner confirms in review)

- **The squad's `AdversarialGame` adapter lives in `squad`**: `actions`
  are the unit to move's legal actions (T84's one-unit decision),
  `outcomes` of a shot are hit and miss with T84's hit chance, `evaluate`
  each side's health left normalised to [-1, 1]. Its constants are in
  `spec/squad/rules.json`. The addon learns nothing about squads.
  (Noted in wave 113: `SquadRuleset.actions` lists every walk and shot of
  the side to move and has no hold or end-turn entry, and it is not yet
  per unit; the adapter adds both.)
- **Fog**: MCTS searches its side's view (T84's `SideView`); unseen
  enemies stand where they were last seen. One determinization, said so
  on the page; sampling several is a later choice.
- **The budget**: iterations per frame, so the tactical scene keeps
  drawing while the enemy thinks, with a stop key that plays the best
  answer so far (anytime).
- **The squad positions are the squad's gate**, not the addon's: a
  committed set in `spec/squad/positions.json` and their expected
  decisions at fixed seeds are held in `godot/test/squad/` and the squad's
  Python tests -- `python/gameaikit/adversarial/` never imports squad.

## What the work decided, for the owner to confirm (wave 125)

None of it changes a decision above; each is a detail the task left open.

- **The scene's one new hook**: `BlueController.keep_thinking()` (no, for
  every controller but this one) and `TacticalGame._process`, which asks it
  each frame and redraws. Six lines in `tactical.gd`; STATUS item 19's
  move of the presentation hooks was not made.
- **The anytime decision is rewritten in place**: the `TacticalDecision`
  the scene holds is the one the search updates each frame, so space plays
  what is drawn. Enter (the rest of the turn) lets each search finish
  before its decision is played (wave 125's review): the window waits
  about a second a piece.
- **An answer names its piece** -- `["walk", id, cell, cost]` -- so the
  expected line can say whose move each is; a walk carries its cost, not
  its route. The search floods with its own Dial's-bucket Dijkstra
  (`SquadSearchGame.reach`), about fifteen times quicker than
  `TacticalReach.walks_for`, held to it cell for cell and cost for cost.
- **A question with only "hold" is passed over**, and the turn passes after
  the side's last piece.
- **`evaluate`** is the health difference over a full squad's (33); +1, -1
  or 0 at the end. `result` of a shot, for a search with no dice, is the
  likelier outcome.
- **The guess at the fog**: an unseen enemy as hurt as when last seen; one
  never seen where the scenario starts it; a guess on a cell its side sees
  empty, or that is taken, moved to the nearest unseen free cell.
- **The numbers** (`rules.json`'s `search`): exploration 0.5, not the
  addon's square root of two; a playout of 8; 1,000 iterations a decision;
  4 a frame. Tuned on a small grid, kept on the page.
- **`MonteCarloSearch.principal_line`**, in both languages, with a test
  each: the addon gains a public method for the expected line.
- **The does-not-cheat check moved** into `SquadUnseenCheck`, shared by
  both enemies; `MctsSquad` is held over 24 positions at 50 iterations, more
  than a walk question's answers, so the tree grows below the root.
- **The vectors' visits come from one run**, not by hand; what holds them
  is the two languages agreeing.
- **No new strength gate**: `make test-squad-match` is unchanged, and
  `make measure-squad-mcts` measures, as `measure-player-model` does.
- **Files outside the Files line**: `godot/game/tactical/blue_controller.gd`
  and `tactical.gd` (the hook), `godot/addons/ai_adversarial/mcts.gd` and
  `python/gameaikit/adversarial/mcts.py` with their tests (the line),
  `godot/menu/catalogue.json` (the card's controllers and technique), and
  `godot/locale/squad.csv`.

## Steps

1. The adapter, and `MctsSquad`, a row in `SquadRoster`.
2. The decision view: for the unit about to act, each option's visits (a
   bar), mean value and UCB bound, updated each frame while the search
   runs; the principal line after it.
3. Squad vectors: three positions, the root's visit counts after a fixed
   number of iterations and seed, equal in both languages
   (`make test-squad-search-vectors`).
4. Measured and written down in `docs/godot/squad.md`: MCTS at 200, 1,000
   and 5,000 iterations against `WeighedSquad`, 100 seeded matches a seat
   each, with the time a decision takes and the worst frame.
5. The does-not-cheat gate of T85 extended to `MctsSquad`.

## Acceptance

```bash
make test-squad-search-vectors
make test-squad-match
make test-godot-some SUITES="test/squad"
python3 -m unittest discover -s python/tests -t python -p "test_squad*.py"
python3 scripts/check_demos.py
make lint-modules
python3 scripts/check_readability.py
make lint-tasks lint-status
```

## Manual check

In the tactical game's XCOM mode, give the enemy to MCTS (C) and turn on
the decision view: while it thinks, do the visit counts on each of the
unit's options grow, and does the one it plays have the most? Stop it
early: is there still a move, and is it a worse one?

How invariant 13 is met: step 2 -- the search's tree read at its root,
drawn on the board while it runs and before the action is played.
