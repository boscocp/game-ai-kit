## A small seeded random-number generator, written out so that Python can
## write out the same one and the two agree draw for draw.
##
## Godot's `RandomNumberGenerator` and Python's `random` are both good, and
## they are different generators: given the same seed they give different
## numbers, so a search, a particle cloud or a ghost that drew from either
## could never be held to its twin in the other language. Marsaglia's
## xorshift (2003) is three shifts and three exclusive-ors on a 32-bit number
## -- short enough to copy by hand and check by eye. Seeded with 1, its first
## draw is 270369.
##
## It lives in `ai_core` because Monte Carlo search, the particle filter, the
## bandit, the maze's ghosts and the constraint solver all draw from it, and
## each had copied it for want of a shared place (ADR 0021, amended by T109;
## the solver's copy folded in by T135). It decides nothing:
## which draw means what is the caller's business.
##
## GDScript's `int` is 64 bits, so every shift to the left is cut back to 32
## with `MASK`; Python's integers have no width at all and are cut the same
## way. Without the mask the two would part at the first draw.
##
## Complexity: constant per draw, one integer of state.
##
## When not to use it: anything that must be hard to predict -- a shuffle a
## player could exploit, cryptography. Its period is 2^32 - 1, and its low
## bits are weaker than its high ones; for a search's choices that is enough.
class_name GakXorshift
extends RefCounted

## Every value is kept to 32 bits, as Marsaglia's generator is defined.
const MASK: int = 0xFFFFFFFF
## A state of zero would stay zero forever, so a seed of zero starts here.
const SEED_FOR_ZERO: int = 1
## One more than the largest draw: `uniform` divides by it.
const SPAN: float = 4294967296.0

var _state: int = SEED_FOR_ZERO


## A generator that starts from `from_seed`. The same seed gives the same draws,
## in this language and in `gameaikit.core.xorshift`.
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
## is a choice to make: with one, the answer is 0 and the generator does not
## move. Both languages follow that rule, or they part at the first forced
## move.
func index(count: int) -> int:
	if count <= 1:
		return 0
	return next() % count


## A number in (0, 1), for choosing among outcomes by their chances.
func uniform() -> float:
	return next() / SPAN
