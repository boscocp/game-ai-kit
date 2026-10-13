## What the learned policy decided, and the numbers it decided on.
##
## The move alone would be enough to play the game and is not enough to teach
## anything: a unit stepping backwards looks identical whether the model gave
## it a 3% chance of winning or whether the pathfinder simply had nowhere
## better to go. Invariant 13 asks every example to show the decision rather
## than the outcome, and this is the object it shows.
##
## When not to use it: as the policy's own working state. It is a record of
## one call, built after the thinking is over.
class_name LearnedDecision
extends RefCounted

## Close with the enemy the model says this unit beats.
const ATTACK: String = "attack"

## Break off from the enemy the model says it does not.
const RETREAT: String = "retreat"

## Nobody worth fighting is in reach; walk at the node that looks quickest.
const ADVANCE: String = "advance"

## Stand still. Also what a decision that could not be made comes back as.
const HOLD: String = "hold"

## One of the four above.
var action: String

var unit_id: int

## The move to play. Always legal on the state it was decided on, or empty.
var move: Move

## What the combat model gave for the fight this unit could pick, or NAN when
## no fight was weighed. Never a default of 0.0 -- a probability of zero is an
## answer, and "no fight was in question" is not.
var win_probability: float = NAN

## The unit that fight would have been against, or -1.
var opponent_id: int = -1

## The node being walked at, when one was chosen.
var target: Vector2i = Vector2i.ZERO

## What the capture model said that node would take, or NAN.
var predicted_turns: float = NAN

## One line for a person, naming the number that decided it.
var reason: String = ""


func _init(decided: String, deciding_for: int, chosen: Move) -> void:
	action = decided
	unit_id = deciding_for
	move = chosen


## Close with this opponent, because the model likes the odds.
static func attack(unit_id: int, chosen: Move, opponent: Unit, chance: float,
		threshold: float) -> LearnedDecision:
	var decision := LearnedDecision.new(ATTACK, unit_id, chosen)
	decision.win_probability = chance
	decision.opponent_id = opponent.id
	decision.reason = "unit %d attacks unit %d: p(win) %.2f at or above %.2f" % [
		unit_id, opponent.id, chance, threshold,
	]
	return decision


## Break off from this opponent, because it does not.
static func retreat(unit_id: int, chosen: Move, opponent: Unit, chance: float,
		threshold: float) -> LearnedDecision:
	var decision := LearnedDecision.new(RETREAT, unit_id, chosen)
	decision.win_probability = chance
	decision.opponent_id = opponent.id
	decision.reason = "unit %d retreats from unit %d: p(win) %.2f below %.2f" % [
		unit_id, opponent.id, chance, threshold,
	]
	return decision


## Walk at the node the capture model puts first.
static func advance(unit_id: int, chosen: Move, node: Vector2i, turns: float,
		against: String) -> LearnedDecision:
	var decision := LearnedDecision.new(ADVANCE, unit_id, chosen)
	decision.target = node
	decision.predicted_turns = turns
	decision.reason = "unit %d advances on %s: %.1f turns%s" % [
		unit_id, node, turns, against,
	]
	return decision


## Stand still, and say why. The reason is required, because an unexplained
## hold is the one answer a reader cannot tell from a policy that crashed.
static func hold(unit_id: int, why: String) -> LearnedDecision:
	var decision := LearnedDecision.new(HOLD, unit_id, Move.new(unit_id, [] as Array[Vector2i]))
	decision.reason = "unit %d holds: %s" % [unit_id, why]
	return decision
