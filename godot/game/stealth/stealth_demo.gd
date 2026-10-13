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

var world: StealthWorld
var _show_danger: bool = false


func _ready() -> void:
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
	_board.draw_board(world.room.graph, [] as Array[Vector2i])
	_refresh()


## One turn: the player's move, then every guard's answer.
func press(direction: Vector2i, sprint: bool = false) -> void:
	world.play(direction, sprint)
	_refresh()


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
