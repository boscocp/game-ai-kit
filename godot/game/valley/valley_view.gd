## The valley drawn in shapes (T165): the two villages, the river and its
## crossings, the places as the world has them today, the villagers -- and
## the decision of the one followed.
##
## No art. A place is a square in its colour, dark once it is burnt or
## gone; the bridge is planks over the river while it stands, and the ford
## grows a footbridge. The decision is the lesson: the followed villager's
## A\* search drawn on the ground -- the cells it expanded, its frontier,
## the route it chose -- and a ring on the place its plan goes to next.
## When the way is shut, the expanded cells fill that villager's bank of
## the river and stop at the water: that is what "unreachable" looks like.
##
## Static functions drawing on the example's own canvas.
class_name ValleyView
extends RefCounted

const CELL: float = 28.0
const TEXT_SIZE: int = 12
const WEST := Color(0.20, 0.30, 0.16)
const EAST := Color(0.26, 0.30, 0.14)
const WATER := Color(0.13, 0.30, 0.62)
const BRIDGE := Color(0.62, 0.45, 0.25)
const PLACE := Color(0.85, 0.75, 0.45)
const GONE := Color(0.18, 0.14, 0.12)
const VILLAGER := Color(0.95, 0.95, 0.90)
const FOLLOWED := Color(1.0, 0.85, 0.10)
const EXPANDED := Color(1.0, 0.85, 0.10, 0.22)
const FRONTIER := Color(0.30, 0.95, 1.0)
const ROUTE := Color(1.0, 1.0, 1.0)
const PERSON := Color(0.85, 0.40, 0.85)
## Each place's words, and the fact that says whether it is there today.
const PLACE_WORDS: Dictionary = {  # shown through tr()
	"market": "the market", "square": "the square", "barn": "the barn", "mill": "the mill",
	"river": "the river", "orchard": "the orchard", "gate": "the gate", "field": "the field",
	"bridge": "the bridge", "ford": "the ford", "home": "home",
}
const STANDS: Dictionary = {
	"market": "market.bread", "square": "square.well", "barn": "barn.standing", "mill": "mill.turning",
	"orchard": "orchard.fruit", "gate": "gate.open", "field": "field.planted",
}


## The top-left corner of `cell` on the canvas.
static func corner(cell: Vector2i) -> Vector2:
	return Vector2(cell) * CELL


## The centre of `cell` on the canvas.
static func centre(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * CELL


## The ground: each village's tint, the river, and its two crossings as
## today's facts leave them.
static func draw_ground(canvas: CanvasItem, ground: ValleyMap, facts: Dictionary) -> void:
	for y: int in range(ground.height):
		for x: int in range(ground.width):
			_draw_cell(canvas, ground, Vector2i(x, y), facts)


# One cell of ground: grass in its village's tint, water, or a crossing --
# planks over the water while its fact holds.
static func _draw_cell(canvas: CanvasItem, ground: ValleyMap, cell: Vector2i, facts: Dictionary) -> void:
	var square := Rect2(corner(cell), Vector2(CELL, CELL))
	var letter: String = ground.letter_at(cell)
	if letter != ValleyMap.WATER and not ground.crossings.has(letter):
		canvas.draw_rect(square, WEST if ground.village_of(cell) == "west" else EAST)
		return
	canvas.draw_rect(square, WATER)
	if ground.crossings.has(letter) and ground.is_open(cell, facts):
		canvas.draw_rect(square.grow_individual(0, -6, 0, -6), BRIDGE)


## Each place, in its colour while today's world has it, dark when not;
## its name beside it.
static func draw_places(canvas: CanvasItem, ground: ValleyMap, facts: Dictionary) -> void:
	var font: Font = ThemeDB.fallback_font
	for place: String in STANDS:
		var there: bool = bool(facts.get(STANDS[place], false))
		for cell: Vector2i in ground.cells_of(place):
			canvas.draw_rect(Rect2(corner(cell) + Vector2(3, 3), Vector2(CELL - 6, CELL - 6)), PLACE if there else GONE)
			canvas.draw_rect(Rect2(corner(cell) + Vector2(3, 3), Vector2(CELL - 6, CELL - 6)), PLACE, false, 1.0)
		var first: Vector2i = ground.cells_of(place)[0]
		canvas.draw_string(font, corner(first) + Vector2(0, -3),
			TranslationServer.translate(PLACE_WORDS[place]), HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE)


## The followed villager's A* search: what it expanded, its frontier, the
## route it walks, and a ring on where it is going.
static func draw_search(canvas: CanvasItem, villager: ValleyVillager) -> void:
	if villager.search == null:
		return
	for cell: Vector2i in villager.search.expanded:
		canvas.draw_rect(Rect2(corner(cell), Vector2(CELL, CELL)), EXPANDED)
	for cell: Vector2i in villager.search.frontier:
		canvas.draw_rect(Rect2(corner(cell) + Vector2(2, 2), Vector2(CELL - 4, CELL - 4)), FRONTIER, false, 2.0)
	var points := PackedVector2Array([centre(villager.cell)])
	for cell: Vector2i in villager.route:
		points.append(centre(cell))
	if points.size() > 1:
		canvas.draw_polyline(points, ROUTE, 2.0)
	if not villager.route.is_empty():
		canvas.draw_arc(centre(villager.route[-1]), CELL * 0.6, 0.0, TAU, 24, ROUTE, 2.0)


## The three people with a manner, a small diamond at their place.
static func draw_people(canvas: CanvasItem, ground: ValleyMap, manners: Array[VillagerManner]) -> void:
	for manner: VillagerManner in manners:
		var at: Vector2 = corner(ground.cells_of(manner.where)[0]) + Vector2(CELL - 4, 4)
		canvas.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -4), at + Vector2(4, 0),
			at + Vector2(0, 4), at + Vector2(-4, 0)]), PERSON)


## Every villager, a disc with an initial; the followed one ringed.
static func draw_villagers(canvas: CanvasItem, villagers: Array[ValleyVillager], followed: int) -> void:
	var font: Font = ThemeDB.fallback_font
	for index: int in range(villagers.size()):
		var villager: ValleyVillager = villagers[index]
		var middle: Vector2 = centre(villager.cell)
		canvas.draw_circle(middle, CELL * 0.32, VILLAGER)
		if index == followed:
			canvas.draw_arc(middle, CELL * 0.42, 0.0, TAU, 24, FOLLOWED, 3.0)
		canvas.draw_string(font, middle + Vector2(-4, 4), villager.name.left(1),
			HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE, Color.BLACK)
