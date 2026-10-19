## The guard as a state machine: four states, and the arrows between them.
##
##     patrol --suspicious--> suspicious --knows where--> searching
##        \\                       \\                        |   ^
##         `------alerted-------> alerted <--alerted-------'   |
##                                   `------cooling-------------'
##     suspicious, searching --calm, or the place checked--> patrol
##
## Each state does one thing: patrol walks the round, suspicious stops and
## turns towards what it heard, searching goes to where the intruder was and
## looks round, alerted gives chase. The arrows down wait for less suspicion
## than the arrows up needed -- T14's gap -- so it does not flicker; that
## memory is the state itself, and it is why this brain snaps: nothing
## changes until an arrow fires, and then everything does.
##
## When not to use it: see `StateMachine`.
class_name GuardFsm
extends GuardBrain

const PATROL: String = "patrol"
const SUSPICIOUS: String = "suspicious"
const SEARCHING: String = "searching"
const ALERTED: String = "alerted"

## The machine; public so the demo can draw it with the current state lit.
var machine := StateMachine.new(PATROL)


func _init() -> void:
	var alerted: Callable = func(facts: Dictionary) -> bool: return facts["alerted"]
	machine.add_arrow(PATROL, ALERTED, alerted, "suspicion reached the chase")
	machine.add_arrow(PATROL, SUSPICIOUS, func(facts: Dictionary) -> bool: return facts["suspicious"], "something is off")
	machine.add_arrow(SUSPICIOUS, ALERTED, alerted, "suspicion reached the chase")
	machine.add_arrow(SUSPICIOUS, SEARCHING, func(facts: Dictionary) -> bool: return facts["knows_where"], "it knows where to look")
	machine.add_arrow(SUSPICIOUS, PATROL, func(facts: Dictionary) -> bool: return facts["calm"], "it calmed down")
	machine.add_arrow(SEARCHING, ALERTED, alerted, "suspicion reached the chase")
	machine.add_arrow(SEARCHING, PATROL, func(facts: Dictionary) -> bool: return facts["calm"] or facts["area_checked"], "calm, or the place is checked")
	machine.add_arrow(ALERTED, SEARCHING, func(facts: Dictionary) -> bool: return facts["cooling"], "lost the trail")


## "state machine".
func brain_name() -> String:
	return "state machine"


## Take an arrow if one fires, then do what the state does.
func decide(facts: Dictionary) -> String:
	match machine.update(facts):
		SUSPICIOUS:
			return TURN_TOWARDS
		SEARCHING:
			return LOOK_AROUND if facts["at_last_known"] else GO_TO_LAST_KNOWN
		ALERTED:
			return CATCH if facts["next_to_player"] else CHASE
	return WALK_ROUND


## The state it is in, every state, and the arrow it last took.
func thinking() -> Dictionary:
	return {"state": machine.current, "states": machine.states(),
		"changed": machine.last_change if machine.last_change != "" else "no arrow fired"}
