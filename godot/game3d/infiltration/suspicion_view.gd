## The watched guard's intruder network on the infiltration HUD (T115): is
## anyone there at all, the chance of each hidden variable, each sign seen
## or not with what it did to the belief, the lead -- the sign seen that
## raised it most, the one a guard checking the evidence walks to -- marked
## `>`, and the last change: which sign, and the belief before and after.
## Signs and numbers both come from the guard's last question (`asked`), so
## they cannot disagree for a step.
##
## The bar is the belief, the tick on it the threshold where checking the
## evidence starts, read from the action's own consideration in
## guard_actions.json, so the bar and the decision cannot disagree. Every
## number is the one `GuardSuspicion` holds: the view asks nothing itself
## (invariant 13).
##
## On a crowded level (T152) two rows more: the figure the guard's eye
## picked out of a group, blending in or standing out, with what it did to
## the belief; and where you stand in the crowd -- the group you are counted
## in, why you blend in or stand out, and what the watched guard's eye and
## ear were left with once the crowd weighed them. On the other levels neither row is drawn.
##
## When not to use it: for where the player is. That is the belief map.
class_name SuspicionView
extends Control

const BACK: Color = Color(0, 0, 0, 0.6)
const BAR: Color = Color(0.95, 0.55, 0.15)
const TICK: Color = Color(1, 1, 1, 0.9)
const SEEN_COLOUR: Color = Color(1.0, 0.85, 0.3)
const UNSEEN_COLOUR: Color = Color(0.75, 0.75, 0.75)
const LINE: float = 16.0
const BAR_HEIGHT: float = 6.0
## The action that reads the belief, and the percept it reads it as.
const CHECKING: String = "check the evidence"  # not shown: an identifier
const PERCEPT: String = "intruder"  # not shown: an identifier
## The view's sentences, as keys: a sign seen or not, the last change.
const SIGN_SEEN: String = "{sign}: seen, {moved}"  # shown through tr()
const SIGN_NOT_SEEN: String = "{sign}: not seen, {moved}"  # shown through tr()
const LAST_SEEN: String = "last change: {sign} seen, {before} to {after}"  # shown through tr()
const LAST_NOT_SEEN: String = "last change: {sign} not seen, {before} to {after}"  # shown through tr()
## The crowd's rows (T152): the figure picked out, how it reads; and you.
const FIGURE_READ: String = "{sign}: {reading}, {moved}"  # shown through tr()
const FIGURE_NONE: String = "{sign}: no one picked out"  # shown through tr()
const LAST_FIGURE: String = "last change: {sign} {reading}, {before} to {after}"  # shown through tr()
const IN_GROUP: String = "you: in group {group}, ringed: {reason}; its eye {certainty}, its ear {loudness}"  # shown through tr()
const NO_GROUP: String = "you: in no group; its eye {certainty}, its ear {loudness}"  # shown through tr()
## How tall the view is, without a crowd and with one.
const HEIGHT: float = 112.0
const CROWDED_HEIGHT: float = 144.0

var world: InfiltrationWorld
var watched: int = 0
var thinking: bool = true


func _draw() -> void:
	if world == null or not thinking or world.guards.is_empty():
		return
	var guard: InfiltrationGuard = world.guard(watched)
	var suspicion: GuardSuspicion = guard.suspicion
	draw_rect(Rect2(Vector2.ZERO, size), BACK)
	var title: String = tr("is anyone there? guard {guard}: {chance}").format({guard = guard.id, chance = "%.2f" % suspicion.belief})
	_text(0, title, Color.WHITE)
	_draw_bar(suspicion.belief)
	var row: int = 1
	var evidence: Dictionary = suspicion.asked
	for variable: String in suspicion.network.names:
		if variable == str(suspicion.spec["query"]) or (_is_figure(suspicion, variable) and world.crowd == null):
			continue
		var mark: String = "> " if variable == suspicion.lead else "  "
		if evidence.has(variable):
			_text(row, mark + _sign_line(variable, evidence[variable], suspicion), UNSEEN_COLOUR if evidence[variable] == GuardSuspicion.NOT_SEEN else SEEN_COLOUR)
		elif _is_figure(suspicion, variable):
			_text(row, mark + TranslationServer.translate(FIGURE_NONE).format({sign = InfiltrationWords.word(variable)}), UNSEEN_COLOUR)
		else:
			_text(row, mark + InfiltrationWords.word(variable) + ": " + "%.2f" % float(suspicion.chances.get(variable, 0.0)), Color.WHITE)
		row += 1
	if world.crowd != null:
		_text(row, crowd_line(world.crowd.cover, guard), Color.WHITE)
		row += 1
	_text(row, last_line(suspicion), Color.WHITE)


