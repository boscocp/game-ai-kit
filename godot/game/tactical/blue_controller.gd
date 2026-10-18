## Whatever plays blue on the tactical board: a `DecisionPolicy` for walking,
## and a build decision for the workshop.
##
## Blue is not one fixed AI. The scene is handed a controller and asks it the
## same two questions every turn, so the rules written for T30, the planner
## T11 brings and the learned policy T26 makes possible can each play the same
## board, and be played against each other, without one replacing another.
##
## A controller decides; it never plays. It returns a `TacticalDecision`, the
## scene draws it, and only then is it applied -- which is how a person sees
## what blue is about to do before it does it.
##
## When not to use it: the other boards. A walk and a build are what this
## scenario has to decide; checkers and the skirmish decide other things.
@abstract
class_name BlueController
extends DecisionPolicy


## Called once at the start of each of its turns, before any decision --
## the place for a controller that keeps something between turns, such as a
## plan (T11), to bring it up to date. A turn number no later than the last
## one it was handed means a new game. The rules keep nothing, and do nothing.
func begin_turn(_state: BoardState) -> void:
	pass


## The name the screen gives this controller, such as "rules".
@abstract func controller_name() -> String


## One line saying what kind of thinking this is, for the screen.
@abstract func describe() -> String


## What the workshop `workshop_id` should build now, or a hold.
@abstract func decide_build(state: BoardState, workshop_id: int) -> TacticalDecision


## Where unit `unit_id` should walk now, or a hold.
@abstract func decide_move(state: BoardState, unit_id: int) -> TacticalDecision


## Whom unit `unit_id` should attack now that it has walked, or null for
## nobody -- asked once a turn, after its move is played (T26). Null rather
## than a hold, so a turn with nothing in reach does not fill the screen
## with "attacks nobody". A controller that never attacks need not say so.
func decide_attack(_state: BoardState, _unit_id: int) -> TacticalDecision:
	return null


## The controller's plan as lines for the screen, or none: only a controller
## that plans has one (T11). The rules and the learned policy decide each
## piece afresh, and say so in their reasons instead.
func plan_lines() -> Array[String]:
	return []


## Cells to mark on the board with the number of the plan step the piece
## there is to carry out; none for a controller without a plan.
func plan_marks(_state: BoardState) -> Dictionary[Vector2i, String]:
	return {}


## The walk `decide_move` chose, as `DecisionPolicy` asks for it: an empty
## path means hold.
func choose(state: BoardState, unit_id: int) -> Move:
	var decision: TacticalDecision = decide_move(state, unit_id)
	return decision.move if decision.move != null else Move.new(unit_id, [] as Array[Vector2i])
