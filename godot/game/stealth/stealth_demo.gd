## The stealth scenario: get across the hall to the exit without being caught.
##
## Arrows walk one cell, shift and an arrow sprint two (and carry much
## further), space waits silently, D shows the danger map, R starts again.
## Every guard's state, suspicion and the strength of each of its controller's
## terms are written out below the room after every turn.
class_name StealthDemo
extends Node2D

const DIRECTIONS: Dictionary = {
	KEY_UP: Vector2i.UP, KEY_DOWN: Vector2i.DOWN,
	KEY_LEFT: Vector2i.LEFT, KEY_RIGHT: Vector2i.RIGHT,
}

@onready var _board: BoardView = $BoardView
@onready var _view: StealthView = $StealthView
@onready var _status: Label = $Interface/Status
## The controller, as the keys (wave 84): the D-pad walks a cell, with LB
## held two; A waits, Y the danger map, X starts again.
const PAD_BUTTONS: Dictionary = {JOY_BUTTON_DPAD_UP: KEY_UP, JOY_BUTTON_DPAD_DOWN: KEY_DOWN,
		JOY_BUTTON_DPAD_LEFT: KEY_LEFT, JOY_BUTTON_DPAD_RIGHT: KEY_RIGHT,
		JOY_BUTTON_LEFT_SHOULDER: KEY_SHIFT, JOY_BUTTON_A: KEY_SPACE, JOY_BUTTON_Y: KEY_D,
		JOY_BUTTON_X: KEY_R}

## The fuzzy controller's alarm terms, as the status line names them.
const TERM_WORDS: Dictionary = {  # shown through tr()
	"calm": "calm {strength}", "wary": "wary {strength}", "alarmed": "alarmed {strength}"}

@onready var _legend: Legend = $Interface/Legend

var world: StealthWorld
var _show_danger: bool = false
var _pad := PadAsKeys.new()


func _ready() -> void:
	_pad.use(PAD_BUTTONS)
	add_child(_pad)
	_show_legend()
	restart()
	Language.apply_if_opened_alone(self)


# The words are rebuilt in the language just chosen: a Label set from code
# keeps the text it was given. The notification also comes on entering the
# tree, before _ready.
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_show_legend()
		_refresh()


# The legend, then the pad's buttons under it when a pad is connected.
func _show_legend() -> void:
	_legend.set_entries([
		[StealthView.STATE_COLOURS[StealthGuard.PATROL], tr("guard on its round")],
		[StealthView.STATE_COLOURS[StealthGuard.INVESTIGATE], tr("guard going to look")],
		[StealthView.STATE_COLOURS[StealthGuard.ALERT], tr("guard giving chase")],
		[Color.TRANSPARENT, "  " + tr("bar: suspicion, white tick: target")],
		[Color.TRANSPARENT, "  " + tr("dots: next steps, ring: where it")],
		[Color.TRANSPARENT, "  " + tr("thinks you are, line: its facing")],
		[StealthView.SIGHT, tr("what a guard sees")],
		[StealthView.DANGER, tr("danger map (D)")],
		[StealthView.EXIT, tr("the way out")],
		[StealthView.PLAYER, tr("you")],
		[BoardView.tile_texture(BoardView.PLAIN), tr("floor, lit")],
		[StealthView.DARKNESS, tr("shade: dark, harder to see you")],
		[BoardView.tile_texture(BoardView.TREES), tr("trees: slow, block sight")],
		[BoardView.tile_texture(BoardView.WALL), tr("wall")],
	] as Array[Array])
	_pad.add_to(_legend)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.is_pressed():
		return
	if DIRECTIONS.has(key.keycode):
		press(DIRECTIONS[key.keycode], key.shift_pressed)
	elif key.keycode == KEY_SPACE:
		press(Vector2i.ZERO)
	elif key.keycode == KEY_D:
		toggle_danger()
	elif key.keycode == KEY_R:
		restart()


