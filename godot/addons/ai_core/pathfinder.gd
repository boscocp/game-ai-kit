## What `ai_search` must provide: a route between two cells, or nothing.
##
## This is an interface, and GDScript has one: `@abstract`, on the class and on
## each method. The engine then refuses to load a subclass that has not replaced
## them -- a parse error at load time, not a message in a log nobody reads.
##
## The first version of this file said the keyword did not exist, and used
## `push_error` with a default return instead. That was wrong twice. It was
## wrong about the engine, measured on the pinned 4.7.2 and written up in
## `docs/godot/addon-anatomy.md`. And the mechanism was worse than the one it
## claimed not to have: the default it returned was an **empty array**, which
## this very file defines below as the legitimate answer "no route exists". A
## forgotten override was indistinguishable from a search that found nothing,
## in exactly the build where nobody is watching the log.
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
@abstract
class_name Pathfinder
extends RefCounted


## A route from `from` to `to`, or an empty array when there is none.
@abstract func find_path(graph: GridGraph, from: Vector2i, to: Vector2i) -> Array[Vector2i]
