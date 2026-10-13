## Draws a `GridGraph` as tiles, and nothing else.
##
## The view knows how to show a board and has no opinion about it: it is handed
## a graph and a set of cells to highlight, and it paints. Every decision stays
## in `ai_core` and in `main.gd`, so a lesson that changes how the AI thinks
## never has to touch a drawing routine.
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

## One tile, in pixels.
const TILE_PIXELS: int = 32

## The atlas is one row of flat colours, and these are its columns.
const PLAIN: Vector2i = Vector2i(0, 0)
const ROUGH: Vector2i = Vector2i(1, 0)
const WALL: Vector2i = Vector2i(2, 0)
const REACHABLE: Vector2i = Vector2i(3, 0)
const NODE: Vector2i = Vector2i(4, 0)

const SOURCE_ID: int = 0

# Index-matched with the atlas columns above: the colour of each tile.
const SWATCHES: Array[Color] = [
	Color(0.21, 0.27, 0.21),
	Color(0.35, 0.29, 0.17),
	Color(0.10, 0.10, 0.12),
	Color(0.25, 0.42, 0.46),
	Color(0.52, 0.45, 0.20),
]

## What counts as rough ground when choosing a tile. Terrain here is a cost,
## not a type, so the view decides where the pictures change.
const ROUGH_FROM_COST: int = 2


func _ready() -> void:
	tile_set = _build_tile_set()


## Paint the whole board, mark the cells the selected unit can afford, and
## mark the nodes both sides are playing for.
##
## Repainting everything on every change is the readable choice and costs
## nothing at this size: the alternative is tracking which cells are dirty,
## which is a cache, and a cache is a second source of truth.
##
## The nodes go on last, so a node stays visible when the selected unit could
## step onto it. That is the right way round for watching the AI: what it is
## walking at has to be on the screen, and a cell the player can reach is
## also a cell the player can see a unit standing next to.
func draw_board(graph: GridGraph, reachable: Array[Vector2i],
		nodes: Array[Vector2i] = [] as Array[Vector2i]) -> void:
	clear()
	for y: int in range(graph.height):
		for x: int in range(graph.width):
			var cell := Vector2i(x, y)
			set_cell(cell, SOURCE_ID, _tile_for(graph.cost_at(cell)))
	for cell: Vector2i in reachable:
		set_cell(cell, SOURCE_ID, REACHABLE)
	for cell: Vector2i in nodes:
		set_cell(cell, SOURCE_ID, NODE)


## The board cell under a point in this layer's own coordinates.
func cell_at(local_point: Vector2) -> Vector2i:
	return local_to_map(local_point)


## The centre of a cell, in this layer's own coordinates. The unit view draws
## on top of this layer and needs to agree with it about where a cell is.
func centre_of(cell: Vector2i) -> Vector2:
	return map_to_local(cell)


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
