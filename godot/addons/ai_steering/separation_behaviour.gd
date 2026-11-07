## Separation: steer away from the neighbours that are too close.
##
## The first of Reynolds' three flocking rules (boids, 1987). Each neighbour
## nearer than `radius` pushes the vehicle straight away from itself, with a
## strength that falls from the whole of `max_force` at contact to nothing at
## the edge of the radius (Millington's linear falloff). The pushes are
## added and the sum clamped, so two neighbours close on the same side push
## harder than one, never more than the vehicle can apply. A neighbour on
## the very same point has no direction to push from and pushes nothing.
##
## It does not find its neighbours. The caller hands it `neighbours` before
## asking -- the ones the vehicle can see, in a fixed order -- and the cost is
## O(neighbours). Finding them is the caller's: a naive search over every
## pair is O(n^2) for a flock of n; a uniform grid makes it about O(n)
## (`godot/demos/flocking/neighbour_grid.gd`).
##
## When not to use it: keeping walls or obstacles away -- they are not
## vehicles; `AvoidBehaviour` is for those.
class_name SeparationBehaviour
extends GakSteeringBehaviour

## The vehicles this one can see, handed over by the caller before each ask.
## The vehicle itself, if listed, is skipped.
var neighbours: Array[SteeringVehicle] = []
## How close is too close, in units. Nobody further than this pushes.
var radius: float


func _init(too_close: float) -> void:
	radius = too_close


## The added pushes of every neighbour inside `radius`, clamped.
func force(vehicle: SteeringVehicle) -> Vector2:
	var push := Vector2.ZERO
	for other: SteeringVehicle in neighbours:
		if other == vehicle:
			continue
		var distance: float = vehicle.position.distance_to(other.position)
		if distance < radius:
			push += Steering.direction_to(other.position, vehicle.position) * (1.0 - distance / radius)
	return Steering.clamped(push * vehicle.max_force, vehicle.max_force)
