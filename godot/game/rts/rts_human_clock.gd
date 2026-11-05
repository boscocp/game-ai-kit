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
## The reference values are the owner's recorded play (`RtsClockMeasure`)
## when there is any in `data/rts/`. Until there is, `stand_in()` gives
## AlphaStar's published figures, and says so wherever it is shown.
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

# Snapshots not yet old enough to hand on, oldest first, and the newest
# that is.
var _waiting: Array[RtsSnapshot] = []
var _ripe: RtsSnapshot = null
# Commands held under the cap, oldest first, and the ticks of those given.
var _held: Array[RtsCommand] = []
var _given_at: Array[int] = []


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


## The knobs' values: measured from the owner's recordings in `data/rts/`
## when there are any (`RtsClockMeasure.measured_from`), else `stand_in()`.
static func knob_values() -> Dictionary:
	var measured: Dictionary = RtsClockMeasure.measured_from(RtsClockMeasure.directory())
	return measured if not measured.is_empty() else stand_in()


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
	inner.work = 0
	_held.append_array(inner.decide(handed))
	work = inner.work
	return _let_through(view.tick)


## `now` with its enemy as `then` showed it: own units, funds and room from
## `now`; every other side's units from `then`, none at all when `then` is
## null; and the board with the cell of each enemy building seen since
## `then` as `then` had it, so a blocked cell does not tell of it early.
static func _late(now: RtsSnapshot, then: RtsSnapshot) -> RtsSnapshot:
	var late := RtsSnapshot.new()
	late.side = now.side
	late.tick = now.tick
	late.resources = now.resources
	late.supply_used = now.supply_used
	late.supply_cap = now.supply_cap
	late.graph = now.graph.duplicate_graph()
	var known: Dictionary = {}
	for unit: Dictionary in now.units:
		if unit["side"] == now.side or unit["side"] == RtsWorld.NEUTRAL:
			late.units.append(unit)
	if then != null:
		for unit: Dictionary in then.enemies():
			late.units.append(unit)
			known[unit["id"]] = true
	for unit: Dictionary in now.enemies():
		if not known.has(unit["id"]) and RtsKinds.is_building(unit["kind"]):
			var cell := Vector2i((unit["position"] as Vector2).floor())
			late.graph.set_cost(cell, then.graph.cost_at(cell) if then != null else GakGridGraph.DEFAULT_COST)
	late.units.sort_custom(func(one: Dictionary, other: Dictionary) -> bool: return one["id"] < other["id"])
	late.units.make_read_only()
	return late


## The inner side, which reads its own thinking for the screen.
func thinking() -> GakRtsController:
	return inner


# As many held commands as the window has room for, oldest first; what is
# still held beyond one window's worth is dropped.
func _let_through(now: int) -> Array[RtsCommand]:
	if most_actions <= 0:
		var all: Array[RtsCommand] = _held.duplicate()
		_held.clear()
		return all
	var window_ticks: int = roundi(window_seconds * RtsWorld.TICKS_PER_SECOND)
	_given_at.assign(_given_at.filter(func(tick: int) -> bool: return tick > now - window_ticks))
	var given: Array[RtsCommand] = []
	while not _held.is_empty() and _given_at.size() < most_actions:
		given.append(_held.pop_front())
		_given_at.append(now)
	delayed += _held.size()
	while _held.size() > most_actions:
		_held.pop_front()
		dropped += 1
	return given
