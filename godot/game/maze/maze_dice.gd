## The maze's dice: Marsaglia's 32-bit xorshift, written out so that Python
## writes out the same one and a seed means the same game in both.
##
## The same generator as `ai_adversarial`'s `Xorshift`, copied rather than
## used, so that the maze stands alone: an example reaching into the
## adversarial-search addon for its dice would be listed as using it.
## Godot's `RandomNumberGenerator` and Python's `random` are different
## generators, and a seed in one says nothing about the other.
##
## GDScript's `int` is 64 bits, so every shift to the left is cut back to 32
## with `MASK`, as `gameaikit.maze.dice` cuts Python's. Seeded with 1, the
## first draw is 270369.
##
## When not to use it: anything that must be hard to predict. Its period is
## 2^32 - 1 and its low bits are weak; for a ghost's fork that is enough.
class_name MazeDice
extends RefCounted

## Every value is kept to 32 bits, as Marsaglia's generator is defined.
const MASK: int = 0xFFFFFFFF
## A state of zero would stay zero forever, so a seed of zero starts here.
const SEED_FOR_ZERO: int = 1
## One more than the largest draw: `uniform` divides by it.
const SPAN: float = 4294967296.0

var _state: int = SEED_FOR_ZERO


## Dice that start from `from_seed`: the same seed, the same draws, in this
## language and in Python.
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


## One of `count` choices, 0 to `count` - 1: which way at an imprecise fork.
func index(count: int) -> int:
	return next() % count


## A number in (0, 1): whether an imprecise ghost keeps the Dossier's way.
func uniform() -> float:
	return next() / SPAN
