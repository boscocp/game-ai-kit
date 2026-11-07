## Draws what blue is about to do, before it does it.
##
## A walk is a pink line along the route with a ring where it ends; an attack
## (T26) is a dashed line from the attacker to its target, with a cross on the
## target; a build is a pink square where the new unit will stand; a hold is a
## ring round the piece that is staying put; a purchase at the workshop (the
## planner's forge, T11) is a diamond round the workshop, so it never reads as
## a hold. Pink because the checkers board already taught
## that pink is "the move the computer will play".
##
## A planning controller's plan (T11) is drawn under the decision: each piece
## a step of the plan counts on gets a small numbered tag, the step's number,
## so the board shows who the plan is waiting for and in what order.
##
## Under everything, the threat map (T48): a red tint on each cell the side
## not moving could strike next turn, and the number of its pieces that
## could, so the danger a decision weighs is on the board. T hides it. In a
## mode whose tint is a hit chance, the chance is written with its `%` in
## the cell's top-right corner, the one corner a piece's own numbers leave
## free (T137): bottom-right, beside the piece's id, the two read as one.
##
## The XCOM-style mode (T85) draws four more things here. The fog: every cell
## the side whose view is shown cannot see, darkened, and a faded picture of
## each enemy where it was last seen. The dash: the cells the piece in hand
## would reach only by spending its whole turn, in a second tint over the
## board's own. The odds: on each enemy the piece in hand may shoot, its hit
## chance. And the weighing: on every cell or target the computer weighed for
## the piece about to act, its score above and its best hit chance below,
## the one it took ringed.
##
## When not to use it: to draw the person's own intentions -- where they
## mean to walk, whom they mean to strike. What it draws on the person's
## turn is what the rules say about the piece in hand (the dash, the odds)
## and the danger round it, never a guess at the person's plan.
class_name IntentView
extends Node2D

const INTENT: Color = Color(1.0, 0.40, 0.85, 0.95)
const WIDTH: float = 4.0
const RING: float = 20.0

const TAG: float = 16.0
## The tint on a threatened cell: red, light enough to read the ground under it.
const THREAT: Color = Color(0.95, 0.15, 0.10, 0.22)
## A cell the side shown cannot see: dark, with the ground still showing.
const FOG: Color = Color(0.02, 0.03, 0.08, 0.62)
## A remembered enemy, where it was last seen: its picture, faded.
const GHOST: Color = Color(1.0, 1.0, 1.0, 0.38)
## A cell the piece in hand reaches only by dashing: amber over the reach.
const DASH: Color = Color(1.0, 0.62, 0.15, 0.38)
## A hit chance on a target, and a weighed option's numbers: white on black.
const LABEL: Color = Color.WHITE
const LABEL_GROUND: Color = Color(0.0, 0.0, 0.0, 0.72)
const LABEL_SIZE: int = 12
## The threat map's count, from the cell's top-left: bottom-right, where the
## Advance Wars mode has always drawn it.
const COUNT_AT: Vector2 = Vector2(BoardView.TILE_PIXELS - 12.0, BoardView.TILE_PIXELS - 4.0)
## The gap between a hit chance and the cell's right edge; its baseline is
## the health's, on the top row (`UnitView.HEALTH_AT`).
const CHANCE_MARGIN: float = 2.0
## The tint's numbers, in the threat's own pale red.
const THREAT_TEXT: Color = Color(1.0, 0.85, 0.85)

var _decision: TacticalDecision
var _state: BoardState
var _board: BoardView
var _plan_marks: Dictionary[Vector2i, String] = {}
var _threat: Dictionary[Vector2i, int] = {}
var _threat_is_chance: bool = false
var _fog: TacticalFog
var _dashes: Array[Vector2i] = []
var _odds: Dictionary[Vector2i, String] = {}
var _weighed: Array[Dictionary] = []


## Draw `decision`, or nothing when it is null.
func show_decision(decision: TacticalDecision, state: BoardState, board: BoardView) -> void:
	_decision = decision
	_state = state
	_board = board
	queue_redraw()


## Tint each cell of `threat` -- `ThreatMap.of` -- and write its count;
## empty draws none. `as_chance` writes each number as a hit chance instead,
## "55%" in the top-right corner, clear of the piece's id (T137).
func show_threat(threat: Dictionary[Vector2i, int], as_chance: bool = false) -> void:
	_threat = threat
	_threat_is_chance = as_chance
	queue_redraw()


