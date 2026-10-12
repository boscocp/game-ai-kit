## What `ai_search` must provide: a route between two cells, or nothing.
##
## This is an interface, and in GDScript an interface is a base class whose
## methods fail loudly. There is no `abstract` keyword, so the choice is between
## a comment asking politely and a method that refuses to be inherited without
## being replaced. This file is the second one.
##
## An implementation must guarantee:
##
## * the returned path **excludes** `from` and **includes** `to`, which is the
##   shape `Move` expects and the reason it is written down here rather than
##   rediscovered in each addon;
## * every cell in it is passable on `graph` at the time of the call;
## * consecutive cells are cardinal neighbours;
## * an empty array means *no route exists*, and is never used to mean "the
##   unit is already there" -- that case also returns empty, and the caller
##   tells them apart by comparing `from` and `to` itself;
## * the call does not change `graph`.
##
## When not to use it: anything that needs the cost of the route as well. Ask
## the returned path with `Move.cost_on`, which is the one definition of cost.
class_name Pathfinder
extends RefCounted


## A route from `from` to `to`, or an empty array when there is none.
func find_path(graph: GridGraph, from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	push_error("Pathfinder.find_path must be overridden; %s %s %s" % [graph, from, to])
	return []
