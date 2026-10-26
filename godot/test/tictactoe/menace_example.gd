# The minimal example on docs/techniques/menace.md, run by
# menace_example_test.gd. A player of your own that plays noughts and
# crosses by the beads Python published, and never adds or takes one.
extends Node

## Where `gameaikit.menace.report --write` put the beads. Moved without
## changing this, the file is not found and every box is empty: MENACE
## resigns every move, which `has_beads()` lets your game say out loud.
const BEADS: String = "res://game/tictactoe/menace_beads.json"

## How many games MENACE had played when the beads were published: 10,
## 100, 1000 or 10000. Fewer, and it plays like a beginner.
var age: int = 10000

var _menace: MenacePlayer = MenacePlayer.load_published(BEADS)
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


## True when the published beads were read: false means the file is not at
## `BEADS`, and every move would be a resignation.
func has_beads() -> bool:
	return not _menace.ages.is_empty()
