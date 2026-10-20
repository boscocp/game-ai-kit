## A squad: a handful of fighters that go somewhere together, and the
## state machine that says what they are doing about it.
##
## The middle of ADR 0010's three layers. The commander decides what to
## build; `SquadTactics` decides where each squad goes; the squad decides,
## from what its members can see, whether it is gathering, advancing,
## fighting or falling back -- T15's `StateMachine`, whose arrows each carry
## the sentence the screen shows when one is taken. Its members move by the
## flow fields T19 built: one move order for the whole squad, one field.
##
## Orders are given only when they change something. A member already
## walking to the squad's goal is left alone, so a squad that stays on
## course gives no orders at all -- which is also what T55's cap on actions
## per minute will count.
##
## When not to use it: a single unit with a job of its own -- a worker, a
## scout. A squad of one is a unit with extra steps.
class_name Squad
extends RefCounted

const GATHER: String = "gather"
const ADVANCE: String = "advance"
const FIGHT: String = "fight"
const RETREAT: String = "retreat"

## How much better another target must score before a squad turns to it.
const STICK: float = 1.25
## Fighters a squad waits for before it sets out.
const SIZE: int = 6
## How near an enemy is, from the squad's middle, to be "near".
const NEAR: float = 7.0
## Below this share of the strength in sight, a squad falls back.
const RETREAT_RATIO: float = 0.6
## How close to its rally point counts as home for a falling-back squad.
const HOME_REACH: float = 6.0

var id: int
var members: Array[int] = []
var machine := StateMachine.new(GATHER)
## The region it is going to, by `RtsScenario.REGIONS` name.
var target: String = ""
## The squad's middle and its strength, as of the last update.
var centre: Vector2 = Vector2.ZERO
var strength: float = 0.0
## Own strength over all strength near it: 1 alone, 0.5 an even fight.
var ratio: float = 1.0
## The enemy the squad is striking now, and every enemy's score when it
## chose: {id, kind, score, why}, best first. What the screen marks.
var focus: Dictionary = {}
var focus_scores: Array[Dictionary] = []
## Every region's score when the squad last chose, by name: what the screen
## writes. Kept, never recomputed for the screen -- the scores carry noise
## from the side's dice, and a screen that drew again would change the game.
var scores: Dictionary = {}

var _home: Vector2i


func _init(squad_id: int, side: int) -> void:
	id = squad_id
	_home = RtsScenario.home(side)
	machine.add_arrow(GATHER, FIGHT, func(facts: Dictionary) -> bool: return facts["enemies_near"],
		"enemies at home: defending")
	machine.add_arrow(GATHER, ADVANCE, func(facts: Dictionary) -> bool: return facts["size"] >= SIZE,
		"%d strong: setting out" % SIZE)
	machine.add_arrow(ADVANCE, RETREAT, func(facts: Dictionary) -> bool: return facts["ratio"] < RETREAT_RATIO,
		"outmatched on the way: falling back")
	machine.add_arrow(ADVANCE, FIGHT, func(facts: Dictionary) -> bool: return facts["enemies_near"],
		"enemies in sight: engaging")
	machine.add_arrow(FIGHT, RETREAT, func(facts: Dictionary) -> bool: return facts["ratio"] < RETREAT_RATIO,
		"outmatched: falling back")
	machine.add_arrow(FIGHT, ADVANCE, func(facts: Dictionary) -> bool: return not facts["enemies_near"] and facts["size"] >= SIZE / 2,
		"nothing left in sight: on to the target")
	machine.add_arrow(FIGHT, GATHER, func(facts: Dictionary) -> bool: return not facts["enemies_near"],
		"nothing left in sight, too few to go on: regrouping")
	machine.add_arrow(RETREAT, GATHER, func(facts: Dictionary) -> bool: return facts["at_home"],
		"home: regrouping")


