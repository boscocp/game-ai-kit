## Levels the stealth properties make up, from a seed: sizes and shapes no
## hand-made level has, so a claim that holds on them is not a claim about
## one level (the owner's rule: a guard on another map must cope).
##
## A level is a `GakGridGraph` with walls scattered over it, and sometimes one
## full-height wall that cuts it in two -- the case where sound must not
## get through. The belief's graph is the level's free cells as a
## neighbour list, which is all `BeliefMap` is ever given.
##
## When not to use it: as a level to play. Nothing here is fair or fun;
## it is only varied.
class_name StealthWorlds
extends RefCounted

const SMALLEST: int = 4
const LARGEST: int = 24
const WALL_SHARE: float = 0.2


## A level of random size with about WALL_SHARE of its cells walled.
static func scattered(rng: RandomNumberGenerator) -> GakGridGraph:
	var level := GakGridGraph.new(rng.randi_range(SMALLEST, LARGEST), rng.randi_range(SMALLEST, LARGEST))
	for cell: Vector2i in every_cell(level):
		if rng.randf() < WALL_SHARE:
			level.block(cell)
	return level


## A level cut in two by a full-height wall at `wall_column`: nothing on one
## side has a path to the other.
static func cut_in_two(rng: RandomNumberGenerator) -> GakGridGraph:
	var level: GakGridGraph = scattered(rng)
	var wall_column: int = rng.randi_range(1, level.width - 2)
	for y: int in range(level.height):
		level.block(Vector2i(wall_column, y))
	return level


## Every free cell of `level`, row by row.
static func free_cells(level: GakGridGraph) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell: Vector2i in every_cell(level):
		if not level.is_blocked(cell):
			cells.append(cell)
	return cells


## Every cell of `level`, walled or not, row by row.
static func every_cell(level: GakGridGraph) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y: int in range(level.height):
		for x: int in range(level.width):
			cells.append(Vector2i(x, y))
	return cells


## The free cells of `level` as a neighbour list over their indices in
## `cells`: what a `BeliefMap` is given.
static func neighbour_list(level: GakGridGraph, cells: Array[Vector2i]) -> Array[PackedInt32Array]:
	var index_of: Dictionary[Vector2i, int] = {}
	for index: int in range(cells.size()):
		index_of[cells[index]] = index
	var lists: Array[PackedInt32Array] = []
	for cell: Vector2i in cells:
		var near := PackedInt32Array()
		for next: Vector2i in level.neighbours(cell):
			near.append(index_of[next])
		lists.append(near)
	return lists
