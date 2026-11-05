## T25's meter in real time: each computer side's share of T19's frame
## budget, drawn beside its base while the match runs (T55).
##
## A side's thinking has two shares of the frame (`FrameBudget`): strategy
## and tactics, 2.5 ms together. Every decision the side times both into
## `RtsSide.timings` -- the counters `test/rts/rts_match.gd` holds to the
## shares -- and the meter reads those, nothing else, so the screen and the
## gate cannot disagree. Drawn per side: a bar of the mean of its last
## `WINDOW` decisions against the share, a tick at their 95th percentile,
## red once either is past it; and a line of the same decisions, so a spike
## can still be found after it has passed -- the commander replanning shows
## as one.
##
## Measuring costs something too: the meter times its own drawing and
## writes it apart, charged to no side -- the last frame's, since this one
## is still being drawn. The demo keeps it hidden until M asks.
##
## When not to use it: as a profiler. It shows what the sides' clocks said,
## on this machine, as T25's league table does.
class_name RtsMeter
extends Node2D

## Decisions shown: the last thirty, as T25 asks.
const WINDOW: int = 30
const BAR_SIZE := Vector2(96.0, 8.0)
const LINE_HEIGHT: float = 18.0
const FITS := Color(0.3, 0.9, 0.4)
const OVER := Color(1.0, 0.25, 0.2)
const BACK := Color(0.0, 0.0, 0.0, 0.6)
const LABEL := Color(1.0, 1.0, 1.0, 0.95)
## The share the meter holds a side to: strategy and tactics together.
const SHARE_MS: float = FrameBudget.SHARES[FrameBudget.STRATEGY] + FrameBudget.SHARES[FrameBudget.TACTICS]

## Side -> the RtsSide whose thinking is metered.
var sides: Dictionary = {}
## What the meter's own last drawing cost, in microseconds.
var own_microseconds: int = 0


## Each decision's strategy and tactics together, the last `WINDOW` of
## them, oldest first, in milliseconds.
static func recent_ms(side: RtsSide) -> Array[float]:
	var strategy: PackedInt64Array = side.timings[FrameBudget.STRATEGY]
	var tactics: PackedInt64Array = side.timings[FrameBudget.TACTICS]
	var count: int = mini(strategy.size(), tactics.size())
	var found: Array[float] = []
	for index: int in range(maxi(count - WINDOW, 0), count):
		found.append((strategy[index] + tactics[index]) / 1000.0)
	return found


## {mean, p95} of `values`, milliseconds; zeros for none.
static func summary(values: Array[float]) -> Dictionary:
	if values.is_empty():
		return {"mean": 0.0, "p95": 0.0}
	var sorted: Array[float] = values.duplicate()
	sorted.sort()
	var total: float = 0.0
	for value: float in values:
		total += value
	return {"mean": total / values.size(), "p95": sorted[mini(int(sorted.size() * 0.95), sorted.size() - 1)]}


func _draw() -> void:
	var started: int = Time.get_ticks_usec()
	for side: int in sides:
		_draw_side(side, sides[side])
	draw_string(ThemeDB.fallback_font, Vector2(8.0, RtsView.MAP_RECT.size.y - 8.0),
		tr("meter: {ms} ms to draw its last frame, charged to no side").format({ms = "%.2f" % (own_microseconds / 1000.0)}),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, LABEL)
	own_microseconds = Time.get_ticks_usec() - started


func _draw_side(side: int, thinking: RtsSide) -> void:
	var recent: Array[float] = recent_ms(thinking)
	var measured: Dictionary = summary(recent)
	var corner: Vector2 = _anchor(side)
	draw_rect(Rect2(corner - Vector2(4.0, 14.0), Vector2(BAR_SIZE.x + 8.0, LINE_HEIGHT * 2.0 + 24.0)), BACK)
	draw_string(ThemeDB.fallback_font, corner, tr("thinking {mean} ms, 95th {p95}, of {share}").format({
		mean = "%.2f" % measured["mean"], p95 = "%.2f" % measured["p95"], share = "%.1f" % SHARE_MS}),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, LABEL)
	var over: bool = measured["mean"] > SHARE_MS or measured["p95"] > SHARE_MS
	var bar_at: Vector2 = corner + Vector2(0.0, 6.0)
	draw_rect(Rect2(bar_at, BAR_SIZE), Color(1, 1, 1, 0.2))
	draw_rect(Rect2(bar_at, Vector2(BAR_SIZE.x * minf(measured["mean"] / SHARE_MS, 1.0), BAR_SIZE.y)), OVER if over else FITS)
	var tick_x: float = bar_at.x + BAR_SIZE.x * minf(measured["p95"] / SHARE_MS, 1.0)
	draw_line(Vector2(tick_x, bar_at.y - 2.0), Vector2(tick_x, bar_at.y + BAR_SIZE.y + 2.0), LABEL, 2.0)
	_draw_history(recent, bar_at + Vector2(0.0, BAR_SIZE.y + 4.0))


# The last decisions as a line, the share as the top of its box.
func _draw_history(recent: Array[float], top_left: Vector2) -> void:
	var height: float = LINE_HEIGHT
	draw_rect(Rect2(top_left, Vector2(BAR_SIZE.x, height)), Color(1, 1, 1, 0.25), false, 1.0)
	if recent.size() < 2:
		return
	var points := PackedVector2Array()
	for index: int in range(recent.size()):
		var x: float = top_left.x + BAR_SIZE.x * index / (WINDOW - 1)
		points.append(Vector2(x, top_left.y + height * (1.0 - minf(recent[index] / SHARE_MS, 1.0))))
	draw_polyline(points, LABEL, 1.0)


# Beside the side's home, held inside the map window when the camera is
# elsewhere, so the meter never scrolls out of sight.
func _anchor(side: int) -> Vector2:
	var home: Vector2 = RtsView.to_screen(Vector2(RtsScenario.home(side))) + Vector2(RtsView.CELL * 2.0, 0.0)
	var room: Vector2 = RtsView.MAP_RECT.size - Vector2(BAR_SIZE.x + 8.0, LINE_HEIGHT * 2.0 + 16.0)
	return Vector2(clampf(home.x, 8.0, room.x), clampf(home.y, 18.0, room.y))
