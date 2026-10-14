## The tactical scenario, played by two people taking turns at one mouse.
##
## There is no AI in it yet, on purpose. T10 builds the game a planner can
## plan over -- five types, two towers, a workshop, funds and one upgrade --
## and T11 hands one side to the planner. Until then this scene is where a
## person checks that the five types feel different and that the river
## changes where they want to stand, which is T10's manual check.
##
## Click one of your pieces, then any highlighted cell: the highlight is
## everywhere it can walk this turn, so a runner lights up half the board and
## a ram two cells. With your workshop in hand, 1-5 build; U buys the forge;
## space ends the turn.
##
## Not yet an example in invariant 13's sense: an example shows an AI
## deciding, and nothing here decides. That is why its make target is
## `play-tactical` and not `demo-tactical`; T11 renames it when there is a
## decision to watch.
class_name TacticalGame
extends Node2D

## Two letters per type, drawn on its piece and repeated in the legend.
const LABELS: Dictionary = {
	TacticalRules.RUNNER: "Ru", TacticalRules.SHIELD: "Sh", TacticalRules.MORTAR: "Mo",
	TacticalRules.WADER: "Wa", TacticalRules.RAM: "Ra", TacticalRules.BOLT_TOWER: "Bt",
	TacticalRules.WATCHTOWER: "Wt", TacticalRules.WORKSHOP: "Ws",
}

@onready var _board: BoardView = $BoardView
@onready var _units: UnitView = $UnitView
@onready var _status: Label = $Interface/Status
@onready var _legend: Legend = $Interface/Legend

var state: BoardState
var _types: Dictionary = TacticalRules.unit_types()
var _selected_id: int = -1
var _last_refusal: String = ""
# What the last action did, in words, so a build is confirmed and not only
# visible as a smaller number.
var _last_event: String = ""
# Units built this turn: they have no movement, and the status says why.
var _built_this_turn: Array[int] = []


func _ready() -> void:
	state = TacticalScenario.build()
	_units.labels = LABELS
	_legend.set_entries(TacticalLegend.entries(_types))
	BoardLayout.lay_out(self, state.graph, _status, _legend)
	_select_first_piece()
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		_press(key.keycode)
		return
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		click_cell(_board.cell_at(_board.to_local(click.global_position)))


## A click picks up one of your pieces, or walks the one in hand to a cell.
func click_cell(cell: Vector2i) -> void:
	var occupant: Unit = state.unit_at(cell)
	_last_event = ""
	if occupant != null and occupant.faction == state.current_faction:
		_selected_id = occupant.id
		_last_refusal = ""
	elif occupant != null:
		_last_refusal = "%s is %s's %s -- you can pick up only your own pieces" % [
			cell, TacticalStatus.side_name(occupant.faction), occupant.type.type_name]
	else:
		_walk_to(cell)
	_refresh()


## Build the `index`th buildable type at the workshop in hand, on the first
## free cell beside it that the new unit could stand on.
func build(index: int) -> void:
	var kind: UnitType = _types[TacticalRules.BUILDABLE[index]]
	var order := ProductionOrder.new(_selected_id, kind, _free_cell_for(kind))
	_try(state.produce(order), state.why_production_refused(order))
	if _last_refusal == "":
		_built_this_turn.append(state.unit_at(order.cell).id)
		_last_event = "built a %s at %s; it moves next turn" % [kind.type_name, order.cell]
	_refresh()


## Buy the forge for the side to move.
func buy_forge() -> void:
	_try(state.buy(TacticalRules.forge()), state.why_upgrade_refused(TacticalRules.forge()))
	_last_event = "bought the forge: rams can be built" if _last_refusal == "" else ""
	_refresh()


## Hand the board to the other side, which is paid its income as it starts.
func end_turn() -> void:
	state = state.end_turn(TacticalScenario.FACTIONS, 0, TacticalRules.INCOME)
	_last_refusal = ""
	_last_event = ""
	_built_this_turn.clear()
	_select_first_piece()
	_refresh()


func _press(keycode: Key) -> void:
	if keycode >= KEY_1 and keycode <= KEY_5:
		build(keycode - KEY_1)
	elif keycode == KEY_U:
		buy_forge()
	elif keycode == KEY_SPACE:
		end_turn()


# Keep the new state, or keep the reason it was refused -- never neither.
func _try(next: BoardState, refusal: String) -> void:
	if next == null:
		_last_refusal = refusal
		return
	state = next
	_last_refusal = ""


# Walk the piece in hand along the cheapest route the highlight offered, or,
# for a cell it did not offer, try one step so the board says why not.
func _walk_to(cell: Vector2i) -> void:
	var unit: Unit = state.unit_by_id(_selected_id)
	var walks: Dictionary = TacticalReach.walks_for(state, unit) if unit != null else {}
	var path: Array[Vector2i] = [cell]
	if walks.has(cell):
		path = walks[cell]
	var move := Move.new(_selected_id, path)
	_try(state.apply(move), _explained(state.why_refused(move), cell))


# The board says a cell is blocked; the game knows what it is blocked *by*.
func _explained(refusal: String, cell: Vector2i) -> String:
	if not refusal.ends_with("is blocked") or not state.graph.contains(cell):
		return refusal
	match TacticalScenario.MAP[cell.y][cell.x]:
		TacticalRules.WATER:
			return refusal + ": water, which only waders cross"
		TacticalRules.ROCK:
			return refusal + ": rock, which nothing crosses"
	return refusal


# The first cell next to the piece in hand with room for `kind` -- room, not
# legality: asking the whole order about every cell hears "you cannot afford
# it" each time and concludes there is no room, which is what the first
# version told a player who was simply out of funds. When there is no room,
# the producer's own cell, so the order is refused for that.
func _free_cell_for(kind: UnitType) -> Vector2i:
	var producer: Unit = state.unit_by_id(_selected_id)
	if producer == null:
		return Vector2i(-1, -1)
	for step: Vector2i in GridGraph.DIRECTIONS:
		if state.why_no_room(producer, kind, producer.cell + step) == BoardState.LEGAL:
			return producer.cell + step
	return producer.cell


# The side to move starts with its first piece that can walk, so the first
# click of a turn does something.
func _select_first_piece() -> void:
	_selected_id = -1
	for unit: Unit in state.units_of(state.current_faction):
		if unit.type.mobile:
			_selected_id = unit.id
			return


func _refresh() -> void:
	_board.draw_board(state.graph, _steps_in_reach(), [] as Array[Vector2i], _water())
	_units.show_state(state, _board, _selected_id)
	var unit: Unit = state.unit_by_id(_selected_id)
	var news: String = _last_event
	if unit != null and unit.id in _built_this_turn:
		news = "this %s was built this turn and moves next turn" % unit.type.type_name
	_status.text = TacticalStatus.text(state, unit, _last_refusal, news)


# Every cell the piece in hand can walk to this turn.
func _steps_in_reach() -> Array[Vector2i]:
	var unit: Unit = state.unit_by_id(_selected_id)
	var found: Array[Vector2i] = []
	if unit != null:
		found.assign(TacticalReach.walks_for(state, unit).keys())
	return found


# Water and the bridge, which the board's costs alone would draw as a wall and
# as open ground.
func _water() -> Dictionary:
	var tiles: Dictionary = {}
	for cell: Vector2i in TacticalRules.cells_of(TacticalScenario.MAP, TacticalRules.WATER):
		tiles[cell] = BoardView.WATER
	for cell: Vector2i in TacticalRules.cells_of(TacticalScenario.MAP, TacticalRules.BRIDGE):
		tiles[cell] = BoardView.BRIDGE
	return tiles
