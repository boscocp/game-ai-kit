## A whole fight on one frame: both fighters, the frame number, what happened
## on it, and who has won.
##
## `FightRules.step` turns one of these and both players' inputs into the
## next one. Nothing else changes a fight, and nothing in a fight is random
## or read from a clock, so the same inputs from the same start give the same
## fight: that is what makes an input log a replay.
##
## When not to use it: rollback netcode, which wants the same thing faster --
## a fixed block of numbers to copy, not objects.
class_name FightState
extends RefCounted

const NOBODY: int = -1
const DRAW: int = 2

## The two fighters: player one, then player two.
var fighters: Array[FighterState] = []
## Frames played so far.
var frame: int = 0
## What happened on the last frame, in words: hits, blocks, trades. For the
## overlay and the log; the rules never read it back.
var events: Array[String] = []
## `NOBODY` while the fight is on; then 0, 1 or `DRAW`.
var winner: int = NOBODY


## The opening frame: each character at its starting place, facing the other.
static func starting(data: FightData, first: String, second: String) -> FightState:
	var state := FightState.new()
	var starts: Array = data.table["stage"]["starts"]
	for index: int in range(2):
		var name: String = [first, second][index]
		state.fighters.append(FighterState.new(name, int(starts[index]), int(data.character(name)["health"])))
	state.fighters[0].facing = 1
	state.fighters[1].facing = -1
	return state


## A fight with copies of the same fighters, to change without changing this one.
func copy() -> FightState:
	var twin := FightState.new()
	for fighter: FighterState in fighters:
		twin.fighters.append(fighter.copy())
	twin.frame = frame
	twin.winner = winner
	return twin


## Everything about this frame as one line of text. Two runs agree on a frame
## when their digests are equal.
func digest() -> String:
	return "%d w%d | %s | %s | %s" % [frame, winner, fighters[0].digest(), fighters[1].digest(), ", ".join(events)]  # not shown: the digest's notation
