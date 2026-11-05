## The clock's two knobs on T25's human-likeness axis, put on any RTS side:
## a reaction delay and a cap on actions. Both are limits, never gifts.
##
## It wraps a controller the way `MeteredTeam` wraps a tactical team: the
## same side, asked the same questions, with two things a person cannot do
## taken away from it.
##
## - `reaction_ms`: the enemy reaches the decision only this late. The
##   side is handed its own units, funds and room as they are now, and the
##   enemy as the newest snapshot at least this old showed it -- where they
##   stood then, and nothing seen since. So an answer to a raid comes at
##   least this long after the raid came into sight. Only the enemy is
##   held back: holding back the side's own state as well was tried first,
##   and a side that did not yet see its last worker in training trained
##   another, and earned more than without the clock -- a gift. A snapshot
##   is taken only when the match asks for a decision
##   (`RtsMatch.decide_every`, half a second), so the delay is served in
##   whole decisions: 350 ms shows the enemy of the previous one.
## - `most_actions` in `window_seconds`: at most that many commands in any
##   such window. A command over the cap waits in a queue, oldest first, for
##   the window to make room; one still waiting when the queue is longer
##   than the cap is dropped, since a person who cannot keep up does not do
##   the old things later, they do not do them. 0 is no cap.
##
## Every enemy handed on is one the world showed this side, and every
## command is one the inner side gave, through the same door
## (`RtsMatch.give`), so the wrapped side sees, earns and may order nothing
## it would not have without the clock: later, or less. `test/league/rts_league.gd` measures that over its seeds.
##
## The reference values are read from `REFERENCE_PATH`, a committed file
## that `make measure-rts-clock` writes from the owner's recordings in
## `data/rts/` (`RtsClockMeasure`). Nothing is measured at game time: a
## five-minute recording takes seconds to replay, and the values a game
## plays by are fixed before it starts, as invariant 6 asks of anything
## learned. Until the file exists, `stand_in()` gives AlphaStar's published
## figures, and says so wherever it is shown.
##
## When not to use it: to make a side weaker. That is T12's strength axis
## (`RtsLevels`); this one changes how a side looks, and costs strength only
## as a side effect, which the league measures.
class_name RtsHumanClock
extends GakRtsController

## AlphaStar "reacts with a delay between observation and action of 350ms
## on average" (DeepMind, January 2019,
## https://deepmind.google/discover/blog/alphastar-mastering-the-real-time-strategy-game-starcraft-ii/).
const STAND_IN_REACTION_MS: float = 350.0
## AlphaStar's cap, "22 agent actions per 5 seconds" (DeepMind, 2019), as
## T25 quotes it. An action there is a click; here it is a command.
const STAND_IN_ACTIONS: int = 22
const STAND_IN_WINDOW_SECONDS: float = 5.0
## Where `make measure-rts-clock` writes the owner's values.
const REFERENCE_PATH: String = "res://game/rts/clock_reference.json"
const STAND_IN_SOURCE: String = "stand-in: AlphaStar's published limits, no recording of the owner yet"  # not shown: the league runner prints it

var inner: GakRtsController
var reaction_ms: float
var most_actions: int
var window_seconds: float
## How often a command was still held at the end of a decision, waiting
## for room under the cap (one command held over three decisions counts
## three), and commands dropped because the queue outgrew it.
var delayed: int = 0
var dropped: int = 0
## Decisions handed the enemy of an earlier view: every one, while the
## delay is on.
var stale: int = 0

# The knobs' values once read.
static var _known: Dictionary = {}

# Snapshots not yet old enough to hand on, oldest first, and the newest
# that is.
var _waiting: Array[RtsSnapshot] = []
var _ripe: RtsSnapshot = null
# Commands held under the cap, oldest first, the tick each was given by
# the inner side, and the ticks of those let through.
var _held: Array[RtsCommand] = []
var _held_at: Array[int] = []
var _given_at: Array[int] = []
# The view last handed to the inner side, the tick it was handed at, and
# the tick of the snapshot its enemy came from (-1: none was old enough).
var _handed: RtsSnapshot = null
var _handed_at: int = -1
var _enemy_from: int = -1


## `wrapped` with the delay `delay_ms` and at most `actions` commands in any
## `window` seconds (0 actions: no cap).
func _init(wrapped: GakRtsController, delay_ms: float, actions: int, window: float = STAND_IN_WINDOW_SECONDS) -> void:
	inner = wrapped
	reaction_ms = delay_ms
	most_actions = actions
	window_seconds = window


## `wrapped` with both knobs at `reference`: {reaction_ms, most_actions,
## window_seconds}, as `knob_values()` gives them.
static func at(wrapped: GakRtsController, reference: Dictionary) -> RtsHumanClock:
	return RtsHumanClock.new(wrapped, reference["reaction_ms"], reference["most_actions"], reference["window_seconds"])


## AlphaStar's figures, labelled as a stand-in.
static func stand_in() -> Dictionary:
	return {"reaction_ms": STAND_IN_REACTION_MS, "most_actions": STAND_IN_ACTIONS,
		"window_seconds": STAND_IN_WINDOW_SECONDS, "source": STAND_IN_SOURCE}


## The knobs' values: `REFERENCE_PATH` when it holds them, else
## `stand_in()`. Read once and kept, so a screen may ask every frame.
static func knob_values() -> Dictionary:
	if _known.is_empty():
		_known = from_file(REFERENCE_PATH)
	return _known


