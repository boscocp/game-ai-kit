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
## One row so far: a seeded random mover, the floor every enemy in this mode
## must beat. T85 adds the first enemy that weighs; T87 and T88 put search
## behind it.
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
