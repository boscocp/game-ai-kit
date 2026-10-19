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
## the table `roster` returns. Behaviour cloning on this board (T25's eighth
## team) joins once there are recordings of a person to clone; until then the
## league says so rather than fielding a clone of nothing.
##
## When not to use it: as a menu of opponents. A team is chosen here for being
## a technique, not for being good to play against; the demo's C key is the
## menu.
class_name League
extends RefCounted

## The level T12's technique plays at in the league: its strongest, so the
## technique is measured at its best, as every other team is.
const LEVEL: String = "hard"

## Teams the task names that have not joined yet, and why, for the table.
const NOT_YET: Array[String] = [
	"cloned: behaviour cloning needs a person's recordings of this board (make record-tactical); none are committed yet",
]


## Every team: [name, what it is, what it delegates, Callable(seed) -> a new
## `BlueController`], in the order the table prints them.
static func roster() -> Array[Array]:
	return [
		["rules", "priority rules, the baseline (T30, T45)", "nothing",
			func(_seed: int) -> BlueController: return RuleBasedBlue.new()],
		["state machine", "a finite state machine per walker (T15)", "production and attacks, to the rules",
			func(_seed: int) -> BlueController: return MachineTeam.new()],
		["behaviour tree", "a behaviour tree, ticked from the root (T15)", "production and attacks, to the rules",
			func(_seed: int) -> BlueController: return TreeTeam.new()],
		["GOAP", "goal-oriented action planning per walker (T15)", "production and attacks, to the rules",
			func(_seed: int) -> BlueController: return GoapTeam.new()],
		["HTN", "a hierarchical task network per walker (T15)", "production and attacks, to the rules",
			func(_seed: int) -> BlueController: return HtnTeam.new()],
		["planner", "heuristic STRIPS for purchases, ADR 0010 (T11)", "walking and attacks, to the rules",
			func(_seed: int) -> BlueController: return PlannedBlue.new()],
		["learned", "trained regressions for fights and points (T44, T46)", "production, to the rules",
			func(_seed: int) -> BlueController: return LearnedBlue.new()],
		["lookahead (%s)" % LEVEL, "two plies at the fight's odds, T12's %s level" % LEVEL, "production, to the rules",
			func(seed_number: int) -> BlueController: return LeveledBlue.new(Difficulty.named(LEVEL), seed_number)],
	]


## The team names, in roster order.
static func names() -> Array[String]:
	var found: Array[String] = []
	for team: Array in roster():
		found.append(team[0])
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
