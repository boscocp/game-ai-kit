## The RTS's difficulty levels: T12's three knobs, read the way real time
## reads them, and nothing else.
##
## A level is a `Difficulty` -- the same class, the same three fields,
## held to them by `test/tactical/difficulty_knobs.gd` -- so the never-cheat rule is
## the one T12 wrote: no level sees, earns or may order anything another
## does not. What each knob means here:
##
## - `plan_horizon`: how many steps of the build order the commander looks
##   ahead. 0 is no plan at all: the economy runs on `QueueSide`'s rules,
##   measured weaker than the plan. Short, and it walks towards the lab
##   without seeing the mortars at the end of the chain.
## - `search_depth`: 1, a squad weighs the enemy at the region it scores; 2,
##   also the enemy round it, who could arrive while it fights.
## - `evaluation_noise`: how much each region's score is blurred, as a
##   fraction either way, before a squad takes the best -- and how much the
##   commander misjudges the count of each enemy fighter it has seen, so a
##   noisy level can build the wrong counter.
##
## Beside these, T25's other axis -- how human a side looks -- has two knobs
## here, where a clock makes them measurable (T55, `RtsHumanClock`):
##
## - `reaction_ms`: the side acts on what it saw at least this long ago;
## - `most_actions` in `window_seconds`: no more commands than that in any
##   such window, AlphaStar's kind of cap.
##
## They are not fields of a level: a level is a point on both axes, the
## strength knobs here and the clock's on top (K in the demo), so *easy
## and human* and *normal and inhuman* are both on offer. Like these, they
## take away and never give: `test/league/rts_league.gd` holds a side with
## each on to seeing, earning and ordering no more than without it.
##
## Chosen by measurement, not taste: `make rts-measure` plays each level
## against the one below and prints the record, and a level that cannot be
## told from its neighbour is cut, as T12 cut its five to three.
##
## When not to use it: to make a side weaker by handicapping its economy.
## That is a different game, not a level.
class_name RtsLevels
extends RefCounted


## The levels, weakest first.
##
## Two, not T12's three: on 2026-10-20, ten seeds from both seats, a "hard"
## of horizon 8, depth 2 and no noise went 11 - 9 and then 10 - 10 against
## normal, and was cut -- the plans here are a step or two long, so a
## longer horizon changes nothing, and depth 2 moved no squad that mattered.
## Normal's noise is 0.2: at 0.5 it misjudged the enemy enough to go 11 - 9
## with easy, which plans nothing at all. At 0.2, on the code merged,
## normal beat easy 17 - 3.
static func presets() -> Array[Difficulty]:
	return [
		Difficulty.new("easy", 0, 1, 0.6),  # not shown: an identifier
		Difficulty.new("normal", 4, 1, 0.2),  # not shown: an identifier
	]


## The preset called `level_name`, or null.
static func named(level_name: String) -> Difficulty:
	for level: Difficulty in presets():
		if level.name == level_name:
			return level
	return null
