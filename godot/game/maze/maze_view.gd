## The maze drawn in shapes: walls, pellets, Pac-Man, the ghosts -- and, with
## V on, what each ghost is deciding.
##
## No art: blue walls, a yellow wedge, a ghost's rounded body with eyes that
## look the way it will move next. The ghost's view is the lesson: its target
## tile, a line from the ghost to it, each way it may take drawn to the cell
## beyond with that cell's straight-line distance to the target written on
## it, and the way it chose drawn thick in white before it takes it. A way
## the dice picked is drawn in orange with a die beside the ghost, so an
## imprecise turn never passes for the Dossier's.
##
## Static functions drawing on the example's own canvas, so the cells and
## the words are measured in one place.
class_name MazeView
extends RefCounted

const CELL: float = 44.0
const WALL := Color(0.13, 0.22, 0.75)
const WALL_EDGE := Color(0.35, 0.50, 1.0)
const FLOOR := Color(0.03, 0.03, 0.06)
const PELLET := Color(1.0, 0.85, 0.70)
const PACMAN := Color(1.0, 0.90, 0.10)
const WAY := Color(0.65, 0.65, 0.70)
const CHOSEN := Color(1.0, 1.0, 1.0)
const DICE := Color(1.0, 0.55, 0.10)
const GHOSTS: Dictionary = {"blinky": Color(0.95, 0.15, 0.15), "pinky": Color(1.0, 0.60, 0.85)}
const TEXT_SIZE: int = 15


## The centre of `cell` on the canvas.
static func centre(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * CELL


## Every wall and floor cell, and the pellets left.
static func draw_maze(canvas: CanvasItem, pellets: Array[Vector2i]) -> void:
	var extent: Vector2i = MazeRules.size()
	for index: int in range(extent.x * extent.y):
		var cell := Vector2i(index % extent.x, index / extent.x)
		var square := Rect2(Vector2(cell) * CELL, Vector2(CELL, CELL))
		if MazeRules.is_open(cell):
			canvas.draw_rect(square, FLOOR)
		else:
			canvas.draw_rect(square.grow(-3.0), WALL)
			canvas.draw_rect(square.grow(-3.0), WALL_EDGE, false, 2.0)
	for pellet: Vector2i in pellets:
		canvas.draw_circle(centre(pellet), CELL * 0.2, PELLET)


## Pac-Man: a yellow disc with its mouth open the way he faces.
static func draw_pacman(canvas: CanvasItem, cell: Vector2i, facing: String) -> void:
	var middle: Vector2 = centre(cell)
	var radius: float = CELL * 0.42
	var aim: float = Vector2(MazeRules.step_of(facing)).angle()
	var outline := PackedVector2Array([middle])
	for index: int in range(25):
		var angle: float = aim + deg_to_rad(35.0) + index * deg_to_rad(290.0) / 24.0
		outline.append(middle + Vector2.from_angle(angle) * radius)
	canvas.draw_colored_polygon(outline, PACMAN)


## A ghost: a rounded body in its colour, eyes looking the way it moves next.
static func draw_ghost(canvas: CanvasItem, ghost: MazeGhost) -> void:
	var middle: Vector2 = centre(ghost.cell)
	var colour: Color = GHOSTS.get(ghost.name, Color.WHITE)
	var radius: float = CELL * 0.38
	canvas.draw_circle(middle + Vector2(0.0, -radius * 0.15), radius, colour)
	canvas.draw_rect(Rect2(middle + Vector2(-radius, -radius * 0.15), Vector2(radius * 2.0, radius * 1.1)), colour)
	var look: Vector2 = Vector2(MazeRules.step_of(ghost.next_move)) * radius * 0.15
	for side: float in [-0.4, 0.4]:
		var eye: Vector2 = middle + Vector2(radius * side, -radius * 0.25)
		canvas.draw_circle(eye, radius * 0.24, Color.WHITE)
		canvas.draw_circle(eye + look, radius * 0.11, Color(0.1, 0.2, 0.8))


## What `ghost` is deciding: its target, every way with its distance, the
## way chosen -- and the die, when the dice chose it.
static func draw_view(canvas: CanvasItem, ghost: MazeGhost) -> void:
	var decision: Dictionary = ghost.decision
	var colour: Color = GHOSTS.get(ghost.name, Color.WHITE)
	var goal: Vector2 = centre(decision["target"])
	_dashed(canvas, centre(ghost.cell), goal, colour)
	var mark := Rect2(goal - Vector2(CELL, CELL) * 0.4, Vector2(CELL, CELL) * 0.8)
	canvas.draw_rect(mark, colour, false, 3.0)
	canvas.draw_line(mark.position, mark.end, colour, 2.0)
	canvas.draw_line(Vector2(mark.end.x, mark.position.y), Vector2(mark.position.x, mark.end.y), colour, 2.0)
	for way: Dictionary in decision["ways"]:
		_draw_way(canvas, ghost, way, decision)
	if decision["kind"] == MazeGhost.DICE:
		_draw_die(canvas, centre(ghost.cell) + Vector2(CELL * 0.35, -CELL * 0.75))


# One way: a line to the cell beyond, its distance to the target written on
# that cell; thick and white if chosen, orange if the dice chose it.
static func _draw_way(canvas: CanvasItem, ghost: MazeGhost, way: Dictionary, decision: Dictionary) -> void:
	var beyond: Vector2 = centre(way["beyond"])
	var chosen: bool = way["direction"] == decision["chosen"]
	var colour: Color = WAY
	if chosen:
		colour = DICE if decision["kind"] == MazeGhost.DICE else CHOSEN
	canvas.draw_line(centre(ghost.cell), beyond, colour, 5.0 if chosen else 2.0)
	var words: String = "%.1f" % sqrt(float(way["squared"]))
	var font: Font = ThemeDB.fallback_font
	var width: float = font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE).x
	var corner: Vector2 = beyond + Vector2(-width / 2.0 - 3.0, -10.0)
	canvas.draw_rect(Rect2(corner, Vector2(width + 6.0, 20.0)), Color(0, 0, 0, 0.75))
	canvas.draw_string(font, corner + Vector2(3.0, 15.0), words, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE, colour)


# A die face showing three, for "the dice chose".
static func _draw_die(canvas: CanvasItem, middle: Vector2) -> void:
	var side: float = CELL * 0.45
	canvas.draw_rect(Rect2(middle - Vector2(side, side) / 2.0, Vector2(side, side)), DICE)
	for spot: float in [-0.25, 0.0, 0.25]:
		canvas.draw_circle(middle + Vector2(spot, -spot) * side, side * 0.09, Color.BLACK)


static func _dashed(canvas: CanvasItem, from: Vector2, to: Vector2, colour: Color) -> void:
	canvas.draw_dashed_line(from, to, Color(colour, 0.6), 2.0, 8.0)
