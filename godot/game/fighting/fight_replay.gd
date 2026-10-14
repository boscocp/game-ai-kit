## A fight played back from an input log, frame by frame.
##
## A log is the two characters and one pair of input numbers per frame,
## player one first. Played from the opening frame through `FightRules`, it
## gives one digest per frame. Two runs of the same log must give the same
## digests, frame for frame: T17 and T18 learn from a person's logged
## inputs, and an engine that played a log differently twice would teach
## them nothing. `test/replay_determinism.gd` holds that.
##
## When not to use it: a log recorded against other frame data. The log is
## inputs, not outcomes, so it replays under whatever rules are current --
## which is the point, and also why a log says which characters it was for.
class_name FightReplay
extends RefCounted


## The digest of every frame `input_log` produces, the opening frame first.
## `input_log` is `{"characters": [first, second], "inputs": [[p1, p2], ...]}`.
static func digests(input_log: Dictionary, data: FightData) -> Array[String]:
	var state: FightState = FightState.starting(data, input_log["characters"][0], input_log["characters"][1])
	var found: Array[String] = [state.digest()]
	for pair: Array in input_log["inputs"]:
		var inputs: Array[int] = [int(pair[0]), int(pair[1])]
		state = FightRules.step(state, inputs, data)
		found.append(state.digest())
	return found


## The first frame on which two runs disagree, or -1 when they agree on every
## frame and are the same length.
static func first_difference(first: Array[String], second: Array[String]) -> int:
	for frame: int in range(mini(first.size(), second.size())):
		if first[frame] != second[frame]:
			return frame
	return -1 if first.size() == second.size() else mini(first.size(), second.size())


## The events of every frame `input_log` produces, joined: what the replay showed
## happening, so a test can ask whether a log exercises a hit, a block or a
## trade at all.
static func events(input_log: Dictionary, data: FightData) -> String:
	var state: FightState = FightState.starting(data, input_log["characters"][0], input_log["characters"][1])
	var seen: PackedStringArray = PackedStringArray()
	for pair: Array in input_log["inputs"]:
		state = FightRules.step(state, [int(pair[0]), int(pair[1])] as Array[int], data)
		seen.append_array(state.events)
	return ", ".join(seen)
