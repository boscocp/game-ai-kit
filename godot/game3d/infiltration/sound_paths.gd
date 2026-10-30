## How a noise reaches the guards of a level: the flood along its walk
## graph, the loudness at each listener, and the off-screen halving.
##
## The wiring, not a technique: `ai_search`'s `CostFlood` over the level's
## `GakGridGraph` gives every cell's path length from the noise, cut off at its
## radius, and `ai_perception`'s `PathHearing` turns one into a loudness
## [Walsh 2015; Miles 2013]. A wall is a blocked cell, so nothing is heard
## through it. The halving is Walsh's: a guard off screen and further than
## the row's `off_screen_beyond` from the player hears minor events -- the
## row's `minor_priority` and below -- at the row's `off_screen_factor` of
## the radius [Walsh 2015]. Which guards are off screen is the camera's to
## say, in T70; here it is an argument.
##
## The flood is linear in the cells within the radius, squared by the
## frontier scan (`dijkstra.gd` says why); a loudness is constant time.
##
## What the flood walks is the level's walk graph, and that has costs: a
## 4-connected grid, so the radius is a diamond, not a circle (a footstep
## of radius 6 is not heard at 3 across and 3 along, 4.24 m in a straight
## line); ground that is slow to walk is quieter to hear across; a door is
## only blocked or open; and there is no height. T70 should flood an
## octile graph, or a sound graph of its own, if those matter on its level.
##
## When not to use it: a level whose sound should carry through thin walls.
## Give those walls a cost instead of blocking them, and this still works.
class_name SoundPaths
extends RefCounted


## Every cell a noise made at `source` reaches within `radius` metres along
## `level`, cells `cell_size` metres wide: cell -> path length in metres.
static func lengths(level: GakGridGraph, source: Vector2i, radius: float, cell_size: float) -> Dictionary[Vector2i, float]:
	var limit: int = floori(radius / cell_size)
	var reached: Dictionary[Vector2i, int] = CostFlood.within(GridSearchGraph.new(level), source, limit)
	var metres: Dictionary[Vector2i, float] = {}
	for cell: Vector2i in reached:
		metres[cell] = reached[cell] * cell_size
	return metres


## The loudness at `listener` of a noise whose flood is `flooded`, of
## `radius` metres, for a listener whose radius is scaled by `factor`.
static func loudness_at(flooded: Dictionary[Vector2i, float], listener: Vector2i, radius: float, factor: float) -> float:
	return PathHearing.loudness(flooded.get(listener, PathHearing.NO_PATH), radius, factor)


## The factor a listener's radius is scaled by: the row's off-screen factor
## for an event of `priority` no higher than the row's minor one, heard by a
## guard `on_screen` or not, `from_player` metres from the player; else 1.
static func listener_factor(hearing: Dictionary, priority: int, on_screen: bool, from_player: float) -> float:
	var minor: bool = priority <= int(hearing["minor_priority"])
	if minor and not on_screen and from_player > float(hearing["off_screen_beyond"]):
		return float(hearing["off_screen_factor"])
	return 1.0
