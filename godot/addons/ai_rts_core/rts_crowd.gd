## How a unit following a flow field takes its step among the others: a port.
##
## The core walks every unit alone. On a move order it follows the arrow
## under its feet from cell centre to cell centre, so a group sent to one
## point files into a column that converges on each cell's middle -- and the
## core's own separation stays off on a move order, because nudging that
## column jammed T19's two armies in the wall's gaps (`RtsWorld._keep_apart`).
##
## Something above the core may walk a group differently -- a flock, in the
## RTS game (`godot/game/rts/rts_flock.gd`) -- without the core depending on
## it: the world asks its `crowd` twice a tick. `before_moves`, once, before
## any unit acts, so whatever is worked out from where everybody stands is
## worked out from one moment; then `step_to`, for each unit as it takes a
## step along a field. The base class is the core's own walk, unchanged:
## a world with it steps to the same digest as one that never had a crowd.
##
## A world's crowd is part of the match, as its seed is: a recording replays
## only on a world given the same crowd, switched the same way.
##
## When not to use it: walking that is not a field's -- the last straight
## stretch to a goal, a chase. Those stay the core's.
class_name GakRtsCrowd
extends RefCounted


## Called once a tick, before any unit acts. The base does nothing.
func before_moves(_world: RtsWorld) -> void:
	pass


## Where `unit` stands after one step of at most `stride` towards
## `waypoint`, the next cell centre its flow field points at. The base walks
## straight at it, as the core always has.
func step_to(unit: RtsUnit, waypoint: Vector2, stride: float) -> Vector2:
	return unit.position.move_toward(waypoint, stride)
