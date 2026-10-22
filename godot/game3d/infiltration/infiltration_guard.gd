## One guard of the infiltration level: its body, its mind and its belief,
## what it heard, and what it chose to do.
##
## The guard is T67's agent: each step its eyes and ears give it a
## `GuardPercept`; its `GuardMind` (T69) turns that into awareness and a
## memory; its own `BeliefMap` holds where the player may be, written only
## from what it perceived or a report it heard; and each decision
## `GuardChoice` scores every action it could take from those numbers
## (T67's `ActionChoice`) and `GuardActs` carries out the highest. Nothing
## here knows a level: the route and the post are given to it.
##
## When not to use it: as the player. The player decides nothing here.
class_name InfiltrationGuard
extends RefCounted

var id: int = 0
var type: GuardType
var mind: GuardMind
var belief: BeliefMap
var position: Vector2 = Vector2.ZERO
## Radians, 0 along +x, turning towards +z.
var facing: float = 0.0
var health: float = 100.0
## Where the level put it: its route, its post and how it faces there.
var route: Array[Vector2] = []
var post: Vector2 = Vector2.ZERO
var post_facing: float = 0.0
var route_index: int = 0
## Its decision: the action taken, every score, and the numbers behind them.
var action: String = "patrol"
var choice: ActionChoice.Choice
var numbers: Dictionary = {}
## Where it is walking, and the walk; INF, standing.
var goal: Vector2 = Vector2.INF
var path: Array[Vector2i] = []
var path_goal: Vector2i = Vector2i(-1, -1)
var running: bool = false
## What the team gave it: a spot to search (its index), a way out to
## cover, the last known position, a role in a fight.
var spot: int = -1
var way_out: Vector2 = Vector2.INF
var granted_last_known: bool = false
var role: String = RoleArbiter.NONE
## The last step's percept, and the cells it would have seen a body in.
var percept: GuardPercept = GuardPercept.new()
var seen_cells: PackedInt32Array = PackedInt32Array()
## The loudest event heard since the last step, for the next percept.
var heard: Dictionary = {}
var noticed_at: float = -INF
var help_heard_at: float = -INF
var reported_at: float = -INF
var alert_since: float = INF
var called: bool = false
## A call for help under way: when it is sent, and what it will carry.
var calling_until: float = -1.0
var body_unraised: Vector2 = Vector2.INF
var bodies_known: Array[Vector2] = []
## Each partner heard checking in: id -> [times, last time, last place].
var partners: Dictionary[int, Array] = {}
var quiet_place: Vector2 = Vector2.INF
var hit_at: float = -INF
var next_shot_at: float = 0.0
## When it first saw the player in this sighting; INF, not seeing.
var sees_since: float = INF
var next_check_in: float = 0.0


func _init(number: int, guard_type: GuardType, spec: Dictionary, nodes: Array[PackedInt32Array], rules: InfiltrationRules) -> void:
	id = number
	type = guard_type
	mind = GuardMind.new(guard_type)
	belief = BeliefMap.new(nodes)
	for point: Vector2 in spec["route"]:
		route.append(point)
	post = spec["post"]
	post_facing = float(spec["facing"])
	position = route[0] if not route.is_empty() else post
	facing = post_facing
	health = rules.guard("health")
	next_check_in = rules.guard("check_in_every") * (1.0 + 0.25 * number)


## True while it can act.
func alive() -> bool:
	return health > 0.0


## The higher of its awarenesses, as a share of the peak.
func aware() -> float:
	var peak: float = float(type.awareness["peak"])
	return maxf(mind.awareness["sight"].value, mind.awareness["sound"].value) / peak


## True in the top phase of its row.
func alert() -> bool:
	return mind.phase() == (type.awareness["phases"] as Array).size() - 1


## Where its eyes are, in 3D, on `arena`'s floor.
func eye(arena: BotArena, rules: InfiltrationRules) -> Vector3:
	return arena.above(position, rules.guard("eye_height"))
