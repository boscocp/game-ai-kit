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
