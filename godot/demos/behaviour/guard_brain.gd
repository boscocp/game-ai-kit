## One way for the guard to decide. Four of them play the same guard
## (`GuardFsm`, `GuardTree`, `GuardGoap`, `GuardHtn`), on the same board,
## knowing the same things (`GuardSenses`).
##
## A brain answers one question, `decide`: which of the guard's six deeds to
## do this turn, given the facts. Everything else is shared, so the four
## differ only where the lesson is: how a deed is chosen. The deed becomes a
## `Move` here, by A\* round anybody in the way, which is what makes each
## brain a `DecisionPolicy` the demo can swap while the guard is mid-round.
##
## When not to use it: a guard whose deeds are not the same for every brain.
## Then the four are not one guard written four times, and side by side they
## teach nothing.
@abstract
class_name GuardBrain
extends DecisionPolicy

## Walk on towards the next waypoint of the round.
const WALK_ROUND: String = "walk_round"  # shown through tr()
## Stop and turn towards what it heard.
const TURN_TOWARDS: String = "turn_towards"  # shown through tr()
## Walk to where the intruder was last seen or heard.
const GO_TO_LAST_KNOWN: String = "go_to_last_known"  # shown through tr()
## Stand there and look round.
const LOOK_AROUND: String = "look_around"  # shown through tr()
## Run at the intruder, two cells a turn.
const CHASE: String = "chase"  # shown through tr()
## Seize the intruder, standing next to it.
const CATCH: String = "catch"  # shown through tr()

## What it knows; set by the world before each turn.
var senses: GuardSenses
## The deed decided on the last turn; "" before the first, so a brain just
## handed the guard does not seem to have decided anything yet.
var deed: String = ""

var _router := GridPathfinder.new(AStarSearch.new())


## Its name on screen: "state machine", "behaviour tree", "GOAP", "HTN".
@abstract func brain_name() -> String


## The deed for this turn, given the facts.
@abstract func decide(facts: Dictionary) -> String


## What it is thinking with -- the state, the tree's trail, the plan -- for
## the screen and `decision_overlay`.
@abstract func thinking() -> Dictionary


## The guard's move this turn: the deed `decide` chooses, as a walk on
## `state`, or a hold for a deed done standing.
func choose(state: BoardState, unit_id: int) -> Move:
	var guard: Unit = state.unit_by_id(unit_id)
	deed = decide(senses.facts(guard.cell))
	return Move.new(unit_id, _walk(state, guard, _goal_of(guard)))


# Where the deed walks to; the guard's own cell for a deed done standing.
func _goal_of(guard: Unit) -> Vector2i:
	match deed:
		WALK_ROUND:
			return senses.waypoint(guard.cell)
		GO_TO_LAST_KNOWN:
			return senses.last_known
		CHASE:
			return senses.player_cell
	return guard.cell


# The first cells of an A* route to `goal` round everybody else, as far as a
# turn goes -- two cells for a chase, one otherwise -- and never onto the
# cell somebody stands on.
func _walk(state: BoardState, guard: Unit, goal: Vector2i) -> Array[Vector2i]:
	if goal == guard.cell or not state.graph.contains(goal):
		return []
	var around: GakGridGraph = state.graph.duplicate_graph()
	for other: Unit in state.units:
		if other.id != guard.id and other.cell != goal:
			around.block(other.cell)
	var route: Array[Vector2i] = _router.find_path(around, guard.cell, goal)
	var steps: Array[Vector2i] = []
	for cell: Vector2i in route.slice(0, 2 if deed == CHASE else 1):
		var longer: Array[Vector2i] = steps.duplicate()
		longer.append(cell)
		if state.unit_at(cell) != null or state.why_refused(Move.new(guard.id, longer)) != BoardState.LEGAL:
			break
		steps = longer
	return steps


## A new brain of each kind, in the order the keys pick them: 0 the state
## machine, 1 the tree, 2 GOAP, 3 the HTN.
##
## Why here and not in `BehaviourDemo`: with the four named there, the demo
## leaked 22 objects at exit (T146, `docs/godot/exit-leaks.md`). Moved into
## `BehaviourWorld` it leaked the same; here it closes clean. Measured, not
## understood.
static func every() -> Array[GuardBrain]:
	return [GuardFsm.new(), GuardTree.new(), GuardGoap.new(), GuardHtn.new()]
