## The league's teams: every way this kit has of deciding the tactical board,
## one team each, held the same way -- as a `BlueController`, which is a
## `DecisionPolicy` -- so the runner plays any two without knowing what is
## inside either (T25).
##
## A team is made fresh for every game, from the game's seed: the state
## machine's states, the HTN's plans and the planner's plan are memories of
## one game, and a team that carried them into the next would be playing a
## board it had not seen. A team with noise of its own (T12's level) draws it
## from that seed, never from the board's dice.
##
## What each decides, and what it hands the rules, is in its own header and in
## `TacticalRoster`, the one table of the board's controllers, which the
## league reads rather than keeping a list of its own (T63). Behaviour cloning on this board (T25's eighth
## team) joins once there are recordings of a person to clone; until then the
## league says so rather than fielding a clone of nothing.
##
## When not to use it: as a menu of opponents. A team is chosen here for being
## a technique, not for being good to play against; the demo's C key is the
## menu.
class_name League
extends RefCounted

## Teams the task names that have not joined yet, and why, for the table.
const NOT_YET: Array[String] = [
	"cloned: behaviour cloning needs a person's recordings of this board (make record-tactical); none are committed yet",
]


## Every team, in the order the table prints them: the rows of
## `TacticalRoster` that play in the league -- the same table the demo's C
## key cycles, so the two cannot list different controllers. A row is that
## table's, `[name, what it is, what it delegates, plays in the league,
## Callable(seed) -> a new BlueController]`.
static func roster() -> Array[Array]:
	var teams: Array[Array] = []
	for row: Array in TacticalRoster.rows():
		if row[TacticalRoster.IN_LEAGUE]:
			teams.append(row)
	return teams


## The team names, in roster order.
static func names() -> Array[String]:
	var found: Array[String] = []
	for team: Array in roster():
		found.append(team[TacticalRoster.NAME])
	return found


## Every game the league plays: [red team index, blue team index, dice seed],
## each pairing from both seats over `seeds` seeds. The two seats roll dice
## of their own -- the second seat's seed is offset by `SEAT_OFFSET` -- since
## two games on one board's dice are tied together, and T12 measured that
## tie making two equal sides look 23 in a hundred apart.
static func schedule(teams: int, seeds: int) -> Array[Array]:
	var games: Array[Array] = []
	for pairing: int in range(teams * teams):
		var one: int = pairing / teams
		var other: int = pairing % teams
		if other <= one:
			continue
		for dice: int in range(seeds):
			games.append([one, other, dice])
			games.append([other, one, dice + SEAT_OFFSET])
	return games


## Added to a seed for the second seat's game.
const SEAT_OFFSET: int = 1000
