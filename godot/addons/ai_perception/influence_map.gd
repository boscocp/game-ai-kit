## A number per cell saying how dangerous it is to stand there.
##
## Sources raise cells to a value, and a cell keeps the strongest: two guards
## watching one cell make it no more watched than the nearer one does. Values
## stay within [0, 1], so a watcher's own cell, at 1, is the maximum.
## Building one from watchers costs one `VisionCone.visible_cells` each.
##
## When not to use it: when influence should spread or add up -- territory in
## a strategy game, where two armies *do* make a region twice as held.
class_name InfluenceMap
extends RefCounted

var width: int
var height: int

# Row-major, one value per cell, like `GakGridGraph`'s costs.
var _values: PackedFloat64Array


func _init(map_width: int, map_height: int) -> void:
	width = maxi(map_width, 0)
	height = maxi(map_height, 0)
	_values = PackedFloat64Array()
	_values.resize(width * height)


## The danger a set of watchers puts on a board: every cell each one sees,
## by how near it is. A watcher sees its own cell at closeness 1, so a watcher
## standing on the board holds the map's maximum; one off it marks nothing
## there, since off the board there is nothing to mark.
##
## `eyes` and `facings` are pairs, index by index. Lists of different lengths
## are a caller's mistake, and the map is then empty rather than built from
## whichever watchers happened to have a partner.
static func of_watchers(graph: GakGridGraph, cone: VisionCone, eyes: Array[Vector2i],
		facings: Array[Vector2i]) -> InfluenceMap:
	var map: InfluenceMap = new(graph.width, graph.height)
	if eyes.size() != facings.size():
		return map
	for index: int in range(eyes.size()):
		for cell: Vector2i in cone.visible_cells(graph, eyes[index], facings[index]):
			map.raise_to(cell, cone.closeness(eyes[index], cell))
	return map


## The value at a cell; 0 off the board.
func value_at(cell: Vector2i) -> float:
	if not _contains(cell):
		return 0.0
	return _values[cell.y * width + cell.x]


## Raise a cell to `value`, clamped into [0, 1]; a lower value, or NaN,
## changes nothing.
func raise_to(cell: Vector2i, value: float) -> void:
	if not _contains(cell) or is_nan(value):
		return
	var index: int = cell.y * width + cell.x
	_values[index] = maxf(_values[index], clampf(value, 0.0, 1.0))


## Where watchers will be soon: the cells of a route, from `strength` at the
## first, falling by an equal share each cell, to `strength / length` at the
## last.
##
## A guard two steps from a corner makes the corner dangerous before it can
## see round it, which is the thing a player is actually afraid of.
func raise_along(route: Array[Vector2i], strength: float) -> void:
	for index: int in range(route.size()):
		raise_to(route[index], strength * (1.0 - float(index) / route.size()))


## The largest value anywhere on the map.
func strongest() -> float:
	var largest: float = 0.0
	for value: float in _values:
		largest = maxf(largest, value)
	return largest


func _contains(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height
