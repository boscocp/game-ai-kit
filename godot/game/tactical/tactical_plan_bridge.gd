## Between the board and the planner: the board as predicates going out, and
## a planned step coming back as what it asks of a piece.
##
## One file and one direction each way, which is T11's rule. The planner never
## sees a cell, and the board never sees a predicate: everything that turns
## one into the other is here, so a reader who wants to know what
## `ram_across` *means* on the map reads one function.
##
## The domain itself is data: `tactics_domain.json`, a byte-for-byte copy of
## `spec/pddl/tactics.json`, which `make test-python` holds equal to
## `spec/pddl/tactics-domain.pddl`. Every name below is one that file uses.
##
## Every fact is about the side to move, as "our" and "their", so one domain
## plans for red or for blue.
##
## When not to use it: a second scenario. The zones -- home bank, their bank,
## their workshop -- are this map's river, and another map needs its own.
class_name TacticalPlanBridge
extends RefCounted

const DOMAIN_PATH: String = "res://game/tactical/tactics_domain.json"

## How near a walker of theirs must stand to their workshop to guard it: one
## blow's walk away for anything, two cells, as a fight's `nearby_radius`
## counts numbers.
const GUARD_RADIUS: int = 2

## What a step asks for, by its name's first word -- the vocabulary the domain
## file is written in.
const BANK: String = "bank"
const BUY: String = "buy"
const BUILD: String = "build"
const CROSS: String = "cross"
const CLOSE_IN: String = "close_in"
const SIEGE: String = "siege"

static var _actions: Array[StripsAction] = []
static var _goal: PackedStringArray = PackedStringArray()


## The domain's actions, read once from the JSON.
static func actions() -> Array[StripsAction]:
	if _actions.is_empty():
		_read_domain()
	return _actions


## What the planner is asked to bring about: their workshop falls.
static func goal() -> PackedStringArray:
	if _goal.is_empty():
		_read_domain()
	return _goal


## Predicates out: the board as the side to move sees it.
static func world_of(state: BoardState) -> WorldState:
	var side: int = state.current_faction
	var theirs: Unit = their_workshop(state)
	var facts := PackedStringArray()
	if state.funds_of(side) >= dearest_purchase():
		facts.append("funds_banked")
	if state.owns(side, TacticalRules.FORGE):
		facts.append("forge_owned")
	if _crossing_open(state):
		facts.append("crossing_open")
	if theirs != null and not _guarded(state, theirs):
		facts.append("their_workshop_unguarded")
	for unit: Unit in state.units_of(side):
		if unit.type.mobile and theirs != null:
			facts.append("%s_%s" % [unit.type.type_name, zone_of(unit, theirs)])
	return WorldState.new(facts)


## Where a walker of ours stands, as the domain names it: "home" on our bank,
## "at_their_workshop" within its reach of their workshop, "across" anywhere
## else on their bank.
static func zone_of(unit: Unit, theirs: Unit) -> String:
	if TacticalCombat.distance(unit.cell, theirs.cell) <= unit.type.attack_range:
		return "at_their_workshop"
	if TacticalScenario.across_the_river(unit.cell, theirs.cell):
		return "home"
	return "across"


## Actions in: what step `step_name` asks for, as `[kind, unit type]` -- the
## kind one of the constants above, the type "" when the step names none
## ("bank_income", "buy_the_forge"). `["", ""]` for a name this file does not
## know, which the planned blue reports rather than guesses at.
static func asks(step_name: String) -> Array[String]:
	for prefix: String in ["build_", "cross_the_river_", "close_in_", "siege_with_"]:
		if step_name.begins_with(prefix):
			var kind: String = {"build_": BUILD, "cross_the_river_": CROSS, "close_in_": CLOSE_IN, "siege_with_": SIEGE}[prefix]
			return [kind, step_name.trim_prefix(prefix)]
	match step_name:
		"bank_income":
			return [BANK, ""]
		"buy_the_forge":
			return [BUY, ""]
		"wade_across":
			return [CROSS, TacticalRules.WADER]
	return ["", ""]


## The zone a walker must be in for a step of `kind` to be its step: crossing
## starts at home, closing in starts across, a siege is made from in reach.
static func zone_for(kind: String) -> String:
	return {CROSS: "home", CLOSE_IN: "across", SIEGE: "at_their_workshop"}.get(kind, "")


## The workshop of the side not moving, or null once it has fallen.
static func their_workshop(state: BoardState) -> Unit:
	for unit: Unit in state.units:
		if unit.faction != state.current_faction and unit.type.type_name == TacticalRules.WORKSHOP:
			return unit
	return null


## What "funds_banked" means: enough for anything the side might buy, which is
## the forge. One threshold, not one fact per price, because STRIPS has no
## arithmetic (see `WorldState`).
static func dearest_purchase() -> int:
	var dearest: int = TacticalRules.FORGE_COST
	var types: Dictionary = TacticalRules.unit_types()
	for type_name: String in TacticalRules.BUILDABLE:
		dearest = maxi(dearest, (types[type_name] as UnitType).cost)
	return dearest


## The river's dry crossings, each as its cells: the bridge, and since T48
## a ford at each end -- one crossing per row the river is crossed on.
static func crossings() -> Array[Array]:
	var by_row: Dictionary = {}
	for cell: Vector2i in TacticalRules.cells_of(TacticalScenario.MAP, TacticalRules.BRIDGE) \
			+ TacticalRules.cells_of(TacticalScenario.MAP, TacticalRules.FORD):
		by_row[cell.y] = by_row.get(cell.y, []) + [cell]
	var found: Array[Array] = []
	for row: int in by_row:
		found.append(by_row[row])
	return found


# True when at least one dry crossing has no piece of theirs on any cell.
static func _crossing_open(state: BoardState) -> bool:
	for crossing: Array in crossings():
		if crossing.all(func(cell: Vector2i) -> bool: return not _theirs_on(state, cell)):
			return true
	return false


static func _theirs_on(state: BoardState, cell: Vector2i) -> bool:
	var standing: Unit = state.unit_at(cell)
	return standing != null and standing.faction != state.current_faction


static func _guarded(state: BoardState, theirs: Unit) -> bool:
	for unit: Unit in state.units_of(theirs.faction):
		var near: bool = TacticalCombat.distance(unit.cell, theirs.cell) <= GUARD_RADIUS
		if unit.type.mobile and near:
			return true
	return false


static func _read_domain() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DOMAIN_PATH))
	_actions = []
	for entry: Dictionary in data["actions"]:
		_actions.append(StripsAction.new(entry["name"], PackedStringArray(entry["preconditions"]),
			PackedStringArray(entry["deletes"]), PackedStringArray(entry["adds"])))
	_goal = PackedStringArray(data["goal"])
