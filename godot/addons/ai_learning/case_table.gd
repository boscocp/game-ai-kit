## A ghost: the situations a recorded player met, and what it did in each,
## looked up rather than learned (T18).
##
## Every recorded decision is a case: a situation written as words, and the
## answer the player gave. The table holds, for each situation met, how many
## times each answer was given there. Asked about a situation, a ghost does
## what the player did in it, drawn by how often -- which is all a ghost
## is. Two ways to look up, the two the sources describe:
##
## * **exact** -- the situation itself, or nothing: the published ghost
##   papers pack it into one identifier and look that up;
## * **nearest** -- the situations that differ from it in the fewest
##   features, their answers pooled: Killer Instinct's Shadows retrieve the
##   nearest recorded case. Counting differing words is the plainest
##   distance there is for situations written as words.
##
## Nothing here changes after it is built: the table was counted in Python
## from the recordings and published, and the game only reads it.
##
## Complexity: exact is one dictionary lookup; nearest compares the situation
## with every case, so it is linear in the cases -- a few hundred.
##
## When not to use it: many features with many words each. The number of
## situations is their product, a player meets few of them, and an exact
## ghost then knows nothing about most of the fight.
class_name CaseTable
extends RefCounted

## The features a situation has, in the order a key writes them.
var features: PackedStringArray
## A situation's key, its words joined by `JOINER`, to `{answer: count}`.
var cases: Dictionary = {}

## How a key joins a situation's words.
const JOINER: String = " | "

var _words_of: Dictionary = {}


## A table over `feature_names` holding a copy of `counted` -- key to answer
## counts. A copy, so the file it was read from and the table cannot change
## each other.
func _init(feature_names: PackedStringArray, counted: Dictionary) -> void:
	features = feature_names
	cases = counted.duplicate(true)
	for key: String in cases:
		_words_of[key] = key.split(JOINER)


## The key `situation` -- `{feature: word}` -- is filed under.
func key_of(situation: Dictionary) -> String:
	var words: PackedStringArray = []
	for feature: String in features:
		words.append(str(situation.get(feature, "")))
	return JOINER.join(words)


## What the player did in exactly `situation`, as `{answer: count}`; empty
## when it never met it. A copy: changing the answer does not change the table.
func exact(situation: Dictionary) -> Dictionary:
	return cases.get(key_of(situation), {}).duplicate()


## The cases nearest `situation`: `{"distance": how many features differ,
## "keys": the cases at that distance, "counts": their answers pooled}`.
## Distance 0 is the exact case; an empty table answers distance -1.
func nearest(situation: Dictionary) -> Dictionary:
	var words: PackedStringArray = key_of(situation).split(JOINER)
	var closest: int = -1
	var keys: PackedStringArray = []
	for key: String in cases:
		var apart: int = _differing(words, _words_of[key])
		if closest == -1 or apart < closest:
			closest = apart
			keys = PackedStringArray([key])
		elif apart == closest:
			keys.append(key)
	var pooled: Dictionary = {}
	for key: String in keys:
		for answer: String in cases[key]:
			pooled[answer] = pooled.get(answer, 0) + int(cases[key][answer])
	return {"distance": closest, "keys": keys, "counts": pooled}


## Every answer the player gave anywhere, pooled: what an exact ghost falls
## back to in a situation it never met.
func everything() -> Dictionary:
	var pooled: Dictionary = {}
	for key: String in cases:
		for answer: String in cases[key]:
			pooled[answer] = pooled.get(answer, 0) + int(cases[key][answer])
	return pooled


# How many of the two situations' words differ, feature by feature.
static func _differing(words: PackedStringArray, other: PackedStringArray) -> int:
	var apart: int = 0
	for index: int in range(words.size()):
		if words[index] != other[index]:
			apart += 1
	return apart