## What the tint writes on `cell` and where: `words`, and the left end of
## their `baseline` on the board. One place for `_draw_threat` and for a
## test that holds the words clear of the piece's numbers.
func tint_label(cell: Vector2i) -> Dictionary:
	var corner: Vector2 = _board.centre_of(cell) - Vector2(BoardView.TILE_PIXELS, BoardView.TILE_PIXELS) / 2.0
	if not _threat_is_chance:
		return {"words": str(_threat[cell]), "baseline": corner + COUNT_AT}
	var words: String = "%d%%" % _threat[cell]
	return {"words": words, "baseline": _board.centre_of(cell) + chance_at(words)}


## Where a hit chance of `words` starts, from its cell's centre: on the
## health's row, ending `CHANCE_MARGIN` short of the right edge, so a "100%"
## and a "5%" both end in the same place.
static func chance_at(words: String) -> Vector2:
	var width: float = ThemeDB.fallback_font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, UnitView.CORNER_TEXT_SIZE).x
	return Vector2(BoardView.TILE_PIXELS / 2.0 - CHANCE_MARGIN - width, UnitView.HEALTH_AT.y)


## Tag each cell of `marks` with its plan step number; empty draws none.
func show_plan(marks: Dictionary[Vector2i, String]) -> void:
	_plan_marks = marks
	queue_redraw()


## Darken what `fog`'s side cannot see and draw its ghosts; null draws none.
func show_fog(fog: TacticalFog) -> void:
	_fog = fog
	queue_redraw()


## Tint each of `cells` as a dash; empty draws none.
func show_dashes(cells: Array[Vector2i]) -> void:
	_dashes = cells
	queue_redraw()


## Write each label of `odds` on its cell, a target's hit chance; empty
## draws none.
func show_odds(odds: Dictionary[Vector2i, String]) -> void:
	_odds = odds
	queue_redraw()


## Write each weighed option's score and hit chance on its cell, as
## `BlueController.weighed` gives them; empty draws none.
func show_weighed(options: Array[Dictionary]) -> void:
	_weighed = options
	queue_redraw()


func _draw() -> void:
	_draw_fog()
	_draw_threat()
	_draw_dashes()
	_draw_weighed()
	_draw_odds()
	_draw_plan()
	if _decision == null or _board == null:
		return
	match _decision.kind():
		"move":
			_draw_walk()
		"attack":
			_draw_attack()
		"buy":
			_draw_purchase()
		"build":
			var side: float = BoardView.TILE_PIXELS - 8.0
			var corner: Vector2 = _board.centre_of(_decision.target) - Vector2(side, side) / 2.0
			draw_rect(Rect2(corner, Vector2(side, side)), INTENT, false, WIDTH)
		_:
			draw_arc(_board.centre_of(_decision.target), RING, 0.0, TAU, 32, INTENT, WIDTH)


# A red tint over every threatened cell, and its number where `tint_label`
# puts it: a count bottom-right, a chance top-right and outlined, as the
# piece's own numbers are, so it reads over the picture.
func _draw_threat() -> void:
	if _board == null:
		return
	var font: Font = ThemeDB.fallback_font
	var side: float = BoardView.TILE_PIXELS
	for cell: Vector2i in _threat:
		var corner: Vector2 = _board.centre_of(cell) - Vector2(side, side) / 2.0
		draw_rect(Rect2(corner, Vector2(side, side)), THREAT)
		var label: Dictionary = tint_label(cell)
		if _threat_is_chance:
			draw_string_outline(font, label["baseline"], label["words"], HORIZONTAL_ALIGNMENT_LEFT, -1, UnitView.CORNER_TEXT_SIZE, 4, Color.BLACK)
		draw_string(font, label["baseline"], label["words"], HORIZONTAL_ALIGNMENT_LEFT, -1, UnitView.CORNER_TEXT_SIZE, THREAT_TEXT)


# Every hidden cell darkened, and over the dark a faded picture of each enemy
# remembered there, with a question mark: it may have gone.
func _draw_fog() -> void:
	if _board == null or _fog == null:
		return
	var side: float = BoardView.TILE_PIXELS
	for cell: Vector2i in _fog.hidden:
		draw_rect(Rect2(_board.centre_of(cell) - Vector2(side, side) / 2.0, Vector2(side, side)), FOG)
	var enemy: int = TacticalScenario.FACTIONS - 1 - _fog.side
	for cell: Vector2i in _fog.ghosts:
		var square := Rect2(_board.centre_of(cell) - Vector2(side, side) * 0.35, Vector2(side, side) * 0.7)
		draw_texture_rect(Art.texture(Art.unit_path(enemy, _fog.ghosts[cell])), square, false, GHOST)
		_label(_board.centre_of(cell) + Vector2(side * 0.25, -side * 0.2), "?")


