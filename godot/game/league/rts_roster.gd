## T25's league on the RTS board: its teams, each a `GakRtsController`, so
## the runner plays any two without knowing what is inside either (T55).
##
## Strength is T12's axis and the levels' (`RtsLevels`); the clock's knobs
## are T25's other axis (`RtsHumanClock`). So the roster holds the
## commander at normal four times besides itself -- late, capped, with
## both knobs, and capped tightly -- and every difference between those
## five is the clock. The
## queues are the floor ADR 0010 measures every commander from, and easy
## (the commander planning nothing) a second point on the strength axis.
##
## A team is made fresh for every match from the match's seed, as the
## tactical league's are: a side's squads and plans are memories of one
## match.
##
## When not to use it: as the demo's opponents. The demo's C and K keys are
## the menu; a team is here for being a point on one of the two axes.
class_name RtsRoster
extends RefCounted

## A row: [name, what it is, Callable(side, seed, clock reference) -> a new
## GakRtsController].
const NAME: int = 0
const ABOUT: int = 1
const MAKE: int = 2
## The tight cap the knob check also plays: two commands in any five
## seconds, so the cap certainly bites whatever the reference says.
const TIGHT_ACTIONS: int = 2


## Every team, the table's order. `clock` is the knobs' values
## (`RtsHumanClock.knob_values()`), read once by the caller.
static func rows() -> Array[Array]:
	return [
		["queues", "QueueSide: fixed rules over the priority queue, ADR 0010's floor", _queues],
		["easy", "the commander at easy: no plan, the queues' rules on its economy", _easy],
		["commander", "the commander at normal: STRIPS over the build order", _plain],
		["late", "the commander at normal, with the reaction delay only", _late],
		["capped", "the commander at normal, with the cap on actions only", _capped],
		["human clock", "the commander at normal, with both knobs", _both],
		["tight cap", "the commander at normal, at most 2 commands in any 5 s", _tight],
	] as Array[Array]


static func _queues(side: int, dice: int, _clock: Dictionary) -> GakRtsController:
	return QueueSide.new(side, _normal(), dice)


static func _easy(side: int, dice: int, _clock: Dictionary) -> GakRtsController:
	return RtsCommander.new(side, RtsLevels.named("easy"), dice)


static func _plain(side: int, dice: int, _clock: Dictionary) -> GakRtsController:
	return _commander(side, dice)


static func _late(side: int, dice: int, clock: Dictionary) -> GakRtsController:
	return RtsHumanClock.new(_commander(side, dice), clock["reaction_ms"], 0)


static func _capped(side: int, dice: int, clock: Dictionary) -> GakRtsController:
	return RtsHumanClock.new(_commander(side, dice), 0.0, clock["most_actions"], clock["window_seconds"])


static func _both(side: int, dice: int, clock: Dictionary) -> GakRtsController:
	return RtsHumanClock.at(_commander(side, dice), clock)


## The team names, in roster order.
static func names() -> Array[String]:
	var found: Array[String] = []
	for row: Array in rows():
		found.append(row[NAME])
	return found


## Each knob the league asserts on: [the clocked team, the same side
## without the clock]. The cap is asserted at `TIGHT_ACTIONS`, not at the
## reference: at AlphaStar's 22 in five seconds it seldom binds here, and a
## cap that never binds would pass by changing nothing. The reference cap is
## printed beside it.
static func knobs() -> Array[Array]:
	return [["late", "commander"], ["tight cap", "commander"], ["human clock", "commander"]] as Array[Array]


static func _tight(side: int, dice: int, _clock: Dictionary) -> GakRtsController:
	return RtsHumanClock.new(_commander(side, dice), 0.0, TIGHT_ACTIONS, RtsHumanClock.STAND_IN_WINDOW_SECONDS)


static func _commander(side: int, dice: int) -> RtsCommander:
	return RtsCommander.new(side, _normal(), dice)


static func _normal() -> Difficulty:
	return RtsLevels.named("normal")