## Drop the members `view` no longer shows, take a fresh look round and
## let the state machine move. Returns the arrow taken, "" for none.
func update(view: RtsSnapshot) -> String:
	var alive: Dictionary = {}
	for unit: Dictionary in view.mine():
		alive[unit["id"]] = unit
	# `filter` hands back an untyped Array; `assign` keeps `members` typed.
	members.assign(members.filter(func(member: int) -> bool: return alive.has(member)))
	strength = 0.0
	centre = Vector2.ZERO
	for member: int in members:
		centre += alive[member]["position"]
		strength += RtsInfluence.strength(alive[member]["kind"], alive[member]["health"])
	if not members.is_empty():
		centre /= members.size()
	var enemy_near: float = 0.0
	var enemies_near: bool = false
	for enemy: Dictionary in view.enemies():
		if (enemy["position"] as Vector2).distance_to(centre) <= NEAR:
			enemies_near = true
			enemy_near += RtsInfluence.strength(enemy["kind"], enemy["health"])
	ratio = strength / (strength + enemy_near) if strength + enemy_near > 0.0 else 1.0
	machine.update({"size": members.size(), "ratio": ratio, "enemies_near": enemies_near,
		"at_home": centre.distance_to(Vector2(rally_point())) <= HOME_REACH})
	return machine.last_change


## The orders this squad's state calls for: none for a member already doing
## the right thing.
func commands(view: RtsSnapshot) -> Array[RtsCommand]:
	if machine.current == FIGHT:
		return _engage(view)
	if machine.current != ADVANCE:
		return _walk_to(view, rally_point())
	if target == "":
		return []
	return _walk_to(view, RtsScenario.REGIONS[target]["cell"])


## Where a gathering or retreating squad waits: a few cells out from its
## home towards the middle of the map, clear of the workers.
func rally_point() -> Vector2i:
	var inward: Vector2i = Vector2i(5, -5) if _home.x < 24 else Vector2i(-5, 5)
	return _home + inward


func _walk_to(view: RtsSnapshot, wanted: Vector2i) -> Array[RtsCommand]:
	var cell: Vector2i = open_cell_near(view, wanted)
	var lagging: Array[int] = []
	for member: int in members:
		var unit: Dictionary = _own(view, member)
		var arrived: bool = (unit["position"] as Vector2).distance_to(Vector2(cell)) < 3.0
		var on_the_way: bool = unit["order"] == RtsCommand.MOVE and unit["goal"] == cell
		if not arrived and not on_the_way and unit["order"] != RtsCommand.ATTACK:
			lagging.append(member)
	if lagging.is_empty() or view.graph.is_blocked(cell):
		return []
	return [RtsCommand.move(lagging, cell)]


## The open cell nearest `wanted`, a ring at a time: a region's cell is
## often a base, which nobody can stand on. `wanted` itself when open, and
## when nothing within four rings is.
static func open_cell_near(view: RtsSnapshot, wanted: Vector2i) -> Vector2i:
	for cell: Vector2i in _nearest_first(wanted, 4):
		if view.graph.contains(cell) and not view.graph.is_blocked(cell):
			return cell
	return wanted


# Every cell within `rings` steps of `centre`, the nearer rings first.
static func _nearest_first(centre: Vector2i, rings: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var across: int = 2 * rings + 1
	for index: int in range(across * across):
		cells.append(centre + Vector2i(index % across - rings, index / across - rings))
	cells.sort_custom(func(one: Vector2i, other: Vector2i) -> bool:
		return maxi(absi(one.x - centre.x), absi(one.y - centre.y)) < maxi(absi(other.x - centre.x), absi(other.y - centre.y)))
	return cells


# The enemy `FocusFire` scores best, struck by every member at once. The
# one already focused is kept unless another beats it by `STICK`, so a
# squad does not swap targets every time a blow changes the numbers; a
# member already on the focus is left alone, so a steady fight gives no
# orders at all.
func _engage(view: RtsSnapshot) -> Array[RtsCommand]:
	var mine: Array[Dictionary] = []
	for member: int in members:
		mine.append(_own(view, member))
	focus_scores = FocusFire.scores(view, mine, centre, NEAR)
	if focus_scores.is_empty():
		focus = {}
		return []
	var best: Dictionary = focus_scores[0]
	for scored: Dictionary in focus_scores:
		if not focus.is_empty() and scored["id"] == focus["id"] and scored["score"] * STICK >= best["score"]:
			best = scored
	focus = best
	var turning: Array[int] = []
	for unit: Dictionary in mine:
		if unit["order"] != RtsCommand.ATTACK or unit["target"] != focus["id"]:
			turning.append(unit["id"])
	if turning.is_empty():
		return []
	return [RtsCommand.attack(turning, focus["id"])]


static func _own(view: RtsSnapshot, member: int) -> Dictionary:
	for unit: Dictionary in view.units:
		if unit["id"] == member:
			return unit
	return {}
