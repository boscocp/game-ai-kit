# The minimal example on docs/techniques/ai_search.md, run by
# route_example_test.gd. A node of your own that finds a route across a
# board of its own as it enters the scene tree.
extends Node

## The route it found: the start left out, the goal included.
var route: Array[Vector2i] = []


func _ready() -> void:
	# Six by four, open ground, and a wall down column 3 with a gap at the
	# bottom -- the route has to find the gap.
	var board := GridGraph.new(6, 4)
	for row: int in range(0, 3):
		board.block(Vector2i(3, row))
	# Held as ai_core's Pathfinder, so the caller does not care which search
	# answers: swap AStarSearch for DijkstraSearch and nothing else changes.
	var pathfinder: Pathfinder = GridPathfinder.new(AStarSearch.new())
	route = pathfinder.find_path(board, Vector2i(0, 0), Vector2i(5, 0))
