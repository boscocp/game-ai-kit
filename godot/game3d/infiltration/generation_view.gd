## The generation view (T95, key K): the constraint solver placing the
## level, replayed from its trace, so the person sees the decisions that
## built the level and not only the level (invariant 13).
##
## Drawn from above, as the radar is: the boxes placed so far grey, every
## other placed thing as a dot in its kind's colour. The variable chosen
## next -- by minimum remaining values -- has each of its candidate places
## drawn: white where still possible, a red cross where propagation crossed
## it out. Beside the map, every variable not yet placed with how many of
## its places remain, the chosen one first. A value undone by a backtrack is
## drawn as a red ring for a moment where it stood.
##
## The replay keeps the solver's own bookkeeping: an assignment saves the
## counts, an undo restores them, as the solver restores its domains.
##
## When not to use it: to see why a guard acts. The panel says that.
class_name GenerationView
extends Control

const BACK: Color = Color(0, 0, 0, 0.75)
const BOX: Color = Color(0.6, 0.6, 0.65)
const CHOSEN: Color = Color(1.0, 1.0, 1.0)
const CROSSED: Color = Color(1.0, 0.25, 0.25)
## Each kind of variable's colour, by its name's start.
const KINDS: Dictionary = {"lamp": Color(1.0, 0.9, 0.4), "hiding": Color(0.3, 0.8, 0.4), "patrol": Color(0.4, 0.7, 1.0),
	"sentry": Color(0.9, 0.5, 1.0)}
## How many steps of the trace are replayed a second.
const STEPS_A_SECOND: float = 60.0
## How long an undone value's ring stays drawn, in steps.
const UNDO_SHOWN: int = 40

var solved: LevelConstraints
var _step: float = 0.0
var _remaining: Dictionary = {}
var _crossed: Dictionary = {}
var _placed: Dictionary = {}
var _saved: Array[Array] = []
var _chosen: String = ""
var _undone: Array[Dictionary] = []
var _applied: int = 0
var _refused: Dictionary = {}


## Start replaying `level`'s trace from the beginning; null shows nothing.
func show_solving(level: LevelConstraints) -> void:
	solved = level
	_step = 0.0
	_applied = 0
	_saved.clear()
	_undone.clear()
	_placed.clear()
	_crossed.clear()
	_chosen = ""
	_refused = {}
	_remaining.clear()
	if level != null:
		for name: String in level.candidates:
			_remaining[name] = (level.candidates[name] as Array).size()
			_crossed[name] = {}
	queue_redraw()


## How far the replay has got, and how long it is: (step, steps).
func progress() -> Vector2i:
	return Vector2i(_applied, solved.solver.trace.size() if solved != null else 0)


func _process(delta: float) -> void:
	if solved == null or not visible:
		return
	_step = minf(_step + delta * STEPS_A_SECOND, solved.solver.trace.size())
	while _applied < int(_step):
		_apply(solved.solver.trace[_applied])
		_applied += 1
	queue_redraw()


# One step of the trace, kept as the solver kept it.
func _apply(event: Dictionary) -> void:
	var name: String = event["variable"]
	match event["event"]:
		"choose":
			_chosen = name
		"refuse":
			_refused = event
		"prune":
			_remaining[name] -= 1
			_crossed[name][event["value"]] = true
		"assign":
			_saved.append([_remaining.duplicate(), _crossed.duplicate(true)])
			_placed[name] = event["value"]
		"undo":
			var saved: Array = _saved.pop_back()
			_remaining = saved[0]
			_crossed = saved[1]
			_placed.erase(name)
			_undone.append({"variable": name, "value": event["value"], "at": _applied})


func _draw() -> void:
	if solved == null:
		return
	var map_size := Vector2(size.x * 0.7, size.y - 52.0)
	var scale_by: float = minf(map_size.x / solved.sketch.width, map_size.y / solved.sketch.depth)
	draw_rect(Rect2(Vector2.ZERO, size), BACK)
	var origin := Vector2(6, 22)
	for name: String in _placed:
		_draw_placed(name, _placed[name], origin, scale_by)
	_draw_choice(origin, scale_by)
	_draw_undone(origin, scale_by)
	draw_circle(origin + (Vector2(solved.sketch.start) + Vector2(0.5, 0.5)) * scale_by, 4.0, InfiltrationDrawing.PLAYER)
	draw_circle(origin + (Vector2(solved.sketch.exit_cell) + Vector2(0.5, 0.5)) * scale_by, 4.0, InfiltrationDrawing.EXIT)
	_draw_counts(Vector2(size.x * 0.72, 22))
	_draw_words()


