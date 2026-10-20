## The RTS board on screen: the ground, the fog, and every unit a side can
## see.
##
## The screen shows what the person's side sees and nothing more: units
## come from that side's `RtsSnapshot`, the same view the computer is given,
## so the fog on the screen and the fog the AI plays under are one fog. A
## cell seen once and not now is drawn dim, the way StarCraft's explored
## ground is; a cell never seen is dark. Watching two computers play, there
## is no person's side, and everything is drawn.
##
## Each unit is a Bos Wars sprite when `RtsArt` found the downloaded sheets,
## and a plain shape when it did not -- a fresh checkout and CI have none --
## so the game never depends on the art.
##
## When not to use it: a board larger than the window. This one draws all
## of it at `CELL` pixels a cell and never scrolls.
class_name RtsView
extends Node2D

const CELL: float = 20.0
const ORIGIN := Vector2(16.0, 56.0)
const SIDE_COLOURS: Array[Color] = [Color(0.25, 0.55, 1.0), Color(0.95, 0.3, 0.25)]
const GROUND: Dictionary = {
	".": Color(0.36, 0.42, 0.27), "T": Color(0.18, 0.32, 0.16), "#": Color(0.35, 0.33, 0.31),
	"~": Color(0.16, 0.3, 0.52), "=": Color(0.5, 0.38, 0.22), "f": Color(0.3, 0.45, 0.55),
	"o": Color(0.36, 0.42, 0.27), "v": Color(0.36, 0.42, 0.27), "A": Color(0.36, 0.42, 0.27),
	"B": Color(0.36, 0.42, 0.27),
}
const DEPOSIT_COLOURS: Dictionary = {RtsKinds.ROCKS: Color(0.75, 0.72, 0.68), RtsKinds.VENT: Color(1.0, 0.55, 0.1)}
const FOG := Color(0.0, 0.0, 0.0, 0.72)
const EXPLORED := Color(0.0, 0.0, 0.0, 0.38)
const SELECTED := Color(1.0, 1.0, 0.6)

## What to draw: the snapshot of the side the screen belongs to; when
## `everything` is set, the whole world instead.
var view: RtsSnapshot
var world: RtsWorld
var everything: bool = false
## Ids the person has selected.
var selected: Dictionary = {}
## The box being dragged, in screen pixels; empty when none.
var dragging: Rect2 = Rect2()
## A building being placed: its kind, or "" for none, and the cell under the mouse.
var placing: String = ""
var placing_at: Vector2i = Vector2i(-1, -1)
var art: RtsArt

## The match's tick, which paces the walking frames.
var tick: int = 0

# Cells this side has ever seen.
var _explored := PackedByteArray()
# Each unit's position when last drawn, and the way it last moved: which
# way a sprite faces, and whether it walks.
var _last_position: Dictionary = {}
var _facing: Dictionary = {}


func _ready() -> void:
	_explored.resize(RtsScenario.MAP[0].length() * RtsScenario.MAP.size())


## The screen point at the middle of `position`, a point in cells.
static func to_screen(position: Vector2) -> Vector2:
	return ORIGIN + position * CELL


## The cell under a screen point.
static func to_cell(point: Vector2) -> Vector2i:
	var inside: Vector2 = (point - ORIGIN) / CELL
	return Vector2i(floori(inside.x), floori(inside.y))


## The units to draw: the whole world's when everything is shown, else the
## snapshot's -- plain dictionaries either way.
func shown_units() -> Array[Dictionary]:
	if not everything:
		return view.units
	var listed: Array[Dictionary] = []
	for unit: RtsUnit in world.units():
		listed.append({"id": unit.id, "side": unit.side, "kind": unit.kind, "position": unit.position,
			"health": unit.health, "complete": unit.complete})
	return listed


func _draw() -> void:
	if view == null:
		return
	_draw_ground()
	for unit: Dictionary in shown_units():
		_draw_unit(unit)
	if not everything:
		_draw_fog()
	if placing != "" and placing_at != Vector2i(-1, -1):
		draw_rect(Rect2(to_screen(Vector2(placing_at)), Vector2(CELL, CELL)), Color(1, 1, 1, 0.35))
	if dragging.size != Vector2.ZERO:
		draw_rect(dragging.abs(), SELECTED, false, 1.0)


func _draw_ground() -> void:
	for row: int in range(RtsScenario.MAP.size()):
		for column: int in range(RtsScenario.MAP[row].length()):
			var letter: String = RtsScenario.MAP[row][column]
			draw_rect(Rect2(to_screen(Vector2(column, row)), Vector2(CELL, CELL)), GROUND[letter])


