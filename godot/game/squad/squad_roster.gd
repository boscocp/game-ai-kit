## Every controller that can play the XCOM-style mode, in one table: what C
## cycles through in this mode, in this order.
##
## Its own table, not rows added to `TacticalRoster`: `League.schedule` seats
## the league's teams by their place in that table, so a row added there
## would re-roll the league's dice (T63). A row has `TacticalRoster`'s shape
## -- `[name, what it is, what it delegates, plays in the league,
## Callable(seed) -> a new BlueController]` -- and nothing here plays in the
## league.
##
## Five rows: the first enemy that weighs (T85), first because it is the
## one a person meets; the enemy that searches by sampling (T87), Monte
## Carlo tree search measured against it in `docs/godot/squad.md`; the enemy
## that searches by working out the odds (T88), expectiminimax, measured
## against both (`make measure-squad-duel`); a greedy shooter that never
## weighs cover, the stronger floor the first must beat (T125,
## `make test-squad-floor`); and a seeded random mover, the floor it beats
## every game (`make test-squad-match`).
##
## When not to use it: as a ranking, for the reason `TacticalRoster` gives.
class_name SquadRoster
extends RefCounted

## Where each field sits in a row, as in `TacticalRoster`.
const NAME: int = 0
const BUILD: int = 4


## Every row, in the order C cycles through them.
static func rows() -> Array[Array]:
	return [  # not shown: the names reach the screen through the scene
		["weighed", "every option of the piece weighed one action ahead, on its side's view (T85)", "ActionChoice", false,
			func(seed_number: int) -> BlueController: return WeighedSquad.new(seed_number)],
		["mcts", "Monte Carlo tree search over the piece's options and the turns after, on the board its side believes in (T87)",
			"MonteCarloSearch", false, func(seed_number: int) -> BlueController: return MctsSquad.new(seed_number)],
		["expecti", "expectiminimax over the piece's options and the turns after, every shot's hit and miss weighed by its chance, with an evaluation written by hand (T88)",
			"ExpectiminimaxSearch", false, func(seed_number: int) -> BlueController: return ExpectiSquad.new(seed_number)],
		["greedy", "the best shot it has, else straight at the nearest enemy it knows of, cover never weighed (T125)", "nothing", false,
			func(seed_number: int) -> BlueController: return GreedySquad.new(seed_number)],
		["random", "a seeded random action per piece, on its side's view (T84)", "nothing", false,
			func(seed_number: int) -> BlueController: return RandomSquad.new(seed_number)],
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


## `build`, for the scene: an enemy that searches is built to search a frame
## at a time (`SearchingSquad.spread_over_frames`), so the board keeps
## drawing while it thinks. The duel and the match build with `build`, and
## search a decision whole.
static func for_the_scene(row_name: String, seed_number: int) -> BlueController:
	var built: BlueController = build(row_name, seed_number)
	if built is SearchingSquad:
		(built as SearchingSquad).spread_over_frames()
	return built