# The solver's counts on top; the key and the last refusal at the bottom.
func _draw_words() -> void:
	var at: Vector2i = progress()
	var label: String = tr("solver: step {step} of {steps}, {assignments} assignments, {backtracks} backtracks, {restarts} fresh starts").format({
		step = at.x, steps = at.y, assignments = solved.solver.assignments, backtracks = solved.solver.backtracks,
		restarts = solved.restarts})
	var font: Font = ThemeDB.fallback_font
	draw_string(font, Vector2(6, 15), label, HORIZONTAL_ALIGNMENT_LEFT, size.x - 12, 12, Color.WHITE)
	var key: String = tr("white: still possible; red cross: crossed out; red ring: undone")
	draw_string(font, Vector2(6, size.y - 22), key, HORIZONTAL_ALIGNMENT_LEFT, size.x - 12, 12, Color.WHITE)
	if not _refused.is_empty():
		var refused: String = tr("refused: {thing}, {rule}").format({thing = _kind_word(_refused["variable"]),
			rule = tr(_refused["constraint"])})
		draw_string(font, Vector2(6, size.y - 6), refused, HORIZONTAL_ALIGNMENT_LEFT, size.x - 12, 12, CROSSED)


func _draw_placed(name: String, value: int, origin: Vector2, scale_by: float) -> void:
	var place: Variant = solved.candidates[name][value]
	if name.begins_with("box"):
		var block: AABB = LevelSketch.box_of(place)
		draw_rect(Rect2(origin + Vector2(block.position.x, block.position.z) * scale_by, Vector2(block.size.x, block.size.z) * scale_by), BOX)
		return
	draw_circle(origin + _centre(name, value) * scale_by, 3.5, _colour(name))


# The chosen variable's candidates: white still possible, a red cross gone.
func _draw_choice(origin: Vector2, scale_by: float) -> void:
	if _chosen == "":
		return
	for value: int in range((solved.candidates[_chosen] as Array).size()):
		var at: Vector2 = origin + _centre(_chosen, value) * scale_by
		if _crossed[_chosen].has(value):
			draw_line(at - Vector2(3, 3), at + Vector2(3, 3), CROSSED, 1.5)
			draw_line(at - Vector2(3, -3), at + Vector2(3, -3), CROSSED, 1.5)
		else:
			draw_arc(at, 3.0, 0.0, TAU, 12, CHOSEN, 1.5)


func _draw_undone(origin: Vector2, scale_by: float) -> void:
	for undone: Dictionary in _undone:
		if _applied - int(undone["at"]) <= UNDO_SHOWN:
			draw_arc(origin + _centre(undone["variable"], undone["value"]) * scale_by, 6.0, 0.0, TAU, 16, CROSSED, 2.0)


# Every variable not yet placed and how many places it has left, the chosen
# one first.
func _draw_counts(corner: Vector2) -> void:
	var waiting: Array = _remaining.keys().filter(func(name: String) -> bool: return not _placed.has(name))
	waiting.sort_custom(func(first: String, second: String) -> bool: return first == _chosen and second != _chosen)
	var line: float = corner.y
	for name: String in waiting.slice(0, int((size.y - corner.y) / 14.0)):
		var colour: Color = CHOSEN if name == _chosen else _colour(name)
		var count: String = tr("{thing}: {left} left").format({thing = _kind_word(name), left = _remaining[name]})
		draw_string(ThemeDB.fallback_font, Vector2(corner.x, line + 10), count, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, colour)
		line += 14.0


func _centre(name: String, value: int) -> Vector2:
	var place: Variant = solved.candidates[name][value]
	if place is Dictionary and place.has("x"):
		return Vector2(float(place["x"]), float(place["z"]))
	return Vector2(solved.cell_of(name, value)) + Vector2(0.5, 0.5)


func _colour(name: String) -> Color:
	for kind: String in KINDS:
		if name.begins_with(kind):
			return KINDS[kind]
	return BOX


# The variable's kind in the language on screen, and its number.
func _kind_word(name: String) -> String:
	var parts: PackedStringArray = name.split("_")
	match parts[0]:
		"box":
			return tr("box {number}").format({number = int(parts[1]) + 1})
		"lamp":
			return tr("lamp {number}").format({number = int(parts[1]) + 1})
		"hiding":
			return tr("hiding place {number}").format({number = int(parts[1]) + 1})
		"patrol":
			return tr("patrol {patrol}, point {point}").format({patrol = int(parts[1]) + 1, point = int(parts[2]) + 1})
	return tr("the sentry's post")
