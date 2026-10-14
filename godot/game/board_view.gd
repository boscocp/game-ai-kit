## Draws a `GridGraph` as tiles, and nothing else.
##
## The view knows how to show a board and has no opinion about it: it is handed
## a graph and a set of cells to highlight, and it paints. Every decision stays
## in `ai_core` and in `main.gd`, so a lesson that changes how the AI thinks
## never has to touch a drawing routine.
##
## Terrain is tiles; everything a reader needs on top of the terrain -- the
## grid, the cells the unit in hand can reach, what a cell costs -- is drawn
## over it on a child canvas item, so it never hides the ground it is about.
## A child, not this layer's own `_draw`: measured on the pinned engine, a
## `TileMapLayer` paints its tiles *over* its own `_draw`, and the first
## version of this overlay was drawn, correct, and invisible. That is the
## measured defect T8 fixed: a reachable cell used to be painted *instead of*
## its terrain, so the moment you most wanted to know what the ground cost was
## the moment it was hidden.
##
## The tile set is built in code from a generated image rather than loaded from
## an atlas. A reader can see exactly what a tile is -- a flat colour and a
## size -- without opening the editor, and this repository stays free of binary
## art nobody can diff.
##
## When not to use it: a real game. Real tiles come from an artist, in a
## `.tres` tile set, and the colours below are placeholders for the shape of
## the thing.
class_name BoardView
extends TileMapLayer

## One tile, in pixels. 48 and not 32: at 32 the board was a small thing in
## the corner of a 1280x720 window, and a cost written on a tile could not be
## read at all.
const TILE_PIXELS: int = 48

## The atlas is one row of flat colours, and these are its columns.
const PLAIN: Vector2i = Vector2i(0, 0)
const ROUGH: Vector2i = Vector2i(1, 0)
const WALL: Vector2i = Vector2i(2, 0)
const NODE: Vector2i = Vector2i(3, 0)
const WATER: Vector2i = Vector2i(4, 0)
const BRIDGE: Vector2i = Vector2i(5, 0)

const SOURCE_ID: int = 0

# Index-matched with the atlas columns above: the colour of each tile. Each one
# differs from the others in brightness as well as in hue -- mid green, light
# tan, near black, gold -- so they separate at a glance and for a reader who
# cannot tell green from brown. The old palette was two dark greys and a dark
# green, which merged into one field.
const SWATCHES: Array[Color] = [
	Color(0.36, 0.50, 0.34),
	Color(0.74, 0.60, 0.38),
	Color(0.13, 0.13, 0.15),
	Color(0.95, 0.78, 0.25),
	Color(0.20, 0.40, 0.72),
	Color(0.55, 0.38, 0.22),
]

## The cells the unit in hand can reach: a tint and a border over the terrain,
## never instead of it.
const REACHABLE: Color = Color(0.70, 0.95, 1.0, 0.40)
const REACHABLE_BORDER: Color = Color(0.85, 1.0, 1.0, 0.95)

## Lines between cells, so ground of one kind still reads as cells.
const GRID: Color = Color(0.0, 0.0, 0.0, 0.30)

## The entry cost written on dear ground.
const COST_TEXT: Color = Color(0.12, 0.08, 0.04)
const COST_TEXT_SIZE: int = 22

## Column numbers above the board and row numbers to its left, because every
## refusal and every reason on the screen names a cell as `(column, row)`.
const AXIS_TEXT: Color = Color(0.85, 0.85, 0.85)
const AXIS_TEXT_SIZE: int = 13

## What counts as rough ground when choosing a tile. Terrain here is a cost,
## not a type, so the view decides where the pictures change.
const ROUGH_FROM_COST: int = 2

var _graph: GridGraph
var _reachable: Array[Vector2i] = []
# Where the overlay is drawn: above the tiles, below whatever the scene puts
# after this layer -- units, routes. Made in `_ready`, so a view that never
# enters the tree leaves nothing behind.
var _marks: Node2D


func _ready() -> void:
	tile_set = _build_tile_set()
	_marks = Node2D.new()
	_marks.name = "Marks"
	_marks.draw.connect(_draw_marks)
	add_child(_marks)


## Paint the whole board, mark the cells the selected unit can afford, and
## mark the nodes both sides are playing for.
##
## Repainting everything on every change is the readable choice and costs
## nothing at this size: the alternative is tracking which cells are dirty,
## which is a cache, and a cache is a second source of truth.
##
## Terrain and nodes are tiles. The reachable cells are not: they are kept and
## drawn over the tiles by `_draw_marks`, so a rough cell you can step onto still
## looks rough and still says what it costs.
##
## `terrain` names a tile for cells whose cost alone cannot say what they are:
## water is blocked to most units, like a wall, and is not a wall. Terrain is
## the game's idea, so the scene passes it in rather than the graph carrying it.
func draw_board(graph: GridGraph, reachable: Array[Vector2i],
		nodes: Array[Vector2i] = [] as Array[Vector2i], terrain: Dictionary = {}) -> void:
	clear()
	_graph = graph
	_reachable = reachable
	for y: int in range(graph.height):
		for x: int in range(graph.width):
			var cell := Vector2i(x, y)
			set_cell(cell, SOURCE_ID, _tile_for(graph.cost_at(cell)))
	for cell: Vector2i in terrain:
		set_cell(cell, SOURCE_ID, terrain[cell])
	for cell: Vector2i in nodes:
		set_cell(cell, SOURCE_ID, NODE)
	if _marks != null:
		_marks.queue_redraw()