## Where you stand in the crowd, as the view says it: the group you are
## counted in and why you blend in or stand out, or no group; and what
## `guard`'s percept was left with this step, weighed: its eye's certainty
## and how loud it heard you, "-" for nothing seen or heard.
static func crowd_line(cover: InfiltrationCrowd.Cover, guard: InfiltrationGuard) -> String:
	var certainty: String = "%.2f" % guard.percept.sight.certainty if guard.percept.sight.perceived() else "-"
	var loudness: String = "%.2f" % guard.percept.loudness if guard.percept.loudness > 0.0 else "-"
	if cover.group == -1:
		return TranslationServer.translate(NO_GROUP).format({certainty = certainty, loudness = loudness})
	return TranslationServer.translate(IN_GROUP).format({group = cover.group + 1,
		reason = TranslationServer.translate(cover.reason), certainty = certainty, loudness = loudness})


# True when `variable` is the crowd's figure sign in `suspicion`'s file.
static func _is_figure(suspicion: GuardSuspicion, variable: String) -> bool:
	return suspicion.spec.has("crowd") and variable == str(suspicion.spec["crowd"]["variable"])


## The last change as the view says it, or that nothing has changed yet.
static func last_line(suspicion: GuardSuspicion) -> String:
	var change: Dictionary = suspicion.last_change
	if change.is_empty():
		return TranslationServer.translate("last change: none yet")
	var key: String = LAST_SEEN if change["seen"] == GuardSuspicion.SEEN else LAST_NOT_SEEN
	var reading: String = str(change["seen"])
	if reading not in [GuardSuspicion.SEEN, GuardSuspicion.NOT_SEEN, ""]:
		key = LAST_FIGURE
	return TranslationServer.translate(key).format({sign = InfiltrationWords.word(change["by"]),
		reading = InfiltrationWords.word(reading), before = "%.2f" % float(change["from"]), after = "%.2f" % float(change["to"])})


## Where checking the evidence starts: the step of `actions`' checking
## action on the belief; 1 when no action reads it.
static func threshold(actions: Array[ActionChoice.Action]) -> float:
	for action: ActionChoice.Action in actions:
		if action.name == CHECKING:
			return _step_on_belief(action)
	return 1.0


static func _step_on_belief(action: ActionChoice.Action) -> float:
	for consideration: ActionChoice.Consideration in action.considerations:
		if consideration.percept == PERCEPT:
			return consideration.at
	return 1.0


# One sign: its name, seen or not -- or the figure's reading -- and what it
# did to the belief.
static func _sign_line(variable: String, value: String, suspicion: GuardSuspicion) -> String:
	var key: String = SIGN_SEEN if value == GuardSuspicion.SEEN else SIGN_NOT_SEEN
	if value not in [GuardSuspicion.SEEN, GuardSuspicion.NOT_SEEN]:
		key = FIGURE_READ
	return TranslationServer.translate(key).format({sign = InfiltrationWords.word(variable),
		reading = InfiltrationWords.word(value), moved = "%+.2f" % float(suspicion.moved.get(variable, 0.0))})


# The belief as a bar under the title, the threshold a tick across it.
func _draw_bar(belief: float) -> void:
	var corner := Vector2(6, 19)
	var length: float = size.x - 12
	draw_rect(Rect2(corner, Vector2(length, BAR_HEIGHT)), Color(1, 1, 1, 0.15))
	draw_rect(Rect2(corner, Vector2(length * clampf(belief, 0.0, 1.0), BAR_HEIGHT)), BAR)
	var tick: float = corner.x + length * threshold(world.actions)
	draw_line(Vector2(tick, corner.y - 2), Vector2(tick, corner.y + BAR_HEIGHT + 2), TICK, 2.0)


# Line `row` of the view; the rows under the bar start below it.
func _text(row: int, line: String, colour: Color) -> void:
	var height: float = 14 + LINE * row + (BAR_HEIGHT + 4 if row > 0 else 0.0)
	draw_string(ThemeDB.fallback_font, Vector2(6, height), line, HORIZONTAL_ALIGNMENT_LEFT, size.x - 12, 12, colour)
