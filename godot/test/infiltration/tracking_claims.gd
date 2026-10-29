## T91's measurement: does a guard that believes with particles find a
## player it lost sooner than one that believes with the grid?
##
## T73 asked whether the particle filter "finds you sooner", and the task
## asked for it measured, whichever way it goes. So the claim held here is
## not that it does -- that is a number, printed and written into
## `docs/godot/infiltration.md` -- but that the measurement measured
## something: enough runs lost a player in both modes, and the particles
## changed what the guards did. The planted case: the particles on and
## stepped as the game steps them, the search wired to the grid instead
## (`InfiltrationWorld.believed`) -- which must make the runs the grid's.
##
## A run (`stage`): a radio report says the player was seen at a place; it
## is there, crouched, and creeps along the walk to a hiding place no guard
## watches 8 to 14 steps away -- the place `HidingStage` draws -- and lies
## prone. Unlike `HidingStage`'s player it moves after it was reported, so
## how a belief models a person walking is what is measured. From the first
## step it lies hidden and no guard has found it, the clock runs until one
## does -- `HidingStage.found`: within reach, or seeing it at least
## `FOUND_SURE` -- or LOST_FOR seconds pass. A glimpse on the way collapses
## the beliefs, as it would in play; a glimpse is not a find. Every run is seeded: the places from
## the seed, and every guard's particles from it.
##
## Measured first with T70's `hide` player -- show yourself, sprint to a
## hiding place -- most runs never got there: the player was shot down on
## the way, or found no way past the guards, and a run that ends in a
## fight measures the fight, not the search.
##
## When not to use it: as the guards' code. This only measures them.
class_name TrackingClaims
extends RefCounted

## How many generated levels, seeds 1 to this.
const GENERATED: int = 20
## The seeds each level is staged with.
const SEEDS: Array[int] = [1, 2]
## Seconds a lost player is searched for before the run counts as never found.
const LOST_FOR: float = 60.0
## The longest run, in steps: the creep to the hiding place and LOST_FOR.
const LONGEST: int = 1000
## Of the runs, how many must lose the player in each mode.
const FEWEST_MEASURED: int = 20


## The levels the measurement runs on.
static func levels() -> Array[InfiltrationLevel]:
	var found: Array[InfiltrationLevel] = []
	for path: String in InfiltrationLevel.HAND_MADE:
		found.append(InfiltrationLevel.read(path))
	for seed_value: int in range(1, GENERATED + 1):
		found.append(InfiltrationLevel.read(LevelGenerator.make(seed_value), "generated %d" % seed_value))
	return found


## The grid, the particles: the two beliefs compared.
static func modes() -> Dictionary:
	return {
		"grid": func(rules: InfiltrationRules) -> void: rules.use_particles = false,
		"particles": func(rules: InfiltrationRules) -> void: rules.use_particles = true,
	}


## Planted: the particles on, stepped every step as the game steps them,
## and the search wired to the grid's belief instead.
static func wired_to_nothing(world: InfiltrationWorld) -> void:
	world.believed = func(_world: InfiltrationWorld, guard: InfiltrationGuard) -> PackedFloat64Array:
		return guard.belief.shares


## Stage a run in `world` from `seed_value`: the player put where a radio
## report says it was seen, and the walk it will creep to a hiding place
## returned -- empty when the level gives no place to stage it.
static func stage(world: InfiltrationWorld, seed_value: int) -> Array[Vector2i]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var hidings: Array[Vector2] = HidingStage.unwatched_hidings(world)
	if hidings.is_empty():
		return []
	var hide_at: Vector2 = hidings[rng.randi_range(0, hidings.size() - 1)]
	var around: Array[Vector2] = HidingStage.cells_steps_from(world, hide_at)
	if around.is_empty():
		return []
	var seen_at: Vector2 = around[rng.randi_range(0, around.size() - 1)]
	var level: InfiltrationLevel = world.level
	var walk: SearchResult = AStarSearch.new().search(level.arena.walk_graph, level.cell_of(seen_at), level.cell_of(hide_at))
	if not walk.reached:
		return []
	world.player.position = seen_at
	world.player.stance = "crouched"  # not shown: an identifier
	world.sounds.emit(world, "radio_report", seen_at, -1, seen_at, HidingStage.URGENCY)
	return walk.path


