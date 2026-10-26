## Every controller that can play the tactical board, in one table: what the
## C key cycles through, in this order, and what the league fields (T63).
##
## Before this, the list lived three times -- an `if playing is X` chain in
## `tactical.gd`, the league's own roster, and a sentence on screen -- kept in
## step by hand, in two modules that depended on each other for it. A
## controller added is now a row added. The game and the league read it, and
## `scripts/check_demos.py` holds the menu's card (`godot/menu/catalogue.json`)
## to it, rows and order.
##
## A row is `[name, what it is, what it delegates, plays in the league,
## Callable(seed) -> a new BlueController]`. The name is the one the
## controller gives itself (`controller_name`), which is how the game finds
## the row it is on; a test holds every row to it. A controller is built fresh
## from a seed every time, because a planner's plan and a state machine's
## state are memories of one game; a level draws its noise from that seed,
## never from the board's dice.
##
## Each name is written as a literal on its row's first line, because
## `check_demos.py` reads them from this file without an engine.
##
## When not to use it: as a ranking. The order is the order a person meets
## them in -- the baseline, then the techniques with a lesson each, the levels
## weakest first -- not how well they play; the league measures that. And
## know that the order is not free: `League.schedule` seats teams by their
## place in it, so a row inserted or moved re-rolls the league's dice and its
## table moves inside its intervals (`docs/concepts/the-league.md`).
class_name TacticalRoster
extends RefCounted

## Where each field sits in a row.
const NAME: int = 0
const ABOUT: int = 1
const DELEGATES: int = 2
const IN_LEAGUE: int = 3
const BUILD: int = 4


## Every row, in the order C cycles through them.
##
## Only `hard` of the three levels plays in the league: a technique is
## measured at its strongest, as every other team is.
static func rows() -> Array[Array]:
	return [  # not shown: the names reach the screen through TacticalStatus.controller_said
		["rules", "priority rules, the baseline (T30, T45)", "nothing", true,
			func(_seed: int) -> BlueController: return RuleBasedBlue.new()],
		["planner", "heuristic STRIPS for purchases, ADR 0010 (T11)", "walking and attacks, to the rules", true,
			func(_seed: int) -> BlueController: return PlannedBlue.new()],
		["learned", "trained regressions for fights and points (T44, T46)", "production, to the rules", true,
			func(_seed: int) -> BlueController: return LearnedBlue.new()],
		["easy", "one ply at the fight's odds, with noise, T12's easy level", "production, to the rules", false,
			func(seed_number: int) -> BlueController: return LeveledBlue.new(Difficulty.named("easy"), seed_number)],
		["normal", "one ply at the fight's odds, T12's normal level", "production, to the rules", false,
			func(seed_number: int) -> BlueController: return LeveledBlue.new(Difficulty.named("normal"), seed_number)],
		["hard", "lookahead: two plies at the fight's odds, T12's hard level", "production, to the rules", true,
			func(seed_number: int) -> BlueController: return LeveledBlue.new(Difficulty.named("hard"), seed_number)],
		["state machine", "a finite state machine per walker (T15)", "production and attacks, to the rules", true,
			func(_seed: int) -> BlueController: return MachineTeam.new()],
		["behaviour tree", "a behaviour tree, ticked from the root (T15)", "production and attacks, to the rules", true,
			func(_seed: int) -> BlueController: return TreeTeam.new()],
		["GOAP", "goal-oriented action planning per walker (T15)", "production and attacks, to the rules", true,
			func(_seed: int) -> BlueController: return GoapTeam.new()],
		["HTN", "a hierarchical task network per walker (T15)", "production and attacks, to the rules", true,
			func(_seed: int) -> BlueController: return HtnTeam.new()],
	]


## The names, in table order.
static func names() -> Array[String]:
	var found: Array[String] = []
	for row: Array in rows():
		found.append(row[NAME])
	return found


## A new controller from the row called `row_name`, or null when no row is.
static func build(row_name: String, seed_number: int) -> BlueController:
	for row: Array in rows():
		if row[NAME] == row_name:
			return (row[BUILD] as Callable).call(seed_number)
	return null


## The name of the row after `row_name`, round to the first after the last.
##
## A name no row has -- a controller handed to the scene from outside the
## table -- is followed by the first row: `find` answers -1 for it, and the
## cycle starts again at the top.
static func after(row_name: String) -> String:
	var order: Array[String] = names()
	return order[(order.find(row_name) + 1) % order.size()]
