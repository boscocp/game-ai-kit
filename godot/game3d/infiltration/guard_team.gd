## What the guards share out each decision: who may go to the last known
## position, who searches which spot, who covers which way out, and, once
## a fight starts, who shoots and who goes round.
##
## The wiring, not the techniques: `ai_teamwork`'s `SearchCoordinator` and
## `RoleArbiter` decide, and this hands them plain numbers -- each
## searcher's walk to each spot (a flood over the walk graph), each spot's
## worth (the belief's mass round it), whether a sight line already reached
## it -- as invariant 2 asks. The spots are the level's cover spots and
## hiding places; the ways out are the edge of the belief's likely region,
## found on the walk graph, never marked by hand [Welsh 2015]. Each guard
## then weighs what it was given among its other actions: the team assigns,
## the guard decides.
##
## A flood per searcher, and the coordinator's greedy pairing.
##
## When not to use it: guards that cannot talk. This shares out work among
## guards in contact; a lone guard needs none of it.
class_name GuardTeam
extends RefCounted

## Each spot: {place, cell (index), searched}.
var spots: Array[Dictionary] = []
## For each cell index, the spots within the search radius of it.
var spots_near: Array[PackedInt32Array] = []
## The memory every search is about: a new one starts the search afresh.
var searching_for: float = -INF


func _init(level: InfiltrationLevel, rules: InfiltrationRules) -> void:
	var places: Array[Vector2] = []
	for spot: BotArena.Spot in level.arena.spots:
		places.append(spot.position)
	for cell: Vector2i in level.hidden:
		places.append(BotArena.centre_of(cell))
	for place: Vector2 in places:
		if level.walkable(level.cell_of(place)):
			spots.append({"place": place, "cell": level.index_of[level.cell_of(place)], "searched": false})
	spots_near.resize(level.cells.size())
	for index: int in range(spots.size()):
		for cell: int in _cells_within(level, spots[index]["place"], float(rules.search["spot_radius"])):
			spots_near[cell].append(index)


## Share out the work among `guards` for this decision.
func coordinate(world: InfiltrationWorld) -> void:
	var living: Array[InfiltrationGuard] = []
	for guard: InfiltrationGuard in world.guards:
		if guard.alive():
			living.append(guard)
	_grant_roles(world, living)
	_grant_last_known(world, living)
	_share_the_search(world, living)


## Mark every spot a guard would have seen a hidden body at: searched.
func mark_seen(seen: PackedInt32Array) -> void:
	for cell: int in seen:
		for spot: int in spots_near[cell]:
			spots[spot]["searched"] = bool(spots[spot]["searched"]) or spots[spot]["cell"] == cell


func _grant_roles(world: InfiltrationWorld, living: Array[InfiltrationGuard]) -> void:
	var fighters: Array[InfiltrationGuard] = []
	var requests: Array[Dictionary] = []
	for guard: InfiltrationGuard in living:
		guard.role = RoleArbiter.NONE
		if guard.alert():
			fighters.append(guard)
			requests.append(request_of(guard))
	var granted: PackedStringArray = world.arbiter.call(requests, world.rules.use_arbiter)
	for index: int in range(fighters.size()):
		fighters[index].role = granted[index]


## What a guard in a fight asks for: to shoot when it sees the player --
## surer, a better shooter -- or else to go round, the nearer the last
## known position, the better a flanker.
static func request_of(guard: InfiltrationGuard) -> Dictionary:
	if guard.percept.sight.perceived():
		return {"role": RoleArbiter.SHOOTER, "can_shoot": true, "score": guard.percept.sight.certainty}
	var away: float = guard.position.distance_to(guard.mind.memory.place)
	return {"role": RoleArbiter.FLANKER, "can_shoot": true, "score": 1.0 / (1.0 + away)}


func _grant_last_known(world: InfiltrationWorld, living: Array[InfiltrationGuard]) -> void:
	var wanting: Array[InfiltrationGuard] = []
	var costs := PackedFloat64Array()
	for guard: InfiltrationGuard in living:
		guard.granted_last_known = false
		if guard.mind.memory.known and guard.mind.phase() >= 1:
			wanting.append(guard)
			costs.append(guard.position.distance_to(guard.mind.memory.place))
	var cap: int = int(world.rules.search["last_known_cap"]) if world.rules.use_coordinator else wanting.size()
	for index: int in SearchCoordinator.grant_last_known(costs, cap):
		wanting[index].granted_last_known = true


func _share_the_search(world: InfiltrationWorld, living: Array[InfiltrationGuard]) -> void:
	var searchers: Array[InfiltrationGuard] = []
	for guard: InfiltrationGuard in living:
		guard.spot = -1
		guard.way_out = Vector2.INF
		if guard.mind.phase() >= 2 and not guard.percept.sight.perceived():
			searchers.append(guard)
	if searchers.is_empty() or not world.rules.use_belief:
		return
	var lead: InfiltrationGuard = _freshest(searchers)
	if lead.mind.memory.at != searching_for:
		_start_afresh(lead.mind.memory.at, living)
	var worth: Array[Dictionary] = _spots_with_worth(lead.belief)
	var costs: Array[PackedFloat64Array] = []
	for guard: InfiltrationGuard in searchers:
		costs.append(_walks(world.level, guard))
	var weights := SearchCoordinator.Weights.new()
	weights.worth = float(world.rules.search["worth"])
	weights.travel = float(world.rules.search["travel"])
	var given: PackedInt32Array = world.coordinator.call(worth, costs, world.rules.use_coordinator, weights)
	for index: int in range(searchers.size()):
		searchers[index].spot = given[index]
	GuardWaysOut.assign(world.level, lead.belief, searchers)


# A new memory, a new search: every spot unsearched, but for those a guard
# would see a hidden body at now.
func _start_afresh(memory_at: float, living: Array[InfiltrationGuard]) -> void:
	searching_for = memory_at
	for spot: Dictionary in spots:
		spot["searched"] = false
	for guard: InfiltrationGuard in living:
		mark_seen(guard.seen_cells)


func _spots_with_worth(belief: BeliefMap) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for spot: Dictionary in spots:
		rows.append({"worth": 0.0, "searched": spot["searched"]})
	for cell: int in range(belief.shares.size()):
		for spot: int in spots_near[cell]:
			rows[spot]["worth"] = float(rows[spot]["worth"]) + belief.shares[cell]
	return rows


# Metres of walk from the guard to each spot, INF where none reaches.
func _walks(level: InfiltrationLevel, guard: InfiltrationGuard) -> PackedFloat64Array:
	var steps: PackedInt32Array = level.arena.steps_from([level.cell_of(guard.position)])
	var row := PackedFloat64Array()
	for spot: Dictionary in spots:
		var cell: Vector2i = level.cells[int(spot["cell"])]
		var walked: int = steps[cell.y * int(level.arena.width) + cell.x]
		row.append(INF if walked < 0 else float(walked))
	return row


static func _freshest(guards: Array[InfiltrationGuard]) -> InfiltrationGuard:
	var best: InfiltrationGuard = guards[0]
	for guard: InfiltrationGuard in guards:
		if guard.mind.memory.at > best.mind.memory.at:
			best = guard
	return best


static func _cells_within(level: InfiltrationLevel, place: Vector2, radius: float) -> PackedInt32Array:
	var found := PackedInt32Array()
	for index: int in range(level.cells.size()):
		if BotArena.centre_of(level.cells[index]).distance_to(place) <= radius:
			found.append(index)
	return found
