## One thing blue decided to do this turn, and why.
##
## A decision is one of five: walk a unit along a route, attack, build a unit
## at the workshop, buy an upgrade there (T11's planner buys the forge), or
## hold. It is made *before* it is played, so the scene can draw
## it and a person can read it first -- invariant 13 -- and then played as it
## was drawn, never re-decided in between.
##
## The why is kept as a `Sentence` -- the English key and its values -- and
## worded where it is shown, so a decision is the same in any language (T104).
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
## The attack, or null when this decision is not one.
var attack: Attack
## The upgrade bought, or null when this decision is not a purchase.
var upgrade: Upgrade
## Why, in one sentence a player can check against the board: a `Sentence`,
## worded by `TacticalStatus.said` on the screen and by `english` elsewhere.
var reason: Array
## The cell the decision is about -- where the unit is heading, or where the
## new unit will stand -- for the overlay to draw.
var target: Vector2i


func _init(deciding_id: int, why: Array, about: Vector2i) -> void:
	unit_id = deciding_id
	reason = why
	target = about


## A walk along `path` towards `about`.
static func walk(deciding_id: int, path: Array[Vector2i], why: Array, about: Vector2i) -> TacticalDecision:
	var decision := TacticalDecision.new(deciding_id, why, about)
	decision.move = Move.new(deciding_id, path)
	return decision


## A unit built by the workshop `deciding_id`.
static func build(deciding_id: int, built: ProductionOrder, why: Array) -> TacticalDecision:
	var decision := TacticalDecision.new(deciding_id, why, built.cell)
	decision.order = built
	return decision


## An attack on `target`, by the unit `deciding_id`.
static func strike(deciding_id: int, target: Unit, why: Array) -> TacticalDecision:
	var decision := TacticalDecision.new(deciding_id, why, target.cell)
	decision.attack = Attack.new(deciding_id, target.id)
	return decision


## `bought` paid for at the workshop `deciding_id`, which stands at `at`.
static func buy(deciding_id: int, bought: Upgrade, why: Array, at: Vector2i) -> TacticalDecision:
	var decision := TacticalDecision.new(deciding_id, why, at)
	decision.upgrade = bought
	return decision


## Nothing done, and the reason nothing was.
static func hold(deciding_id: int, why: Array, at: Vector2i) -> TacticalDecision:
	return TacticalDecision.new(deciding_id, why, at)


## The reason in English, as a log, a test or an overlay reads it, whatever
## the language on screen.
func english() -> String:
	return Sentence.english(reason)


## What kind of decision it is, as the overlay names it.
func kind() -> String:
	if move != null:
		return "move"  # not shown: the overlay's kind
	if order != null:
		return "build"  # not shown: the overlay's kind
	if attack != null:
		return "attack"  # not shown: the overlay's kind
	if upgrade != null:
		return "buy"  # not shown: the overlay's kind
	return "hold"  # not shown: the overlay's kind


## The state after this decision, or null when the board refuses it. A hold
## changes nothing and is never refused. A walk and an attack are played by
## `rules` (T84), Advance Wars when none is given; a build and a purchase
## are the board's in every mode.
func played_on(state: BoardState, rules: TacticalRuleset = null) -> BoardState:
	var playing: TacticalRuleset = AdvanceWarsRuleset.or_default(rules)
	if move != null:
		return playing.walk(state, move)
	if order != null:
		return state.produce(order)
	if attack != null:
		return playing.attack(state, attack)
	if upgrade != null:
		return state.buy(upgrade)
	return state
