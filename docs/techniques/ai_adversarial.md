# ai_adversarial — the best move against someone who answers

<!-- doc-meta
half_life: practice
verified_on: 2026-11-05
tier: 2
source: book:Stuart Russell and Peter Norvig, "Artificial Intelligence: A Modern Approach", 4th edition, Pearson, 2020 -- chapter 5, figures 5.3, 5.7 and 5.11, section 5.5
invalidated_if: the kit's AdversarialGame, MinimaxSearch, AlphaBetaSearch, ExpectiminimaxSearch, AdversarialResult, MonteCarloSearch, MctsResult or GakXorshift signatures change, or the demos that use them are renamed
teaches: adversarial-search
-->

> Português: [ai_adversarial.pt-BR.md](ai_adversarial.pt-BR.md). The words
> that stay in English are in the [glossary](glossary.pt-BR.md).

## What it decides {#what}

Which move to make in a two-player game, on the assumption that the other
player will then make the move worst for you. **Minimax** (`MinimaxSearch`)
looks down the tree -- your best on your turn, their worst on theirs -- to a
fixed depth and asks the game to score the position it reached. **Alpha-beta**
(`AlphaBetaSearch`) returns the same move and value after looking at fewer
positions, by stopping on a move once it is proved no better than one
already found. Both hand back an `AdversarialResult`: every root move with
its value, the positions visited, and the moves cut.

**Monte Carlo tree search** (`MonteCarloSearch`) needs no score for an
unfinished position: it plays the game out at random from each move, many
times, and spends more of those playouts on the moves that do well (UCT).
It is **anytime** -- `step(iterations)` runs a few and returns, and the
move tried most is its answer so far -- and it handles dice, through the
game's `outcomes`. It hands back an `MctsResult`: every root move's visits,
mean and bound.

**Expectiminimax** (`ExpectiminimaxSearch`) is minimax for a game with
dice: where an action's `outcomes` are several, the move is worth their
sum, each value weighed by its probability -- its *expected* value -- and
MAX and MIN choose between those. It needs an evaluation, as minimax does,
and a better one than minimax: a chance node adds values, so their scale
matters, not only their order. It is anytime by iterative deepening --
`step(positions)` goes on a few positions at a time, depth 1, then 2, and
answers with the deepest finished depth -- and hands back an
`AdversarialResult` whose `considered` carries each outcome's value. The
book: Russell and Norvig, *AIMA*, chapter 5; MCTS is section 5.4,
expectiminimax 5.5.

## When not to use it {#when-not}

A game with hidden cards: every search here assumes both players see the
whole state. Minimax and alpha-beta on a game with dice: they read only
`result`, so they see the dice always falling one way -- use MCTS, which
draws them, or expectiminimax, which weighs them. Expectiminimax where
there are many outcomes or many moves: the dice multiply the branching, and
in the squad mode one second reaches two or three plies (T88's duel,
`docs/godot/squad.md`). There a ply is one piece's answer and a side's
turn up to eight, so at depth 2 the enemy chooses in 5 of the duel's 30
positions and in none of its 14 walks: on a walk the search plays against
an enemy that does not move. Count a ply in whole turns when a turn is
many moves. And where you cannot write the evaluation, since MCTS needs
none. MCTS where random play says nothing --
where almost any random move loses at once -- because the playouts then
measure the randomness; and where alpha-beta already searches deep enough
with a good evaluation, because there it is exact and MCTS only converges
towards it. And plain `MinimaxSearch` almost never: it is here so the
shortcut can be seen beside the thing it shortens.

## Where to watch it {#watch}

- `make run` -- checkers against minimax. **Space** plays white's move,
  **1-6** set how many plies it looks ahead. Every move it considered is a
  **blue** arrow with its value, the one it will play is **pink**, and the
  panel says how many positions it searched and how many replies it
  skipped.
- `make demo-tactical MODE=squad` -- the tactical game in XCOM mode; **C**
  changes the computer. `mcts` draws each option of the piece about to
  act with its mean, and its visits as bars in the status, growing while it
  thinks. `expecti` draws each option's expected value, and in the status
  the depth finished so far, a bar for each option, and for a shot its hit
  and miss with what each is worth. **Space** plays what either has now.
- `make measure-squad-duel` -- the two searches on the same 30 positions at
  50, 200 and 1,000 ms, then in seeded matches; the table it printed is in
  `docs/godot/squad.md`.
- Which demo uses which technique, both ways: the catalogue (T76, coming).

## In this kit {#in-this-kit}

`godot/game/checkers/checkers_game.gd` is checkers told to the search: an
`GakAdversarialGame` whose states are boards and whose actions are moves.
`checkers.gd` asks `AlphaBetaSearch` for white's move. The knobs that
matter:

