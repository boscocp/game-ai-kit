## The room: walls, trees, where the lamps are, the guards' rounds, the way out.
##
## Data and nothing else. The board is an ordinary `GridGraph` -- trees cost
## three to walk through, and `LineOfSight` reads that same number as "blocks
## sight" -- and light is one more number per cell, which only the guards'
## suspicion reads.
class_name StealthRoom
extends RefCounted

const COLUMNS: int = 18
const ROWS: int = 12

## Trees: dear to walk through, and opaque.
const TREE: int = 3

## A lamp lights its own cell fully and fades to nothing this many cells away.
const LAMP_REACH: float = 4.0

## The light every cell has with no lamp near it: moonlight.
const AMBIENT: float = 0.1

var graph: GridGraph
var player_start: Vector2i
var exit: Vector2i

## One round per guard: the cells it walks between, in order, forever.
var rounds: Array[Array] = []

var _light: PackedFloat64Array


func _init(room_graph: GridGraph, lamps: Array[Vector2i], start: Vector2i, way_out: Vector2i,
		guard_rounds: Array[Array]) -> void:
	graph = room_graph
	player_start = start
	exit = way_out
	rounds = guard_rounds
	_light = PackedFloat64Array()
	_light.resize(graph.width * graph.height)
	for y: int in range(graph.height):
		for x: int in range(graph.width):
			_light[y * graph.width + x] = _light_from(lamps, Vector2i(x, y))


## The room the demo opens on: a hall split by a wall with two doors, a copse
## to hide in, two lamps, and two guards on their rounds.
static func default_room() -> StealthRoom:
	var room_graph := GridGraph.new(COLUMNS, ROWS)
	for row: int in range(ROWS):
		if row != 2 and row != 8:
			room_graph.block(Vector2i(9, row))
	for cell: Vector2i in [Vector2i(4, 4), Vector2i(5, 4), Vector2i(4, 5), Vector2i(5, 5),
			Vector2i(13, 6), Vector2i(14, 6), Vector2i(13, 7)]:
		room_graph.set_cost(cell, TREE)
	var lamps: Array[Vector2i] = [Vector2i(9, 2), Vector2i(14, 9)]
	var rounds_walked: Array[Array] = [
		[Vector2i(2, 2), Vector2i(7, 2), Vector2i(7, 9), Vector2i(2, 9)],
		[Vector2i(11, 1), Vector2i(16, 1), Vector2i(16, 10), Vector2i(11, 10)],
	]
	return StealthRoom.new(room_graph, lamps, Vector2i(1, 6), Vector2i(16, 5), rounds_walked)


## How lit a cell is, from 0 (pitch dark) to 1 (under a lamp).
func light_at(cell: Vector2i) -> float:
	if not graph.contains(cell):
		return 0.0
	return _light[cell.y * graph.width + cell.x]


# The brightest lamp at this cell, or moonlight where none reaches.
func _light_from(lamps: Array[Vector2i], cell: Vector2i) -> float:
	var brightest: float = AMBIENT
	for lamp: Vector2i in lamps:
		var fade: float = 1.0 - Vector2(cell - lamp).length() / LAMP_REACH
		brightest = maxf(brightest, fade)
	return brightest
