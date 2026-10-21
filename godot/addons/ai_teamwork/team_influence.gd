## A team's hold on the map: friends add, enemies subtract, and both fade
## with distance.
##
## Every bot is a source of its strength (a share of its health), spread over
## a radius with a linear falloff, and the sources add up. So two friends
## make a place twice as held, and a place where the two sides balance reads
## zero -- contested. One map is computed per team and read by all of it, so
## a squad asks "where are we strong" without asking any other bot [Mark
## 2015]. Building it costs sources times the cells in a radius.
##
## The kit's other influence map, in ai_perception, keeps the strongest
## source per cell, in [0, 1]: that is "how watched is this cell", and its
## header says it is the wrong one for territory. This is territory.
##
## When not to use it: for one bot's own safety. Additive strength says where
## a team is, not whether this cell is in someone's sights.
class_name TeamInfluence
extends RefCounted

var width: int
var height: int
## Metres per cell, and where cell (0, 0)'s corner is.
var cell_size: float
var origin: Vector2
## How far a source reaches, in metres.
var radius: float

# Row-major, one value per cell.
var _values: PackedFloat64Array


func _init(map_width: int, map_height: int, metres_per_cell: float,
		corner: Vector2, reach: float) -> void:
	width = maxi(map_width, 0)
	height = maxi(map_height, 0)
	cell_size = metres_per_cell
	origin = corner
	radius = reach
	_values = PackedFloat64Array()
	_values.resize(width * height)


## Add a source of `strength` at `place`: positive for a friend, negative for
## an enemy. A cell takes it at its centre, falling linearly to zero at
## `radius`.
func add_source(place: Vector2, strength: float) -> void:
	var reach: int = ceili(radius / cell_size)
	var centre: Vector2i = cell_of(place)
	for row: int in range(maxi(centre.y - reach, 0), mini(centre.y + reach + 1, height)):
		for column: int in range(maxi(centre.x - reach, 0), mini(centre.x + reach + 1, width)):
			_spread(place, strength, Vector2i(column, row))


# One cell's share of a source: its strength, falling to zero at `radius`.
func _spread(place: Vector2, strength: float, cell: Vector2i) -> void:
	var distance: float = place.distance_to(centre_of(cell))
	if distance < radius:
		_values[cell.y * width + cell.x] += strength * (1.0 - distance / radius)


## The value at the cell holding `place`; zero off the map.
func value_at(place: Vector2) -> float:
	var cell: Vector2i = cell_of(place)
	if cell.x < 0 or cell.y < 0 or cell.x >= width or cell.y >= height:
		return 0.0
	return _values[cell.y * width + cell.x]


## The cell a point falls in, which may be off the map.
func cell_of(place: Vector2) -> Vector2i:
	var local: Vector2 = (place - origin) / cell_size
	return Vector2i(floori(local.x), floori(local.y))


## The middle of a cell, in metres.
func centre_of(cell: Vector2i) -> Vector2:
	return origin + (Vector2(cell) + Vector2(0.5, 0.5)) * cell_size


## Every cell's value, row-major, for a view that draws the map.
func values() -> PackedFloat64Array:
	return _values.duplicate()
