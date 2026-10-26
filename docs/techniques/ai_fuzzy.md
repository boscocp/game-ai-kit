# ai_fuzzy — how much, by degrees

<!-- doc-meta
half_life: practice
verified_on: 2026-10-26
tier: 2
source: book:Ian Millington, "AI for Games", 3rd edition, CRC Press, 2019 -- chapter 5, fuzzy logic ; book:IEC 61131-7, "Programmable controllers -- Part 7: Fuzzy control programming", 2000
invalidated_if: the kit's FuzzySet, FuzzyVariable, FuzzyRule or FuzzyRuleBase signatures change, or the demos that use them are renamed
teaches: stealth-ai
-->

> Português: [ai_fuzzy.pt-BR.md](ai_fuzzy.pt-BR.md). The words that stay in
> English are in the [glossary](glossary.pt-BR.md).

## What it decides {#what}

An amount, from numbers your game measured, by rules a designer can read
aloud: *if distance is near and light is lit then alarm is alarmed*. Each
input belongs to its sets by a degree from 0 to 1 (`FuzzySet`, a trapezoid
or a triangle); each rule is as true as its weakest condition (AND) or its
strongest (OR); and the centroid (`FuzzyCentroid`) turns the output terms,
each cut at its rule's strength, back into one number. Two rules firing at
once land between their terms, so the answer moves smoothly where a
threshold would jump. `activations` says how strongly each term was
concluded -- the *why*. The book: Millington, *AI for Games*, chapter 5;
the rule language is IEC 61131-7's FCL.

## When not to use it {#when-not}

A choice between deeds: the centroid of "flee" and "fight" is a unit
standing still -- let fuzzy answer *how much*, and something else *which*.
A discrete input ("has a key"), where a set is a boolean in disguise. And
past a dozen rules: every change then moves every output a little, and
nobody can predict the system; a decision tree says the same more plainly.

## Where to watch it {#watch}

- `make demo-stealth` -- the bar over each guard is its suspicion, which
  rises towards what a fuzzy controller over distance, light, noise and
  silence answers. Step into the light near a guard, or **shift** to
  sprint past one, and watch the bar fill by degrees.
- `make demo-infiltration` -- how fast a guard's awareness rises is a fuzzy
  controller read from data. **Tab** follows a guard.
- Which demo uses which technique, both ways: the catalogue (T76, coming).

## In this kit {#in-this-kit}

`godot/game/stealth/suspicion.gd` writes the stealth guard's controller out
in `build_controller()`, so the rules read aloud beside the code;
`godot/game3d/infiltration/fuzzy_from_data.gd` builds one from a JSON row
instead. The knobs that matter:

| knob | where | what it changes |
|---|---|---|
| a set's shape | `FuzzySet.new(name, [rise_start, rise_end, fall_start, fall_end])` | where a value starts and stops belonging; three points make a triangle |
| a variable's range | `FuzzyVariable.new(name, minimum, maximum, sets)` | inputs are clamped into it before they are read |
| the output's samples | `FuzzyVariable.new(..., samples)` on an output | how finely the centroid measures; at least two |
| the rules | `FuzzyRule.new(conditions, conclusion, connective)` | which terms each combination concludes; `FuzzyRule.AND` or `FuzzyRule.OR` |

## In your own project {#your-project}

### What to copy {#copy}

One folder: `godot/addons/ai_fuzzy/`. It needs nothing else, not even
`ai_core`. Open the project once, or run `godot --headless --import`, so
Godot registers its classes. The FCL reader, for rules written in a file,
is on the Python side, in `python/gameaikit/fuzzy/`.

### A minimal example {#example}

A guard of yours that grows more alarmed the nearer and the better lit what
it sees is. `alarm(1.0, 1.0)` is above 75; `alarm(9.0, 0.0)` below 25; in
between it moves by degrees. This file is run by `alarm_example_test.gd`,
and the gate holds the page equal to it.

<!-- example: godot/test/ai_fuzzy/alarm_example.gd -->
```gdscript
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
```

### What you implement {#implement}

The measuring: your game hands `evaluate` a `Dictionary` of input name to a
finite number, every input present -- a missing one is refused (`NAN` out),
not read as zero. And the acting: the number that comes back is an amount,
so your game decides what it means -- a suspicion that rises towards it
each turn, as the stealth guard's does, or a speed. The arrays it is typed
with are strict: sets are `Array[FuzzySet]`, variables
`Array[FuzzyVariable]`, rules `Array[FuzzyRule]`, and each condition a
`PackedStringArray` of variable and set. Call `problem()` once after
building: `""` means it can be evaluated.

## Deeper {#deeper}

- The stealth guard's suspicion, rule by rule:
  [concepts/stealth.md](../concepts/stealth.md).
- Why the kit rewrote fuzzy logic rather than port a library:
  [ADR 0011](../adr/0011-fuzzy-is-rewritten-not-ported.md).
