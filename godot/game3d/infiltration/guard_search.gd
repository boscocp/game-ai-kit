## Who searches which spot, and who covers which way out -- shared only
## among guards who know the same thing.
##
## **A search is shared by what was heard, not by being on the same side.**
## Guards whose memories hold the same place -- because they heard the same
## report, or saw the same sighting -- search together: the spots are
## weighed from the freshest one's belief, the spots any of them has seen
## are off the list, and `ai_teamwork`'s `SearchCoordinator` divides the
## rest so no two take one [Welsh 2015]. A guard whose knowledge no one
## shares -- raised by its own footstep, or out of earshot of the report --
## searches alone, from its own belief. Each spot a guard is given records
## whose belief it was weighed from (`InfiltrationGuard.spot_from`), so a
## claim can hold that no guard is sent by a belief it never heard of.
##
## "Searched" is each guard's own: the spots its eyes would have seen a
## hidden body at, since its knowledge last changed. A group's searched
## spots are its members' together.
##
## The spots are the level's cover spots and hiding places; the ways out
## are the edge of the group's likely region, found on the walk graph
## (`GuardWaysOut`). A flood per searcher, and the coordinator's pairing.
##
## When not to use it: guards that share a mind -- a hive. Then one belief
## and one list is the honest model, and this grouping is ceremony.
class_name GuardSearch
extends RefCounted

## Each spot: {place, cell (index)}.
var spots: Array[Dictionary] = []
## For each cell index, the spots within the search radius of it.
var spots_near: Array[PackedInt32Array] = []
## How searchers are grouped: (searchers) -> Array of groups. The game's
## groups by knowledge; the properties plant one group for all.
var group_of: Callable = GuardSearch.by_knowledge


func _init(level: InfiltrationLevel, rules: InfiltrationRules) -> void:
	var places: Array[Vector2] = []
	for spot: BotArena.Spot in level.arena.spots:
		places.append(spot.position)
	for cell: Vector2i in level.hidden:
		places.append(BotArena.centre_of(cell))
	for place: Vector2 in places:
		if level.walkable(level.cell_of(place)):
			spots.append({"place": place, "cell": level.index_of[level.cell_of(place)]})
	spots_near.resize(level.cells.size())
	for index: int in range(spots.size()):
		for cell: int in _cells_within(level, spots[index]["place"], float(rules.search["spot_radius"])):
			spots_near[cell].append(index)


## Mark the spots `guard`'s eyes would have seen a hidden body at, `seen`
## by cell index, as searched by it -- starting afresh when its knowledge
## changed since it last marked.
func mark_seen(guard: InfiltrationGuard, seen: PackedInt32Array) -> void:
	if guard.searched_for != guard.mind.memory.place:
		guard.searched_for = guard.mind.memory.place
		guard.searched.clear()
	for cell: int in seen:
		_mark_cell(guard, cell)


# The spots standing on `cell`, searched by `guard`.
func _mark_cell(guard: InfiltrationGuard, cell: int) -> void:
	for spot: int in spots_near[cell]:
		if int(spots[spot]["cell"]) == cell:
			guard.searched[spot] = true


## Give each of `searchers` a spot or a way out, group by group.
func share(world: InfiltrationWorld, searchers: Array[InfiltrationGuard]) -> void:
	for group: Array in group_of.call(searchers):
		var members: Array[InfiltrationGuard] = []
		members.assign(group)
		_search_together(world, members)


## The searchers grouped by the place their memories hold: guards that
## heard one report, or saw one sighting, know the same place.
static func by_knowledge(searchers: Array[InfiltrationGuard]) -> Array:
	var groups: Dictionary = {}
	for guard: InfiltrationGuard in searchers:
		var known: Vector2 = guard.mind.memory.place
		if not groups.has(known):
			groups[known] = []
		groups[known].append(guard)
	return groups.values()


## The spots `group` has searched between them.
func searched_by(group: Array[InfiltrationGuard]) -> Dictionary:
	var union: Dictionary = {}
	for guard: InfiltrationGuard in group:
		if guard.searched_for == guard.mind.memory.place:
			union.merge(guard.searched)
	return union


func _search_together(world: InfiltrationWorld, group: Array[InfiltrationGuard]) -> void:
	var lead: InfiltrationGuard = _freshest(group)
	var worth: Array[Dictionary] = _spots_with_worth(world.believed.call(world, lead), searched_by(group))
	var costs: Array[PackedFloat64Array] = []
	for guard: InfiltrationGuard in group:
		costs.append(_walks(world.level, guard))
	var weights := SearchCoordinator.Weights.new()
	weights.worth = float(world.rules.search["worth"])
	weights.travel = float(world.rules.search["travel"])
	var given: PackedInt32Array = world.coordinator.call(worth, costs, world.rules.use_coordinator, weights)
	for index: int in range(group.size()):
		group[index].spot = given[index]
		group[index].spot_from = lead.id
		group[index].spot_for = group[index].mind.memory.place
	GuardWaysOut.assign(world.level, world.believed.call(world, lead), group)


func _spots_with_worth(shares: PackedFloat64Array, searched: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for index: int in range(spots.size()):
		rows.append({"worth": 0.0, "searched": searched.has(index)})
	for cell: int in range(shares.size()):
		for spot: int in spots_near[cell]:
			rows[spot]["worth"] = float(rows[spot]["worth"]) + shares[cell]
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
