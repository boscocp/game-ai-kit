# Behaviour cloning — the fighter that plays like you

<!-- doc-meta
half_life: practice
verified_on: 2026-10-26
tier: 2
source: https://www.gamedeveloper.com/programming/the-killer-groove-the-shadow-ai-of-killer-instinct
invalidated_if: ClonedPlayer, SoftmaxModel, CaseTable, the clone file's shape or gameaikit.cloning's publish change, or demo-fighting is renamed
teaches: behaviour-cloning
-->

> Português: [behaviour_cloning.pt-BR.md](behaviour_cloning.pt-BR.md). The
> words that stay in English are in the [glossary](glossary.pt-BR.md).

## What it decides {#what}

What a recorded player would do in this situation. Every fight the player
plays is kept as an input log; each decision in it becomes a row -- the
situation in a few words (the last action, the distance, the health, a
corner) and the action the player took. From the rows come two opponents.
A **ghost** (`CaseTable`) looks the situation up: what the player did in
exactly this one, or in the nearest ones it met. A **clone**
(`SoftmaxModel`) is a model fitted in Python, which gives a probability for
every action even in a situation the player never met. Killer Instinct's
Shadows are this kind: if you never block while training your shadow, it
never blocks.

## When not to use it {#when-not}

An opponent that should be good: a clone is as good as the player
recorded, and only in situations the player met. Few recordings: a ghost
then knows nothing about most of the fight, and a clone guesses from the
little it saw. Many features with many words each: the situations multiply
past anything a player meets. And timing a player holds an action for: the
rows keep one decision per change of action, so the clone decides sooner
than the player did.

## Where to watch it {#watch}

- `make demo-fighting` -- **M** cycles the dummy: "ghost: exact", "ghost:
  nearest" and "clone" fight like the recorded player. The panel shows the
  situation it read and what it chose from, and **P** pauses, **space**
  steps a frame.
- `make record-fights` -- play the training mode and keep every fight,
  for the next clone to learn from.
- Which demo uses which technique, both ways: the catalogue (T76, coming).

## In this kit {#in-this-kit}

Godot records and replays: `make record-fights` keeps each fight as an
input log in `data/fights/`, and `make clone-rows` replays them and cuts
one row per decision into `data/cloning/rows.json` -- only Godot can replay
a fight. Python fits: `python/gameaikit/cloning/` fits the softmax model,
counts the ghost's table and writes both to
`godot/game/fighting/clone_weights.json` (`make train-clone`).
`godot/game/fighting/fight_clone_opponent.gd` plays it through
`ClonedPlayer`. The knobs that matter:

| knob | where | what it changes |
|---|---|---|
| whose play | `CLONE_PLAYER` for `make train-clone` | the recorded player, or a scripted stand-in |
| the features | the situation the rows are cut with | what the clone can tell apart; each word is a column |
| exact or nearest | `CaseTable.exact`, `CaseTable.nearest` | what a ghost does in a situation the player never met |
| ghost or clone | **M** in the game | a lookup or a fitted model, from the same rows |

## In your own project {#your-project}

### What to copy {#copy}

The Python side fits: `python/gameaikit/cloning/` (standard library only)
-- `softmax.py` the model, `ghost.py` the table, `publish.py` the file.
The Godot side only reads: `godot/addons/ai_learning/`, whose
`ClonedPlayer.load_from(path)` loads and checks the file, and whose
`SoftmaxModel` and `CaseTable` answer. Recording and cutting rows are your
game's: the kit's are in `godot/game/fighting/` and
`godot/test/fighting/export_clone_rows.gd`.

### A minimal example {#example}

An opponent of yours that plays like a recorded player, from the file
Python published: the clone's likeliest answer, its chances, and what the
ghost would do. This file is run by `clone_example_test.gd`, and the gate
holds the page equal to it.

<!-- example: godot/test/fighting/clone_example.gd -->
```gdscript
# The minimal example on docs/techniques/behaviour_cloning.md, run by
# clone_example_test.gd. An opponent of your own that plays like a recorded
# player: the model Python fitted to its decisions, and the ghost -- the
# table of what it did in each situation it met.
extends Node

var _player: ClonedPlayer


## Load the cloned player Python published at `path`. Returns "" when it
## loaded, or why not, with a code -- a half-read file is never played.
func load_player(path: String) -> String:
	_player = ClonedPlayer.load_from(path)
	return _player.error


## What the clone does in `situation` -- its features by name, each a word
## -- the likeliest answer of the fitted model.
func clone_answer(situation: Dictionary) -> String:
	return _player.model.likeliest(situation)


## How likely each answer is in `situation`: what a panel draws, so the
## player sees how sure the clone is.
func clone_chances(situation: Dictionary) -> Dictionary:
	return _player.model.probabilities(situation)


## What the recorded player did in the situations nearest `situation`, as
## answer to count: the ghost, looked up rather than fitted.
func ghost_counts(situation: Dictionary) -> Dictionary:
	return _player.cases.nearest(situation)["counts"]
```

### What you implement {#implement}

A recording: your game's inputs, frame by frame, so a fight can be played
again. Rows: replay each recording and write, at each decision, the
situation as words and the action taken -- the same words your game will
build when it asks. Then fit in Python, publish, and in Godot build the
situation each decision and ask. Call `load_player` and show its message
when it is not `""`: a file with anything wrong is refused whole, with a
code (C1 to C7), never half played. A word the model never saw adds
nothing and leaves the answer to the other features.

## Deeper {#deeper}

- The Shadows, the ghost and the clone, measured:
  [concepts/behaviour-cloning.md](../concepts/behaviour-cloning.md).
- The file and the Godot side: [godot/cloning.md](../godot/cloning.md).
- The model's half of the addon: [ai_learning](ai_learning.md).