## The knobs' values in the file at `path`, or `stand_in()` when it is
## missing or does not hold all four.
static func from_file(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	if not parsed is Dictionary:
		return stand_in()
	for key: String in ["reaction_ms", "most_actions", "window_seconds", "source"]:
		if not (parsed as Dictionary).has(key):
			return stand_in()
	var values: Dictionary = parsed
	values["most_actions"] = int(values["most_actions"])
	return values


## The inner side's commands for `view` with the enemy held back, let
## through as the cap allows.
func decide(view: RtsSnapshot) -> Array[RtsCommand]:
	_waiting.append(view)
	var old_enough: int = view.tick - roundi(reaction_ms / 1000.0 * RtsWorld.TICKS_PER_SECOND)
	while not _waiting.is_empty() and _waiting[0].tick <= old_enough:
		_ripe = _waiting.pop_front()
	var handed: RtsSnapshot = view if _ripe == view else _late(view, _ripe)
	if handed != view:
		stale += 1
	_handed = handed
	_handed_at = view.tick
	_enemy_from = _ripe.tick if _ripe != null else -1
	inner.work = 0
	var wanted: Array[RtsCommand] = inner.decide(handed)
	_held.append_array(wanted)
	for _command: RtsCommand in wanted:
		_held_at.append(view.tick)
	work = inner.work
	return _let_through(view.tick)


## The view the inner side was last handed, or null before its first
## decision: its own side now, and the enemy where the side believes it.
## The thinking overlay draws this one, so it cannot show a view the side
## did not get (T118). Read-only, as every snapshot is.
func last_handed() -> RtsSnapshot:
	return _handed


## How old the enemy in `last_handed()` was when it was handed, in ms: from
## the snapshot it came from to the decision. -1 when no snapshot was old
## enough yet, so the side was handed no enemy at all.
func enemy_age_ms() -> float:
	if _handed == null or _enemy_from < 0:
		return -1.0
	return float(_handed_at - _enemy_from) * 1000.0 / RtsWorld.TICKS_PER_SECOND


## The commands held for room under the cap after the last decision: how
## many, and how long the oldest had waited then, in ms. A person watching
## the side wait can see what it is waiting with.
func waiting() -> Dictionary:
	if _held.is_empty():
		return {"count": 0, "oldest_ms": 0.0}
	return {"count": _held.size(),
		"oldest_ms": float(_handed_at - _held_at[0]) * 1000.0 / RtsWorld.TICKS_PER_SECOND}


## `now` with its enemy as `then` showed it: own units, funds and room from
## `now`; every other side's units from `then`, none at all when `then` is
## null; an own unit's target forgotten (0, no target) when it names an
## enemy the late view does not show, since a unit that has just turned on
## a raider would tell of the raid early; and the board with the cell of
## each enemy building seen since `then` as `then` had it, so a blocked
## cell does not tell of it either.
static func _late(now: RtsSnapshot, then: RtsSnapshot) -> RtsSnapshot:
	var late := RtsSnapshot.new()
	late.side = now.side
	late.tick = now.tick
	late.resources = now.resources
	late.supply_used = now.supply_used
	late.supply_cap = now.supply_cap
	late.graph = now.graph.duplicate_graph()
	var shown: Dictionary = {}
	var enemies: Array[Dictionary] = then.enemies() if then != null else ([] as Array[Dictionary])
	for unit: Dictionary in enemies:
		shown[unit["id"]] = true
	for unit: Dictionary in now.units:
		if unit["side"] == now.side or unit["side"] == RtsWorld.NEUTRAL:
			shown[unit["id"]] = true
	for unit: Dictionary in now.units:
		if unit["side"] == now.side or unit["side"] == RtsWorld.NEUTRAL:
			late.units.append(_unaware(unit, shown))
	late.units.append_array(enemies)
	_unblock_unseen(late.graph, now, then, shown)
	late.units.sort_custom(func(one: Dictionary, other: Dictionary) -> bool: return one["id"] < other["id"])
	late.units.make_read_only()
	return late


# `unit` as shown late: its target forgotten when it is not in `shown`.
static func _unaware(unit: Dictionary, shown: Dictionary) -> Dictionary:
	if int(unit.get("target", 0)) == 0 or shown.has(unit["target"]):
		return unit
	var forgot: Dictionary = unit.duplicate()
	forgot["target"] = 0
	forgot.make_read_only()
	return forgot


# The cell of each enemy building `now` shows and `shown` does not, given
# the cost `then` had there.
static func _unblock_unseen(graph: GakGridGraph, now: RtsSnapshot, then: RtsSnapshot, shown: Dictionary) -> void:
	for unit: Dictionary in now.enemies():
		if not shown.has(unit["id"]) and RtsKinds.is_building(unit["kind"]):
			var cell := Vector2i((unit["position"] as Vector2).floor())
			graph.set_cost(cell, then.graph.cost_at(cell) if then != null else GakGridGraph.DEFAULT_COST)


## The inner side, which reads its own thinking for the screen.
func thinking() -> GakRtsController:
	return inner


# As many held commands as the window has room for, oldest first; what is
# still held beyond one window's worth is dropped.
func _let_through(now: int) -> Array[RtsCommand]:
	if most_actions <= 0:
		var all: Array[RtsCommand] = _held.duplicate()
		_held.clear()
		_held_at.clear()
		return all
	var window_ticks: int = roundi(window_seconds * RtsWorld.TICKS_PER_SECOND)
	_given_at.assign(_given_at.filter(func(tick: int) -> bool: return tick > now - window_ticks))
	var given: Array[RtsCommand] = []
	while not _held.is_empty() and _given_at.size() < most_actions:
		given.append(_held.pop_front())
		_held_at.pop_front()
		_given_at.append(now)
	delayed += _held.size()
	while _held.size() > most_actions:
		_held.pop_front()
		_held_at.pop_front()
		dropped += 1
	return given
