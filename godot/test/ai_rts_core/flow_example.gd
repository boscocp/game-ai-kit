# The minimal example on docs/techniques/ai_rts_core.md, run by
# flow_example_test.gd. A map of your own where any number of units are
# sent to one cell, and the way there is worked out once for all of them,
# a slice every frame.
extends Node

## How many steps the flood may take in one frame -- each step takes one
## cell off its queue, a stale copy or an empty bucket included, so a few
## settle nothing: the share of the frame you give it. More, and the field
## is ready sooner.
const STEPS_PER_FRAME: int = 64

## Your map: 1 is open ground, dearer cells are slower, blocked is a wall.
## Change it before you send anyone; a field already built does not see it.
var map := GridGraph.new(24, 16)

var _field: FlowField


func _physics_process(_delta: float) -> void:
	if _field != null:
		_field.settle(STEPS_PER_FRAME)


## Send everybody to `goal`. The field is built over the next frames.
func send_everyone_to(goal: Vector2i) -> void:
	_field = FlowField.new(map, goal)


## Which way a unit standing on `cell` steps now: one of the four
## directions, or zero when it has arrived, when nothing reaches the goal
## from there, or while the field is still being built.
func step_from(cell: Vector2i) -> Vector2i:
	if _field == null or not _field.complete:
		return Vector2i.ZERO
	return _field.direction_at(cell)
