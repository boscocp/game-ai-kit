## What every car in the race is, whoever drives it: one resource, shared.
##
## T23's rule is that a harder driver is faster because it drives better, and
## never because its car was given something. So the car's limits live here,
## in one place, and the race hands the same instance to every car.
## `test/demo_racing/racing_does_not_cheat.gd` holds that field for field.
##
## The numbers are a quick road car's, roughly, in metres and seconds. They
## are not measured from anything: the lesson is the driver, not the car.
class_name RacingPhysics
extends Resource

## The fastest any car goes, in metres a second (about 216 km/h).
@export var top_speed: float = 60.0
## How fast the engine adds speed, in metres a second, every second.
@export var acceleration: float = 8.0
## The hardest the brakes take speed away, in metres a second, every second.
@export var braking: float = 14.0
## The most sideways acceleration the tyres hold before the car will not turn
## any tighter: speed times turn rate never goes past it. 16 is about 1.6 g.
@export var grip: float = 16.0
## The fastest the car turns, in radians a second, however slow it is going.
@export var turn_rate: float = 2.0
## Off the track the grass holds the car to this speed, in metres a second.
@export var off_track_speed: float = 18.0
