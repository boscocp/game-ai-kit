## What every 3D car in the race is, whoever drives it: one resource, shared.
##
## T23's rule carries over whole: a harder driver is faster because it drives
## better, never because its car was given something. So the car's numbers
## live here, the race hands the same instance to every car, and
## `test/racing3d/racing3d_does_not_cheat.gd` holds that field for field.
##
## The numbers are a small racing car's, roughly, in kilograms, metres,
## newtons and seconds. They are not measured from any car: the lesson is
## the driver, and the physics is only there so the driver cannot know
## exactly what its car will do.
class_name CarPhysics3D
extends Resource

## The car's mass, in kilograms.
@export var mass: float = 1200.0
## Metres between the front and the rear axle.
@export var wheelbase: float = 2.6
## Metres between the left and the right wheel of an axle.
@export var track_width: float = 1.6
## How far below the centre of mass the springs are mounted, in metres. The
## centre of mass sits above the road, so a force at the tyres pitches and
## rolls the body: that is where weight transfer comes from.
@export var mount_drop: float = -0.15
## The spring's length with no load on it, in metres.
@export var rest_length: float = 0.3
@export var wheel_radius: float = 0.33
## Newtons per metre the spring is compressed. A quarter of the car's weight
## compresses it by about a tenth of a metre.
@export var spring: float = 30000.0
## Newtons per metre a second of compression: about 0.6 of the damping that
## would stop the body bouncing at all.
@export var damper: float = 3600.0
## The most force a tyre holds, as a fraction of the load on it: 1.05 times
## the load, on tarmac whose own grip is 1.
@export var tyre_grip: float = 1.05
## The slip angle, in radians, at which a tyre gives its most sideways
## force. Below it the force grows with the slip; past it the tyre slides.
@export var peak_slip: float = 0.12
## What a sliding tyre keeps of its peak, once it is twice past the peak.
@export var slide_grip: float = 0.8
## The rear tyres are wider, as a racing car's are: this much more grip, and
## their peak this much sooner. With the same tyres all round, the rear lets
## go first whenever braking or the engine takes some of its grip, and the
## car spins; with these the front lets go first, and the car runs wide --
## understeer, which a driver can catch.
@export var rear_grip: float = 1.15
@export var rear_peak: float = 0.75
## The engine's push at the rear wheels, in newtons, at full throttle --
## until its power runs out: above power / engine_force metres a second
## (about 17) it pushes with `engine_power` watts over the speed instead.
## Full push at speed would leave the rear tyres no grip to turn with.
@export var engine_force: float = 6000.0
@export var engine_power: float = 100000.0
## The fastest any car goes, in metres a second (180 km/h): above it the
## engine gives nothing.
@export var top_speed: float = 50.0
## Newtons of brake at full pedal, all four wheels together, and the share
## of it the front wheels take: about the share of the load they carry
## while braking hard, so the rear tyres keep some grip to steer with.
@export var brake_force: float = 11500.0
@export var brake_front: float = 0.8
## Air resistance: newtons per (metre a second) squared.
@export var drag: float = 0.4
## The front wheels' widest angle, in radians, and how fast they turn to it.
@export var max_steer: float = 0.5
@export var steer_speed: float = 2.5


## The fields, by name, as plain values: what the cheat check compares at
## the start of a race and on every frame after.
func fields() -> Dictionary:
	var values: Dictionary = {}
	for property: Dictionary in get_property_list():
		if property["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
			values[property["name"]] = get(property["name"])
	return values
