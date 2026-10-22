## What the guards share out each decision: who may go to the last known
## position, who searches which spot and who covers which way out
## (`GuardSearch`), and, once a fight starts, who shoots and who goes round.
##
## The wiring, not the techniques: `ai_teamwork`'s `SearchCoordinator` and
## `RoleArbiter` decide, and this hands them plain numbers, as invariant 2
## asks. What is shared follows what was heard: the last known position is
## capped among the guards who know that same place, and a search is shared
## only among guards who know the same thing (`GuardSearch`). A fight is
## shared by every guard in it -- each sees the player, or flanks a place
## it was told -- so the arbiter weighs them all. Each guard then weighs
## what it was given among its other actions: the team assigns, the guard
## decides.
##
## When not to use it: a lone guard. It needs none of this.
class_name GuardTeam
extends RefCounted

var search: GuardSearch
## The spots the search may give, for the view: {place, cell}.
var spots: Array[Dictionary]:
	get:
		return search.spots


func _init(level: InfiltrationLevel, rules: InfiltrationRules) -> void:
	search = GuardSearch.new(level, rules)


## Share out the work among the living guards for this decision.
func coordinate(world: InfiltrationWorld) -> void:
	var living: Array[InfiltrationGuard] = []
	for guard: InfiltrationGuard in world.guards:
		if guard.alive():
			living.append(guard)
	_grant_roles(world, living)
	_grant_last_known(world, living)
	_share_the_search(world, living)


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


# Among the guards that know each place, the nearest `last_known_cap` may
# go to it [Welsh 2015; Miles 2013].
func _grant_last_known(world: InfiltrationWorld, living: Array[InfiltrationGuard]) -> void:
	var wanting: Array[InfiltrationGuard] = []
	for guard: InfiltrationGuard in living:
		guard.granted_last_known = false
		if guard.mind.memory.known and guard.mind.at_least(str(world.rules.decision["suspect_from"])):
			wanting.append(guard)
	for group: Array in GuardSearch.by_knowledge(wanting):
		var costs := PackedFloat64Array()
		for guard: InfiltrationGuard in group:
			costs.append(guard.position.distance_to(guard.mind.memory.place))
		var cap: int = int(world.rules.search["last_known_cap"]) if world.rules.use_coordinator else group.size()
		for index: int in SearchCoordinator.grant_last_known(costs, cap):
			(group[index] as InfiltrationGuard).granted_last_known = true


func _share_the_search(world: InfiltrationWorld, living: Array[InfiltrationGuard]) -> void:
	var searchers: Array[InfiltrationGuard] = []
	for guard: InfiltrationGuard in living:
		guard.spot = -1
		guard.spot_from = -1
		guard.spot_for = Vector2.INF
		guard.way_out = Vector2.INF
		var searching: bool = guard.mind.at_least(str(world.rules.decision["search_from"]))
		if searching and not guard.percept.sight.perceived():
			searchers.append(guard)
	if not searchers.is_empty() and world.rules.use_belief:
		search.share(world, searchers)
