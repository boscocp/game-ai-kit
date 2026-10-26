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
