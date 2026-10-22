## How loud a noise is at a listener, from the length of the way between
## them: 1 at the source, 0 at the edge of its radius and where no way exists.
##
## Measured in a straight line, a sound "would mean the player would be
## heard through walls" [Walsh 2015]; Mark of the Ninja runs its search over
## the level, and a guard inside the radius with no path to the noise does
## not hear it [Miles 2013]. So this takes the path length, not the two
## positions -- the caller floods the level (the cost flood in `ai_search`) and
## passes what it found. `Hearing`, the straight line, stays for the 2D
## stealth demo, whose walls a guard is meant to hear through.
##
## A listener factor of at most 1 shrinks the radius for that listener:
## Walsh's off-screen halving, where a guard the player cannot see hears
## minor events at half the radius because being heard by it "feels unfair"
## whatever the simulation says [Walsh 2015]. A factor above 1 is read as 1,
## so the factor can only ever lower what is heard. Constant time.
##
## When not to use it: sound that should go through a thin wall at a cost.
## Give the wall a cost in the graph the flood walks, and this still works;
## leave it out of the graph and nothing is heard through it.
class_name PathHearing
extends RefCounted

## A path length that means "no way from the noise to the listener".
const NO_PATH: float = -1.0


## The loudness at a listener `path_length` away along the level from a
## noise of `radius`, for a listener whose radius is scaled by
## `listener_factor` (1 hears in full; 0.5, Walsh's halving).
static func loudness(path_length: float, radius: float, listener_factor: float = 1.0) -> float:
	var heard_within: float = radius * clampf(listener_factor, 0.0, 1.0)
	if path_length < 0.0 or not is_finite(path_length) or heard_within <= 0.0:
		return 0.0
	return clampf(1.0 - path_length / heard_within, 0.0, 1.0)