## Seconds from the player lying hidden, unfound, to a guard finding it,
## on `level` staged from `seed_value`, `change` applied to the rules and
## `plant`, when valid, to the world; LOST_FOR when never; NAN when the
## run could not be staged or no guard ever lost it.
static func regained_after(level: InfiltrationLevel, seed_value: int, change: Callable, plant: Callable = Callable()) -> float:
	var rules: InfiltrationRules = InfiltrationRules.read()
	change.call(rules)
	var world: InfiltrationWorld = InfiltrationWorld.make(level, rules, seed_value)
	if plant.is_valid():
		plant.call(world)
	var creep := ScriptedPlayer.new("creep", stage(world, seed_value))
	if creep.path.is_empty():
		return NAN
	var lying := ScriptedPlayer.new("still")
	var lost: float = INF
	for step: int in range(LONGEST):
		world.step((creep if not creep.path.is_empty() else lying).intent(world))
		var seen: bool = HidingStage.found(world)
		if lost == INF and creep.path.is_empty() and not seen:
			lost = world.time
		elif lost != INF and seen:
			return world.time - lost
		elif lost != INF and world.time - lost >= LOST_FOR:
			return LOST_FOR
	return NAN


## Every run of `levels` x SEEDS under `change` (and `plant`), in order:
## seconds or NAN.
static func runs(levels: Array[InfiltrationLevel], change: Callable, plant: Callable = Callable()) -> Array[float]:
	var times: Array[float] = []
	for level: InfiltrationLevel in levels:
		for seed_value: int in SEEDS:
			times.append(regained_after(level, seed_value, change, plant))
	return times


## The measured runs of `times` (the NANs left out), from level `first` to
## before level `last`, as [count, mean, median, found within LOST_FOR].
static func summary(times: Array[float], first: int, last: int) -> Array:
	var measured: Array[float] = []
	for index: int in range(first * SEEDS.size(), mini(last * SEEDS.size(), times.size())):
		if not is_nan(times[index]):
			measured.append(times[index])
	if measured.is_empty():
		return [0, NAN, NAN, 0]
	measured.sort()
	var total: float = 0.0
	var regained: int = 0
	for seconds: float in measured:
		total += seconds
		regained += 1 if seconds < LOST_FOR else 0
	return [measured.size(), total / measured.size(), measured[floori(measured.size() / 2.0)], regained]


## The claims over the two modes' runs and the planted one's, as findings:
## enough measured in each, and the particles changed something. `planted`
## may be shorter -- the first levels' runs only -- and is held against as
## many of the grid's.
static func findings(grid: Array[float], particles: Array[float], planted: Array[float]) -> Array[String]:
	var honest: Array[String] = []
	for mode: Array in [["grid", grid], ["particles", particles]]:
		var measured: int = (mode[1] as Array).filter(func(seconds: float) -> bool: return not is_nan(seconds)).size()
		if measured < FEWEST_MEASURED:
			honest.append("%s: %d run(s) lost the player, fewer than %d" % [mode[0], measured, FEWEST_MEASURED])
	if _same(grid, particles):
		honest.append("the particles changed no run: the search does not read them")
	var caught: Array[String] = []
	if _same(grid.slice(0, planted.size()), planted):
		caught.append("the particles wired to nothing changed no run")
	return LevelClaims.pair("the particles are what the search reads", honest, caught)


# True when every run of `one` took what the same run of `other` did.
static func _same(one: Array[float], other: Array[float]) -> bool:
	for index: int in range(one.size()):
		var both_nan: bool = is_nan(one[index]) and is_nan(other[index])
		if not both_nan and not is_equal_approx(one[index], other[index]):
			return false
	return true
