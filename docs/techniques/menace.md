# MENACE — the matchbox machine that learns noughts and crosses

<!-- doc-meta
half_life: practice
verified_on: 2026-10-26
tier: 2
source: book:Donald Michie, "Experiments on the mechanization of game-learning, part I", The Computer Journal 6(3), 1963
invalidated_if: MenacePlayer, the bead file's shape or gameaikit.menace's report change, or demo-tictactoe is renamed
teaches: reinforcement-learning
-->

> Português: [menace.pt-BR.md](menace.pt-BR.md). The words that stay in
> English are in the [glossary](glossary.pt-BR.md).

## What it decides {#what}

Where to play in noughts and crosses, by drawing a bead. Donald Michie's
1961 machine was a matchbox for every position it could meet, each holding
coloured beads, one colour per empty square. To move, draw a bead from the
box for this position and play its square; after the game, add beads to
every box used if it won, fewer if it drew, take them away if it lost. A
square that keeps winning collects beads and is drawn more often. That is
reinforcement learning from reward alone, with the whole policy on the
table to count. Positions that are the same board turned or mirrored share
a box. The paper: Michie, *The Computer Journal*, 1963.

## When not to use it {#when-not}

Any game with more positions than you would build matchboxes for: noughts
and crosses has a few hundred boxes once the symmetries are folded; a game
with millions has no box for most of what it meets, and learns nothing
about a position it has not seen. And learning while a person plays:
adding beads is training, so here it happens in Python, from a seed, and
the game plays by the beads it was given (invariant 6).

## Where to watch it {#watch}

- `make demo-tictactoe` -- MENACE moves first. **Space** draws its bead,
  and each empty square shows its beads and its chance of being drawn;
  **click** a square to answer. **1-4** choose its age -- after 10, 100,
  1,000 or 10,000 games -- and **M** shows what perfect play (minimax)
  makes of each square, so you see where MENACE agrees with it.
- Which demo uses which technique, both ways: the catalogue (T76, coming).

## In this kit {#in-this-kit}

The learning is `python/gameaikit/menace/`: `matchbox.py` is the machine and
Michie's rule, `train.py` plays it from a seed, and `report.py` publishes
the beads at four ages to `godot/game/tictactoe/menace_beads.json`
(`make train-menace`). In Godot, `godot/game/tictactoe/menace_player.gd`
reads that file read-only and draws; `check_no_training.py` refuses a bead
count written in GDScript (N5) and a file a fresh run would not write
(N6). The knobs that matter:

| knob | where | what it changes |
|---|---|---|
| starting beads | `STARTING_BEADS` in `python/gameaikit/menace/matchbox.py` | how sure a fresh box is; fewer and one game moves it a lot |
| the rewards | `REWARDS` in the same file | beads added for a win and a draw, taken for a loss |
| the opponent | `python/gameaikit/menace/opponents.py` | what it learns against, and so what it learns |
| the age | `MenacePlayer.move_for(age, board, chance)` | which published snapshot plays: a beginner or a veteran |

## In your own project {#your-project}

### What to copy {#copy}

The Python side trains: `python/gameaikit/menace/` (standard library only)
-- `board.py` is the game and its symmetries, and is what you rewrite for
another small game. Run `PYTHONPATH=python python3 -m
gameaikit.menace.report --write <your folder>` to publish the beads. The
Godot side only infers: `godot/game/tictactoe/menace_player.gd` and the
`tictactoe_board.gd` it reads boxes with, plus the published JSON.

### A minimal example {#example}

A player of yours that plays by the published beads and shows how sure it
is. `move_for(".........")` is a square from 0 to 8; `chances` is what to
draw over each square. This file is run by `menace_example_test.gd`, and
the gate holds the page equal to it.

<!-- example: godot/test/tictactoe/menace_example.gd -->
```gdscript
# The minimal example on docs/techniques/menace.md, run by
# menace_example_test.gd. A player of your own that plays noughts and
# crosses by the beads Python published, and never adds or takes one.
extends Node

## How many games MENACE had played when the beads were published: 10,
## 100, 1000 or 10000. Fewer, and it plays like a beginner.
var age: int = 10000

var _menace: MenacePlayer = MenacePlayer.load_published()
var _dice := RandomNumberGenerator.new()


## The square, 0 to 8, MENACE plays on `board` -- nine characters, "X",
## "O" or "." row by row -- or -1 when its box is empty and it resigns.
func move_for(board: String) -> int:
	return _menace.move_for(age, board, _dice.randf())


## Each empty square's chance of being drawn: what the panel draws, so the
## player sees how sure the machine is.
func chances(board: String) -> Dictionary:
	var by_square: Dictionary = {}
	for square: Dictionary in _menace.squares_for(age, board):
		by_square[square["square"]] = square["probability"]
	return by_square
```

### What you implement {#implement}

On the Python side, for a game of your own: its positions as strings, its
moves, its symmetries (or none), an opponent to learn against, and the
rewards. On the Godot side, nothing that learns: read the published file,
draw with a number in [0, 1) -- the same number gives the same square in
Python and Godot, which `spec/vectors/menace/` holds -- and never write a
bead. `MenacePlayer.draw(beads, chance)` is the drawing rule alone, for
boxes of your own.

## Deeper {#deeper}

- Michie's machine, its rule and what it learns in how many games:
  [concepts/menace.md](../concepts/menace.md).
- Learning in the kit, and why it happens in Python:
  [concepts/learning.md](../concepts/learning.md).
