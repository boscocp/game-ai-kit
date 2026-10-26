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
