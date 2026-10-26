# ai_adversarial — the best move against someone who answers

<!-- doc-meta
half_life: practice
verified_on: 2026-10-26
tier: 2
source: book:Stuart Russell and Peter Norvig, "Artificial Intelligence: A Modern Approach", 4th edition, Pearson, 2020 -- chapter 5, figures 5.3 and 5.7
invalidated_if: the kit's AdversarialGame, MinimaxSearch, AlphaBetaSearch or AdversarialResult signatures change, or the demos that use them are renamed
teaches: adversarial-search
-->

> Português: [ai_adversarial.pt-BR.md](ai_adversarial.pt-BR.md). The words
> that stay in English are in the [glossary](glossary.pt-BR.md).

## What it decides {#what}

Which move to make in a two-player game, on the assumption that the other
player will then make the move worst for you. **Minimax** (`MinimaxSearch`)
alternates down the tree -- your best, their worst -- to a fixed depth and
asks the game to score the position it reached. **Alpha-beta**
(`AlphaBetaSearch`) returns the same move and value after looking at fewer
positions, by stopping on a move once it is proved no better than one
already found. Both hand back an `AdversarialResult`: every root move with
its value, the positions visited, and the moves cut. The book: Russell and
Norvig, *AIMA*, chapter 5.

## When not to use it {#when-not}

A game with dice or hidden cards: minimax assumes both players see
everything and nothing is left to chance -- that is expectiminimax, or
another family. A game so wide that even alpha-beta's cuts leave too many
positions -- go -- where Monte Carlo tree search is the usual answer. And
plain `MinimaxSearch` almost never: it is here so the shortcut can be seen
beside the thing it shortens.

## Where to watch it {#watch}

- `make run` -- checkers against minimax. **Space** plays white's move,
  **1-6** set how many plies it looks ahead. Every move it considered is a
  **blue** arrow with its value, and the panel says how many positions it
  searched and how many replies it skipped.
- Which demo uses which technique, both ways: the catalogue (T76, coming).

## In this kit {#in-this-kit}

`godot/game/checkers/checkers_game.gd` is checkers told to the search: an
`AdversarialGame` whose states are boards and whose actions are moves.
`checkers.gd` asks `AlphaBetaSearch` for white's move. The knobs that
matter:

| knob | where | what it changes |
|---|---|---|
| depth | `search(game, state, depth)` | how many plies ahead it looks; each one costs about the branching factor times the last |
| the estimate | your `AdversarialGame.evaluate(state, player)` | how a position the search stops at is scored; never infinite |
| move order | your `AdversarialGame.actions(state)` | how much alpha-beta cuts -- never the move it returns. Same order every time: of equal moves, the first wins |
| which search | `MinimaxSearch` or `AlphaBetaSearch` | the work, not the answer |

## In your own project {#your-project}

### What to copy {#copy}

One folder: `godot/addons/ai_adversarial/`. It needs nothing else, not even
`ai_core`. Open the project once, or run `godot --headless --import`, so
Godot registers its classes.

### A minimal example {#example}

Your game, told to the search: Nim, where the players take one, two or
three sticks and whoever takes the last one wins. `best_take(10)` answers 2,
leaving the opponent a multiple of four. This file is run by
`nim_example_test.gd`, and the gate holds the page equal to it.

<!-- example: godot/test/ai_adversarial/nim_example.gd -->
```gdscript
# The minimal example on docs/techniques/ai_adversarial.md, run by
# nim_example_test.gd. A game of your own, told to the search: Nim, where
# the players take one, two or three sticks in turn, and whoever takes the
# last stick wins.
extends AdversarialGame


## A position: the sticks left, and whose turn it is, 0 or 1. The search
## never looks inside it; it only hands it back to the functions below.
class Pile extends RefCounted:
	var sticks: int
	var player: int

	func _init(left: int, to_play: int) -> void:
		sticks = left
		player = to_play


## How many sticks to take from a pile of `sticks` (at least one), looking
## `depth` moves ahead. Alpha-beta returns what minimax would, for less work.
func best_take(sticks: int, depth: int = 12) -> int:
	return AlphaBetaSearch.new().search(self, Pile.new(sticks, 0), depth).action


# Whose turn it is: the search plays for whoever moves at the root.
func to_move(state: RefCounted) -> int:
	return (state as Pile).player


# One, two or three, never more than are left, always in the same order.
func actions(state: RefCounted) -> Array:
	var takes: Array = []
	for take: int in range(1, mini(3, (state as Pile).sticks) + 1):
		takes.append(take)
	return takes


# A new pile: the search keeps the old one while it tries the others.
func result(state: RefCounted, action: Variant) -> RefCounted:
	var pile := state as Pile
	return Pile.new(pile.sticks - int(action), 1 - pile.player)


# Over when the pile is empty: whoever took the last stick has won.
func is_terminal(state: RefCounted) -> bool:
	return (state as Pile).sticks == 0


# Over: whoever is to move has nothing to take, so the other one took the
# last stick and won. Not over, but as deep as the search may look: no
# opinion. A real game's estimate goes here -- see the learned evaluation.
func evaluate(state: RefCounted, player: int) -> float:
	var pile := state as Pile
	if pile.sticks > 0:
		return 0.0
	return 1.0 if pile.player != player else -1.0
```

### What you implement {#implement}

The five functions of `AdversarialGame`, for your game: `to_move`,
`actions`, `result`, `is_terminal` and `evaluate`. A state and an action
are whatever you like -- a state must be a `RefCounted`, and the search
never looks inside either. Four promises the search relies on: `result`
returns a new state and leaves the old one alone; `actions` lists the same
moves in the same order each time; the players alternate (a multi-jump is
one action); and `evaluate` returns the true outcome on a finished game and
is never infinite. Then call `AlphaBetaSearch.new().search(game, state,
depth)` and read `action`; `considered` is what to draw.

## Deeper {#deeper}

- Why minimax works, and what alpha-beta cuts:
  [concepts/minimax.md](../concepts/minimax.md).
- Scoring a position with weights fitted in Python:
  [learned_evaluation](learned_evaluation.md).
