## The whole game, as one value: the board, the units, and whose turn it is.
##
## Every turn-based example decides *on* a `BoardState` and returns a `Move`. The
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
## Since T10 a state also holds what a strategy game needs to plan a build
## order over: each faction's funds, the upgrades it owns, and a cost map for
## each kind of mover that does not walk on the board's own. All of it is copied
## or shared by the same rules as the units and the graph.
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

## Every unit on the board. A state never holds a dead one: `_init` drops them,
## which is the only place that rule lives.
var units: Array[Unit]

## Which faction moves now.
var current_faction: int

## Turns taken since the state was built. Not decoration: a scenario that ends
## in a draw ends by this number, and a training run needs it to cut an episode.
var turn_number: int

## A cost map per `UnitType.mover` name, for the types that do not walk on
## `graph`. Shared between states exactly as `graph` is (see `duplicate_state`).
## This is how a boat crosses water a soldier cannot, with the board knowing
## nothing about water: the scenario builds a second map where water is cheap.
var movement_graphs: Dictionary = {}

## What each faction has to spend, by faction number.
var funds: Dictionary = {}

## The upgrades each faction owns, by faction number, as `Array[String]`.
var upgrades: Dictionary = {}

## Numbers a scenario keeps across turns, by name and then by faction -- the
## tactical board's rounds spent holding its points, which decide a game that
## reaches the round limit (T47). The board carries them from state to state
## and never reads them: what they mean is the scenario's.
var tally: Dictionary = {}

## The id the next produced unit gets. A counter carried from state to state,
## not worked out from the units: worked out from the living, a dead unit's id
## came back as soon as the highest one died, and a stored move naming the
## dead unit commanded the new one.
var next_id: int

## Where the next fight's dice start. Kept in the state, and replaced by each
## fight, so playing an attack stays a function of the state: the same state
## and the same attack give the same fight, which is what lets a search or an
## undo replay one rather than roll it again.
var dice_seed: int = 0


func _init(board: GridGraph, board_units: Array[Unit], faction: int = 0,
		turn: int = 0) -> void:
	graph = board
	units = _living_copies(board_units)
	current_faction = faction
	turn_number = turn
	next_id = _largest_id(board_units) + 1


# Every living unit, copied. Both rules this type depends on live here and
# nowhere else, which is why every other method can be read without asking
# what might be in `units`.
#
# Copying is why the header's immutability claim is true. The first version
# assigned the caller's array straight in, so whoever built the state could
# keep a reference to a unit and move it afterwards -- the state said one
# thing and the caller saw another.
#
# Dropping the dead is the other half. Nothing in T2 reduces health, so a dead
# unit can only arrive by being built that way, and letting one in made four
# parts of this file disagree: it blocked a cell, was invisible to `units_of`,
# and was handed fresh movement by `end_turn`.
static func _living_copies(given: Array[Unit]) -> Array[Unit]:
	var kept: Array[Unit] = []
	for unit: Unit in given:
		if unit.is_alive():
			kept.append(unit.duplicate_unit())
	return kept


## The unit with this id, or null.
##
## Ids are the caller's to keep unique, and nothing here enforces it: with two
## units sharing an id this answers with the first, so the second can never be
## named by a move and is effectively frozen. Measured.
##
## The first version of this comment claimed that and stopped there, and it was
## wrong about something worse: the duplicate was not merely frozen, the two
## units **walked through each other and stacked on one cell**, because the
## occupancy rule exempted "the same unit" by comparing ids. That is fixed; the
## freezing is not, because it is a bug in whoever built the scenario rather
## than a state this type can refuse.
func unit_by_id(unit_id: int) -> Unit:
	for unit: Unit in units:
		if unit.id == unit_id:
			return unit
	return null


## The unit standing on this cell, or null.
##
## Two units cannot legally occupy one cell -- `why_refused` sees to that -- but
## a caller can *build* a state in which they do, and then this answers with the
## one earliest in `units`. That is a consequence of the loop rather than a
## design, and it is written down because a reviewer could not tell which it
## was.
func unit_at(cell: Vector2i) -> Unit:
	for unit: Unit in units:
		if unit.cell == cell:
			return unit
	return null


## The cost map this unit walks on: its type's, when the scenario gave that
## mover one, and the board's own otherwise. Untyped units walk on the board.
func graph_for(unit: Unit) -> GridGraph:
	return graph if unit.type == null else graph_for_type(unit.type)


