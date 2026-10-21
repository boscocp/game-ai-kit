## The state-machine team (T25), one of the board's controllers: every walker
## has a machine of its own, five states named for the five deeds, and the
## arrows between them.
##
##     advance    --in danger and wounded-->    fall back
##     advance    --home threatened-->          defend
##     advance    --prey in reach-->            hunt
##     advance    --a point free-->             take point
##     hunt       --in danger and wounded-->    fall back
##     hunt       --home threatened-->          defend
##     hunt       --no prey in reach-->         advance
##     take point --in danger and wounded-->    fall back
##     take point --home threatened-->          defend
##     take point --no point free-->            advance
##     defend     --in danger and wounded-->    fall back
##     defend     --home clear-->               advance
##     fall back  --out of danger-->            advance
##
## The state is the memory, and it is what makes this team commit: a walker
## sent home stays a defender until home is *clear* -- further than it had to
## come to be a threat (`TeamFacts.CALM_MARGIN`) -- and a walker holding a
## point holds it while it is free, whatever else is in reach. Nothing
## changes until an arrow fires, and only one fires a turn. The cost is the
## state machine's: "in danger and wounded" is written into four states.
##
## Advance is the siege deed: the rules' walk at their workshop.
##
## When not to use it: see `StateMachine`.
class_name MachineTeam
extends TechniqueTeam

const ADVANCE: String = "advance"

# Walker id -> its machine. A walker met for the first time starts advancing.
var _machines: Dictionary[int, StateMachine] = {}
var _last_turn: int = -1


## The name the league table and the screen give it.
func controller_name() -> String:
	return "state machine"


## One line for the screen: what kind of thinking this is.
func describe() -> String:
	return "a state machine per walker: it commits to a state until an arrow fires; builds by the rules"


## A new turn; a turn no later than the last means a new game, and every
## machine starts again.
func begin_turn(state: BoardState) -> void:
	if state.turn_number <= _last_turn:
		_machines.clear()
	_last_turn = state.turn_number
	super.begin_turn(state)


## Take an arrow if one fires, and do what the state does.
func decide(unit: Unit, known: TeamFacts) -> String:
	if not _machines.has(unit.id):
		_machines[unit.id] = _made()
	var now: String = _machines[unit.id].update(known.facts)
	_work += 1
	return SIEGE if now == ADVANCE else now


## The walker's state, and the arrow it took this turn.
func thinking(unit_id: int) -> String:
	var machine: StateMachine = _machines.get(unit_id)
	if machine == null:
		return "no machine yet"
	return "state %s, %s" % [machine.current, machine.last_change if machine.last_change != "" else "no arrow fired"]


## "States updated": one per walker decision.
func work_unit() -> String:
	return "states updated"


static func _made() -> StateMachine:
	var machine := StateMachine.new(ADVANCE)
	var danger: Callable = func(facts: Dictionary) -> bool: return facts["in_danger"] and facts["wounded"]
	var threatened: Callable = func(facts: Dictionary) -> bool: return facts["home_threatened"]
	for from: String in [ADVANCE, HUNT, TAKE_POINT, DEFEND]:
		machine.add_arrow(from, FALL_BACK, danger, "in danger and wounded")
		if from != DEFEND:
			machine.add_arrow(from, DEFEND, threatened, "an enemy walker is near its workshop")
	machine.add_arrow(ADVANCE, HUNT, func(facts: Dictionary) -> bool: return facts["prey_in_reach"], "a piece it beats is in reach")
	machine.add_arrow(ADVANCE, TAKE_POINT, func(facts: Dictionary) -> bool: return facts["point_free"], "a control point is free")
	machine.add_arrow(HUNT, ADVANCE, func(facts: Dictionary) -> bool: return not facts["prey_in_reach"], "nothing it beats is in reach")
	machine.add_arrow(TAKE_POINT, ADVANCE, func(facts: Dictionary) -> bool: return not facts["point_free"], "no point is free")
	machine.add_arrow(DEFEND, ADVANCE, func(facts: Dictionary) -> bool: return facts["home_clear"], "home is clear")
	machine.add_arrow(FALL_BACK, ADVANCE, func(facts: Dictionary) -> bool: return not facts["in_danger"], "out of danger")
	return machine
