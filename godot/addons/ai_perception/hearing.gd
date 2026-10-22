## How loud a noise is where a listener stands, from 1 at the source to 0.
##
## A noise is a cell and a radius: a footstep fills a small one, a sprint a
## large one. Loudness falls off in a straight line with distance, and walls
## do not stop it. Constant time per listener.
##
## This is the 2D stealth demo's hearing, whose guards are meant to hear
## through its walls. A level whose walls should stop sound uses
## `PathHearing`, which takes the length of the way round instead.
##
## When not to use it: when the walls should matter. Sound that goes round
## corners is a search over the grid (`CostFlood`, a Dijkstra flood from the
## source) and `PathHearing` on what it finds.
class_name Hearing
extends RefCounted


## How loud a noise of `radius` cells, made at `source`, is at `listener`.
##
## 0 at the edge of the radius and beyond, and for a silent action (radius 0):
## standing still makes no sound, rather than a sound that divides by zero.
static func loudness_at(listener: Vector2i, source: Vector2i, radius: float) -> float:
	if radius <= 0.0:
		return 0.0
	return clampf(1.0 - Vector2(listener - source).length() / radius, 0.0, 1.0)
