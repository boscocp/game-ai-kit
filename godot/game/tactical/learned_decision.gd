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
const ATTACK: String = "attack"  # shown through tr()

## Break off from the enemy the model says it does not.
const RETREAT: String = "retreat"  # shown through tr()

## Nobody worth fighting is in reach; walk at the node that looks quickest.
const ADVANCE: String = "advance"  # shown through tr()

## An enemy stands on a node; walk at it. A rule, not a model's answer.
const CONTEST: String = "contest"  # shown through tr()

## Stand still. Also what a decision that could not be made comes back as.
const HOLD: String = "hold"  # shown through tr()

## One of the five above.
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
	decision.reason = TranslationServer.translate("unit {unit} attacks unit {opponent}: p(win) {chance} at or above {bar}").format({
		unit = unit_id, opponent = opponent.id, chance = "%.2f" % chance, bar = "%.2f" % threshold})
	return decision


## Break off from this opponent, because it does not.
static func retreat(unit_id: int, chosen: Move, opponent: Unit, chance: float,
		threshold: float) -> LearnedDecision:
	var decision := LearnedDecision.new(RETREAT, unit_id, chosen)
	decision.win_probability = chance
	decision.opponent_id = opponent.id
	decision.reason = TranslationServer.translate("unit {unit} retreats from unit {opponent}: p(win) {chance} below {bar}").format({
		unit = unit_id, opponent = opponent.id, chance = "%.2f" % chance, bar = "%.2f" % threshold})
	return decision


## Walk at the node the capture model puts first. `runner_up` is the node it
## was chosen over, as {"turns", "cell"}, or {} when there was only one.
static func advance(unit_id: int, chosen: Move, node: Vector2i, turns: float,
		runner_up: Dictionary) -> LearnedDecision:
	var decision := LearnedDecision.new(ADVANCE, unit_id, chosen)
	decision.target = node
	decision.predicted_turns = turns
	var said: Dictionary = {unit = unit_id, node = node, turns = "%.1f" % turns}
	decision.reason = TranslationServer.translate("unit {unit} advances on {node}: {turns} turns").format(said)
	if not runner_up.is_empty():
		said.merge({other = "%.1f" % runner_up["turns"], cell = runner_up["cell"]})
		decision.reason = TranslationServer.translate("unit {unit} advances on {node}: {turns} turns, against {other} at {cell}").format(said)
	return decision


## Walk at a node an enemy is standing on, because a node left to the enemy
## is a node lost -- said as the rule it is, with no number, because no model
## was asked.
static func contest(unit_id: int, chosen: Move, node: Vector2i, holder: Unit) -> LearnedDecision:
	var decision := LearnedDecision.new(CONTEST, unit_id, chosen)
	decision.target = node
	decision.opponent_id = holder.id
	decision.reason = TranslationServer.translate("unit {unit} contests {node}: unit {holder} stands on it, and a node left to the enemy is lost (a rule, not the model)").format({
		unit = unit_id, node = node, holder = holder.id})
	return decision


## Stand still, and say why. The reason is required, because an unexplained
## hold is the one answer a reader cannot tell from a policy that crashed.
static func hold(unit_id: int, why: String) -> LearnedDecision:
	var decision := LearnedDecision.new(HOLD, unit_id, Move.new(unit_id, [] as Array[Vector2i]))
	decision.reason = TranslationServer.translate("unit {unit} holds: {why}").format({unit = unit_id, why = why})
	return decision
