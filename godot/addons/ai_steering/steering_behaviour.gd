## One steering behaviour: asked about a vehicle, answers with a force.
##
## The whole contract every behaviour here keeps. It reads the vehicle and
## whatever it was given (a target, obstacles); it changes nothing; and the
## force it returns is never longer than `vehicle.max_force` --
## `test/steering_properties.gd` asks every behaviour that on every kind of
## input, a target on top of the vehicle and one at infinity included.
##
## When not to use it: a decision that is not "which way, how hard" -- which
## target to chase is a choice made above this, by whatever sets the target.
class_name SteeringBehaviour
extends RefCounted


## The force this behaviour asks of `vehicle` now. The base asks for none.
func force(_vehicle: SteeringVehicle) -> Vector2:
	return Vector2.ZERO
