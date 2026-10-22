## The stealth properties about sound: it goes round walls, not through;
## the off-screen halving only lowers it; and nothing in a guard type's
## data names a cell of one level.
##
## Each claim takes the technique as a Callable, so `awareness_properties.gd`
## can hand it the real one, which must pass, and a planted one, which must
## not (invariant 4). Each returns its findings, one line each.
##
## When not to use it: as a level's sound. These only test it.
class_name SoundClaims
extends RefCounted

const RADIUS: float = 12.0
const TOLERANCE: float = 1e-9


## The honest loudness at `listener` of a noise at `source` on `level`: the
## flood along the level, then the loudness at its path length.
static func along_the_level(level: GridGraph, source: Vector2i, listener: Vector2i, radius: float) -> float:
	return SoundPaths.loudness_at(SoundPaths.lengths(level, source, radius, 1.0), listener, radius, 1.0)


## Planted: the straight line, as if walls let sound through.
static func through_walls(_level: GridGraph, source: Vector2i, listener: Vector2i, radius: float) -> float:
	return PathHearing.loudness(Vector2(listener - source).length(), radius)


## Sound goes round, not through: on `seeds` levels cut in two by a wall, a
## noise is heard by nobody on the far side at any distance, at 1 where it
## is made, and never louder further along the way. `heard` is called as
## (level, source, listener, radius); `source_of` (level, rng) picks where
## the noise is made.
static func goes_round(heard: Callable, source_of: Callable, seeds: int) -> Array[String]:
	for seed_value: int in range(1, seeds + 1):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var level: GridGraph = StealthWorlds.cut_in_two(rng)
		var source: Vector2i = source_of.call(level, rng)
		var wrong: String = _one_noise(level, source, heard)
		if wrong != "":
			return ["seed %d, a noise at %s: %s" % [seed_value, source, wrong]]
	return []


static func _one_noise(level: GridGraph, source: Vector2i, heard: Callable) -> String:
	if float(heard.call(level, source, source, RADIUS)) != 1.0:
		return "it is not heard at 1 where it is made"
	var reached: Dictionary[Vector2i, int] = CostFlood.within(GridSearchGraph.new(level), source, level.width * level.height * 10)
	for cell: Vector2i in StealthWorlds.free_cells(level):
		if not reached.has(cell) and float(heard.call(level, source, cell, RADIUS)) > 0.0:
			return "%s hears it with no way round the wall" % cell
	var by_length: Array[Vector2i] = reached.keys()
	by_length.sort_custom(func(one: Vector2i, other: Vector2i) -> bool: return reached[one] < reached[other])
	var last: float = 1.0
	for cell: Vector2i in by_length:
		var loudness: float = heard.call(level, source, cell, RADIUS)
		if loudness > last + TOLERANCE:
			return "%s is louder than a cell nearer along the way" % cell
		last = loudness
	return ""


## A noise anywhere on the level's free cells: where the honest claim makes
## it, so no cell of one level is assumed.
static func anywhere(level: GridGraph, rng: RandomNumberGenerator) -> Vector2i:
	var cells: Array[Vector2i] = StealthWorlds.free_cells(level)
	return cells[rng.randi_range(0, cells.size() - 1)] if not cells.is_empty() else Vector2i.ZERO


## Off-screen halving only lowers: over `seeds` random hearings, no
## listener hears an event louder with each guard type's factor than
## without it. `heard` is called as (path length, radius, factor).
static func halving_only_lowers(types: Dictionary[String, GuardType], heard: Callable, seeds: int) -> Array[String]:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	for draw: int in range(seeds):
		var type: GuardType = types.values()[draw % types.size()]
		var length: float = rng.randf_range(0.0, 2.0 * RADIUS)
		var factor: float = SoundPaths.listener_factor(type.hearing, rng.randi_range(1, 3), rng.randf() < 0.5, rng.randf_range(0.0, 20.0))
		if float(heard.call(length, RADIUS, factor)) > float(heard.call(length, RADIUS, 1.0)) + TOLERANCE:
			return ["draw %d: factor %.2f made %.2f m louder" % [draw, factor, length]]
	return []


## Planted: a factor above 1, taken at its word -- the halving written as a
## doubling, by a hearing with no clamp on the factor.
static func amplified(length: float, radius: float, factor: float) -> float:
	var taken: float = 2.0 if factor < 1.0 else factor
	return clampf(1.0 - length / (radius * taken), 0.0, 1.0)
