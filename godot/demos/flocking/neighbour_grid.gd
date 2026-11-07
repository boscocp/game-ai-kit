## Who is near whom, without asking every pair: a uniform grid.
##
## The flock's rules are handed their neighbours; this is how the flocking
## demo finds them. Every point is filed in the square cell it falls in,
## cells as wide as the sight radius, so everyone within that radius of a
## point is in its cell or one of the eight around it. Filling is O(n); a
## query looks at nine cells, about O(neighbours) when the points are spread
## out. The naive answer -- every point against every other -- is O(n^2):
## 9,900 distances a step for a hundred boids. Here, measured on the
## demo's flock, 1,622 at the start and 1,836 ten seconds in (`make
## measure-flocking`) -- and the more the boids bunch, the closer it comes
## to the naive count: 2,944 with separation off (docs/concepts/steering.md).
##
## The answer comes in index order, whatever the order of the cells, so two
## runs from one start hand every rule the same neighbours in the same order
## and agree to the last bit (the RTS core does the same).
##
## When not to use it: points packed into a few cells -- then a cell holds
## nearly everyone and it is the naive search again -- or a world far wider
## than the points, where most cells are empty: a hash of cells, which this
## is, only stores the full ones; a fixed array of cells would not.
class_name NeighbourGrid
extends RefCounted

## A cell and the eight around it.
const AROUND: Array[Vector2i] = [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0), Vector2i(0, 0),
	Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]

## The side of a cell, never smaller than the radius asked about.
var cell_size: float
## How many distances the queries since the last `fill` have measured: the
## cost the page compares with the naive search's.
var distances: int = 0
# The indices in each cell, in the order they were filed.
var _cells: Dictionary = {}


func _init(side: float) -> void:
	cell_size = side


## Files every point by its index, forgetting the last filling.
func fill(points: PackedVector2Array) -> void:
	_cells.clear()
	distances = 0
	for index: int in range(points.size()):
		var cell: Vector2i = _cell_of(points[index])
		if not _cells.has(cell):
			_cells[cell] = PackedInt32Array()
		_cells[cell].append(index)


## The indices of the points closer than `radius` to point `index`, itself
## left out, in increasing order. `radius` must not exceed `cell_size`, or
## the nine cells looked in would miss some.
func near(points: PackedVector2Array, index: int, radius: float) -> PackedInt32Array:
	var found := PackedInt32Array()
	var centre: Vector2i = _cell_of(points[index])
	for offset: Vector2i in AROUND:
		var candidates: PackedInt32Array = _cells.get(centre + offset, PackedInt32Array())
		distances += candidates.size()
		found.append_array(_near_in(candidates, points, index, radius))
	found.sort()
	return found


## The same answer the slow way, every point against `index`: what the grid
## must agree with, for `test/demo_flocking/`.
static func near_naively(points: PackedVector2Array, index: int, radius: float) -> PackedInt32Array:
	return _near_in(PackedInt32Array(range(points.size())), points, index, radius)


# Those of `candidates` closer than `radius` to point `index`, not itself.
static func _near_in(candidates: PackedInt32Array, points: PackedVector2Array, index: int,
		radius: float) -> PackedInt32Array:
	var found := PackedInt32Array()
	for other: int in candidates:
		if other != index and points[other].distance_to(points[index]) < radius:
			found.append(other)
	return found


func _cell_of(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / cell_size), floori(point.y / cell_size))
