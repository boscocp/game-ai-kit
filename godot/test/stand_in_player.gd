## A scripted player with a habit, standing in for a person until a person
## has been recorded (T18).
##
## Behaviour cloning needs recordings of somebody, and the pipeline has to run
## before anybody sits down to play. So each stand-in is the fixed opponent
## with a table of its own -- what it does in each of T37's five situations
## -- and a strong habit in it: the rushdown walks in and throws, the turtle
## guards and answers low, the jumper jumps. It sees the fight a quarter of a
## second late, as a person does, and fumbles one press in ten.
##
## A stand-in is easier to clone than a person, by construction: its choices
## depend on the situation and on a die, nothing else. Numbers measured on
## stand-ins say the pipeline works, not what cloning a person buys -- the
## recordings say which they are, and the report prints it.
##
## When not to use it: as evidence about people.
class_name StandInPlayer
extends FightOpponent

## Each stand-in's options in each of T37's situations, `[action, weight]`.
const HABITS: Dictionary = {
	"rushdown": {
		"after being hit": [["step in", 3], ["throw", 2], ["mid", 1]],
		"after blocking": [["throw", 4], ["mid", 2]],
		"it whiffed": [["step in", 2], ["mid", 3]],
		"it crouches": [["throw", 3], ["overhead", 2], ["step in", 1]],
		"neutral": [["step in", 5], ["throw", 2], ["mid", 2], ["low", 1]],
	},
	"turtle": {
		"after being hit": [["guard crouching", 3], ["step out", 2]],
		"after blocking": [["low", 4], ["guard crouching", 2]],
		"it whiffed": [["low", 3], ["mid", 1]],
		"it crouches": [["guard crouching", 2], ["overhead", 1]],
		"neutral": [["guard crouching", 4], ["guard standing", 2], ["crouch", 2], ["step out", 1], ["low", 1]],
	},
	"jumper": {
		"after being hit": [["jump", 3], ["step out", 1]],
		"after blocking": [["jump", 2], ["high", 2]],
		"it whiffed": [["high", 2], ["jump", 1]],
		"it crouches": [["jump", 3], ["overhead", 2]],
		"neutral": [["jump", 4], ["step in", 2], ["high", 2], ["guard standing", 1]],
	},
}
## One press in ten comes out late or as something else.
const EXECUTION: int = 90

var _habits: Dictionary


## The stand-in called `habit`, one of `HABITS`, its chances from `chance_seed`.
func _init(habit: String, data: FightData, chance_seed: int = 0) -> void:
	super("stand-in: " + habit, data, chance_seed)
	_habits = HABITS[habit]
	_execution = EXECUTION


## Its own options in the situation `name`, the ones `character` can do.
func _weighted_options(name: String, character: String) -> Array:
	return _habits[name].filter(func(option: Array) -> bool: return _has_option(character, option[0]))
