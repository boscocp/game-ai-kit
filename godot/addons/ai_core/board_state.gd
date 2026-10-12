## The whole game, as one value: the board, the units, and whose turn it is.
##
## Everything in this kit decides *on* a `BoardState` and returns a `Move`. The
## state is what the search searches, what the planner plans over, and what the
## learned policy is shown. One type, so an experiment and the running game
## cannot drift apart.
##
## Applying a move returns a **new** state and leaves this one untouched. That
## costs a copy per move and buys the thing every one of these techniques needs:
## a search may try a thousand moves without the board remembering any of them.
## The copy is shallow in the only place it can afford to be -- the graph is
## shared until something changes it, and nothing here changes it.
##
## When not to use it: a real-time game, or a board large enough that copying
## the unit list per node matters. At that size you want an undo stack, and an
## undo stack is a different lesson.
class_name BoardState
extends RefCounted

## No refusal. Returned by `why_refused` when a move is legal, so a caller can
## read the result as a sentence: `if state.why_refused(move) == BoardState.LEGAL`.
const LEGAL: String = ""

var graph: GridGraph

## Every unit, dead ones already removed.
var units: Array[Unit]

## Which faction moves now.
var current_faction: int

## Turns taken since the state was built. Not decoration: a scenario that ends
## in a draw ends by this number, and a training run needs it to cut an episode.
var turn_number: int


func _init(board: GridGraph, board_units: Array[Unit], faction: int = 0,
		turn: int = 0) -> void:
	graph = board
	units = board_units
	current_faction = faction
	turn_number = turn


## The unit with this id, or null.
func unit_by_id(unit_id: int) -> Unit:
	for unit: Unit in units:
		if unit.id == unit_id:
			return unit
	return null


## The unit standing on this cell, or null.
func unit_at(cell: Vector2i) -> Unit:
	for unit: Unit in units:
		if unit.cell == cell:
			return unit
	return null


## Why this move cannot be made, or `LEGAL`.
##
## The reason is a sentence rather than an error code because both callers need
## it in words: the interface shows it to a player, and a failing test that
## prints "unit 2 is not this faction's to move" is a test you can read.
func why_refused(move: Move) -> String:
	var unit: Unit = unit_by_id(move.unit_id)
	if unit == null:
		return "no unit with id %d is on the board" % move.unit_id
	if not unit.is_alive():
		return "unit %d is dead" % unit.id
	if unit.faction != current_faction:
		return "unit %d belongs to faction %d, and faction %d is to move" % [
			unit.id, unit.faction, current_faction,
		]
	var walk: String = _why_walk_refused(unit, move)
	if walk != LEGAL:
		return walk
	var cost: int = move.cost_on(graph)
	if cost > unit.movement_points:
		return "the move costs %d and unit %d has %d movement left" % [
			cost, unit.id, unit.movement_points,
		]
	return LEGAL


## This move applied, as a new state, or null when it is refused.
##
## Refusing by returning null rather than by pushing an error is deliberate: a
## search tries illegal moves constantly, and a gate that fills the log with
## engine errors during a normal search teaches people to ignore the log.
func apply(move: Move) -> BoardState:
	if why_refused(move) != LEGAL:
		return null

	var next: BoardState = duplicate_state()
	var unit: Unit = next.unit_by_id(move.unit_id)
	unit.cell = move.destination(unit.cell)
	unit.movement_points -= move.cost_on(graph)
	return next


## The same state with the turn passed to the next faction.
##
## Movement is restored on the units that are about to move, not on everyone:
## a unit's remaining points are part of what an opponent can see and reason
## about, and wiping them on both sides throws that away.
func end_turn(factions: int = 2, points_per_turn: int = 3) -> BoardState:
	var next: BoardState = duplicate_state()
	next.current_faction = (current_faction + 1) % factions
	next.turn_number = turn_number + 1
	for unit: Unit in next.units:
		if unit.faction == next.current_faction:
			unit.movement_points = points_per_turn
	return next


## An independent copy: the units are copied, the graph is shared.
##
## Sharing the graph is safe only because nothing on this type changes terrain.
## The day something does, it has to call `graph.duplicate_graph()` first, and
## this comment is the warning that it must.
func duplicate_state() -> BoardState:
	var copies: Array[Unit] = []
	for unit: Unit in units:
		copies.append(unit.duplicate_unit())
	return BoardState.new(graph, copies, current_faction, turn_number)


## Every unit of a faction that is still alive.
func units_of(faction: int) -> Array[Unit]:
	var found: Array[Unit] = []
	for unit: Unit in units:
		if unit.faction == faction and unit.is_alive():
			found.append(unit)
	return found


# Each step of the walk, checked on its own. Split out of `why_refused` because
# the two ask different questions: that one is about whose unit it is and what
# it can afford, this one is about whether the route exists at all.
func _why_walk_refused(unit: Unit, move: Move) -> String:
	var previous: Vector2i = unit.cell
	for step: Vector2i in move.path:
		var refusal: String = _why_step_refused(unit, previous, step)
		if refusal != LEGAL:
			return refusal
		previous = step
	return LEGAL


# One step, from `previous` to `step`.
func _why_step_refused(unit: Unit, previous: Vector2i, step: Vector2i) -> String:
	if not GridGraph.DIRECTIONS.has(step - previous):
		return "%s does not follow %s; a step is one cell, no diagonals" % [step, previous]
	if not graph.contains(step):
		return "%s is off the board" % step
	if graph.is_blocked(step):
		return "%s is blocked" % step
	var occupant: Unit = unit_at(step)
	if occupant != null and occupant.id != unit.id:
		return "%s is occupied by unit %d" % [step, occupant.id]
	return LEGAL
