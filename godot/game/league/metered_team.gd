## A team with a meter on it: the same team, asked the same questions, with
## what each decision cost written down -- the milliseconds, and the work
## where the technique counts any (`BlueController.work_done`) (T25, step 2).
##
## The meter is the one place the cost is read, so the league's table and,
## later, the meter on screen (T25, step 6) read the same counters and cannot
## disagree. Work the team does at the start of its turn -- the planner plans
## there -- is charged to its first decision that turn, since that decision
## waited for it.
##
## The clock is `Time.get_ticks_usec`, read before and after each call. It
## measures this machine, under whatever else it is doing, which is why the
## league prints the budget beside every number and the slowest decision as
## well as the mean.
##
## When not to use it: to compare across machines. A millisecond here is a
## millisecond on this machine; the work counts are what travel.
class_name MeteredTeam
extends BlueController

## Each decision, in order: {"usec", "work", "replanned", "kind"}.
var decisions: Array[Dictionary] = []

var _inner: BlueController
# Turn-start time and work not yet charged to a decision.
var _pending_usec: int = 0
var _pending_work: int = 0
var _pending_plans: int = 0


func _init(inner: BlueController) -> void:
	_inner = inner


## The team inside, for a caller that wants its name or its thinking.
func inner() -> BlueController:
	return _inner


## The inner start of turn, timed and held for its first decision.
func begin_turn(state: BoardState) -> void:
	var work: int = _inner.work_done()
	var plans: int = _inner.replans()
	var started: int = Time.get_ticks_usec()
	_inner.begin_turn(state)
	_pending_usec += Time.get_ticks_usec() - started
	_pending_work += _inner.work_done() - work
	_pending_plans += _inner.replans() - plans


## The team's own name: a meter changes no name in the table.
func controller_name() -> String:
	return _inner.controller_name()


## The team's own line for the screen.
func describe() -> String:
	return _inner.describe()


## What the team counts its work in, passed through so a reader of the
## wrapper reads the team.
func work_unit() -> String:
	return _inner.work_unit()


## The team's running total of work, passed through likewise.
func work_done() -> int:
	return _inner.work_done()


## The team's plans made, passed through likewise.
func replans() -> int:
	return _inner.replans()


## The inner build, metered.
func decide_build(state: BoardState, workshop_id: int) -> TacticalDecision:
	return _metered(func() -> TacticalDecision: return _inner.decide_build(state, workshop_id), "build")


## The inner walk, metered.
func decide_move(state: BoardState, unit_id: int) -> TacticalDecision:
	return _metered(func() -> TacticalDecision: return _inner.decide_move(state, unit_id), "move")


## The inner attack, metered.
func decide_attack(state: BoardState, unit_id: int) -> TacticalDecision:
	return _metered(func() -> TacticalDecision: return _inner.decide_attack(state, unit_id), "attack")


## The inner plan.
func plan_lines() -> Array[String]:
	return _inner.plan_lines()


## The inner plan's marks.
func plan_marks(state: BoardState) -> Dictionary[Vector2i, String]:
	return _inner.plan_marks(state)


# Ask `asking`, and write down what it cost, with whatever the start of the
# turn had not yet charged.
func _metered(asking: Callable, kind: String) -> TacticalDecision:
	var work: int = _inner.work_done()
	var plans: int = _inner.replans()
	var started: int = Time.get_ticks_usec()
	var decision: TacticalDecision = asking.call()
	var spent: int = Time.get_ticks_usec() - started
	decisions.append({
		"usec": spent + _pending_usec,
		"work": _inner.work_done() - work + _pending_work,
		"replanned": _inner.replans() - plans + _pending_plans > 0,
		"kind": kind,
	})
	_pending_usec = 0
	_pending_work = 0
	_pending_plans = 0
	return decision
