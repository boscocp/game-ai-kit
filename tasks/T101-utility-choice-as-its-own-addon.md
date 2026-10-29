# T101 — Utility choice as its own addon, out of `ai_teamwork`

Size: M · Prereqs: T67, T70 · Files: `godot/addons/ai_utility/`, `godot/addons/ai_teamwork/`, `godot/test/ai_utility/`, `godot/test/ai_teamwork/`, `godot/test/botmatch/`, `modules/ai_utility.json`, `modules/ai_teamwork.json`, `modules/botmatch.json`, `modules/infiltration.json`, `python/gameaikit/utility/`, `python/gameaikit/teamwork/`, `spec/vectors/utility/`, `spec/vectors/teamwork/`, `python/tests/`, `godot/game3d/botmatch/`, `godot/game3d/infiltration/`, `docs/techniques/`, `docs/concepts/the-literature-and-the-kit.md`, `Makefile`

## Goal

The owner, 2026-10-26, answering T73's question 5: part B "segue o
recomendado" -- B.2 with MCTS (T88), and **B.6, utility choice as its own
addon**. T73's page: "`ActionChoice` and `ErrandChoice` live in
`ai_teamwork`, though nothing in them is about teams, and the bot match and
the infiltration guards both use them. Moving them out would let a game
take utility choice without taking teamwork."

It is a move, not a new technique: the lesson is the one T58 to T63
taught -- a module any game can take is one whose name and folder say what
it is. The scored-considerations technique is GAP1 ch. 9's [Graham 2013],
and T73's table lists it.

## Decisions written down first (the owner confirms in review)

- **Name: `ai_utility`.** If T64's naming ADR has landed, its rule
  applies (only ports and the kernel prefixed, so a technique addon's
  folder keeps this form); if not, T64's pass covers it. Doing this task
  **before T64** is recommended, so the library ships the final shape.
- **What moves**: `ActionChoice` and `ErrandChoice`, the two the owner's
  B.6 names, with their Python twins and vectors. **What is examined and
  decided in the task**, one line each in the review: `AimChoice` (aims
  by zone and spread -- shooting, so likely stays), `PassageChoice` (a
  request a teammate weighs -- teamwork, so likely stays). A class moves
  only if nothing in it is about teams.
- **No alias left behind**: `class_name` is global in Godot, so the moved
  classes keep their names and only their folder changes; nothing in
  `ai_teamwork` refers to them after the move. If any `ai_teamwork` class
  uses them, that use is the finding -- invariant 2 forbids `ai_teamwork`
  depending on `ai_utility`, so the class either moves too or the shared
  part becomes the game's.
- **Its first new user**: T85's squad enemy, if it lands after this, uses
  `ai_utility` -- a third game for the technique.

## What the wave decided (wave 103)

- **`ActionChoice` and `ErrandChoice` moved**, with their `.uid`s (moved with
  them, so each script keeps its uid; the import rewrote none), the
  Python twins (`gameaikit.utility.action`, `.errands`), their 21 vectors
  (byte for byte: `spec/vectors/utility/derive.py` is the utility half of
  the old teamwork `derive.py`, and writes every file identical to what is
  committed), the refusal test and the fighter example. Neither file has a
  team word; no `ai_teamwork` class used either, so nothing had to move
  with them and nothing is left behind.
- **`AimChoice` stays.** Nothing in it is about a team either -- it is one
  shooter's hit model (zones, a spread, rolls) and the zone worth most --
  so the rule "moves only if nothing in it is about teams" does not keep
  it here; what does is that it is not scored choice in the sense B.6
  names. It is a shooting technique that lives in `ai_teamwork` because the
  bot match's shooting was put there. Where it belongs is the owner's to
  say -- a shooting addon, or T64's naming pass; this wave does not decide
  it. T64's task file records it as open (the review's nit).
- **`PassageChoice` stays.** Its ask is a request to a teammate, and the
  teammate's answer (`Request`, `Prices`, `answer`) is half the class:
  that is teamwork.
- **`ai_teamwork`'s page needed a new minimal example**, since the fighter
  went with `ActionChoice`: `squad_example.gd`, one flank granted by
  `RoleArbiter`, run by `squad_example_test.gd`.
- **One test path changed, no number**: `botmatch_test.gd` reads the bot
  match's copied actions from `spec/vectors/utility/` now.

## Steps

1. `grep` every use of the two classes (the bot match, infiltration's
   guards, the teamwork tests, the vectors' README, the technique pages);
   read `action_choice.gd` and `errand_choice.gd` for any team word.
2. Move the files, their `.uid`s, their tests and vectors; run
   `./scripts/godot --headless --path godot --import` (CLAUDE.md: a moved
   `class_name` is invisible until imported) and commit what it writes.
3. Manifests: `ai_utility` owns its folders; `botmatch` and
   `infiltration` depend on it; `ai_teamwork` loses what moved.
4. The technique pages: a new `ai_utility` pair (English and pt-BR,
   T74's shape), `ai_teamwork`'s pair shortened; the catalogue (T76)
   regenerated; the literature table's utility row names `ai_utility`.
5. The bot match's and infiltration's gates pass unchanged: the same
   seeds, the same results -- a move changes no number.

## Acceptance

```bash
make lint-modules
python3 scripts/check_addon_deps.py
make test-teamwork-vectors
make test-utility-vectors
make test-godot-some SUITES="test/ai_utility test/ai_teamwork test/botmatch test/infiltration"
python3 scripts/check_translations_docs.py
python3 scripts/catalogue.py --check
python3 scripts/check_literature_table.py
python3 scripts/check_readability.py
make lint-tasks lint-status
```

## Manual check

Read the `ai_utility` page as someone who wants only scored choice for
their own game: can they copy `ai_utility` and nothing else,
and does the example run?

How invariant 13 is met: unchanged -- the bot match's V view and the
infiltration level's thinking view draw every option's score before the
choice, as they do now; this task must leave both populated
(`check_demos.py` holds it).

References: Graham, D. "An Introduction to Utility Theory." Game AI Pro,
2013, ch. 9, as cited by T73.
