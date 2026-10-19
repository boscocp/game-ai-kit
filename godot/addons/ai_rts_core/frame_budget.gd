## How a sixtieth of a second is shared out, and how much each layer spent.
##
## A frame at 60 frames a second is 16.7 ms, and the AI is not the only thing
## in it: drawing, input and the engine's own work take the rest. The shares
## below are this kit's, stated in milliseconds so a measurement can hold
## them. What layers do *within* a share is counted in work -- cells settled,
## nodes expanded -- never cut off by the clock, because a match that decided
## by the clock would not replay. The clock is only read here, to measure.
##
## How often a layer decides is a different question from how much of a
## frame it may take. The StarCraft survey (Ontañón et al., 2013) puts
## strategy on a scale of minutes and reactive control near a second; a
## strategic replan may be heavy and rare, so it is the layer that must be
## cut into slices, as Killzone 3's planners are (ADR 0010).
##
## When not to use it: as a profiler. It times layers the world hands it, and
## nothing else; Godot's own profiler sees the whole frame.
class_name FrameBudget
extends RefCounted

const FRAME_MS: float = 1000.0 / 60.0
## Moving, fighting, gathering, building and training every unit.
const SIMULATION: String = "simulation"
## Settling flow fields, `RtsWorld.FIELD_CELLS_PER_TICK` cells at most.
const FLOW_FIELDS: String = "flow fields"
## Where squads go: utility over influence maps, T20's.
const TACTICS: String = "tactics"
## The commander's plan, in slices: T20's, under ADR 0010.
const STRATEGY: String = "strategy"
## Each layer's share of a frame, in milliseconds. 8.0 of the 16.7 is the
## AI's; the other 8.7 are left for drawing and the engine.
const SHARES: Dictionary = {SIMULATION: 4.0, FLOW_FIELDS: 1.5, TACTICS: 1.0, STRATEGY: 1.5}

# Layer -> every time it was measured, in microseconds.
var _measured: Dictionary = {}


## Note that `layer` took `microseconds` this frame.
func record(layer: String, microseconds: int) -> void:
	# A packed array is a value: appending to the one read out of the
	# dictionary appends to a copy, and the first version recorded nothing.
	var times: PackedInt64Array = _measured.get(layer, PackedInt64Array())
	times.append(microseconds)
	_measured[layer] = times


## How many times `layer` was measured.
func count(layer: String) -> int:
	return (_measured.get(layer, PackedInt64Array()) as PackedInt64Array).size()


## The mean time `layer` took, in milliseconds; 0 when never measured.
func mean_ms(layer: String) -> float:
	var times: PackedInt64Array = _measured.get(layer, PackedInt64Array())
	var total: int = 0
	for time: int in times:
		total += time
	return total / 1000.0 / times.size() if not times.is_empty() else 0.0


## The time `layer` stayed under in `fraction` of its frames (0.95: all but
## the slowest one in twenty), in milliseconds. A percentile rather than the
## worst, because the worst frame of a thousand is the operating system's as
## often as the code's.
func percentile_ms(layer: String, fraction: float) -> float:
	var times: PackedInt64Array = (_measured.get(layer, PackedInt64Array()) as PackedInt64Array).duplicate()
	if times.is_empty():
		return 0.0
	times.sort()
	return times[mini(int(times.size() * fraction), times.size() - 1)] / 1000.0


## Why `layer` broke its share, or "" when its mean and its 95th percentile
## both fit.
func why_over(layer: String) -> String:
	var share: float = SHARES[layer]
	if count(layer) == 0:
		return "%s was never measured" % layer
	if mean_ms(layer) > share or percentile_ms(layer, 0.95) > share:
		return "%s: mean %.2f ms, 95th percentile %.2f ms, share %.2f ms" % [
			layer, mean_ms(layer), percentile_ms(layer, 0.95), share]
	return ""
