## How suspicious one guard is, as a number from 0 to 100 that moves.
##
## A boolean "has seen the player" is what this replaces. Each turn a fuzzy
## controller reads what the guard perceives -- how near, how lit, how loud,
## how long since -- and answers how alarming that is. The level then moves a
## share of the way towards that answer, so it rises and falls rather than
## snapping, and **it never falls while the player is in sight**: a guard
## looking at you does not calm down because you stepped into the shade. With
## nothing to go on it settles near 12, not 0: that is where the shape of
## "calm" balances, and a centroid never lands on the edge of a shape.
class_name Suspicion
extends RefCounted

## How far the level moves towards the controller's answer each turn. A half
## means three turns to cover most of the distance: slow enough to watch, fast
## enough that a player standing in the light is caught.
const RATE: float = 0.5

## How far the guard sees, which is also where "far" ends for the controller.
const SIGHT: float = 8.0

## The longest silence the controller distinguishes, in turns.
const LONG_SILENCE: float = 10.0

var level: float = 0.0

## Turns since the player was last seen or heard.
var unseen_for: int = 0

## What the controller answered last turn, before the level moved towards it.
var alarm: float = 0.0

## Each output term's strength last turn: the *why* the overlay draws.
var activations: Dictionary = {}

var _controller: FuzzyRuleBase = Suspicion.build_controller()


## The controller, written out so a designer can read the rules aloud.
##
## Distance and light are what the guard sees, noise is what it hears, and
## silence is how long it has been since either. A guard that sees nobody is
## given the far edge of sight and darkness, so the sight rules say "calm".
##
## That is why a loud noise concludes *alarmed* rather than *wary*. Heard in
## the dark, it is always blended with that full-strength "calm", and the two
## balance at 50: enough to send the guard to look. Written as *wary*, the
## blend is 35.3 -- under the threshold to investigate -- and a guard ignored
## every sprint it heard. A test found it.
static func build_controller() -> FuzzyRuleBase:
	var silence_terms := {"recent": [0, 0, 1, 4], "long": [1, 4, LONG_SILENCE, LONG_SILENCE]}
	var inputs: Array[FuzzyVariable] = [
		_variable("distance", SIGHT, {"near": [0, 0, 2, 5], "far": [2, 5, SIGHT, SIGHT]}),
		_variable("light", 1.0, {"dark": [0, 0, 0.2, 0.6], "lit": [0.2, 0.6, 1, 1]}),
		_variable("noise", 1.0, {"quiet": [0, 0, 0.1, 0.5], "loud": [0.1, 0.5, 1, 1]}),
		_variable("silence", LONG_SILENCE, silence_terms),
	]
	var alarm_terms := {"calm": [0, 0, 10, 35], "wary": [20, 45, 55, 80], "alarmed": [65, 90, 100, 100]}
	var outputs: Array[FuzzyVariable] = [_variable("alarm", 100.0, alarm_terms, 101)]
	var rules: Array[FuzzyRule] = [
		_rule([["distance", "near"], ["light", "lit"]], "alarmed"),
		_rule([["distance", "near"], ["light", "dark"]], "wary"),
		_rule([["distance", "far"], ["light", "lit"]], "wary"),
		_rule([["distance", "far"], ["light", "dark"]], "calm"),
		_rule([["noise", "loud"]], "alarmed"),
		_rule([["silence", "long"], ["noise", "quiet"]], "calm"),
	]
	return FuzzyRuleBase.new(inputs, outputs, rules)


## One turn of perception. `seen` says whether the player is in sight, and
## `distance` and `light` are only read when it is; `noise` is how loud the
## player's last action was here, from 0 to 1.
func observe(seen: bool, distance: float, light: float, noise: float) -> void:
	unseen_for = 0 if seen or noise > 0.0 else unseen_for + 1
	var values: Dictionary = {
		"distance": distance if seen else SIGHT,
		"light": light if seen else 0.0,
		"noise": noise,
		"silence": float(unseen_for),
	}
	activations = _controller.activations(values)
	alarm = _controller.evaluate(values)["alarm"]
	var step: float = RATE * (alarm - level)
	level = clampf(level + (maxf(step, 0.0) if seen else step), 0.0, 100.0)


static func _variable(name: String, top: float, terms: Dictionary, samples: int = 0) -> FuzzyVariable:
	var sets: Array[FuzzySet] = []
	for term: String in terms:
		sets.append(FuzzySet.new(term, PackedFloat64Array(terms[term])))
	return FuzzyVariable.new(name, 0.0, top, sets, samples)


static func _rule(conditions: Array, term: String) -> FuzzyRule:
	var typed: Array[PackedStringArray] = []
	for condition: Array in conditions:
		typed.append(PackedStringArray(condition))
	return FuzzyRule.new(typed, PackedStringArray(["alarm", term]))
