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
@onready var _legend: Legend = $Interface/Legend

var world: StealthWorld
var _show_danger: bool = false


func _ready() -> void:
	_legend.set_entries([
		[StealthView.STATE_COLOURS[StealthGuard.PATROL], "guard on its round"],
		[StealthView.STATE_COLOURS[StealthGuard.INVESTIGATE], "guard going to look"],
		[StealthView.STATE_COLOURS[StealthGuard.ALERT], "guard giving chase"],
		[Color.TRANSPARENT, "  bar: suspicion, white tick: target"],
		[Color.TRANSPARENT, "  dots: next steps, ring: where it"],
		[Color.TRANSPARENT, "  thinks you are, line: its facing"],
		[StealthView.SIGHT, "what a guard sees"],
		[StealthView.DANGER, "danger map (D)"],
		[StealthView.EXIT, "the way out"],
		[StealthView.PLAYER, "you"],
		[BoardView.tile_texture(BoardView.PLAIN), "floor, lit"],
		[StealthView.DARKNESS, "shade: dark, harder to see you"],
		[BoardView.tile_texture(BoardView.TREES), "trees: slow, block sight"],
		[BoardView.tile_texture(BoardView.WALL), "wall"],
	] as Array[Array])
	restart()


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
		guards.append({
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
		lines.append("guard %d  %s  ·  %s  ·  %s" % [
			guard.unit.id, guard.reason, _inputs(guard.suspicion), _terms(guard.suspicion)])
	return "\n".join(lines)


func _refresh() -> void:
	_view.show_world(world, _board, _show_danger)
	_status.text = status_text()


func _headline() -> String:
	var ending: String = {StealthWorld.ESCAPED: "  ·  ESCAPED", StealthWorld.CAUGHT: "  ·  CAUGHT"}.get(world.outcome, "")
	return "turn %d%s  ·  arrows walk  ·  shift sprints  ·  space waits  ·  D danger  ·  R restarts" % [
		world.turn, ending]


# What the controller was given: the half of the decision a person needs to
# see to tell why one guard sits at 12 while another jumps to 48.
func _inputs(suspicion: Suspicion) -> String:
	var given: Dictionary = suspicion.inputs
	if given.is_empty():
		return "nothing perceived yet"
	return "distance %.1f  light %.2f  noise %.2f  silence %d" % [
		given["distance"], given["light"], given["noise"], int(given["silence"])]


func _terms(suspicion: Suspicion) -> String:
	var strengths: Dictionary = suspicion.activations.get("alarm", {})
	var parts: Array[String] = []
	for term: String in strengths:
		parts.append("%s %.2f" % [term, strengths[term]])
	return "rules: " + ("  ".join(parts) if not parts.is_empty() else "none yet")


# The room's dear ground is trees, which the board would otherwise draw from
# their cost alone as rough ground.
func _trees() -> Dictionary:
	var tiles: Dictionary = {}
	var graph: GridGraph = world.room.graph
	for index: int in range(graph.width * graph.height):
		var cell := Vector2i(index % graph.width, index / graph.width)
		if graph.cost_at(cell) == StealthRoom.TREE:
			tiles[cell] = BoardView.TREES
	return tiles