## A fresh room, every guard calm and at the start of its round.
func restart() -> void:
	world = StealthWorld.new(StealthRoom.default_room())
	_board.draw_board(world.room.graph, [] as Array[Vector2i], [] as Array[Vector2i], _trees())
	_refresh()


## One turn: the player's move, then every guard's answer.
func press(direction: Vector2i, sprint: bool = false) -> void:
	world.play(direction, sprint)
	_refresh()


## One decision: the player waits, and every guard takes its turn.
func step_decision() -> void:
	press(Vector2i.ZERO)


## What every guard is reasoning with: its state, its suspicion, where the
## rules pull it, what it was given, what it sees, where it thinks you are
## and where it is about to walk.
func decision_overlay() -> Dictionary:
	var guards: Array[Dictionary] = []
	for guard: StealthGuard in world.guards:
		guards.append({  # not shown: the overlay's data, for the tests
			"state": guard.state,
			"suspicion": guard.suspicion.level,
			"alarm": guard.suspicion.alarm,
			"inputs": guard.suspicion.inputs,
			"rules": guard.suspicion.activations,
			"sees": world.cone.visible_cells(world.room.graph, guard.unit.cell, guard.facing),
			"thinks_you_are": guard.last_known if guard.last_known != StealthGuard.NOWHERE else "nowhere yet",
			"next_steps": guard.upcoming(4) if not guard.route.is_empty() else "looking round",
		})
	return {"guards": guards}


## Show or hide the danger map.
func toggle_danger() -> void:
	_show_danger = not _show_danger
	_refresh()


## Everything the status line says, so a test can read what a person would.
func status_text() -> String:
	var lines: Array[String] = [_headline()]
	for guard: StealthGuard in world.guards:
		lines.append(tr("guard {id}  {reason}  ·  {inputs}  ·  {terms}").format({id = guard.unit.id,
			reason = guard.reason, inputs = _inputs(guard.suspicion), terms = _terms(guard.suspicion)}))
	return "\n".join(lines)


func _refresh() -> void:
	_view.show_world(world, _board, _show_danger)
	_status.text = status_text()


func _headline() -> String:
	var line: String = tr("turn {turn}  ·  arrows walk  ·  shift sprints  ·  space waits  ·  D danger  ·  R restarts")
	if world.outcome == StealthWorld.ESCAPED:
		line = tr("turn {turn}  ·  ESCAPED  ·  arrows walk  ·  shift sprints  ·  space waits  ·  D danger  ·  R restarts")
	elif world.outcome == StealthWorld.CAUGHT:
		line = tr("turn {turn}  ·  CAUGHT  ·  arrows walk  ·  shift sprints  ·  space waits  ·  D danger  ·  R restarts")
	return line.format({turn = world.turn})


# What the controller was given: the half of the decision a person needs to
# see to tell why one guard sits at 12 while another jumps to 48.
func _inputs(suspicion: Suspicion) -> String:
	var given: Dictionary = suspicion.inputs
	if given.is_empty():
		return tr("nothing perceived yet")
	return tr("distance {distance}  light {light}  noise {noise}  silence {silence}").format({
		distance = "%.1f" % given["distance"], light = "%.2f" % given["light"],
		noise = "%.2f" % given["noise"], silence = int(given["silence"])})


func _terms(suspicion: Suspicion) -> String:
	var strengths: Dictionary = suspicion.activations.get("alarm", {})
	var parts: Array[String] = []
	for term: String in strengths:
		parts.append(tr(TERM_WORDS[term]).format({strength = "%.2f" % strengths[term]}))
	if parts.is_empty():
		return tr("rules: none yet")
	return tr("rules: {terms}").format({terms = "  ".join(parts)})


# The room's dear ground is trees, which the board would otherwise draw from
# their cost alone as rough ground.
func _trees() -> Dictionary:
	var tiles: Dictionary = {}
	var graph: GakGridGraph = world.room.graph
	for index: int in range(graph.width * graph.height):
		var cell := Vector2i(index % graph.width, index / graph.width)
		if graph.cost_at(cell) == StealthRoom.TREE:
			tiles[cell] = BoardView.TREES
	return tiles