## The cost map a kind of unit walks on -- for a unit that does not exist yet,
## such as one about to be built.
func graph_for_type(kind: UnitType) -> GridGraph:
	return movement_graphs.get(kind.mover, graph)


## What a faction has to spend.
func funds_of(faction: int) -> int:
	return funds.get(faction, 0)


## True when a faction owns the upgrade with this name.
func owns(faction: int, upgrade_name: String) -> bool:
	return upgrade_name in upgrades.get(faction, [])


## Why this move cannot be made, or `LEGAL`.
##
## The reason is a sentence rather than an error code because both callers need
## it in words: the interface shows it to a player, and a failing test that
## prints "unit 2 belongs to faction 1, and faction 0 is to move" is a test you
## can read. (That is the message the code below actually emits. The first
## version of this comment invented a tidier one, which is the kind of comment
## this repository counts as a finding.)
func why_refused(move: Move) -> String:
	var unit: Unit = unit_by_id(move.unit_id)
	if unit == null:
		# A dead unit is not on the board, so this is also the answer for one.
		return "no unit with id %d is on the board" % move.unit_id
	if unit.faction != current_faction:
		return "unit %d belongs to faction %d, and faction %d is to move" % [
			unit.id, unit.faction, current_faction,
		]
	if unit.type != null and not unit.type.mobile and not move.path.is_empty():
		return "unit %d is a %s and cannot move" % [unit.id, unit.type.type_name]
	# The route is judged before the bill. A move that is both impossible and
	# unaffordable reports the impossibility, because "there is a wall there"
	# is the thing the player has to act on and "you cannot afford it" would
	# send them looking for more movement points. The order is a decision, so
	# it is written here and tested.
	var walk: String = _why_walk_refused(unit, move)
	if walk != LEGAL:
		return walk
	var cost: int = move.cost_on(graph_for(unit))
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
	unit.movement_points -= move.cost_on(graph_for(unit))
	return next


## Why this order cannot be filled, or `LEGAL`.
##
## Checked in the order a player would want to hear it: whose building it is,
## whether it makes that at all, whether it is unlocked, whether there is room,
## and only then whether it can be paid for -- "you cannot afford it" is the
## wrong thing to say about a cell that is a wall.
func why_production_refused(order: ProductionOrder) -> String:
	var producer: Unit = unit_by_id(order.producer_id)
	if producer == null or producer.faction != current_faction:
		return "the side to move has no building with id %d" % order.producer_id
	var kind: UnitType = order.unit_type
	if kind == null:
		return "the order names no unit type"
	if producer.type == null or not producer.type.produces.has(kind.type_name):
		return "unit %d does not produce %s" % [producer.id, kind.type_name]
	if kind.requires != "" and not owns(current_faction, kind.requires):
		return "%s needs the %s upgrade first" % [kind.type_name, kind.requires]
	var room: String = why_no_room(producer, kind, order.cell)
	if room != LEGAL:
		return room
	if kind.cost > funds_of(current_faction):
		return "%s costs %d and the side to move has %d" % [
			kind.type_name, kind.cost, funds_of(current_faction)]
	return LEGAL


## This order filled, as a new state, or null when it is refused. The new unit
## has no movement until its side's next turn: built this turn, it waits.
func produce(order: ProductionOrder) -> BoardState:
	if why_production_refused(order) != LEGAL:
		return null
	var next: BoardState = duplicate_state()
	next.funds[current_faction] = funds_of(current_faction) - order.unit_type.cost
	next.units.append(Unit.new(next.next_id, current_faction, order.cell, 10, 0, order.unit_type))
	next.next_id += 1
	return next


## Why the side to move cannot buy this upgrade, or `LEGAL`.
func why_upgrade_refused(upgrade: Upgrade) -> String:
	if owns(current_faction, upgrade.upgrade_name):
		return "the side to move already owns %s" % upgrade.upgrade_name
	if upgrade.cost > funds_of(current_faction):
		return "%s costs %d and the side to move has %d" % [
			upgrade.upgrade_name, upgrade.cost, funds_of(current_faction)]
	return LEGAL


## The upgrade bought, as a new state, or null when it is refused.
func buy(upgrade: Upgrade) -> BoardState:
	if why_upgrade_refused(upgrade) != LEGAL:
		return null
	var next: BoardState = duplicate_state()
	next.funds[current_faction] = funds_of(current_faction) - upgrade.cost
	var owned: Array = next.upgrades.get(current_faction, []).duplicate()
	owned.append(upgrade.upgrade_name)
	next.upgrades[current_faction] = owned
	return next


