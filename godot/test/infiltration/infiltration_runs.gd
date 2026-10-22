## Runs of the infiltration level for the properties: a world, a scripted
## player, a cap on time, and a watcher called after every step.
##
## Every claim in `infiltration_properties.gd` is a watcher -- a Callable
## that reads the world after each step and answers "" or what it found --
## or a number measured over runs. The levels are the two hand-made ones
## and GENERATED from the generator, so every claim is held on ground no
## one tuned the guards on.
##
## When not to use it: in the game. A run here has no view.
class_name InfiltrationRuns
extends RefCounted

const GENERATED: Array[int] = [1, 2, 3]
## The longest run, in steps of the rules' step: two minutes.
const LONGEST: int = 1200


## The levels every claim is held on.
static func levels() -> Array[InfiltrationLevel]:
	var found: Array[InfiltrationLevel] = []
	for path: String in InfiltrationLevel.HAND_MADE:
		found.append(InfiltrationLevel.read(path))
	for seed_value: int in GENERATED:
		found.append(InfiltrationLevel.read(LevelGenerator.make(seed_value), "generated %d" % seed_value))
	return found


## Play `player` in `world` until it ends, LONGEST steps pass, or `watch`
## (world) -> String finds something or `stop` (world) -> bool says so;
## the first finding, or "".
static func play(world: InfiltrationWorld, player: ScriptedPlayer, watch: Callable, stop: Callable = Callable()) -> String:
	for step: int in range(LONGEST):
		world.step(player.intent(world))
		var found: String = watch.call(world)
		if found != "":
			return "%s at %.1f s: %s" % [world.level.name, world.time, found]
		if world.outcome != "" or (stop.is_valid() and bool(stop.call(world))):
			return ""
	return ""


## A watcher that finds nothing: for runs that are measured, not watched.
static func nothing(_world: InfiltrationWorld) -> String:
	return ""


## The highest phase any guard reached in a run of `player` on `level`.
static func highest_phase(level: InfiltrationLevel, rules: InfiltrationRules, player: ScriptedPlayer,
		change: Callable = Callable()) -> int:
	var world: InfiltrationWorld = InfiltrationWorld.make(level, rules, 1)
	if change.is_valid():
		change.call(world)
	var highest: Array[int] = [0]
	play(world, player, func(seen: InfiltrationWorld) -> String:
		for guard: InfiltrationGuard in seen.guards:
			highest[0] = maxi(highest[0], guard.mind.phase())
		return "")
	return highest[0]