func _draw_dashes() -> void:
	if _board == null:
		return
	var side: float = BoardView.TILE_PIXELS
	for cell: Vector2i in _dashes:
		draw_rect(Rect2(_board.centre_of(cell) - Vector2(side, side) / 2.0, Vector2(side, side)), DASH)


# A target's chance, low in its cell, under the piece's picture.
func _draw_odds() -> void:
	if _board == null:
		return
	for cell: Vector2i in _odds:
		_label(_board.centre_of(cell) + Vector2(0.0, BoardView.TILE_PIXELS * 0.32), _odds[cell])


# The score high in the cell and the best chance from it low, and a ring
# round the option taken: every option drawn the same way, so a reader
# compares numbers rather than marks.
func _draw_weighed() -> void:
	if _board == null:
		return
	var side: float = BoardView.TILE_PIXELS
	for option: Dictionary in _weighed:
		var centre: Vector2 = _board.centre_of(option["cell"])
		_label(centre - Vector2(0.0, side * 0.3), "%.2f" % option["score"])
		if int(option["chance"]) >= 0:
			_label(centre + Vector2(0.0, side * 0.32), "%d%%" % option["chance"])
		if option["chosen"]:
			draw_rect(Rect2(centre - Vector2(side, side) / 2.0 + Vector2(2.0, 2.0), Vector2(side - 4.0, side - 4.0)), INTENT, false, 2.0)


# `words` centred on `at`, on a dark ground so it reads over any picture.
func _label(at: Vector2, words: String) -> void:
	var font: Font = ThemeDB.fallback_font
	var size: Vector2 = font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE)
	var corner: Vector2 = at - Vector2(size.x / 2.0, size.y / 2.0)
	draw_rect(Rect2(corner - Vector2(2.0, 0.0), size + Vector2(4.0, 0.0)), LABEL_GROUND)
	draw_string(font, corner + Vector2(0.0, size.y - 3.0), words, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, LABEL)


# A filled square in the tile's top-left corner, with the step's number in it.
func _draw_plan() -> void:
	if _board == null:
		return
	var font: Font = ThemeDB.fallback_font
	for cell: Vector2i in _plan_marks:
		var corner: Vector2 = _board.centre_of(cell) - Vector2(BoardView.TILE_PIXELS, BoardView.TILE_PIXELS) / 2.0 + Vector2(2.0, 2.0)
		draw_rect(Rect2(corner, Vector2(TAG, TAG)), INTENT)
		draw_string(font, corner + Vector2(3.0, TAG - 3.0), _plan_marks[cell], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.BLACK)


# A diamond round the workshop: something bought there, not a unit placed.
func _draw_purchase() -> void:
	var centre: Vector2 = _board.centre_of(_decision.target)
	var reach: float = RING + 4.0
	var corners: Array[Vector2] = [Vector2(0, -reach), Vector2(reach, 0), Vector2(0, reach), Vector2(-reach, 0), Vector2(0, -reach)]
	var points := PackedVector2Array()
	for corner: Vector2 in corners:
		points.append(centre + corner)
	draw_polyline(points, INTENT, WIDTH)


# Who strikes whom: dashed, so it is never read as a walk, from the attacker
# to a cross on the target -- a ring alone looked exactly like a hold.
func _draw_attack() -> void:
	var unit: Unit = _state.unit_by_id(_decision.unit_id)
	var target: Vector2 = _board.centre_of(_decision.target)
	if unit != null:
		draw_dashed_line(_board.centre_of(unit.cell), target, INTENT, WIDTH, 8.0)
	var arm: Vector2 = Vector2(RING, RING) * 0.6
	draw_line(target - arm, target + arm, INTENT, WIDTH)
	draw_line(target + Vector2(arm.x, -arm.y), target + Vector2(-arm.x, arm.y), INTENT, WIDTH)


func _draw_walk() -> void:
	var unit: Unit = _state.unit_by_id(_decision.unit_id)
	if unit == null:
		return
	var points := PackedVector2Array([_board.centre_of(unit.cell)])
	for cell: Vector2i in _decision.move.path:
		points.append(_board.centre_of(cell))
	draw_polyline(points, INTENT, WIDTH)
	draw_arc(points[points.size() - 1], RING, 0.0, TAU, 32, INTENT, WIDTH)
