# T60 — `ai_learning` without the board

Size: M · Prereqs: T58 · Files: `godot/addons/ai_learning/`, `godot/game/tactical/`, `godot/game/fighting/`, `godot/test/ai_learning/`, `godot/test/tactical/`, `python/gameaikit/training/`, `python/gameaikit/dataset/`, `python/gameaikit/cloning/`, `modules/`, `scripts/check_no_training.py`, `Makefile`, `docs/`

## Goal

The first of the ports-and-kernel tasks T58 planned ("one addon a wave,
`ai_learning` first", D4). Someone who wants a logistic model for their own
game copies `ai_learning` today and gets the tactical board with it. After
this task the addon is the technique -- a model, its file, a case table --
and the game that uses it writes the adapter.

## Diagnosis (measured 2026-10-20 on `5129bfc`)

Lines are the file's whole length and, in brackets, its code lines with
comments left out; "reaches for" counts code only.

| file | lines | reaches for |
|---|---:|---|
| `learned_model.gd` | 93 (34) | nothing |
| `softmax_model.gd` | 103 (51) | nothing |
| `case_table.gd` | 101 (46) | nothing |
| `model_file.gd` | 239 (132) | `LearnedModel` (a comment names `BoardFeatures`) |
| `cloned_player.gd` | 123 (78) | `CaseTable`, `SoftmaxModel`; situations as words, no game type |
| `learned_decision.gd` | 115 (58) | `Move`, `Unit` |
| `board_features.gd` | 204 (95) | `BoardState`, `Unit`, `UnitType`, `GridGraph` |
| `learned_policy.gd` | 315 (163) | `BoardState`, `Unit`, `Move`, `DecisionPolicy`, `Pathfinder` |

Five files are the technique and three the tactical board's adapter.
`weights.json`/`weights.txt` are the tactical model's published weights and
`clone_weights.json` the fighting clone's: data of a game, kept in the
technique's folder, and named by two constants of the technique,
`ModelFile.DEFAULT_PATH` and `ClonedPlayer.DEFAULT_PATH` -- `res://` paths
into the addon that name a game's file. Only `ClonedPlayer.load_from` uses
its constant as a default; `ModelFile.load_from` already takes a path, and
callers pass the constant (`main.gd:84`, `learned_blue.gd:111`,
`clone_fights.gd:58`, two tests, and `check_no_training.py`'s
`CLONE_NAMES_RE`). `python/gameaikit/cloning/` writes `clone_weights.json`
into the addon. Three of the four suites in `godot/test/ai_learning/`
(`decision_scenarios`, `learned_policy_test`, `learning_test`) test the
adapter, not the technique.

The Python half has the same seam. `gameaikit.training` is generic in
`descent.py`, `models.py`, `split.py` -- and `train.py`, `report.py`,
`evaluate.py` import `gameaikit.dataset` (the tactical rows and board). So
`gameaikit.checkers.train`, which needs only `descent` and `models`, depends
on the tactical game through the package it borrows from. And by
ownership: `python/gameaikit/training/` is listed in `modules/tactical.json`,
and `modules/checkers.json` depends on `tactical` -- so a change to the
tactical dataset selects checkers today (measured: `checkers` is in the
`selected:` line for `python/gameaikit/dataset/rows.py`).

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
   technique's loaders take one with no default -- so the callers listed
   above change, each to its own game's path. The three adapter suites
   move to `godot/test/tactical/`. `git mv` with the `.uid` files, one
   commit with no content change, then
   `./scripts/godot --headless --path godot --import`. Every path that names
   the old folder follows; `grep -rn 'addons/ai_learning/' godot python spec
   scripts docs Makefile` lists them, `gameaikit.cloning`'s output path
   among them.
3. **The technique's header says what it is now**: a model, its file and a
   case table, inference only; when not to use it. `ModelFile`'s comment that
   names `BoardFeatures` goes.
4. **The Python seam.** `train.py`, `report.py`, `evaluate.py` move to the
   tactical side (`gameaikit.dataset`, or a `gameaikit.tactical` if the
   module reads better -- decided by which one a reader finds first);
   `gameaikit.training` keeps `descent`, `models`, `split`, and moves from
   `modules/tactical.json` to `modules/ai_learning.json` (the Python half of
   the technique, as T58 step 2 found it to be). `checkers` then depends on
   `ai_learning`, not on `tactical`, unless the measurement finds another
   reason it does. Every
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
! printf 'python/gameaikit/dataset/rows.py\n' | python3 scripts/affected.py --paths - | grep -qE '^selected:.*\bcheckers\b'
```

```bash
python3 scripts/check_no_training.py --self-test
```

```bash
python3 -c "import json,sys; sys.exit('tactical' in json.load(open('modules/checkers.json'))['depends_on'])"
```

## Manual check

Read `godot/addons/ai_learning/` top to bottom as someone who has never seen
the tactical board: does it teach a model and stop there?

## Out of scope

- `BoardState` and the rest of the board leaving `ai_core` (T61).
- Retraining anything: the weights move, byte for byte.
- A new model kind.