## A **new** state with the turn passed to the next faction. This one is not
## touched -- the same promise `apply` makes, for the same reason, and it was
## stated only for `apply`.
##
## Movement is restored on the units that are about to move, not on everyone:
## a unit's remaining points are part of what an opponent can see and reason
## about, and wiping them on both sides throws that away. A typed unit gets its
## type's movement; `points_per_turn` is for the untyped.
##
## `income` is paid to the side about to move, at the start of its turn, so a
## build order refused for want of funds can be placed again a turn later.
func end_turn(factions: int = 2, points_per_turn: int = 3, income: int = 0) -> BoardState:
	var next: BoardState = duplicate_state()
	# `% 0` is a modulo-by-zero engine error that returns null from here -- on
	# the one type whose `apply` argues, two functions up, that refusing with
	# an error in the log is worse than refusing with a value. A board has at
	# least one side.
	next.current_faction = (current_faction + 1) % maxi(factions, 1)
	next.turn_number = turn_number + 1
	for unit: Unit in next.units:
		if unit.faction == next.current_faction:
			unit.movement_points = unit.type.movement if unit.type != null else points_per_turn
	next.funds[next.current_faction] = next.funds_of(next.current_faction) + income
	return next


## An independent copy of the units. **The graph is shared, not copied.**
##
## There is no copying loop here, because the constructor already copies the
## units it is given. Writing one in both places is how the two drift.
##
## The graph is deliberately shared: a search builds thousands of states and
## copying the terrain into each one would dominate everything else. The cost of
## that choice is real and is stated rather than hidden -- `graph` is a public
## field, so `state.graph.block(cell)` changes the terrain under **every** state
## that shares it, including the one a search is still exploring. An earlier
## version of this comment said that nothing on this type changes terrain, which
## was not true even of this repository's own tests.
##
## Build the terrain before you build the state. If terrain must change during
## play, copy it first with `graph.duplicate_graph()` and build a state on the
## copy.
##
## The funds, upgrades and tallies are copied, since play changes them; the cost maps
## in `movement_graphs` are shared, like `graph`, and for the same reason.
func duplicate_state() -> BoardState:
	var copy := BoardState.new(graph, units, current_faction, turn_number)
	copy.movement_graphs = movement_graphs
	copy.funds = funds.duplicate()
	copy.upgrades = upgrades.duplicate(true)
	copy.tally = tally.duplicate(true)
	copy.next_id = next_id
	copy.dice_seed = dice_seed
	return copy


## Every unit of a faction. They are all alive; see `units`.
func units_of(faction: int) -> Array[Unit]:
	var found: Array[Unit] = []
	for unit: Unit in units:
		if unit.faction == faction:
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
	# The unit's own cost map: water is blocked on the board and open to a wader.
	if graph_for(unit).is_blocked(step):
		return "%s is blocked" % step
	var occupant: Unit = unit_at(step)
	# The exemption is for the unit *itself* walking back over its own cell,
	# so it compares identity rather than id. Comparing ids meant that a board
	# built with two units sharing one id let them walk through each other and
	# **stack on one cell** -- measured, and the reverse of what the doc on
	# `unit_by_id` used to claim.
	if occupant != null and occupant != unit:
		return "%s is occupied by unit %d" % [step, occupant.id]
	return LEGAL


## Why a new `kind` cannot appear on `cell` beside `producer`, or `LEGAL`:
## one step away, free, and ground its own type could stand on -- a boat is
## built on water, a soldier on land. Public because choosing *where* to build
## is the caller's job, and a caller that picks a cell by asking the whole of
## `why_production_refused` hears "you cannot afford it" about every cell and
## concludes there is no room.
func why_no_room(producer: Unit, kind: UnitType, cell: Vector2i) -> String:
	if not GridGraph.DIRECTIONS.has(cell - producer.cell):
		return "%s is not next to unit %d" % [cell, producer.id]
	var ground: GridGraph = graph_for_type(kind)
	if not ground.contains(cell) or ground.is_blocked(cell):
		return "a %s cannot stand on %s" % [kind.type_name, cell]
	if unit_at(cell) != null:
		return "%s is occupied by unit %d" % [cell, unit_at(cell).id]
	return LEGAL


# The largest id among the units a state is built from, dead ones included:
# they are dropped from `units`, and their ids must still never come back.
static func _largest_id(given: Array[Unit]) -> int:
	var largest: int = 0
	for unit: Unit in given:
		largest = maxi(largest, unit.id)
	return largest
