## The infiltration example's rules, read once from `rules.json`, and the
## switches a person turns while playing.
##
## Every number the level, the player or a guard is tuned by is a row of
## the file; this only gives each a name and a type, so the code that reads
## it says `rules.run_speed`, not a dictionary path. The switches are the
## techniques (invariant 13: each can be turned off and the difference
## seen) and the difficulty knobs, named (T70 step 7).
##
## When not to use it: as the guard types' numbers. What a guard perceives
## and how fast it grows aware are `guard_types.json`'s, per type.
class_name InfiltrationRules
extends RefCounted

const FILE: String = "res://game3d/infiltration/rules.json"
const ACTIONS: String = "res://game3d/infiltration/guard_actions.json"

var step_seconds: float = 0.1
var decision_seconds: float = 0.3
## Stance -> {speed, noise, points}: the player's body.
var stances: Dictionary = {}
var player: Dictionary = {}
var guards: Dictionary = {}
var spread: float = 0.4
var search: Dictionary = {}
## The knobs: reaction (s), turn_rate (degrees a second), aim_error, the
## awareness rate's multiplier, belief steps a second, off-screen halving.
var reaction: float = 0.5
var turn_rate: float = 180.0
var aim_error: float = 0.03
var awareness_rate: float = 1.0
var belief_steps: float = 2.0
var off_screen_halving: bool = true
## The techniques, each switchable: the belief (off: guards walk to the
## last known position and give up), the coordinator (off: each searches
## alone), the arbiter (off: everyone who can shoot does), the accumulator
## (off: a plain yes-or-no sight test).
var use_belief: bool = true
var use_coordinator: bool = true
var use_arbiter: bool = true
var use_accumulator: bool = true


## The rules in `path`.
static func read(path: String = FILE) -> InfiltrationRules:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var rules := InfiltrationRules.new()
	rules.step_seconds = float(data["step_seconds"])
	rules.decision_seconds = float(data["decision_seconds"])
	rules.player = data["player"]
	rules.stances = data["player"]["stances"]
	rules.guards = data["guards"]
	rules.spread = float(data["belief"]["spread"])
	rules.search = data["search"]
	var knobs: Dictionary = data["difficulty"]
	rules.reaction = float(knobs["reaction"])
	rules.turn_rate = float(knobs["turn_rate"])
	rules.aim_error = float(knobs["aim_error"])
	rules.awareness_rate = float(knobs["awareness_rate"])
	rules.belief_steps = float(knobs["belief_steps"])
	rules.off_screen_halving = bool(knobs["off_screen_halving"])
	return rules


## The guards' actions, for `ActionChoice`.
static func actions() -> Array[ActionChoice.Action]:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ACTIONS))
	return ActionChoice.actions_from(data["actions"])


## A guard's number by name, from the `guards` row.
func guard(field: String) -> float:
	return float(guards[field])


## The heights of the player's body points in `stance`, head first.
func points_of(stance: String) -> PackedFloat64Array:
	return PackedFloat64Array(stances[stance]["points"])
