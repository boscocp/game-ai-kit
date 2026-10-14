## The tactical scenario, played by two people taking turns at one mouse.
##
## There is no AI in it yet, on purpose. T10 builds the game a planner can
## plan over -- five types, two towers, a workshop, funds and one upgrade --
## and T11 hands one side to the planner. Until then this scene is where a
## person checks that the five types feel different and that the river
## changes where they want to stand, which is T10's manual check.
##
## Click one of your pieces, then a highlighted cell beside it. With your
## workshop in hand, 1-5 build; U buys the forge; space ends the turn.
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


## A click picks up one of your pieces, or steps the one in hand onto a cell.
func click_cell(cell: Vector2i) -> void:
	var occupant: Unit = state.unit_at(cell)
	if occupant != null and occupant.faction == state.current_faction:
		_selected_id = occupant.id
		_last_refusal = ""
	else:
		var move := Move.new(_selected_id, [cell] as Array[Vector2i])
		_try(state.apply(move), state.why_refused(move))
	_refresh()


## Build the `index`th buildable type at the workshop in hand, on the first
## free cell beside it that the new unit could stand on.
func build(index: int) -> void:
	var kind: UnitType = _types[TacticalRules.BUILDABLE[index]]
	var order := ProductionOrder.new(_selected_id, kind, _free_cell_for(kind))
	_try(state.produce(order), state.why_production_refused(order))
	_refresh()


## Buy the forge for the side to move.
func buy_forge() -> void:
	_try(state.buy(TacticalRules.forge()), state.why_upgrade_refused(TacticalRules.forge()))
	_refresh()


## Hand the board to the other side, which is paid its income as it starts.
func end_turn() -> void:
	state = state.end_turn(TacticalScenario.FACTIONS, 0, TacticalRules.INCOME)
	_last_refusal = ""
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


# The first cell next to the piece in hand where `kind` may appear. When there
# is none, the producer's own cell, so the order is refused with the reason.
func _free_cell_for(kind: UnitType) -> Vector2i:
	var producer: Unit = state.unit_by_id(_selected_id)
	if producer == null:
		return Vector2i(-1, -1)
	for step: Vector2i in GridGraph.DIRECTIONS:
		var order := ProductionOrder.new(producer.id, kind, producer.cell + step)
		if state.why_production_refused(order) == BoardState.LEGAL:
			return order.cell
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
	_status.text = TacticalStatus.text(state, state.unit_by_id(_selected_id), _last_refusal)


# The cells beside the piece in hand it could step onto now -- asked of the
# board, the same question a click asks, so the two cannot disagree.
func _steps_in_reach() -> Array[Vector2i]:
	var unit: Unit = state.unit_by_id(_selected_id)
	var found: Array[Vector2i] = []
	if unit == null:
		return found
	for step: Vector2i in GridGraph.DIRECTIONS:
		if state.why_refused(Move.new(unit.id, [unit.cell + step] as Array[Vector2i])) == BoardState.LEGAL:
			found.append(unit.cell + step)
	return found


# Every water cell, so the board draws it as water and not as a wall.
func _water() -> Dictionary:
	var tiles: Dictionary = {}
	for cell: Vector2i in TacticalRules.cells_of(TacticalScenario.MAP, TacticalRules.WATER):
		tiles[cell] = BoardView.WATER
	return tiles