| knob | where | what it changes |
|---|---|---|
| depth | `search(game, state, depth)` | how many plies ahead it looks; each one costs about the branching factor times the last |
| the estimate | your `GakAdversarialGame.evaluate(state, player)` | how a position the search stops at is scored; never infinite |
| move order | your `GakAdversarialGame.actions(state)` | how much alpha-beta cuts -- never the move it returns. Same order every time: of equal moves, the first wins |
| which search | `MinimaxSearch` or `AlphaBetaSearch` | the work, not the answer |
| iterations | `MonteCarloSearch.step(iterations)` | MCTS's budget for this call; the tree carries over to the next, so a frame can take a few and come back |
| the seed | `MonteCarloSearch.new(game, state, from_seed)` | every random choice the search makes; the same seed, the same search, in GDScript and in Python |
| exploration | `MonteCarloSearch.new(…, exploration)` | UCB1's C, √2 by default: larger tries poorly known moves more, smaller trusts the means sooner |
| playout limit | `MonteCarloSearch.new(…, playout_limit)` | how many random moves a playout makes before it asks `evaluate`; 200 by default |
| chance | your `GakAdversarialGame.outcomes(state, action)` | what an action may lead to, with its probabilities; MCTS keeps one child per outcome, expectiminimax sums them |
| positions | `ExpectiminimaxSearch.step(positions)` | expectiminimax's budget for this call, counted in positions; the stack carries over, so a frame can take a few |
| depth, at most | `ExpectiminimaxSearch.new(game, state, deepest)` | how deep iterative deepening may go; `search_to(depth)` searches one depth and stops |

## In your own project {#your-project}

### What to copy {#copy}

From the library: unzip `ai_core-<version>.zip` and
`ai_adversarial-<version>.zip` into your project's `res://addons/` --
[using the library](using-the-library.md) has every step, the Python wheel
too. Or copy them from a checkout:

Two folders: `godot/addons/ai_core/` (for `GakXorshift`, the seeded generator
Monte Carlo search draws from) and `godot/addons/ai_adversarial/`. Minimax
and alpha-beta alone use nothing of `ai_core`, but the folder is one. Open
the project once, or run `godot --headless --import`, so Godot registers
their classes.

### A minimal example {#example}

Your game, told to the search: Nim, where the players take one, two or
three sticks and whoever takes the last one wins. `best_take(10)` answers 2,
leaving the opponent a multiple of four. `most_visited_take(10)` asks MCTS
instead and, after its 1000 iterations, answers 2 too -- with no depth and
no estimate, only finished games scored. Ask it after 300
(`most_visited_take(10, 300)`) and it still prefers 1: an anytime answer is
not always a right one. This file is run by `nim_example_test.gd`, and the
gate holds the page equal to it.

<!-- example: godot/test/ai_adversarial/nim_example.gd -->
```gdscript
# The minimal example on docs/techniques/ai_adversarial.md, run by
# nim_example_test.gd. A game of your own, told to the search: Nim, where
# the players take one, two or three sticks in turn, and whoever takes the
# last stick wins.
extends GakAdversarialGame


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


## The same question asked of Monte Carlo tree search: `iterations` games
## played out at random from here, spread by UCB1, and the take tried most.
## No depth and no estimate: `evaluate` is only asked about finished games.
func most_visited_take(sticks: int, iterations: int = 1000, from_seed: int = 1) -> int:
	return MonteCarloSearch.new(self, Pile.new(sticks, 0), from_seed).step(iterations).action


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

The five functions of `GakAdversarialGame`, for your game: `to_move`,
`actions`, `result`, `is_terminal` and `evaluate`, and a sixth only if
your game has dice: `outcomes`, whose default is `result`, certain. A state
and an action are whatever you like -- a state must be a `RefCounted`, and
the search never looks inside either. The promises the searches rely on:
`result` returns a new state and leaves the old one alone; `actions` lists
the same moves in the same order each time; `to_move` is the only word on
whose turn it is, read at every position, so a side may act twice running;
and `evaluate` returns the true outcome on a finished game and is never
infinite. Then call `AlphaBetaSearch.new().search(game, state, depth)` and
read `action`; `considered` is what to draw. Or keep a
`MonteCarloSearch.new(game, state, seed)` and call `step(iterations)` each
frame; its `considered` -- visits, mean, bound -- is what to draw while it
runs. With dice and an evaluation you trust, keep an
`ExpectiminimaxSearch.new(game, state)` and call `step(positions)` each
frame; `result()` is the deepest finished depth's answer, and its
`considered` carries each move's expected value and, per outcome, its
chance and value.

## Deeper {#deeper}

- Why minimax works, what alpha-beta cuts, MCTS's four phases, and when
  expectiminimax or MCTS wins on the same positions:
  [concepts/minimax.md](../concepts/minimax.md).
- Scoring a position with weights fitted in Python:
  [learned_evaluation](learned_evaluation.md).
