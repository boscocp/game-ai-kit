## How lit each cell of a level is, from 0 (dark) to 1 (lit), read at a
## body's feet.
##
## Thief weights the player's light to the floor beneath them, because that
## gives the player "an objective, perceivable way to anticipate their own
## safety" [Leonard 2003]: a number the player can see on the ground, not a
## render's guess. So light here is a value per cell, set by whoever builds
## the level -- a lamp lights its cells, a shot-out lamp darkens them -- and
## everywhere else is the ambient light. Constant time per question.
##
## When not to use it: light that moves every frame, or soft shadows the
## player reads off the picture. Then sample the renderer, and accept that
## the player can no longer read the rule off the floor.
class_name LightMap
extends RefCounted

## The light of every cell nobody set.
var ambient: float = 0.0
var _cells: Dictionary[Vector2i, float] = {}


func _init(ambient_light: float = 0.0) -> void:
	ambient = clampf(ambient_light, 0.0, 1.0)


## Light `cell` at `value`, held to 0..1.
func set_light(cell: Vector2i, value: float) -> void:
	_cells[cell] = clampf(value, 0.0, 1.0)


## Back to the ambient light: a lamp put out.
func clear_light(cell: Vector2i) -> void:
	_cells.erase(cell)


## The light in `cell`.
func at(cell: Vector2i) -> float:
	return _cells.get(cell, ambient)


## The light at the feet of a body standing at `position`, on a level whose
## cells are `cell_size` metres: the cell under it, as Thief reads the floor.
func at_feet(position: Vector2, cell_size: float) -> float:
	return at(Vector2i(floori(position.x / cell_size), floori(position.y / cell_size)))
