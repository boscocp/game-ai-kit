# The minimal example on docs/techniques/ai_perception.md, run by
# watcher_example_test.gd. A guard of your own that sees in a cone, off any
# grid, and grows aware of what it sees by degrees: calm, then suspicious,
# then alert -- and back down through each when it loses sight.
extends Node2D

## How aware it is, as data: rising past each phase's share of the peak, and
## falling a fifth of the peak a second. Once alert, it stays at least
## suspicious for five seconds.
const AWARENESS: Dictionary = {
	"peak": 1.0,
	"decay": 0.2,
	"phases": [
		{"name": "calm", "at": 0.0},
		{"name": "suspicious", "at": 0.3},
		{"name": "alert", "at": 0.8},
	],
	"caution": {"floor": 0.3, "seconds": 5.0},
}

## How fast awareness rises while it sees, in shares of the peak a second.
const RISE: float = 0.5

## Who it is watching for. Set it from your game.
var target: Node2D

## 300 units of reach, 45 degrees either side of where the node faces.
var cone := VisionCone.new(300.0, 45.0)

var _awareness := Awareness.new()
var _seconds: float = 0.0


func _physics_process(delta: float) -> void:
	_seconds += delta
	_awareness.step(AWARENESS, sees_target(), RISE, delta, _seconds)


## True when the target is within reach, inside the cone this node faces
## along (its rotation), and nothing stands between.
func sees_target() -> bool:
	if target == null:
		return false
	return cone.sees_in_the_open(global_position, global_rotation, target.global_position, _line_is_clear)


## "calm", "suspicious" or "alert": what your game shows above the guard.
func phase() -> String:
	return Awareness.phase_name(_awareness.value, AWARENESS)


# Your walls go here: a raycast from the guard to the target, say. The
# open field of this example has none.
func _line_is_clear() -> bool:
	return true
