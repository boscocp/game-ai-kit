## The level's walk graph as a sneaking player prices it: a cell in light
## costs more, and a cell a guard is watching now, or one near a guard,
## costs far more.
##
## The quiet player of `infiltration_properties.gd` plans over this with
## A*, as a person would pick a way through the shadows: it reads what a
## player can see -- where the guards stand, which way they face, which
## cells are lit -- and nothing of what any guard thinks.
##
## When not to use it: for a guard. Guards walk the plain walk graph.
class_name SneakGraph
extends GakSearchGraph

const LIT_COST: int = 12
const WATCHED_COST: int = 200
## A cell this near a guard is dear too: a guard turns, and a patrol walks
## on, and a player passing within arm's reach behind one is a player who
## chose to be seen.
const NEAR_A_GUARD: float = 4.0

var walk: ArenaWalk
var level: InfiltrationLevel
## Cells some guard watches now: in a zone with a clear line to a crouched
## body's chest.
var watched: Dictionary[Vector2i, bool] = {}


func _init(on_level: InfiltrationLevel, guards: Array[InfiltrationGuard], rules: InfiltrationRules) -> void:
	level = on_level
	walk = on_level.arena.walk_graph
	for guard: InfiltrationGuard in guards:
		if guard.alive():
			_watch(guard, rules)
			_keep_clear_of(guard)


## True when the cell is on the walk graph.
func contains(node: Vector2i) -> bool:
	return walk.contains(node)


## The walk graph's own neighbours: stairs and all.
func neighbours(node: Vector2i) -> Array[Vector2i]:
	return walk.neighbours(node)


## One, plus the light's price, plus the watched price where a guard looks.
func cost_at(node: Vector2i) -> int:
	var lit: int = roundi(level.light.at(node) * LIT_COST)
	return 1 + lit + (WATCHED_COST if watched.has(node) else 0)


## Manhattan distance: consistent, since no cell costs less than one.
func estimate(node: Vector2i, goal: Vector2i) -> int:
	return absi(node.x - goal.x) + absi(node.y - goal.y)


func _keep_clear_of(guard: InfiltrationGuard) -> void:
	for cell: Vector2i in level.cells:
		if BotArena.centre_of(cell).distance_to(guard.position) <= NEAR_A_GUARD:
			watched[cell] = true


func _watch(guard: InfiltrationGuard, rules: InfiltrationRules) -> void:
	var chest: float = rules.points_of("crouched")[1]
	for cell: Vector2i in level.cells:
		var offset: Vector2 = BotArena.centre_of(cell) - guard.position
		if guard.type.vision.zone_at(offset.length(), GuardEyes.angle_off(guard.facing, offset)) == -1:
			continue
		if level.arena.clear_line(guard.eye(level.arena, rules), level.arena.above(BotArena.centre_of(cell), chest)):
			watched[cell] = true