## Everything the overlay draws, as data: the reachable cells and the cost
## written on each dear cell. `_draw_marks` draws exactly this and nothing
## else, so a test can hold what is drawn without a picture -- headless, no
## picture exists.
func marks() -> Dictionary:
	return {"reachable": _reachable.duplicate(), "costs": _costs_to_write()}


# Every cell with a cost worth writing, and the words written on it.
func _costs_to_write() -> Dictionary:
	var costs: Dictionary = {}
	if _graph == null:
		return costs
	for index: int in range(_graph.width * _graph.height):
		var cell := Vector2i(index % _graph.width, index / _graph.width)
		if not cost_label(cell).is_empty():
			costs[cell] = cost_label(cell)
	return costs


## The words drawn on a cell: its entry cost when that is more than an
## ordinary step, and nothing otherwise. Rough ground that looks dear and says
## `3` needs no legend; a `1` on every plain cell would be noise.
func cost_label(cell: Vector2i) -> String:
	if _graph == null or not _graph.contains(cell):
		return ""
	var cost: int = _graph.cost_at(cell)
	if cost == GridGraph.BLOCKED or cost <= GridGraph.DEFAULT_COST:
		return ""
	return str(cost)


## Where to put a board so it sits in the middle of an area: the top-left
## corner, in the area's own coordinates. Derived from the board's size, so a
## scenario with more columns stays centred instead of sliding off the edge.
static func offset_to_centre(graph: GridGraph, area: Vector2) -> Vector2:
	return ((area - pixel_size(graph)) / 2.0).floor()


## How much of the screen a board covers, in pixels. The scene lays out its
## panels around this, so it is the one number they all agree on.
static func pixel_size(graph: GridGraph) -> Vector2:
	return Vector2(graph.width, graph.height) * TILE_PIXELS


## The board cell under a point in this layer's own coordinates.
func cell_at(local_point: Vector2) -> Vector2i:
	return local_to_map(local_point)


## The centre of a cell, in this layer's own coordinates. The unit view draws
## on top of this layer and needs to agree with it about where a cell is.
func centre_of(cell: Vector2i) -> Vector2:
	return map_to_local(cell)


# Everything in `marks()`, in the order a reader needs it: the reachable tint
# under the grid, so the grid still separates reachable cells from each other;
# the costs last, so nothing on this layer covers a number.
func _draw_marks() -> void:
	if _graph == null:
		return
	var drawn: Dictionary = marks()
	for cell: Vector2i in drawn["reachable"]:
		_draw_reachable(cell)
	_draw_grid()
	_draw_axes()
	for cell: Vector2i in drawn["costs"]:
		_draw_centred(drawn["costs"][cell], centre_of(cell), COST_TEXT_SIZE, COST_TEXT)


func _draw_reachable(cell: Vector2i) -> void:
	var square := Rect2(Vector2(cell * TILE_PIXELS), Vector2(TILE_PIXELS, TILE_PIXELS))
	_marks.draw_rect(square, REACHABLE)
	_marks.draw_rect(square.grow(-2.0), REACHABLE_BORDER, false, 3.0)


func _draw_grid() -> void:
	var board_size: Vector2 = pixel_size(_graph)
	for column: int in range(_graph.width + 1):
		var x: float = column * TILE_PIXELS
		_marks.draw_line(Vector2(x, 0.0), Vector2(x, board_size.y), GRID, 1.0)
	for row: int in range(_graph.height + 1):
		var y: float = row * TILE_PIXELS
		_marks.draw_line(Vector2(0.0, y), Vector2(board_size.x, y), GRID, 1.0)


# Just outside the board, where they cover nothing.
func _draw_axes() -> void:
	var half: float = TILE_PIXELS / 2.0
	for column: int in range(_graph.width):
		_draw_centred(str(column), Vector2(column * TILE_PIXELS + half, -10.0), AXIS_TEXT_SIZE, AXIS_TEXT)
	for row: int in range(_graph.height):
		_draw_centred(str(row), Vector2(-12.0, row * TILE_PIXELS + half), AXIS_TEXT_SIZE, AXIS_TEXT)


# `draw_string` takes the left end of the baseline; a label in a cell wants
# its middle on a point.
func _draw_centred(words: String, middle: Vector2, text_size: int, colour: Color) -> void:
	var font: Font = ThemeDB.fallback_font
	var width: float = font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1.0, text_size).x
	var baseline: Vector2 = middle + Vector2(-width / 2.0, text_size * 0.35)
	_marks.draw_string(font, baseline, words, HORIZONTAL_ALIGNMENT_LEFT, -1.0, text_size, colour)


# Which atlas column a cost is drawn with.
func _tile_for(cost: int) -> Vector2i:
	if cost == GridGraph.BLOCKED:
		return WALL
	if cost >= ROUGH_FROM_COST:
		return ROUGH
	return PLAIN


# One row of flat colours, one column per tile, built at run time.
func _build_tile_set() -> TileSet:
	var atlas := Image.create_empty(
		TILE_PIXELS * SWATCHES.size(), TILE_PIXELS, false, Image.FORMAT_RGBA8
	)
	for index: int in range(SWATCHES.size()):
		var region := Rect2i(index * TILE_PIXELS, 0, TILE_PIXELS, TILE_PIXELS)
		atlas.fill_rect(region, SWATCHES[index])

	var source := TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(atlas)
	source.texture_region_size = Vector2i(TILE_PIXELS, TILE_PIXELS)
	for index: int in range(SWATCHES.size()):
		source.create_tile(Vector2i(index, 0))

	var tiles := TileSet.new()
	tiles.tile_size = Vector2i(TILE_PIXELS, TILE_PIXELS)
	tiles.add_source(source, SOURCE_ID)
	return tiles
