## How much an AI is allowed to think: the only thing a difficulty level
## changes.
##
## The usual hard AI is given more than the player -- more money, more
## vision, a shorter cooldown. That is a lie told to the player, and it
## teaches nothing. Here a level is three numbers about thinking and nothing
## else:
##
## - `plan_horizon`, in actions: how far ahead the plan may look. A planner
##   asked for a goal further off than that comes back with the first steps
##   towards it (`HeuristicPlanner`'s horizon); 0 is no plan at all.
## - `search_depth`, in plies: how many turns of the exchange the search
##   weighs before it chooses -- 1, only what its own move does; 2, also the
##   other side's best answer to it.
## - `evaluation_noise`, a fraction: how much each option's value is blurred
##   before the best is taken, drawn uniformly from a seed the AI is given.
##   0 is its honest judgement; 1 blurs each option by up to one shield's
##   worth either way, 2 by up to two.
##
## Strength is one axis. How human the AI looks is another (T25), and its
## knobs live elsewhere so that a level can be weak and human-looking, or
## strong and inhuman, on purpose.
##
## `KNOBS` is the allowlist: `test/difficulty_knobs.gd` holds every preset to
## exactly these fields. A knob added here is written down here, with why.
##
## When not to use it: as a handicap on the rules of the game. A level that
## needs the board changed is not a level, it is a different game.
class_name Difficulty
extends RefCounted

## Every field a level may set, and nothing else.
const KNOBS: Array[String] = ["plan_horizon", "search_depth", "evaluation_noise"]

## The level's name, for the menu and the measurements.
var name: String
## Actions the plan may look ahead; 0 for no plan.
var plan_horizon: int
## Plies the search weighs: 1 its own move, 2 also the answer to it. The
## tactical board's search has no third; a deeper level weighs as 2 does.
var search_depth: int
## How much each option's value is blurred, in shields' worth either way.
var evaluation_noise: float


func _init(level_name: String, horizon: int, depth: int, noise: float) -> void:
	name = level_name
	plan_horizon = horizon
	search_depth = depth
	evaluation_noise = noise


## The levels, weakest first. Each is a point on the three knobs, chosen so
## that every neighbouring pair is measurably ordered
## (`test/difficulty_matches.gd`); a level that cannot be told from its
## neighbour is cut, not kept for the menu.
##
## Chosen from what the knobs were measured to do on the tactical board
## (T12's record has every pairing and the command that plays it): at 1 ply,
## no noise beat a noise of 0.5 by 70 games to 29 in 100, and 1.0 by 86 to
## 12; 2 plies beat 1 by 59 to 40. Noise above 0.5 was too much: at 1.0 a
## level beat the rules only 39 and 41 times in 50 from each seat, under the
## floor. Every horizon is 0: there, a plan was measured to make a side
## weaker (`LeveledBlue`), and more of it would make "hard" the easier level.
##
## Three, not five: nothing measured fits between normal and hard -- 2 plies
## with a noise of 0.5 lost to normal 42 to 58 -- nor below easy above the
## floor, and nothing here thinks further than 2 plies.
static func presets() -> Array[Difficulty]:
	return [
		Difficulty.new("easy", 0, 1, 0.5),
		Difficulty.new("normal", 0, 1, 0.0),
		Difficulty.new("hard", 0, 2, 0.0),
	]


## The preset called `level_name`, or null.
static func named(level_name: String) -> Difficulty:
	for level: Difficulty in presets():
		if level.name == level_name:
			return level
	return null


## The level in one line, for the screen: its name and its three knobs.
func describe() -> String:
	var horizon: String = "any length" if plan_horizon == HeuristicPlanner.NO_HORIZON else "%d actions" % plan_horizon
	return "%s: plans %s ahead, searches %d ply/plies, noise %.2f" % [name, horizon, search_depth, evaluation_noise]
