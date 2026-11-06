## The seeded draws a `ConstraintSolver` orders its ties with, and a
## `WaveCollapse` picks its tiles with, the same in GDScript and Python.
##
## Godot's `RandomNumberGenerator` and Python's `random` are different
## generators, so a solver shuffling with either could never be held to its
## twin in the other language. The numbers come from `GakXorshift`, the
## kernel's Marsaglia xorshift (`ai_core`, which invariant 2 lets every addon
## use); T95 had written a copy of it here before T109 moved it to the
## kernel, and T135 folded the copy in. A number and a choice among
## `count` are the kernel's, passed through; only the Fisher-Yates shuffle
## is this addon's own. Seeded with 1, its first draw is 270369, as the
## kernel's is.
##
## `ConstraintSolver` draws only to shuffle, once, before it searches: the
## variables, then each domain. Every later tie goes to whichever came first
## in that shuffled order, so a seed is one answer in both languages.
## `WaveCollapse` (T96) also draws during the search, once for each cell it
## collapses, from a second generator with the same seed.
##
## Complexity: constant per draw, linear per shuffle; one generator of state.
##
## When not to use it: anything that must be hard to predict. Its period is
## 2^32 - 1; for the order of a few hundred values, that is plenty.
class_name ConstraintDraws
extends RefCounted

## The kernel's rule for a seed of zero, under the name the solver and the
## collapse take their default seed from.
const SEED_FOR_ZERO: int = GakXorshift.SEED_FOR_ZERO

var _numbers: GakXorshift


## Draws that start from `from_seed`. The same seed gives the same draws, in
## this language and in `gameaikit.constraints.draws`.
func _init(from_seed: int = SEED_FOR_ZERO) -> void:
	_numbers = GakXorshift.new(from_seed)


## The next number, between 1 and 2^32 - 1, straight from the kernel's
## generator. The other draws are made from it.
func next() -> int:
	return _numbers.next()


## One of `count` choices, 0 to `count` - 1, by the kernel's rule: a draw is
## spent only when there is a choice, so both languages agree on a forced one.
func index(count: int) -> int:
	return _numbers.index(count)


## A copy of `items` in Fisher and Yates's order: from the last place down to
## the second, each swapped with one drawn from it and before it. The same
## steps as Python's, so the same seed gives the same order.
func shuffle(items: Array) -> Array:
	var shuffled: Array = items.duplicate()
	for place: int in range(shuffled.size() - 1, 0, -1):
		var other: int = index(place + 1)
		var kept: Variant = shuffled[place]
		shuffled[place] = shuffled[other]
		shuffled[other] = kept
	return shuffled
