## An opponent that fights like a recorded player: in each situation, it does
## what the player did there (T18).
##
## T17's learner *answers* the player -- it predicts the next action and
## leans towards what beats it. This one *imitates*: it is the player, as
## well as the recordings let it be. Killer Instinct's Shadows are this kind:
## "if you never block while training your shadow, then it will never block".
##
## Three ways of deciding what the player would do, one per `SOURCES`:
##
## * **ghost: exact** -- the answers the player gave in exactly this
##   situation, drawn by how often; in one it never met, its answers
##   anywhere;
## * **ghost: nearest** -- the answers given in the recorded situations
##   nearest this one, the fewest features apart;
## * **clone** -- the softmax model fitted to the same recordings, drawn by
##   its probabilities.
##
## Everything else is T37's: it sits behind `FightDelay`, sees the fight
## `reaction` frames late, and turns what it chose into inputs as the fixed
## opponent does -- a crouch and a jump included, which a player does and the
## fixed opponent never chooses. Its execution is clean: a player's fumbles are already
## in what the player did.
##
## One difference from the player is left, and said here rather than hidden:
## the rows hold one decision per *change* of action, and this opponent
## decides whenever its plan runs out -- every 10 to 12 frames of a walk or a
## guard. So after a step in it is asked "what next?" sooner than the player
## was, and tends to stop walking sooner. Matching the player's timing would
## need how long each action was held, which the rows do not keep.
##
## When not to use it: an opponent that should be good. A clone is as good as
## the player recorded, and only in situations the player met.
class_name FightCloneOpponent
extends FightOpponent

const SOURCES: Array[String] = ["ghost: exact", "ghost: nearest", "clone"]
## How a probability becomes a whole-number weight to draw by: per thousand.
const PER: int = 1000

## The recorded player it imitates.
var player: ClonedPlayer
## Its last decision, for the panel: the situation in words, how it found the
## answers, and the answers it drew from with their weights.
var seen_situation: Dictionary = {}
var found: String = "nothing seen yet"
var considered: Array = []

var _last: String = ""


## An opponent imitating `recorded` by `source`, one of `SOURCES`, drawing
## its chances from `chance_seed`.
func _init(source: String, recorded: ClonedPlayer, data: FightData, chance_seed: int = 0) -> void:
	super(source, data, chance_seed)
	player = recorded


## A new fight: nothing done yet.
func new_fight() -> void:
	super()
	_last = ""
	seen_situation = {}
	found = "nothing seen yet"
	considered = []


# As the fixed opponent's, from the situation as the recordings write it.
func _decide(seen: FightState, me: int) -> void:
	seen_situation = FightSituation.of(seen, me, _last, _data)
	super(seen, me)


## As the fixed opponent's, after reading its own fighter off the frame it
## was handed: the last action it was seen doing is its `last`, exactly as
## `FightRecording.last_seen` writes it into the rows -- not the option it
## drew, which a strike out of reach or a guard with nothing to block turns
## into something else on screen.
func choose(seen: FightState, me: int) -> int:
	var reading: String = FightAction.of(seen, me, _data)
	if reading != "":
		_last = reading
	return super(seen, me)


## What the recorded player did in the situation last seen, as `[action,
## weight]`, the actions `character` can do. The fixed opponent's situation
## `name` is not used: the recordings have their own.
func _weighted_options(_name: String, character: String) -> Array:
	var weights: Dictionary = _answers()
	considered = []
	for action: String in weights:
		if int(weights[action]) > 0 and _has_option(character, action):
			considered.append([action, int(weights[action])])
	if considered.is_empty():
		found += "; nothing it can do, so it guards"
		considered = [["guard standing", 1]]
	return considered


# `{action: weight}` from the source, and `found` saying where it came from.
func _answers() -> Dictionary:
	if not player.is_loaded():
		found = "no recorded player: " + player.error
		return {}
	if Array(player.cases.features) != FightSituation.FEATURES:
		found = "the recorded player was cut with other features (%s) -- run `make train-clone`" % ", ".join(
			player.cases.features)
		return {}
	match level:
		"ghost: exact":
			return _exact()
		"ghost: nearest":
			var nearest: Dictionary = player.cases.nearest(seen_situation)
			found = "%d case(s), %d feature(s) apart" % [nearest["keys"].size(), nearest["distance"]]
			return nearest["counts"]
	var chances: Dictionary = player.model.probabilities(seen_situation)
	found = "the model's probabilities"
	var weights: Dictionary = {}
	for action: String in chances:
		weights[action] = roundi(chances[action] * PER)
	return weights


# The exact case, or everything the player did when it never met this one.
func _exact() -> Dictionary:
	var counts: Dictionary = player.cases.exact(seen_situation)
	if counts.is_empty():
		found = "never met this one: all its play"
		return player.cases.everything()
	var times: int = counts.values().reduce(func(sum: int, count: Variant) -> int: return sum + int(count), 0)
	found = "met it %d time(s)" % times
	return counts

