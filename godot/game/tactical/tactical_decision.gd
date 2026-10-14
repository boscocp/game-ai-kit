## One thing blue decided to do this turn, and why, in words for the screen.
##
## A decision is one of three: walk a unit along a route, build a unit at the
## workshop, or hold. It is made *before* it is played, so the scene can draw
## it and a person can read it first -- invariant 13 -- and then played as it
## was drawn, never re-decided in between.
##
## When not to use it: a decision that spans turns. That is a plan, and a plan
## is T11's.
class_name TacticalDecision
extends RefCounted

## The unit deciding: a walker for a move, the workshop for a build.
var unit_id: int
## The walk, or null when this decision is not a move.
var move: Move
## The build, or null when this decision is not one.
var order: ProductionOrder
## Why, in one sentence a player can check against the board.
var reason: String
## The cell the decision is about -- where the unit is heading, or where the
## new unit will stand -- for the overlay to draw.
var target: Vector2i


func _init(deciding_id: int, why: String, about: Vector2i) -> void:
	unit_id = deciding_id
	reason = why
	target = about


## A walk along `path` towards `about`.
static func walk(deciding_id: int, path: Array[Vector2i], why: String, about: Vector2i) -> TacticalDecision:
	var decision := TacticalDecision.new(deciding_id, why, about)
	decision.move = Move.new(deciding_id, path)
	return decision


## A unit built by the workshop `deciding_id`.
static func build(deciding_id: int, built: ProductionOrder, why: String) -> TacticalDecision:
	var decision := TacticalDecision.new(deciding_id, why, built.cell)
	decision.order = built
	return decision


## Nothing done, and the reason nothing was.
static func hold(deciding_id: int, why: String, at: Vector2i) -> TacticalDecision:
	return TacticalDecision.new(deciding_id, why, at)


## What kind of decision it is, as the overlay names it.
func kind() -> String:
	if move != null:
		return "move"
	if order != null:
		return "build"
	return "hold"


## The state after this decision, or null when the board refuses it. A hold
## changes nothing and is never refused.
func played_on(state: BoardState) -> BoardState:
	if move != null:
		return state.apply(move)
	if order != null:
		return state.produce(order)
	return state
