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
## The board is larger than its window: `camera` is the cell at the
## window's top left, moved by the arrow keys, the mouse at an edge, or a
## click on the minimap. Everything here draws in the map window's own
## coordinates; `MAP_RECT` is where that window sits on the screen.
##
## When not to use it: a board that fits the window whole. Then drop the
## camera, as T10's tactical board does.
class_name RtsView
extends Node2D

const CELL: float = 32.0
## Where the map window sits on the screen, under the top bar.
const MAP_RECT := Rect2(0.0, 32.0, 960.0, 528.0)
## How fast the camera moves, in cells a second.
const PAN_SPEED: float = 18.0
## How near an edge of the map window the mouse pans it, in pixels.
const EDGE: float = 12.0
const SIDE_COLOURS: Array[Color] = [Color(0.25, 0.55, 1.0), Color(0.95, 0.3, 0.25)]
const GROUND: Dictionary = {
	".": Color(0.36, 0.42, 0.27), "T": Color(0.18, 0.32, 0.16), "#": Color(0.35, 0.33, 0.31),
	"~": Color(0.16, 0.3, 0.52), "=": Color(0.5, 0.38, 0.22), "f": Color(0.3, 0.45, 0.55),
	"o": Color(0.36, 0.42, 0.27), "v": Color(0.36, 0.42, 0.27), "A": Color(0.36, 0.42, 0.27),
	"B": Color(0.36, 0.42, 0.27),
}
const DEPOSIT_COLOURS: Dictionary = {RtsKinds.ROCKS: Color(0.75, 0.72, 0.68), RtsKinds.VENT: Color(1.0, 0.55, 0.1)}
## Never seen: the ground is known, as in StarCraft -- the map is the same
## for both sides and the computer knows it -- but nothing on it is shown.
const FOG := Color(0.0, 0.0, 0.0, 0.6)
const EXPLORED := Color(0.0, 0.0, 0.0, 0.35)
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
## Why the rules would refuse the building under the cursor; "" when they
## would take it. Asked of `RtsRules` itself, so the preview cannot disagree
## with the click.
var placing_refusal: String = ""
## A message across the top of the map, and until when it shows (msec).
var toast: String = ""
var toast_bad: bool = false
var toast_until: int = 0
var art: RtsArt

## The match's tick, which paces the walking frames.
var tick: int = 0

## Cells this side has ever seen: 1 seen, 0 never. The minimap reads it.
var explored := PackedByteArray()
# Each unit's position when last drawn, and the way it last moved: which
# way a sprite faces, and whether it walks.
var _last_position: Dictionary = {}
var _facing: Dictionary = {}


func _ready() -> void:
	explored.resize(RtsScenario.MAP[0].length() * RtsScenario.MAP.size())


## The cell at the map window's top left: what the person is looking at.
static var camera: Vector2 = Vector2.ZERO


## The point in the map window over `position`, a point in cells.
static func to_screen(position: Vector2) -> Vector2:
	return (position - camera) * CELL


## The cell under `point`, a point on the screen.
static func to_cell(point: Vector2) -> Vector2i:
	var inside: Vector2 = (point - MAP_RECT.position) / CELL + camera
	return Vector2i(floori(inside.x), floori(inside.y))


## The camera moved by `cells`, kept on the board.
static func pan(cells: Vector2) -> void:
	frame_at(camera + cells)


## The camera put with `top_left` at the window's corner, kept on the board.
static func frame_at(top_left: Vector2) -> void:
	var board := Vector2(RtsScenario.MAP[0].length(), RtsScenario.MAP.size())
	var biggest: Vector2 = (board - MAP_RECT.size / CELL).max(Vector2.ZERO)
	camera = top_left.clamp(Vector2.ZERO, biggest)


## The cells the window shows, as a rectangle in cells: what the minimap frames.
static func shown_cells() -> Rect2:
	return Rect2(camera, MAP_RECT.size / CELL)


## The units to draw: the whole world's when everything is shown, else the
## snapshot's -- plain dictionaries either way.
func shown_units() -> Array[Dictionary]:
	if not everything:
		return view.units
	var listed: Array[Dictionary] = []
	for unit: RtsUnit in world.units():
		listed.append({"id": unit.id, "side": unit.side, "kind": unit.kind, "position": unit.position,
			"health": unit.health, "complete": unit.complete, "armed": unit.armed})
	return listed


