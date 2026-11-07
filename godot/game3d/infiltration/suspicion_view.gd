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
		if variable == str(suspicion.spec["query"]):
			continue
		var mark: String = "> " if variable == suspicion.lead else "  "
		if evidence.has(variable):
			_text(row, mark + _sign_line(variable, evidence[variable], suspicion), SEEN_COLOUR if evidence[variable] == GuardSuspicion.SEEN else UNSEEN_COLOUR)
		else:
			_text(row, mark + InfiltrationWords.word(variable) + ": " + "%.2f" % float(suspicion.chances.get(variable, 0.0)), Color.WHITE)
		row += 1
	_text(row, last_line(suspicion), Color.WHITE)


## The last change as the view says it, or that nothing has changed yet.
static func last_line(suspicion: GuardSuspicion) -> String:
	var change: Dictionary = suspicion.last_change
	if change.is_empty():
		return TranslationServer.translate("last change: none yet")
	var key: String = LAST_SEEN if change["seen"] == GuardSuspicion.SEEN else LAST_NOT_SEEN
	return TranslationServer.translate(key).format({sign = InfiltrationWords.word(change["by"]),
		before = "%.2f" % float(change["from"]), after = "%.2f" % float(change["to"])})


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


# One sign: its name, seen or not, and what it did to the belief.
static func _sign_line(variable: String, value: String, suspicion: GuardSuspicion) -> String:
	var key: String = SIGN_SEEN if value == GuardSuspicion.SEEN else SIGN_NOT_SEEN
	return TranslationServer.translate(key).format({sign = InfiltrationWords.word(variable),
		moved = "%+.2f" % float(suspicion.moved.get(variable, 0.0))})


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
