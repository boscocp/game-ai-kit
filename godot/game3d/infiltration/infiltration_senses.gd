## One guard's senses for one step: what it sees and hears, what its mind
## makes of that, the bodies it finds, and where its belief goes -- and the
## radio check-ins by which guards notice a partner gone quiet.
##
## The percept is built from the eyes (`GuardEyes`) and what reached the
## guard's ears since the last step (`LevelSounds`), and `GuardMind` (T69)
## reads nothing else. The belief collapses on the cell the eye put the
## player in, or else spreads and is zeroed where a hidden body would have
## been perceived -- and the particles (T91) also thin where a footstep
## would have been heard and none was; the cells it would have seen mark the team's search
## spots searched. With the accumulator switched off, sight is a plain
## yes-or-no: the peak when anything is perceived, nothing when not.
##
## A partner checks in by radio every `check_in_every` seconds; one heard
## at least twice and then silent for `quiet_after` is a partner gone quiet
## [Walsh 2015], an event the guard alone notices, at where it was last heard.
##
## When not to use it: to decide. Deciding is `GuardChoice`'s.
class_name InfiltrationSenses
extends RefCounted


## Sense one step of `seconds`; spread or collapse the belief when `belief_due`.
static func sense(guard: InfiltrationGuard, world: InfiltrationWorld, seconds: float, belief_due: bool) -> void:
	var percept: GuardPercept = GuardEyes.look_at_player(guard, world.player, world.level, world.rules, seconds)
	var heard: Dictionary = LevelSounds.heard_now(guard, world.time)
	if not heard.is_empty():
		percept.loudness = float(heard["loudness"])
		percept.heard_place = heard["place"]
		percept.heard_kind = str(heard["kind"])
	guard.percept = percept
	var perceived: bool = percept.sight.perceived()
	guard.sees_since = minf(guard.sees_since, world.time) if perceived else INF
	if perceived or percept.loudness > 0.0:
		guard.noticed_at = world.time
	guard.mind.step(percept, world.time, seconds, world.rules.awareness_rate)
	if not world.rules.use_accumulator:
		guard.mind.awareness["sight"].value = float(guard.type.awareness["peak"]) if perceived else 0.0
	_track_alert(guard, world)
	_find_bodies(guard, world)
	if belief_due:
		_update_belief(guard, world, perceived)


## Every living guard checks in when it is due, and every guard notices the
## partners it used to hear that have gone quiet.
static func check_in(world: InfiltrationWorld) -> void:
	for guard: InfiltrationGuard in world.guards:
		if guard.alive() and world.time >= guard.next_check_in:
			guard.next_check_in = world.time + world.rules.guard("check_in_every")
			world.sounds.emit(world, "check_in", guard.position, guard.id)  # not shown: an identifier
	for guard: InfiltrationGuard in world.guards:
		if guard.alive():
			_notice_silence(guard, world)


static func _notice_silence(guard: InfiltrationGuard, world: InfiltrationWorld) -> void:
	for partner: int in guard.partners:
		var heard: Array = guard.partners[partner]
		if int(heard[0]) >= 2 and world.time - float(heard[1]) >= world.rules.guard("quiet_after"):
			_gone_quiet(guard, world, partner, heard[2])


# The guard notices `partner` silent since it was heard at `place`.
static func _gone_quiet(guard: InfiltrationGuard, world: InfiltrationWorld, partner: int, place: Vector2) -> void:
	guard.quiet_place = place
	guard.partners[partner] = [-1, INF, place]
	var noticed: Dictionary = {"kind": "partner_quiet", "place": place, "at": world.time, "from": guard.id}  # not shown: an identifier
	noticed["reached"] = {}
	noticed["heard_by"] = [guard.id]
	world.sounds.recent.append(noticed)


static func _track_alert(guard: InfiltrationGuard, world: InfiltrationWorld) -> void:
	if guard.alert() and guard.alert_since == INF:
		guard.alert_since = world.time
		guard.called = false
	elif not guard.alert():
		guard.alert_since = INF


static func _find_bodies(guard: InfiltrationGuard, world: InfiltrationWorld) -> void:
	if guard.body_unraised != Vector2.INF:
		return
	for body: Vector2 in world.bodies:
		if not guard.bodies_known.has(body) and GuardEyes.sees_body(guard, world.level, world.rules, body):
			guard.body_unraised = body
			guard.mind.memory.remember(body, world.time, "body")  # not shown: an identifier
			return


static func _update_belief(guard: InfiltrationGuard, world: InfiltrationWorld, perceived: bool) -> void:
	var seen: PackedInt32Array = world.seen_by.call(guard, world.level, world.rules)
	guard.seen_cells = seen
	world.team.search.mark_seen(guard, seen)
	if not world.rules.use_belief:
		return
	var cell: Vector2i = world.level.cell_of(guard.percept.seen_place)
	if perceived and world.level.walkable(cell):
		guard.collapse_belief(world.level.index_of[cell])
	else:
		guard.belief.step_unseen(seen, world.rules.spread)
		guard.particles.step_unseen(seen, would_hear(guard, world))


## The walk cells a footstep made in would have reached `guard`, by index
## -- empty when it heard something this step, so silence is evidence only
## when there was silence. A particle there is weighed down, not zeroed: a
## player lying still makes no sound (`ParticleBelief`'s sensor model). The
## footstep's own radius, along the level, as `LevelSounds` floods it.
static func would_hear(guard: InfiltrationGuard, world: InfiltrationWorld) -> PackedInt32Array:
	var cells := PackedInt32Array()
	if guard.percept.loudness > 0.0:
		return cells
	var radius: float = world.sounds.table.radius("footstep")  # not shown: an identifier
	var reached: Dictionary[Vector2i, int] = CostFlood.within(world.level.arena.walk_graph,
		world.level.cell_of(guard.position), floori(radius))
	for reached_cell: Vector2i in reached:
		if world.level.index_of.has(reached_cell):
			cells.append(world.level.index_of[reached_cell])
	return cells
