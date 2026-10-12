## What anything that decides a unit's turn must provide: a state in, a move out.
##
## `ai_planning` implements it with STRIPS, `ai_learning` with a trained model,
## and a scripted opponent implements it with four lines of `if`. The game calls
## all three the same way, which is what makes the lessons comparable: swap the
## policy, keep the board, watch what changes.
##
## An implementation must guarantee:
##
## * the returned move is legal on `state` -- `state.why_refused(move)` returns
##   `BoardState.LEGAL` -- or the policy returns a move with an empty path,
##   which means "hold";
## * the move belongs to a unit of `state.current_faction`;
## * `state` is not modified;
## * the call returns. A policy that searches must bound itself, because this
##   runs inside a frame and invariant 7 says nothing here blocks one.
##
## When not to use it: a decision spanning several turns. That is a plan, and a
## plan is a sequence of these, produced by `ai_planning`.
class_name DecisionPolicy
extends RefCounted


## The move this policy would make for `unit_id` on `state`.
func choose(state: BoardState, unit_id: int) -> Move:
	push_error("DecisionPolicy.choose must be overridden; %s %d" % [state, unit_id])
	return Move.new(unit_id, [] as Array[Vector2i])
