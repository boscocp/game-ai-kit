## The seeded generator a `ParticleBelief` draws from, written out so that
## Python can write out the same one and the two agree draw for draw.
##
## Godot's `RandomNumberGenerator` and Python's `random` are different
## generators, so a particle cloud drawn from either could never be held to
## its twin in the other language. This is Marsaglia's xorshift (2003): three
## shifts and three exclusive-ors on a 32-bit number. **It is a copy** of
## the generator T86 wrote for Monte Carlo search, a dozen lines: an
## addon depends on nothing but `ai_core` (invariant 2), so it cannot
## import that one, and moving one generator into `ai_core` is for the
## owner to decide (ADR 0021 keeps `ai_core` to the grid and the
## pathfinder port). Seeded with 1, its first draw is 270369, as that
## one's is.
##
## GDScript's `int` is 64 bits, so every shift to the left is cut back to 32
## with `MASK`; without it the two languages part at the first draw.
##
## Complexity: constant per draw, one integer of state.
##
## When not to use it: anything that must be hard to predict. Its period is
## 2^32 - 1; for where a guard guesses the player went, that is plenty.
class_name ParticleDraws
extends RefCounted

## Every value is kept to 32 bits, as Marsaglia's generator is defined.
const MASK: int = 0xFFFFFFFF
## A state of zero would stay zero forever, so a seed of zero starts here.
const SEED_FOR_ZERO: int = 1
## One more than the largest draw: `uniform` divides by it.
const SPAN: float = 4294967296.0

var _state: int = SEED_FOR_ZERO


## A generator that starts from `from_seed`. The same seed gives the same
## draws, in this language and in `gameaikit.perception.draws`.
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
## Both languages follow that rule, or they part at the first dead end.
func index(count: int) -> int:
	if count <= 1:
		return 0
	return next() % count


## A number in (0, 1), for choosing among outcomes by their chances.
func uniform() -> float:
	return next() / SPAN
