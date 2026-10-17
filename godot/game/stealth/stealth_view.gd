## Draws what the guards know on top of the room, which is the point of the demo.
##
## Under each guard, the cells it sees. Above it, its suspicion as a bar, with
## a tick where the fuzzy controller is pulling it; its colour is its state.
## Its next steps are dots, and where it thinks you are is a ring. Darkness
## shades the floor, and the danger map, when shown, tints every cell by how
## watched it is.
class_name StealthView
extends Node2D

const TILE: float = float(BoardView.TILE_PIXELS)
const BAR_WIDTH: float = 28.0
const BAR_HEIGHT: float = 4.0

const DARKNESS: Color = Color(0.0, 0.0, 0.05, 0.6)
const SIGHT: Color = Color(1.0, 0.95, 0.5, 0.22)
const DANGER: Color = Color(0.9, 0.1, 0.1, 0.55)
# Cyan, not green: a green square on grass is the start dot T41 found in the
# search demo, and `marker_contrast_test.gd` holds this one to the same bar.
const EXIT: Color = Color(0.2, 0.9, 1.0, 0.85)
const EXIT_EDGE: Color = Color(0.05, 0.05, 0.05)
const PLAYER: Color = Color(0.95, 0.95, 0.95)
const STATE_COLOURS: Dictionary = {
	StealthGuard.PATROL: Color(0.35, 0.55, 0.9),
	StealthGuard.INVESTIGATE: Color(0.95, 0.7, 0.2),
	StealthGuard.ALERT: Color(0.9, 0.2, 0.2),
}

var _world: StealthWorld
var _board: BoardView
var _show_danger: bool = false


## Hand the view everything it draws. Called after every turn.
func show_world(world: StealthWorld, board: BoardView, show_danger: bool) -> void:
	_world = world
	_board = board
	_show_danger = show_danger
	queue_redraw()


func _draw() -> void:
	if _world == null:
		return
	_draw_floor()
	for guard: StealthGuard in _world.guards:
		_draw_sight(guard)
	draw_rect(_cell_rect(_world.room.exit, 4.0), EXIT)
	draw_rect(_cell_rect(_world.room.exit, 4.0), EXIT_EDGE, false, 2.0)
	for guard: StealthGuard in _world.guards:
		_draw_guard(guard)
	draw_circle(_board.centre_of(_world.player.cell), 9.0, PLAYER)


func _draw_floor() -> void:
	var danger: InfluenceMap = _world.danger() if _show_danger else null
	for y: int in range(_world.room.graph.height):
		for x: int in range(_world.room.graph.width):
			_draw_cell(Vector2i(x, y), danger)


# Darker where the lamps do not reach, redder where the guards watch.
func _draw_cell(cell: Vector2i, danger: InfluenceMap) -> void:
	var shade: Color = DARKNESS
	shade.a *= 1.0 - _world.room.light_at(cell)
	draw_rect(_cell_rect(cell, 0.0), shade)
	if danger != null and danger.value_at(cell) > 0.0:
		var heat: Color = DANGER
		heat.a *= danger.value_at(cell)
		draw_rect(_cell_rect(cell, 0.0), heat)


func _draw_sight(guard: StealthGuard) -> void:
	for cell: Vector2i in _world.cone.visible_cells(_world.room.graph, guard.unit.cell, guard.facing):
		draw_rect(_cell_rect(cell, 2.0), SIGHT)


func _draw_guard(guard: StealthGuard) -> void:
	var colour: Color = STATE_COLOURS[guard.state]
	var centre: Vector2 = _board.centre_of(guard.unit.cell)
	for cell: Vector2i in guard.upcoming(4):
		draw_circle(_board.centre_of(cell), 3.0, colour)
	if guard.last_known != StealthGuard.NOWHERE and guard.state != StealthGuard.PATROL:
		draw_arc(_board.centre_of(guard.last_known), 10.0, 0.0, TAU, 24, colour, 2.0)
	draw_circle(centre, 11.0, colour)
	draw_line(centre, centre + Vector2(guard.facing) * 14.0, Color.WHITE, 2.0)
	# The number the status lines call it by.
	draw_string(ThemeDB.fallback_font, centre + Vector2(-4.0, 5.0), str(guard.unit.id),
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, Color.BLACK)
	_draw_bar(centre + Vector2(-BAR_WIDTH / 2.0, -TILE * 0.6), guard.suspicion, colour)


# The level as a filled bar, the controller's answer as a tick: watch the bar
# chase the tick, and you are watching the fuzzy controller decide.
func _draw_bar(corner: Vector2, suspicion: Suspicion, colour: Color) -> void:
	draw_rect(Rect2(corner, Vector2(BAR_WIDTH, BAR_HEIGHT)), Color(0, 0, 0, 0.7))
	draw_rect(Rect2(corner, Vector2(BAR_WIDTH * suspicion.level / 100.0, BAR_HEIGHT)), colour)
	var tick: float = corner.x + BAR_WIDTH * suspicion.alarm / 100.0
	draw_line(Vector2(tick, corner.y - 2.0), Vector2(tick, corner.y + BAR_HEIGHT + 2.0), Color.WHITE, 1.5)


func _cell_rect(cell: Vector2i, inset: float) -> Rect2:
	var centre: Vector2 = _board.centre_of(cell)
	var half: float = TILE / 2.0 - inset
	return Rect2(centre - Vector2(half, half), Vector2(half, half) * 2.0)
