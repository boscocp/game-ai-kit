## Whether a map wave function collapse built can be played (T96): what T84's
## rules need of it that no rule between two neighbours can say.
##
## WFC only keeps neighbours agreeing -- water beside the bridge, rock out of
## the river -- so a map can be all agreement and still no game: a squad
## walled in by rock, or a start in the open with nothing to hide behind
## before the first shot. Two checks, read with the mode's own rules:
##
## - **the starts are connected**: every piece's start reaches every other
##   over the ground the board walks (`TacticalRules.graphs_from`), so each
##   side can reach the other on foot -- the wader is not counted on;
## - **cover within one action**: from each start, a walk of at most that
##   piece's one action (`SquadTable.action`) reaches a cell beside trees or
##   rock (`SquadCover.worth_at`), so no piece must take its first shot
##   standing in the open.
##
## A map that fails is refused and the next seed built (`SquadMapBuild`),
## the reason kept in English for the overlay.
##
## When not to use it: to judge whether a map is fair or fun. These are the
## two things the rules cannot play without; the rest is the manual check.
class_name SquadMapCheck
extends RefCounted


## Why `rows` cannot be played, in English, or "" when it can.
static func why_unplayable(rows: Array[String]) -> String:
	var ground: GakGridGraph = TacticalRules.graphs_from(rows)[UnitType.GROUND]
	var starts: Array[Array] = SquadScenario.starts()
	var reached: Dictionary = TacticalReach.route_costs(ground, starts[0][0])
	for start: Array in starts:
		if not reached.has(start[0]):
			return "no walk from %s to %s" % [starts[0][0], start[0]]  # not shown: the overlay's English
	for start: Array in starts:
		if not has_cover_within(rows, ground, start[0], SquadTable.action(start[1])):
			return "no cover within one action of %s" % [start[0]]  # not shown: the overlay's English
	return ""


## True when a walk of at most `action` from `start` ends beside trees or rock.
static func has_cover_within(rows: Array[String], ground: GakGridGraph, start: Vector2i, action: int) -> bool:
	var costs: Dictionary = TacticalReach.route_costs(ground, start)
	for cell: Vector2i in costs:
		if int(costs[cell]) <= action and is_covered(rows, cell):
			return true
	return false


## True when `cell` has trees or rock beside it: cover against a shot from
## that side.
static func is_covered(rows: Array[String], cell: Vector2i) -> bool:
	for step: Vector2i in GakGridGraph.DIRECTIONS:
		if SquadCover.worth_at(rows, cell + step) > 0:
			return true
	return false
