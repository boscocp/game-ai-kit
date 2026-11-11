## What a search found, and what it had to look at to find it.
##
## The path alone is the boring half. Four algorithms on the same map return
## the same path and arrive at it completely differently, and the difference is
## only visible in what they expanded -- which is why `expanded` is a field
## rather than a debug print, and why the demo can draw it.
##
## `expanded` is in the order the search took the cells off its frontier, so
## drawing it in order replays the search. `frontier` is what was still waiting
## when it stopped, which is what makes "A* stopped early" something you can
## see rather than something you are told.
##
## When not to use it: a search that runs over several frames. This is the
## result of a finished search; a running one needs its own state object.
class_name SearchResult
extends RefCounted

## The cost of a route that does not exist. The same number as
## `GakGridGraph.BLOCKED`, so a grid's caller compares it with what it knows; named
## here because a search over waypoints has no grid to borrow it from.
const NO_ROUTE: int = -1

## The route, excluding the start and including the goal, exactly as
## `GakPathfinder` requires. Empty when there is no route -- and also empty when
## the start *is* the goal, which is why `reached` exists.
var path: Array[Vector2i]

## Every cell taken off the frontier, in order.
var expanded: Array[Vector2i]

## What was still waiting when the search stopped.
var frontier: Array[Vector2i]

## What the path costs on the graph it was found on, or `NO_ROUTE` when
## there is no path. Carried rather than recomputed: the caller would have
## to be handed the graph again to ask, and two answers to one question is how
## they drift.
var cost: int

## True when the goal was reached, including the case where the search started
## on it. Tells the two empty paths apart.
var reached: bool


func _init(found_path: Array[Vector2i], cells_expanded: Array[Vector2i],
		cells_waiting: Array[Vector2i], path_cost: int, goal_reached: bool) -> void:
	path = found_path
	expanded = cells_expanded
	frontier = cells_waiting
	cost = path_cost
	reached = goal_reached


## The result of a search that found nothing, with its work still on show.
##
## A failed search is the one whose expansion is most worth looking at: it is
## the picture of the whole reachable region, which is how you see that the
## goal was walled off rather than that the search was broken.
static func nothing_found(cells_expanded: Array[Vector2i],
		cells_waiting: Array[Vector2i]) -> SearchResult:
	# `new()`, not its own class name: naming it would make the script hold itself (T162, docs/godot/exit-leaks.md).
	return new(
		[] as Array[Vector2i], cells_expanded, cells_waiting, NO_ROUTE, false
	)
