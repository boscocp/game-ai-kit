## How the door, the guard and his two numbers are drawn.
##
## Shapes only, no art: a door in its frame, Bram beside it, the player
## before him, and above them the two bars the rules move -- trust, with the
## mark that opens the door, and suspicion, with the mark that sounds the
## alarm. While the model is answering, three dots over Bram's head take
## turns to light: the game keeps drawing while he thinks (invariant 7).
##
## When not to use it: for anything a test reads. These are pictures.
class_name TalkView
extends RefCounted

const DOOR: Color = Color(0.45, 0.32, 0.22)
const FRAME: Color = Color(0.25, 0.25, 0.28)
const GUARD: Color = Color(0.3, 0.45, 0.75)
const PLAYER: Color = Color(0.85, 0.75, 0.45)
const THINKING: Color = Color(1.0, 1.0, 1.0)
const TRUST: Color = Color(0.35, 0.8, 0.45)
const SUSPICION: Color = Color(0.9, 0.3, 0.3)
const MARK: Color = Color(1.0, 1.0, 1.0)
const ALARM_LAMP: Color = Color(1.0, 0.15, 0.1)

## How wide one point of trust or suspicion is.
const POINT_WIDTH: float = 34.0
const BAR_HEIGHT: float = 16.0
## How long each of the three thinking dots stays lit, in seconds.
const DOT_SECONDS: float = 0.3


## The whole picture, at the canvas item's origin.
static func draw_scene(canvas: CanvasItem, state: Dictionary, thinking: bool, seconds: float) -> void:
	_draw_bar(canvas, Vector2(0, 0), TranslationServer.translate("trust"), int(state["trust"]),
		int(TalkRules.scene()["open_at"]), TRUST)
	_draw_bar(canvas, Vector2(0, 30), TranslationServer.translate("suspicion"), int(state["suspicion"]),
		int(TalkRules.scene()["alarm_at"]), SUSPICION)
	_draw_door(canvas, state["outcome"], seconds)
	_draw_person(canvas, Vector2(330, 250), GUARD)
	_draw_person(canvas, Vector2(140, 260), PLAYER)
	if thinking:
		_draw_thinking(canvas, Vector2(330, 120), seconds)


# A bar of `value` points out of room for a few past `mark`, the mark in white.
static func _draw_bar(canvas: CanvasItem, at: Vector2, label: String, value: int, mark: int,
		colour: Color) -> void:
	var left: float = at.x + 110.0
	var font: Font = ThemeDB.fallback_font
	canvas.draw_string(font, at + Vector2(0, BAR_HEIGHT - 2), label, HORIZONTAL_ALIGNMENT_LEFT, 105, 15)
	canvas.draw_rect(Rect2(left, at.y, POINT_WIDTH * (mark + 2), BAR_HEIGHT), Color(1, 1, 1, 0.1))
	canvas.draw_rect(Rect2(left, at.y, POINT_WIDTH * mini(value, mark + 2), BAR_HEIGHT), colour)
	var mark_x: float = left + POINT_WIDTH * mark
	canvas.draw_line(Vector2(mark_x, at.y - 4), Vector2(mark_x, at.y + BAR_HEIGHT + 4), MARK, 3.0)


# The door: shut, open (a dark gap and the panel swung aside), or shut under
# a blinking red lamp once the alarm sounds.
static func _draw_door(canvas: CanvasItem, outcome: String, seconds: float) -> void:
	var frame := Rect2(400, 80, 120, 180)
	canvas.draw_rect(frame.grow(8), FRAME)
	if outcome == TalkRules.OPEN:
		canvas.draw_rect(frame, Color(0.05, 0.05, 0.08))
		canvas.draw_rect(Rect2(frame.position, Vector2(18, frame.size.y)), DOOR)
	else:
		canvas.draw_rect(frame, DOOR)
		canvas.draw_circle(frame.position + Vector2(100, 100), 5, Color(0.8, 0.7, 0.3))
	if outcome == TalkRules.ALARM and fmod(seconds, 0.6) < 0.3:
		canvas.draw_circle(Vector2(560, 70), 12, ALARM_LAMP)


# A person: a head over a body, standing on `feet`.
static func _draw_person(canvas: CanvasItem, feet: Vector2, colour: Color) -> void:
	canvas.draw_rect(Rect2(feet + Vector2(-18, -80), Vector2(36, 80)), colour)
	canvas.draw_circle(feet + Vector2(0, -98), 17, colour)


# Three dots, one lit at a time, moving on every DOT_SECONDS.
static func _draw_thinking(canvas: CanvasItem, centre: Vector2, seconds: float) -> void:
	var lit: int = int(seconds / DOT_SECONDS) % 3
	for dot: int in 3:
		var alpha: float = 1.0 if dot == lit else 0.3
		canvas.draw_circle(centre + Vector2((dot - 1) * 16, 0), 5, Color(THINKING, alpha))
