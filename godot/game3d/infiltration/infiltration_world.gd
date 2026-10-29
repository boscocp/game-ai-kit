## The infiltration level running: the player, the guards, the sounds and
## the team, stepped a tenth of a second at a time, headless or under the
## demo's view alike.
##
## Each step the player moves and acts; each guard's eyes and ears give it
## a percept, its mind grows aware and remembers, and its belief collapses
## on what it saw or spreads where it did not look; guards check in by radio
## and notice a partner gone quiet. Each decision the team shares out the
## work and every guard weighs its actions (`GuardChoice`), and every step
## each carries its action out (`GuardActs`). The run ends when the player
## leaves by the exit, or is downed.
##
## A few seams are Callables so the properties can plant a broken technique
## in the same world: the coordinator, the arbiter, what counts as seen, the
## belief a search is weighed from, the decision, the act, and where a
## guard's post comes from. The game sets none of them.
##
## A step is linear in the guards, plus a flood per sound and a ray per
## cell in reach for each guard's belief.
##
## When not to use it: as the view. Drawing is `InfiltrationDrawing`'s.
class_name InfiltrationWorld
extends RefCounted

var level: InfiltrationLevel
var rules: InfiltrationRules
var actions: Array[ActionChoice.Action] = []
var player: InfiltrationPlayer
var guards: Array[InfiltrationGuard] = []
var team: GuardTeam
var sounds: LevelSounds
var rng := RandomNumberGenerator.new()
var time: float = 0.0
var next_decision: float = 0.0
var next_belief: float = 0.0
## Each guard's last decision, by id, as the overlay draws it.
var decisions: Dictionary[int, Dictionary] = {}
var shots: Array[Dictionary] = []
var bodies: Array[Vector2] = []
## "", "escaped" or "caught".
var outcome: String = ""
## The seams the properties plant in; see the header.
var coordinator: Callable = SearchCoordinator.assign
var arbiter: Callable = func(requests: Array[Dictionary], use: bool) -> PackedStringArray: return RoleArbiter.grant(requests, use)
var seen_by: Callable = GuardEyes.seen_cells
var believed: Callable = InfiltrationWorld.searched_from
var decide: Callable = GuardChoice.decide
var act: Callable = GuardActs.carry


## A world on `level` under `rules`, from `seed_value`. `specs` overrides
## where the guards stand -- the properties' planted guard reads it from
## another level; the game leaves it to the level.
static func make(on_level: InfiltrationLevel, with_rules: InfiltrationRules, seed_value: int, specs: Array[Dictionary] = []) -> InfiltrationWorld:
	var world := InfiltrationWorld.new()
	world.level = on_level
	world.rules = with_rules
	world.rng.seed = seed_value
	world.actions = InfiltrationRules.actions()
	var data: Dictionary = GuardType.read_file()
	var types: Dictionary[String, GuardType] = GuardType.all_in(data)
	world.sounds = LevelSounds.new(StimulusTable.new(data["events"]))
	world.player = InfiltrationPlayer.new(on_level.start, with_rules)
	for spec: Dictionary in (specs if not specs.is_empty() else on_level.guard_specs):
		world.guards.append(InfiltrationGuard.new(world.guards.size(), types[spec["type"]], spec, on_level.neighbours, with_rules,
			seed_value * 7919 + world.guards.size()))
	world.team = GuardTeam.new(on_level, with_rules)
	return world


## One step: the player's `intent`, then every guard senses, decides when
## a decision is due, and acts.
func step(intent: PlayerIntent) -> void:
	if outcome != "":
		return
	var seconds: float = rules.step_seconds
	time += seconds
	player.move(intent, level, rules, seconds)
	var noise: String = player.step_noise(rules, time)
	if noise != "":
		sounds.emit(self, noise, player.position, -1, Vector2.INF, 0.0, float(rules.player["noise_every"]))
	PlayerActions.apply(self, intent)
	var belief_due: bool = time >= next_belief
	if belief_due:
		next_belief = time + 1.0 / maxf(rules.belief_steps, 0.01)
	for guard: InfiltrationGuard in guards:
		if guard.alive():
			InfiltrationSenses.sense(guard, self, seconds, belief_due)
	InfiltrationSenses.check_in(self)
	if time >= next_decision:
		_decide_all()
	for guard: InfiltrationGuard in guards:
		if guard.alive():
			act.call(guard, self, seconds)
			_finish_call(guard)
	_end_when_over()


# Each decision: the team shares out the work, then every guard weighs.
func _decide_all() -> void:
	next_decision = time + rules.decision_seconds
	team.coordinate(self)
	for guard: InfiltrationGuard in guards:
		if guard.alive():
			decide.call(guard, self)


## The belief `guard` searches from in `world`: whichever the rules have
## on (`InfiltrationGuard.believed`).
static func searched_from(world: InfiltrationWorld, guard: InfiltrationGuard) -> PackedFloat64Array:
	return guard.believed(world.rules.use_particles)


## The guard by id.
func guard(number: int) -> InfiltrationGuard:
	return guards[number]


# A call for help is sent when it has been said for its whole time, and
# only by a guard still standing.
func _finish_call(guard: InfiltrationGuard) -> void:
	if guard.calling_until < 0.0 or time < guard.calling_until:
		return
	guard.calling_until = -1.0
	guard.called = true
	sounds.emit(self, "call_for_help", guard.position, guard.id, guard.mind.memory.place, 1.0)  # not shown: an identifier


func _end_when_over() -> void:
	if player.position.distance_to(level.exit_place) <= 1.0:
		outcome = "escaped"
	elif not player.alive():
		outcome = "caught"