func _draw() -> void:
	if view == null:
		return
	_draw_ground()
	var shown: Array[Dictionary] = _painters_order(shown_units())
	for unit: Dictionary in shown:
		_draw_unit(unit)
	_draw_strikes(shown)
	if not everything:
		_draw_fog()
	if placing != "" and placing_at != Vector2i(-1, -1):
		_draw_placing()
	if toast != "" and Time.get_ticks_msec() < toast_until:
		_draw_toast()
	if dragging.size != Vector2.ZERO:
		draw_rect(dragging.abs(), SELECTED, false, 1.0)


# Deposits, then buildings, then units, each layer from the top of the
# screen down: a three-quarter view hides what stands behind, so what is
# nearer the bottom is drawn last. In id order a rock raised after a worker
# was painted over the worker gathering beside it.
static func _painters_order(units: Array[Dictionary]) -> Array[Dictionary]:
	var ordered: Array[Dictionary] = units.duplicate()
	ordered.sort_custom(func(one: Dictionary, other: Dictionary) -> bool:
		if _layer(one["kind"]) != _layer(other["kind"]):
			return _layer(one["kind"]) < _layer(other["kind"])
		return (one["position"] as Vector2).y < (other["position"] as Vector2).y)
	return ordered


static func _layer(kind: String) -> int:
	if RtsKinds.is_deposit(kind):
		return 0
	return 1 if RtsKinds.is_building(kind) else 2


func _draw_ground() -> void:
	for row: int in range(RtsScenario.MAP.size()):
		for column: int in range(RtsScenario.MAP[row].length()):
			var letter: String = RtsScenario.MAP[row][column]
			draw_rect(Rect2(to_screen(Vector2(column, row)), Vector2(CELL, CELL)), GROUND[letter])


func _draw_unit(unit: Dictionary) -> void:
	var centre: Vector2 = to_screen(unit["position"])
	var kind: String = unit["kind"]
	if RtsKinds.is_deposit(kind):
		if art == null or not art.draw_unit(self, unit, centre, CELL, Vector2.ZERO, false, tick):
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
	if art == null or not art.draw_unit(self, unit, centre, CELL, facing, moved.length() > 0.001, tick):
		_draw_shape(kind, centre, colour)
	if selected.has(unit["id"]):
		draw_arc(centre, CELL * 0.62, 0.0, TAU, 20, SELECTED, 1.5)
	if unit["armed"]:
		# The gun's reach, faint: where a unit walks into its fire.
		var reach: float = RtsKinds.of(RtsKinds.ARM, "reach")
		draw_arc(centre, CELL * reach, 0.0, TAU, 48, Color(colour, 0.35), 1.0)
	var full: float = float(RtsKinds.of(kind, "health"))
	var bar := Rect2(centre + Vector2(-CELL * 0.4, -CELL * 0.7), Vector2(CELL * 0.8, 4.0))
	draw_rect(bar, Color(0.2, 0.0, 0.0))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(unit["health"] / full, 0.0, 1.0), bar.size.y)), Color(0.3, 0.95, 0.3))
	if not unit["complete"]:
		_draw_construction(unit, centre)
	elif not (unit.get("queue", []) as Array).is_empty():
		var first: String = unit["queue"][0]
		var share: float = clampf(float(unit["progress"]) / float(RtsKinds.of(first, "ticks")), 0.0, 1.0)
		var under := Rect2(centre + Vector2(-CELL * 0.4, CELL * 0.62), Vector2(CELL * 0.8, 4.0))
		draw_rect(under, Color(0.05, 0.1, 0.2))
		draw_rect(Rect2(under.position, Vector2(under.size.x * share, under.size.y)), Color(0.4, 0.75, 1.0))


## Ticks a blow shows for: a flash at the target, and for the mortar the
## shell's flight and its burst. Only drawn: the blow itself was struck,
## whole, on the tick the cooldown began, so a replay never waits for it.
const FLASH_TICKS: int = 8
const SHELL_TICKS: int = 24
const BURST_TICKS: int = 10


