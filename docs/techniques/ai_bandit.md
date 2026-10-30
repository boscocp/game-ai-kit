# ai_bandit — which option to try next?

<!-- doc-meta
half_life: practice
verified_on: 2026-10-30
tier: 1
source: book:Stuart Russell and Peter Norvig, "Artificial Intelligence: A Modern Approach", 4th edition, Pearson, 2020 -- section 17.3, Bandit Problems ; https://homes.di.unimi.it/~cesabian/Pubblicazioni/ml-02.pdf
invalidated_if: the kit's Bandit signature changes, ADR 0016's amendment is withdrawn, or the demos that use it are renamed
teaches: fighting-game-ai
-->

> Português: [ai_bandit.pt-BR.md](ai_bandit.pt-BR.md). The words that
> stay in English are in the [glossary](glossary.pt-BR.md).

## What it decides {#what}

Which of a fixed set of options to try next, by what each has paid so far.
Each option is an *arm*; pull one and it pays something between 0 and 1.
`Bandit` keeps two numbers an arm -- how often it was pulled, and the sum
of what it paid -- and chooses from them. The lesson is the dilemma between
taking the option that has paid best (*exploitation*) and trying the ones
still poorly known (*exploration*). UCB1 [Auer, Cesa-Bianchi & Fischer
2002] answers it with "the sum of two terms": an arm's mean payoff, and a
bonus that grows with every pull it is left out of and shrinks with every
pull it gets. Epsilon-greedy, here for the comparison, takes the best mean
except, with chance `epsilon`, any arm at random. The book: AIMA 4th
edition, 17.3, Bandit Problems.

## When not to use it {#when-not}

When an option's worth depends on the situation -- that is a contextual
bandit, or a table of bandits, one a situation, as the fighting game keeps.
When the payoffs drift: UCB1 counts an old pull as much as a new one, so it
follows a change slowly. When there are too few pulls to try every option
even once: a hand-written weight is better than a bandit that never got
past its first round. And keeping the counts between matches: that would be
a model fitted at game time, which invariant 6 forbids; ADR 0016, as
amended, allows this one only because it counts, starts empty every fight,
and is never saved.

## Where to watch it {#watch}

- `make demo-fighting` -- **M** until the dummy is a "bandit" (easy,
  medium or hard). The panel shows, for the situation the opponent just
  named, each of its options' pulls, mean payoff and UCB1 bound, with a bar
  -- `#` the mean, `+` the exploration term -- and the option it chose
  marked `>` before it is played; then the last option paid and what it
  earned. Keep answering one situation the same way and watch the bars.
- `make measure-bandit` -- the bandit opponent against T18's stand-ins and
  the owner's ghost, beside T37's fixed opponent, and how many pulls it
  takes to settle.
- Which demo uses which technique, both ways: the
  [catalogue](catalogue.md).

## In this kit {#in-this-kit}

`godot/game/fighting/fight_bandit_opponent.gd` keeps T37's situations,
options, reaction and execution, and replaces the fixed draw with one
`Bandit` per situation whose arms are that situation's options. An option
is paid the change in the health lead while it played and for half a
second after, scaled into [0, 1]. The knobs that matter:

| knob | where | what it changes |
|---|---|---|
| arms | `Bandit.new(arm_count, ...)` | how many options; an arm is an index, and your game keeps the names |
| policy | the second argument, `Bandit.UCB1` or `Bandit.EPSILON_GREEDY` | how it trades exploring against exploiting |
| exploration | the third, 0 or more; `Bandit.EXPLORATION`, the square root of two, by default | how much being poorly known counts against having paid well; the fighting opponent uses 0.5, measured, because its payoffs sit near 0.5 |
| epsilon | the fourth, between 0 and 1 | how often epsilon-greedy pulls at random |
| seed | the fifth | epsilon-greedy's draws, the same in GDScript and Python |

## In your own project {#your-project}

### What to copy {#copy}

One folder: `godot/addons/ai_bandit/`. It needs nothing else, not even
`ai_core`. Open the project once, or run `godot --headless --import`, so
Godot registers its classes.

### A minimal example {#example}

An opponent of yours with three openings that learns, during the match,
which one wins against this player. Against a player who beats the rush
and loses to the expansion, it tries each once and then plays the
expansion most. This file is run by `opening_example_test.gd`, and the gate
holds the page equal to it.

<!-- example: godot/test/ai_bandit/opening_example.gd -->
```gdscript
# The minimal example on docs/techniques/ai_bandit.md, run by
# opening_example_test.gd. An opponent of your own that has three openings
# and learns, during this match only, which one wins against this player:
# it tries each, then keeps choosing by UCB1.
extends Node

const OPENINGS: Array[String] = ["rush", "turtle", "expand"]

# One arm an opening, UCB1 by default. It starts empty, and nothing here
# saves it: a new match makes a new one (ADR 0016).
var _bandit := Bandit.new(OPENINGS.size())
var _played: int = 0


func _ready() -> void:
	# No arms, an unknown policy or an epsilon outside [0, 1] is refused here.
	if _bandit.problem() != "":
		push_error(_bandit.problem())


## The opening to play this round.
func next_opening() -> String:
	_played = _bandit.choose()
	return OPENINGS[_played]


## The round is over: 1 for a win, 0 for a loss, anything between for a draw.
func round_ended(payoff: float) -> void:
	_bandit.reward(_played, payoff)


## Each opening's pulls, mean payoff and UCB1 bound. Draw them, and the
## player sees why the opponent chose what it chose.
func worth() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for arm: int in range(OPENINGS.size()):
		var opening: String = OPENINGS[arm]
		rows.append({"opening": opening, "pulls": _bandit.pulls[arm], "mean": _bandit.mean(arm), "bound": _bandit.bound(arm)})
	return rows
```

### What you implement {#implement}

The payoff: a number between 0 and 1 for what one pull earned -- a round
won, damage dealt less damage taken, scaled -- and the moment it is known.
`choose()` changes no count; only `reward()` does, so call it once per
pull, with the arm you actually played. Keep the mean as the bandit keeps
it, a sum over a count read when needed: a mean updated in place with
`+= (payoff - mean) / n` is the same number with the shape of a learning
step, and this kit's gate refuses it. Call `problem()` after building: `""`
means the settings are sound.

## Deeper {#deeper}

- How fighting-game AI is made, and what the bandit opponent measured:
  [concepts/fighting-game-ai.md](../concepts/fighting-game-ai.md).
- Why counting during the fight is allowed, and nothing more:
  [ADR 0016](../adr/0016-an-opponent-model-counts-during-the-fight.md),
  and its amendment of 2026-10-26.
- Where bandits sit among the field's techniques:
  [concepts/the-literature-and-the-kit.md](../concepts/the-literature-and-the-kit.md).
