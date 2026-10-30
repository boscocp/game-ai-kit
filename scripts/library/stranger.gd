## What a stranger's project does with two unzipped addons: find a route.
##
## Run by `scripts/library_check.py` in a blank Godot project that holds
## nothing but `addons/ai_core/` and `addons/ai_search/` as the release zips
## them. It uses the classes as the documentation shows -- a `GakGridGraph`,
## a `GakPathfinder` answered by `AStarSearch` -- and prints one marker line
## when the route is the one the board allows. A missing class is a parse
## error before `_init` runs, and a script error inside it skips the marker;
## the caller requires the marker, not only the exit code (CLAUDE.md, "A
## script error in a `-s` script does not fail the run").
extends SceneTree

const MARKER: String = "LIBRARY-CHECK: the route goes round the wall"


func _init() -> void:
	var board := GakGridGraph.new(6, 4)
	for row: int in range(0, 3):
		board.block(Vector2i(3, row))
	var pathfinder: GakPathfinder = GridPathfinder.new(AStarSearch.new())
	var route: Array[Vector2i] = pathfinder.find_path(board, Vector2i(0, 0), Vector2i(5, 0))
	var through_the_gap: bool = route.has(Vector2i(3, 3)) and route.back() == Vector2i(5, 0)
	if through_the_gap:
		print(MARKER)
	quit(0 if through_the_gap else 1)
