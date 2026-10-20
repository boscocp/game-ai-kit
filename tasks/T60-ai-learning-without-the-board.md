# T60 — `ai_learning` without the board

Size: M · Prereqs: T58 · Files: `godot/addons/ai_learning/`, `godot/game/tactical/`, `godot/game/fighting/`, `python/gameaikit/training/`, `python/gameaikit/dataset/`, `modules/`, `scripts/check_no_training.py`

## Goal

The first of the ports-and-kernel tasks T58 planned ("one addon a wave,
`ai_learning` first", D4). Someone who wants a logistic model for their own
game copies `ai_learning` today and gets the tactical board with it. After
this task the addon is the technique -- a model, its file, a case table --
and the game that uses it writes the adapter.

## Diagnosis (measured 2026-10-20 on `5129bfc`, code lines, doc comments excluded)

| file | lines | reaches for |
|---|---:|---|
| `learned_model.gd` | 93 | nothing |
| `softmax_model.gd` | 103 | nothing |
| `case_table.gd` | 101 | nothing |
| `model_file.gd` | 239 | `LearnedModel` (a comment names `BoardFeatures`) |
| `cloned_player.gd` | 123 | `CaseTable`, `SoftmaxModel`; situations as words, no game type |
| `learned_decision.gd` | 115 | `Move`, `Unit` |
| `board_features.gd` | 204 | `BoardState`, `Unit`, `UnitType`, `GridGraph` |
| `learned_policy.gd` | 315 | `BoardState`, `Unit`, `Move`, `DecisionPolicy`, `Pathfinder` |

Five files are the technique and three the tactical board's adapter.
`weights.json`/`weights.txt` are the tactical model's published weights and
`clone_weights.json` the fighting clone's: data of a game, kept in the
technique's folder, and found by it through `ModelFile.DEFAULT_PATH` and
`ClonedPlayer.DEFAULT_PATH` -- two `res://` paths into the addon that name a
game's file.

The Python half has the same seam. `gameaikit.training` is generic in
`descent.py`, `models.py`, `split.py` -- and `train.py`, `report.py`,
`evaluate.py` import `gameaikit.dataset` (the tactical rows and board). So
`gameaikit.checkers.train`, which needs only `descent` and `models`, depends
on the tactical game through the package it borrows from, and a change to
the tactical dataset selects checkers.

## Steps

1. **Measure first, on the branch, before moving anything**: what
   `affected.py --paths` selects today for a change to `board_features.gd`,
   to `learned_model.gd` and to `python/gameaikit/dataset/rows.py`. The
   numbers go in this file, beside step 6's.
2. **The adapter moves to the game.** `board_features.gd`,
   `learned_policy.gd`, `learned_decision.gd`, `weights.json`,
   `weights.txt` to `godot/game/tactical/`; `clone_weights.json` to
   `godot/game/fighting/`. The two `DEFAULT_PATH`s leave the addon: the game
   that owns the file passes its path (`load_from(path)`), and the
   technique's loaders take one with no default. `git mv` with their
   `.uid` files, one commit with no content change, then
   `./scripts/godot --headless --path godot --import`. `class_name` keeps
   the names, so callers do not change; `res://` paths that name the old
   folder do, and `grep -rn 'addons/ai_learning/' godot python spec scripts`
   lists them.
3. **The technique's header says what it is now**: a model, its file and a
   case table, inference only; when not to use it. `ModelFile`'s comment that
   names `BoardFeatures` goes.
4. **The Python seam.** `train.py`, `report.py`, `evaluate.py` move to the
   tactical side (`gameaikit.dataset`, or a `gameaikit.tactical` if the
   module reads better -- decided by which one a reader finds first);
   `gameaikit.training` keeps `descent`, `models`, `split`. Every
   `python -m gameaikit.training...` in the Makefile, the docs and
   `check_no_training.py` follows.
5. **Manifests and gates follow the files.** `ai_learning` `depends_on`
   becomes `[]`; `tactical` and `fighting` gain what they now own;
   `check_no_training.py`'s N-rules name the weights' new paths, each with
   its planted case still failing (`--self-test`). `make lint-modules`
   holds the rest.
6. **Measure again**, the three paths of step 1.

## Acceptance

```bash
make check
```

The technique's code names nothing of the board:

```bash
! grep -vE '^\s*#' godot/addons/ai_learning/*.gd | grep -wE 'BoardState|Unit|UnitType|Move|DecisionPolicy|GridGraph|Pathfinder'
```

```bash
python3 -c "import json,sys; sys.exit(json.load(open('modules/ai_learning.json'))['depends_on'] != [])"
```

A change to the tactical dataset no longer selects checkers:

```bash
! printf 'python/gameaikit/dataset/rows.py\n' | python3 scripts/affected.py --paths - | grep -qx checkers
```

```bash
python3 scripts/check_no_training.py --self-test
```

## Manual check

Read `godot/addons/ai_learning/` top to bottom as someone who has never seen
the tactical board: does it teach a model and stop there?

## Out of scope

- `BoardState` and the rest of the board leaving `ai_core` (T61).
- Retraining anything: the weights move, byte for byte.
- A new model kind.
