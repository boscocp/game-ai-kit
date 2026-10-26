# The minimal example on docs/techniques/ai_fuzzy.md, run by
# alarm_example_test.gd. A guard of your own that grows more alarmed the
# nearer and the better lit what it sees is -- by degrees, not at a line.
extends Node

var _controller: FuzzyRuleBase


func _ready() -> void:
	var distance := FuzzyVariable.new("distance", 0.0, 10.0, [
		FuzzySet.new("near", PackedFloat64Array([0, 0, 2, 6])),
		FuzzySet.new("far", PackedFloat64Array([2, 6, 10, 10])),
	] as Array[FuzzySet])
	var light := FuzzyVariable.new("light", 0.0, 1.0, [
		FuzzySet.new("dark", PackedFloat64Array([0, 0, 0.2, 0.6])),
		FuzzySet.new("lit", PackedFloat64Array([0.2, 0.6, 1, 1])),
	] as Array[FuzzySet])
	# An output is measured at 101 points across its range by the centroid.
	var alarm := FuzzyVariable.new("alarm", 0.0, 100.0, [
		FuzzySet.new("calm", PackedFloat64Array([0, 0, 10, 35])),
		FuzzySet.new("wary", PackedFloat64Array([20, 45, 55, 80])),
		FuzzySet.new("alarmed", PackedFloat64Array([65, 90, 100, 100])),
	] as Array[FuzzySet], 101)
	_controller = FuzzyRuleBase.new([distance, light] as Array[FuzzyVariable],
		[alarm] as Array[FuzzyVariable], [
			_rule("near", "lit", "alarmed"),
			_rule("near", "dark", "wary"),
			_rule("far", "lit", "wary"),
			_rule("far", "dark", "calm"),
		] as Array[FuzzyRule])
	# A misspelt set or an empty range is refused here, not guessed at later.
	if _controller.problem() != "":
		push_error(_controller.problem())


## How alarmed the guard is, 0 to 100, by what it sees: `distance` in metres
## and `light` from 0, dark, to 1, lit. Your game moves its guard by this.
func alarm(distance: float, light: float) -> float:
	return _controller.evaluate({"distance": distance, "light": light})["alarm"]


## Why: how strongly each of calm, wary and alarmed was concluded. Draw it,
## and the player sees which rule fired.
func why(distance: float, light: float) -> Dictionary:
	return _controller.activations({"distance": distance, "light": light})["alarm"]


# IF distance IS `near_or_far` AND light IS `dark_or_lit` THEN alarm IS `alarm_term`.
func _rule(near_or_far: String, dark_or_lit: String, alarm_term: String) -> FuzzyRule:
	return FuzzyRule.new([
		PackedStringArray(["distance", near_or_far]),
		PackedStringArray(["light", dark_or_lit]),
	] as Array[PackedStringArray], PackedStringArray(["alarm", alarm_term]))
