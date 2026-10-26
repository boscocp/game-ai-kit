## The control points: cells on the tactical map that pay whoever holds them,
## as cities do in Advance Wars.
##
## A side **holds** a point while one of its walkers stands on it and no enemy
## piece stands beside it -- T41's rule, brought over from the skirmish, where
## it decided the game. Here it decides money: at the start of its own turn a
## side is paid `TacticalRules.POINT_INCOME` for each point it holds, so the
## other side always has a whole turn to walk up and break a hold, and
## breaking one is as simple as arriving beside it -- or, since T26, as
## destroying the holder.
##
## Points are where the capture model finally has a question worth asking
## (T44): which of them falls first.
##
## When not to use it: a point that is won rather than paid for. Holding one
## here never ends the game; the workshop does (`TacticalVictory`).
class_name ControlPoints
extends RefCounted

## Nobody holds the point.
const NOBODY: int = -1


## The side holding `point` on `state`, or `NOBODY`.
static func holder(state: BoardState, point: Vector2i) -> int:
	var standing: Unit = state.unit_at(point)
	if standing == null or not standing.type.mobile:
		return NOBODY
	for step: Vector2i in GridGraph.DIRECTIONS:
		var beside: Unit = state.unit_at(point + step)
		if beside != null and beside.faction != standing.faction:
			return NOBODY
	return standing.faction


## The points `side` holds on `state`, in `TacticalScenario.POINTS` order.
static func held_by(state: BoardState, side: int) -> Array[Vector2i]:
	var held: Array[Vector2i] = []
	for point: Vector2i in TacticalScenario.POINTS:
		if holder(state, point) == side:
			held.append(point)
	return held


## What `BoardState.tally` counts the points under: for each side, the
## points it held summed over the turns it held them (T47).
const POINT_TURNS: String = "point turns"  # not shown


## Pay the side to move for every point it holds, as `[BoardState, String]`:
## the state with its funds raised and the turn counted under `POINT_TURNS`,
## and the line saying so -- "" when it holds none. Called at the start of a
## side's turn, with its ordinary income.
static func pay(state: BoardState) -> Array:
	var side: int = state.current_faction
	var held: Array[Vector2i] = held_by(state, side)
	if held.is_empty():
		return [state, ""]
	var paid: BoardState = state.duplicate_state()
	paid.funds[side] = paid.funds_of(side) + held.size() * TacticalRules.POINT_INCOME
	var counted: Dictionary = paid.tally.get(POINT_TURNS, {})
	counted[side] = counted.get(side, 0) + held.size()
	paid.tally[POINT_TURNS] = counted
	var where: Array[String] = []
	for point: Vector2i in held:
		where.append(str(point))
	return [paid, TranslationServer.translate("{side} is paid {amount} for holding the point(s) at {cells}").format({
		side = TacticalStatus.side_name(side), amount = held.size() * TacticalRules.POINT_INCOME, cells = ", ".join(where)})]


## One line for the screen: each point and who holds it.
static func describe(state: BoardState) -> String:
	var parts: Array[String] = []
	for point: Vector2i in TacticalScenario.POINTS:
		var side: int = holder(state, point)
		parts.append("%s %s" % [point, TacticalStatus.side_name(side) if side != NOBODY else TranslationServer.translate("nobody")])
	return TranslationServer.translate("points (each pays its holder {income} a turn): {points}").format({
		income = TacticalRules.POINT_INCOME, points = ", ".join(parts)})
