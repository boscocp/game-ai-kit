## Any of the four searches, held as the `Pathfinder` a game asks for.
##
## `Pathfinder` is `ai_core`'s: a route across a `GridGraph`, so that a game's
## code can be handed a pathfinder without depending on this addon. The
## searches here work on any `SearchGraph`, so they no longer are one; this is
## the adapter between the two, and the only file in `ai_search` that knows
## both a grid and a `Pathfinder`.
##
## When not to use it: when you want the expansion as well as the route, or a
## graph that is not a grid. Call `Search.search` with a `SearchGraph`.
class_name GridPathfinder
extends Pathfinder

var _search: Search


## A pathfinder answering with `search`, A\* when none is given.
func _init(search: Search = null) -> void:
	_search = search if search != null else AStarSearch.new()


## The `Pathfinder` contract: the route, excluding `from` and including `to`,
## or an empty array -- the search's answer with the expansion thrown away.
func find_path(graph: GridGraph, from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	return _search.search(GridSearchGraph.new(graph), from, to).path
