## The valley's ground as a grid (T165): where each place stands, the river
## that cuts the valley in two, and the two ways across it.
##
## `valley_map.json` draws it one letter a cell. The ground never changes;
## what changes is which crossings are open, and that is read off the day's
## facts: the bridge while `bridge.standing` holds, the ford while
## `ford.footbridge` does. So a deed that pulls the bridge down changes no
## cell here -- it changes a fact, and the next grid built from the facts
## has one way fewer across, which is what A\* then finds.
##
## Building the grid costs one pass over its cells.
##
## When not to use it: for ground that changes under the walkers' feet
## within a day in ways no fact names. Here every change comes from a deed
## through a fact, so the grid can always be rebuilt from the facts alone.
class_name ValleyMap
extends RefCounted

const FILE: String = "res://game/valley/valley_map.json"
## The river's letter: nobody walks on it.
const WATER: String = "~"

## The ground, one string a row, from the top.
var rows: Array[String] = []
var width: int = 0
var height: int = 0
## For each place, the cells a villager stands on to use it.
var places: Dictionary = {}
## For each crossing's letter, the fact that opens it.
var crossings: Dictionary = {}
## Each village's first and last column, by name.
var villages: Dictionary = {}

static var _authored: ValleyMap = null


func _init(table: Dictionary = {}) -> void:
	var read: Dictionary = table if not table.is_empty() else read_file()
	rows.assign(read["rows"])
	height = rows.size()
	width = rows[0].length()
	crossings = read["crossings"]
	villages = read["villages"]
	for place: String in read["places"]:
		var cells: Array[Vector2i] = []
		for pair: Array in read["places"][place]:
			cells.append(Vector2i(int(pair[0]), int(pair[1])))
		places[place] = cells


## The map as `valley_map.json` writes it.
static func read_file() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(FILE))


## The one authored map, read once and shared: it never changes.
static func authored() -> ValleyMap:
	if _authored == null:
		_authored = ValleyMap.new()
	return _authored


## The cells a villager stands on to use `place`.
func cells_of(place: String) -> Array[Vector2i]:
	return places.get(place, [] as Array[Vector2i])


## The letter of `cell`.
func letter_at(cell: Vector2i) -> String:
	return rows[cell.y][cell.x]


## The grid a villager walks on, given the day's `facts`: the river
## blocked, and each crossing open only while its fact holds.
func graph_for(facts: Dictionary) -> GakGridGraph:
	var graph := GakGridGraph.new(width, height)
	for index: int in range(width * height):
		var cell := Vector2i(index % width, index / width)
		if not is_open(cell, facts):
			graph.block(cell)
	return graph


## Whether anyone can stand on `cell` with the world's `facts`.
func is_open(cell: Vector2i, facts: Dictionary) -> bool:
	var letter: String = letter_at(cell)
	if crossings.has(letter):
		return bool(facts.get(crossings[letter], false))
	return letter != WATER


## The facts of the crossings `facts` leaves shut, in the file's order:
## what a villager on one bank cannot walk past.
func shut_crossings(facts: Dictionary) -> Array[String]:
	var shut: Array[String] = []
	for letter: String in crossings:
		if not bool(facts.get(crossings[letter], false)):
			shut.append(str(crossings[letter]))
	return shut


## The village `cell` is in, by its columns, or "" on the river.
func village_of(cell: Vector2i) -> String:
	for village: String in villages:
		var span: Array = villages[village]
		if cell.x >= int(span[0]) and cell.x <= int(span[1]):
			return village
	return ""
