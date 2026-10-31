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
