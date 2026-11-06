# ai_opponent — what will the player do next?

<!-- doc-meta
half_life: practice
verified_on: 2026-10-26
tier: 2
source: book:Ian Millington and John Funge, "Artificial Intelligence for Games", 2nd edition, Morgan Kaufmann, 2009 -- chapter 7, Learning
invalidated_if: the kit's NGramPredictor signature changes, ADR 0016 is withdrawn, or the demos that use it are renamed
teaches: fighting-game-ai
-->

> Português: [ai_opponent.pt-BR.md](ai_opponent.pt-BR.md). The words that
> stay in English are in the [glossary](glossary.pt-BR.md).

## What it decides {#what}

How likely each of the player's actions is next, from what the player did
just before. `NGramPredictor` counts, during the match, which action came
after each run of the last `order - 1` actions -- the *context* -- and
reads the counts back as a probability for every action. Two numbers
refine it: `prior`, the imaginary sightings every action starts with, so a
context never seen answers "I do not know" rather than a guess from
nothing; and `decay`, how much an old sighting counts against a new one, so
a player who changes habits is followed. The table is printable
(`rows()`), which is the reason to choose an n-gram over a network. The
book: Millington and Funge, *Artificial Intelligence for Games*, chapter 7.

## When not to use it {#when-not}

Actions that depend on more than the last few -- on distance, health, the
clock: the n-gram sees only the sequence, so anything else must be built
into the symbols. An opponent that should not get better at beating one
player -- a tutorial, a difficulty somebody chose on purpose. And keeping
the table between matches: that would be a model fitted at game time,
which invariant 6 forbids; ADR 0016 allows this one only because it starts
empty every fight and is never saved.

## Where to watch it {#watch}

- `make demo-fighting` -- **M** until the dummy is a "learner" (easy,
  medium or hard). The panel prints its table as it stands: what it expects
  you to do next, after which context, how often its last guesses were
  right, and the rows it has counted. Repeat a habit and watch it climb.
- Which demo uses which technique, both ways: [the catalogue](catalogue.md#ai_opponent).

## In this kit {#in-this-kit}

`godot/game/fighting/fight_model_opponent.gd` builds an `NGramPredictor`
over the fighting game's actions, observes what you did as it was drawn on
screen, and leans its choice towards the answer to what it expects -- it
may only weight options its level already has, so a sure prediction never
makes it perfect. The knobs that matter:

| knob | where | what it changes |
|---|---|---|
| order | `NGramPredictor.new(order, actions, decay, prior)` | how many past actions it looks at, plus one; too low tells no moment from another, too high never sees a context twice |
| decay | the third argument, above 0 and at most 1 | how fast old habits are forgotten; 1 averages the whole match |
| prior | the fourth argument, above 0 | how much evidence it needs before it is sure |
| actions | the second argument | every action it may see or predict; one it was not told about is ignored |

## In your own project {#your-project}

### What to copy {#copy}

From the library: unzip `ai_opponent-<version>.zip` into your project's
root, `res://` -- [using the library](using-the-library.md) has every step,
the Python wheel too. Or copy it from a checkout:

One folder: `godot/addons/ai_opponent/`. It needs nothing else, not even
`ai_core`. Open the project once, or run `godot --headless --import`, so
Godot registers its class.

### A minimal example {#example}

An opponent of yours at rock, paper, scissors that learns the player's
habit during the match and plays what beats it. A player who plays rock,
rock, paper over and over is answered with paper after "rock, paper". This
file is run by `counter_example_test.gd`, and the gate holds the page equal
to it.

<!-- example: godot/test/ai_opponent/counter_example.gd -->
```gdscript
# The minimal example on docs/techniques/ai_opponent.md, run by
# counter_example_test.gd. An opponent of your own at rock, paper, scissors
# that counts what the player did after what, during this match only, and
# plays what beats the likeliest next move.
extends Node

const MOVES: Array[String] = ["rock", "paper", "scissors"]

## What beats each move.
const BEATEN_BY: Dictionary = {"rock": "paper", "paper": "scissors", "scissors": "rock"}

# Order 3: it looks at the player's last two moves. Each old sighting of a
# context counts 0.9 of the one after it, so a player who changes habits is
# followed. The table starts empty and is never saved (ADR 0016).
var _predictor := NGramPredictor.new(3, MOVES, 0.9)


func _ready() -> void:
	# An order below 1 or a decay outside (0, 1] is refused here.
	if _predictor.problem() != "":
		push_error(_predictor.problem())


## The player just played `move`: count it.
func player_played(move: String) -> void:
	_predictor.observe(move)


## What to play now: the move that beats what the player will likeliest do.
func counter() -> String:
	return BEATEN_BY[_predictor.likeliest()]


## How likely each of the player's moves is next, summing to 1. Draw it, and
## the player sees what the opponent expects.
func expectation() -> Dictionary:
	return _predictor.probabilities()
```

### What you implement {#implement}

The symbols: turn what the player did into one of a short list of action
names -- a move's height, a jump, a guard -- and call `observe` once per
new action, not once per frame. Feed it only what was on screen when your
opponent could have seen it, or it reacts to presses no person could. And
the use: `probabilities()` is a lean, not a verdict -- weight your
opponent's own choices by it rather than always playing the counter, or it
becomes unbeatable and no fun. Call `problem()` after building: `""` means
the settings are sound.

## Deeper {#deeper}

- How fighting-game AI is made, and where the n-gram fits:
  [concepts/fighting-game-ai.md](../concepts/fighting-game-ai.md).
- Why counting during the fight is allowed, and nothing more:
  [ADR 0016](../adr/0016-an-opponent-model-counts-during-the-fight.md).
