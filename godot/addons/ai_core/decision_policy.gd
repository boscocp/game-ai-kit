## What anything that decides a unit's turn must provide: a state in, a move out.
##
## `ai_learning` implements it with a trained model. The tactical board's
## controllers implement it too (`BlueController`): the rules, the learned
## policy, and since T11 a plan from `ai_planning` -- which itself knows
## nothing of boards, so the game's bridge turns the board into facts and the
## plan back into moves. The point of one interface is that the
## game calls every policy the same way, which is what makes the lessons
## comparable: swap the policy, keep the board, watch what changes.
##
## `@abstract` is the enforcement, for the reason set out in `pathfinder.gd`:
## the engine refuses to load a subclass that has not replaced these, and the
## `push_error` this file used to rely on returned a move with an empty path --
## which the contract below defines as the legitimate answer "hold". A policy
## that had forgotten to think looked exactly like a policy that had decided to
## wait.
##
## An implementation must guarantee:
##
## * the returned move's `unit_id` is the `unit_id` it was given. Obvious, and
##   it was missing: this interface handed a policy a unit to think about and
##   then said nothing about which unit the answer was for;
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
@abstract
class_name DecisionPolicy
extends RefCounted


## The move this policy would make for `unit_id` on `state`.
@abstract func choose(state: BoardState, unit_id: int) -> Move
