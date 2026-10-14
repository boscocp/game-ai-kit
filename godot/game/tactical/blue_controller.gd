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


## The name the screen gives this controller, such as "rules".
@abstract func controller_name() -> String


## One line saying what kind of thinking this is, for the screen.
@abstract func describe() -> String


## What the workshop `workshop_id` should build now, or a hold.
@abstract func decide_build(state: BoardState, workshop_id: int) -> TacticalDecision


## Where unit `unit_id` should walk now, or a hold.
@abstract func decide_move(state: BoardState, unit_id: int) -> TacticalDecision


## The walk `decide_move` chose, as `DecisionPolicy` asks for it: an empty
## path means hold.
func choose(state: BoardState, unit_id: int) -> Move:
	var decision: TacticalDecision = decide_move(state, unit_id)
	return decision.move if decision.move != null else Move.new(unit_id, [] as Array[Vector2i])