# Every blow struck lately by a unit on the screen at a unit on the screen.
# Read from the world -- a cooldown the snapshot does not carry -- and only
# for what this side already sees, so the screen shows no more than a
# player would: who is hitting whom.
func _draw_strikes(shown: Array[Dictionary]) -> void:
	var seen: Dictionary = {}
	for unit: Dictionary in shown:
		seen[unit["id"]] = true
	for unit: Dictionary in shown:
		var striker: RtsUnit = world.unit(unit["id"])
		# An armed tower takes no attack order; whom it struck last is its target.
		var striking: bool = striker != null and (striker.order == RtsCommand.ATTACK or striker.armed)
		if not striking or not seen.has(striker.target_id):
			continue
		var gun: String = RtsKinds.ARM if striker.armed else striker.kind
		var since: int = int(RtsKinds.of(gun, "cooldown")) - striker.cooldown
		var from: Vector2 = to_screen(striker.position)
		var to: Vector2 = to_screen(world.unit(striker.target_id).position)
		if RtsKinds.of(striker.kind, "siege"):
			_draw_shell(from, to, since)
		elif since < FLASH_TICKS:
			draw_line(from, to, Color(1.0, 1.0, 0.8, 0.6), 1.5)
			draw_circle(to, CELL * 0.3 * (1.0 - float(since) / FLASH_TICKS), Color(1.0, 0.85, 0.3, 0.8))


# The mortar's shell, flying a low arc to its target, then bursting.
func _draw_shell(from: Vector2, to: Vector2, since: int) -> void:
	if since < SHELL_TICKS:
		var along: float = float(since) / SHELL_TICKS
		var lift := Vector2(0.0, -sin(along * PI) * CELL * 1.5)
		draw_circle(from.lerp(to, along) + lift, 3.5, Color(1.0, 0.6, 0.2))
	elif since < SHELL_TICKS + BURST_TICKS:
		var spread: float = float(since - SHELL_TICKS) / BURST_TICKS
		draw_circle(to, CELL * (0.2 + 0.5 * spread), Color(1.0, 0.45, 0.1, 0.8 * (1.0 - spread)))


# A site going up: its cell outlined, and how far along it is -- from the
# work done for one's own, from its health for anybody else's.
func _draw_construction(unit: Dictionary, centre: Vector2) -> void:
	var share: float = float(unit["health"]) / float(RtsKinds.of(unit["kind"], "health"))
	if unit.has("progress"):
		share = float(unit["progress"]) / float(RtsKinds.of(unit["kind"], "ticks"))
	draw_rect(Rect2(centre - Vector2(CELL, CELL) * 0.5, Vector2(CELL, CELL)), Color(1.0, 0.9, 0.3), false, 2.0)
	draw_string(ThemeDB.fallback_font, centre + Vector2(-CELL, CELL * 0.95), tr("building {percent}%").format({percent = roundi(share * 100.0)}),
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color(1.0, 0.9, 0.3))


# The building under the cursor, as it would stand: green where the rules
# take it, red where they would not, with why.
func _draw_placing() -> void:
	var good: bool = placing_refusal == ""
	var tint := Color(0.5, 1.0, 0.5, 0.7) if good else Color(1.0, 0.4, 0.4, 0.7)
	var centre: Vector2 = to_screen(Vector2(placing_at) + Vector2(0.5, 0.5))
	var ghost: Dictionary = {"kind": placing, "side": 0, "health": RtsKinds.of(placing, "health"), "complete": true}
	if art == null or not art.draw_unit(self, ghost, centre, CELL, Vector2.ZERO, false, tick, tint):
		draw_rect(Rect2(centre - Vector2(CELL, CELL) * 0.5, Vector2(CELL, CELL)), tint)
	draw_rect(Rect2(centre - Vector2(CELL, CELL) * 0.5, Vector2(CELL, CELL)), tint, false, 2.0)
	var words: String = tr("click to build {what}").format({what = RtsWords.with_the(placing)}) if good else placing_refusal
	draw_string(ThemeDB.fallback_font, centre + Vector2(CELL, -CELL * 0.6), words, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, tint)


func _draw_toast() -> void:
	var font: Font = ThemeDB.fallback_font
	var width: float = font.get_string_size(toast, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16).x
	var box := Rect2(Vector2((MAP_RECT.size.x - width) / 2.0 - 12.0, 10.0), Vector2(width + 24.0, 30.0))
	draw_rect(box, Color(0.0, 0.0, 0.0, 0.75))
	var colour := Color(1.0, 0.45, 0.4) if toast_bad else Color(0.6, 1.0, 0.6)
	draw_string(font, box.position + Vector2(12.0, 21.0), toast, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, colour)


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
	seen.resize(explored.size())
	for unit: Dictionary in view.mine():
		_mark_seen(seen, unit["position"], RtsKinds.sight(unit["kind"], unit["complete"]))
	for index: int in range(seen.size()):
		if seen[index] == 1:
			explored[index] = 1
			continue
		var cell := Vector2(index % width, index / width)
		draw_rect(Rect2(to_screen(cell), Vector2(CELL, CELL)), EXPLORED if explored[index] == 1 else FOG)


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
