## The seeded generator a `ConstraintSolver` orders its ties with, written
## out so that Python can write out the same one and the two agree draw for
## draw.
##
## Godot's `RandomNumberGenerator` and Python's `random` are different
## generators, so a solver shuffling with either could never be held to its
## twin in the other language. This is Marsaglia's xorshift (2003): three
## shifts and three exclusive-ors on a 32-bit number. **It is a copy** of the
## generator T86 wrote for Monte Carlo search, T91 for the particle filter
## and T99 for the bandit. Since T109 that generator lives in the kernel,
## `ai_core`, which this addon may use (invariant 2 allows the kernel);
## T95 wrote this copy before, and folding it in is T135. Seeded with 1, its
## first draw is 270369, as theirs is.
##
## `ConstraintSolver` draws only to shuffle, once, before it searches: the
## variables, then each domain. Every later tie goes to whichever came first
## in that shuffled order, so a seed is one answer in both languages.
## `WaveCollapse` (T96) also draws during the search, once for each cell it
## collapses, from a second generator with the same seed.
##
## GDScript's `int` is 64 bits, so every shift to the left is cut back to 32
## with `MASK`; without it the two languages part at the first draw.
##
## Complexity: constant per draw, linear per shuffle; one integer of state.
##
## When not to use it: anything that must be hard to predict. Its period is
## 2^32 - 1; for the order of a few hundred values, that is plenty.
class_name ConstraintDraws
extends RefCounted

## Every value is kept to 32 bits, as Marsaglia's generator is defined.
const MASK: int = 0xFFFFFFFF
## A state of zero would stay zero forever, so a seed of zero starts here.
const SEED_FOR_ZERO: int = 1

var _state: int = SEED_FOR_ZERO


## A generator that starts from `from_seed`. The same seed gives the same
## draws, in this language and in `gameaikit.constraints.draws`.
func _init(from_seed: int = SEED_FOR_ZERO) -> void:
	_state = from_seed & MASK
	if _state == 0:
		_state = SEED_FOR_ZERO


## The next number, between 1 and 2^32 - 1. The other draws are made from it.
func next() -> int:
	_state ^= (_state << 13) & MASK
	_state ^= _state >> 17
	_state ^= (_state << 5) & MASK
	return _state


## One of `count` choices, 0 to `count` - 1. A draw is spent only when there
## is a choice: with one, the answer is 0 and the generator does not move.
func index(count: int) -> int:
	if count <= 1:
		return 0
	return next() % count


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
