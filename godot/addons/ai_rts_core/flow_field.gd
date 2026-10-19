## One answer to "how do I get to that cell?", shared by everybody asking it.
##
## A* answers it for one unit: a route, paid for in full by whoever asked. Two
## hundred units sent to one place would pay two hundred times for nearly the
## same answer. A flow field pays once: a Dijkstra flood outwards from the
## goal gives every cell its cost to reach the goal, and each cell's arrow
## points at the neighbour that is cheapest from there. A unit anywhere on the
## map reads the arrow under its feet; it holds no route of its own.
##
## The flood is Dial's form of Dijkstra -- a bucket per distance instead of a
## heap -- because cell costs here are small whole numbers, and it is built in
## slices (`settle`) so a frame budget can spread it over several ticks.
## O(cells x the dearest cell) to build, O(1) per unit per tick to follow.
##
## When not to use it: few units with many different goals. Then each field
## is built for one reader, and A* from `ai_search`, which stops when it
## arrives, is cheaper.
class_name FlowField
extends RefCounted

## The distance of a cell nothing can reach the goal from.
const UNREACHABLE: int = -1

## The cell everybody reading this field is going to.
var goal: Vector2i
## True once every reachable cell has its distance.
var complete: bool = false
## Cells settled so far.
var settled: int = 0
## Steps the flood has taken: every cell taken off the queue, stale copies
## and empty buckets included. What a slice of `settle` is counted in, so a
## budget of 512 is 512 steps, however many of them settle a cell.
var work: int = 0

var _graph: GridGraph
var _distance: PackedInt32Array
# Dial's queue: _buckets[d] holds the cells first reached at distance d.
var _buckets: Array[Array] = []
var _current: int = 0


## A field towards `goal` on `graph`, with nothing settled yet. The goal may
## be a blocked cell -- a building, a mine -- and then the field leads to the
## cells beside it, which is where a worker stands to use one.
func _init(graph: GridGraph, goal_cell: Vector2i) -> void:
	_graph = graph
	goal = goal_cell
	_distance = PackedInt32Array()
	_distance.resize(graph.width * graph.height)
	_distance.fill(UNREACHABLE)
	if graph.contains(goal):
		_distance[_index(goal)] = 0
		_buckets.append([goal])
	else:
		complete = true


## Take up to `budget` more steps of the flood. True when the field is
## complete -- which is how a frame budget hands it a slice and comes back
## next tick.
func settle(budget: int) -> bool:
	var spent: int = 0
	while spent < budget and not complete:
		if _current >= _buckets.size():
			complete = true
		elif _buckets[_current].is_empty():
			_current += 1
		else:
			_settle_one(_buckets[_current].pop_back())
		spent += 1
		work += 1
	return complete


## What it costs to reach the goal from `cell`; `UNREACHABLE` off the board,
## behind a wall, or where the flood has not arrived yet.
func distance_at(cell: Vector2i) -> int:
	return _distance[_index(cell)] if _graph.contains(cell) else UNREACHABLE


## Which way to step from `cell`: towards the reachable neighbour nearest the
## goal, ties broken in `GridGraph.DIRECTIONS` order. Zero at the goal, and
## where there is no way on.
func direction_at(cell: Vector2i) -> Vector2i:
	var best: Vector2i = Vector2i.ZERO
	var best_distance: int = distance_at(cell)
	if best_distance == UNREACHABLE or cell == goal:
		return Vector2i.ZERO
	for direction: Vector2i in GridGraph.DIRECTIONS:
		var distance: int = distance_at(cell + direction)
		if distance != UNREACHABLE and distance < best_distance:
			best_distance = distance
			best = direction
	return best


# Take one cell off the queue and offer its neighbours a distance through it.
# A cell can sit in a bucket twice, once at a worse distance; that stale copy
# is skipped here rather than searched for and removed when it was improved.
func _settle_one(cell: Vector2i) -> void:
	var distance: int = _distance[_index(cell)]
	if distance != _current:
		return
	settled += 1
	var entering: int = 1 if cell == goal else _graph.cost_at(cell)
	for neighbour: Vector2i in _graph.neighbours(cell):
		var through: int = distance + entering
		var known: int = _distance[_index(neighbour)]
		if known == UNREACHABLE or through < known:
			_distance[_index(neighbour)] = through
			_queue(neighbour, through)


# File `cell` in the bucket for `distance`, growing the buckets to reach it.
func _queue(cell: Vector2i, distance: int) -> void:
	while _buckets.size() <= distance:
		_buckets.append([])
	_buckets[distance].append(cell)


func _index(cell: Vector2i) -> int:
	return cell.y * _graph.width + cell.x
