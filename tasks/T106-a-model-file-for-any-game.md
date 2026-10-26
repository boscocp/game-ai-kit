# T106 — A model file any game can load

Size: M · Prereqs: T75 · Files: `godot/addons/ai_learning/`, `godot/game/tactical/`, `godot/game/main.gd`, `godot/test/ai_learning/`, `godot/test/tactical/`, `python/gameaikit/training/`, `python/gameaikit/tactical/report.py`, `spec/vectors/model_file/`, `modules/`, `docs/techniques/ai_learning*.md`

## Goal

Two defects wave 90 found and recorded in STATUS, the owner approved fixing
on 2026-10-26, and T64 (the library) needs gone. `ModelFile`, the addon's
loader, refuses any file without the tactical game's four
`feature_conventions`, so outside that game a reader builds `LearnedModel`
by hand: the addon is not usable by somebody else's game. And
`modules/checkers.json` declares `ai_learning` for the game, when only its
test folder's learned-evaluation example uses it.

The addon keeps what every model file has -- `models`, each with `kind`,
`features`, `weights` and `bias` -- and refuses what is wrong with those.
The tactical game's conventions become the tactical game's own check,
layered on top in `godot/game/tactical/`, the way the Python side already
checks them in `gameaikit.tactical.report` and not in `gameaikit.training`.
The published `weights.json` loads unchanged: no field is added and none
retrained (invariant 6, and `check_no_training.py` compares it).

## Steps

1. `ModelFile` validates the generic format only (M1-M8, M10) and hands
   everything else the file carries to its reader as `extra`; a text entry
   (`from_text`) so a game can hold its JSON however it likes.
2. The tactical game's check (`TacticalWeights`): the four conventions, as
   `gameaikit.tactical.report` checks them (W6, and the reversed range W7),
   over a loaded `ModelFile`. Every tactical and skirmish reader takes it.
3. The Python twin, `gameaikit.training.model_file`: the generic writer
   `report.py` uses and the same refusals; `spec/vectors/model_file/` holds
   both languages to the same code for each planted file.
4. The technique page, both languages: the example loads a model file of
   its own through `ModelFile`; the finding goes.
5. `checkers.json`: `ai_learning` moves to `tests_depend_on`; the catalogue
   regenerated.
6. STATUS: the two follow-up lines go.

## Acceptance

```bash
make test-godot-some SUITES="test/ai_learning test/tactical test/skirmish test/checkers"
make test-learning-vectors test-combat-vectors test-cloning-vectors
make test-python-some PYTESTS="test_model_file test_training test_learning_vectors"
python3 scripts/check_no_training.py
python3 scripts/catalogue.py --check
python3 scripts/check_translations_docs.py
make lint-modules lint-tasks lint-status lint-readability
```

## Manual check

Copy `godot/addons/ai_learning/` alone into an empty Godot project, write a
weights file with one model and nothing else, and load it with
`ModelFile.load_from`: does it load, and does the page say all you needed?