func _draw_unit(unit: Dictionary) -> void:
	var centre: Vector2 = to_screen(unit["position"])
	var kind: String = unit["kind"]
	if RtsKinds.is_deposit(kind):
		if art == null or not art.draw_unit(self, kind, 0, centre, CELL, Vector2.ZERO, false, tick):
			draw_circle(centre, CELL * 0.42, DEPOSIT_COLOURS[kind])
		return
	var colour: Color = SIDE_COLOURS[unit["side"]]
	if not unit["complete"]:
		colour = colour.darkened(0.5)
	var moved: Vector2 = (unit["position"] as Vector2) - _last_position.get(unit["id"], unit["position"])
	_last_position[unit["id"]] = unit["position"]
	if moved.length() > 0.001:
		_facing[unit["id"]] = moved
	var facing: Vector2 = _facing.get(unit["id"], Vector2.ZERO)
	if art == null or not art.draw_unit(self, kind, unit["side"], centre, CELL, facing, moved.length() > 0.001, tick):
		_draw_shape(kind, centre, colour)
	if selected.has(unit["id"]):
		draw_arc(centre, CELL * 0.62, 0.0, TAU, 20, SELECTED, 1.5)
	var full: float = float(RtsKinds.of(kind, "health"))
	var bar := Rect2(centre + Vector2(-CELL * 0.4, -CELL * 0.62), Vector2(CELL * 0.8, 2.5))
	draw_rect(bar, Color(0.2, 0.0, 0.0))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(unit["health"] / full, 0.0, 1.0), bar.size.y)), Color(0.3, 0.95, 0.3))


## A plain shape per kind, so the board reads with no art at all: a dot for
## a worker, a triangle for a runner, a square for a shield, a diamond for
## a mortar, and a lettered block for a building.
func _draw_shape(kind: String, centre: Vector2, colour: Color) -> void:
	var size: float = CELL * 0.38
	var up := Vector2(0, -size)
	var right := Vector2(size, 0)
	match kind:
		RtsKinds.WORKER:
			draw_circle(centre, size * 0.6, colour)
		RtsKinds.RUNNER:
			draw_colored_polygon(PackedVector2Array([centre + up, centre + right - up, centre - right - up]), colour)
		RtsKinds.SHIELD:
			draw_rect(Rect2(centre - Vector2(size, size), Vector2(size, size) * 2.0), colour)
		RtsKinds.MORTAR:
			draw_colored_polygon(PackedVector2Array([centre + up, centre + right, centre - up, centre - right]), colour)
		_:
			_draw_building(kind, centre, colour)


func _draw_building(kind: String, centre: Vector2, colour: Color) -> void:
	draw_rect(Rect2(centre - Vector2(CELL, CELL) * 0.48, Vector2(CELL, CELL) * 0.96), colour)
	var letter: String = kind.substr(0, 1).to_upper()
	draw_string(ThemeDB.fallback_font, centre + Vector2(-4.0, 5.0), letter, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, Color.BLACK)


# Fog from the side's own sight, unit by unit: a disc of cells round each.
func _draw_fog() -> void:
	var width: int = RtsScenario.MAP[0].length()
	var seen := PackedByteArray()
	seen.resize(_explored.size())
	for unit: Dictionary in view.mine():
		_mark_seen(seen, unit["position"], RtsKinds.of(unit["kind"], "sight"))
	for index: int in range(seen.size()):
		if seen[index] == 1:
			_explored[index] = 1
			continue
		var cell := Vector2(index % width, index / width)
		draw_rect(Rect2(to_screen(cell), Vector2(CELL, CELL)), EXPLORED if _explored[index] == 1 else FOG)


# Every cell whose middle is within `sight` of `middle`, marked in `seen`.
static func _mark_seen(seen: PackedByteArray, middle: Vector2, sight: float) -> void:
	var width: int = RtsScenario.MAP[0].length()
	var reach: int = ceili(sight)
	var across: int = 2 * reach + 1
	for index: int in range(across * across):
		var cell := Vector2i(floori(middle.x), floori(middle.y)) + Vector2i(index % across - reach, index / across - reach)
		var inside: bool = cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < RtsScenario.MAP.size()
		if inside and middle.distance_to(Vector2(cell) + Vector2(0.5, 0.5)) <= sight:
			seen[cell.y * width + cell.x] = 1
