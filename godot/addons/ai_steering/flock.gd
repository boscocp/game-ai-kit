## A flock from three rules: separation, alignment and cohesion, added.
##
## Reynolds' boids (1987). No boid knows about the flock. Each one looks at
## the neighbours it can see and asks three questions -- am I too close to
## any of them, which way are they heading, where is their middle -- and
## `Steering.combined` adds the three answers with `weights`, clamped once.
## The flock is what a hundred boids doing that look like from outside.
##
## Cost: O(neighbours) a boid, once the neighbours are known. Finding them is
## the caller's, handed over with `see`: the naive search, every boid against
## every other, is O(n^2) for a flock of n, fine for a few dozen; a uniform
## grid with cells as wide as the sight radius brings it to about O(n)
## (`godot/demos/flocking/neighbour_grid.gd`). Hand the neighbours in a fixed
## order -- by id, as that grid does -- and two runs from one start agree.
##
## When not to use it: a group that must arrive in order, or hold a
## formation. A flock has no places and no leader: it moves as one, and
## nobody in it knows where it is going. Follow a path or a leader instead.
## A weight of zero switches a rule off.
class_name Flock
extends GakSteeringBehaviour

## The order of the three rules in `weights` and in `forces`.
enum Rule { SEPARATION, ALIGNMENT, COHESION }

var separation: SeparationBehaviour
var alignment: AlignmentBehaviour
var cohesion: CohesionBehaviour
## How much each rule counts, in `Rule` order. Separation weighs most by
## default, as in Shiffman's flocking example (*The Nature of Code*): a boid
## that must choose between keeping up and not colliding should not collide.
## Set once, when the flock is made: these are a designer's numbers, not a
## model's, and a caller that switches a rule off mid-game passes its own
## weights to `Steering.combined`, as the flocking demo does. Keep it so:
## `scripts/check_no_training.py`'s N3 net refuses any assignment to
## `.weights` in GDScript, a fitted model's or not.
var weights: PackedFloat64Array


func _init(too_close: float, within: float = 1.0,
		weighed: PackedFloat64Array = PackedFloat64Array([1.5, 1.0, 1.0])) -> void:
	weights = weighed
	separation = SeparationBehaviour.new(too_close)
	alignment = AlignmentBehaviour.new(within)
	cohesion = CohesionBehaviour.new(within)


## Hands the same neighbours to all three rules: the vehicles the next boid
## asked can see, in a fixed order.
func see(neighbours: Array[SteeringVehicle]) -> void:
	separation.neighbours = neighbours
	alignment.neighbours = neighbours
	cohesion.neighbours = neighbours


## The three rules' forces, in `Rule` order, each clamped and unweighted --
## what the demo draws, so a person sees which rule pulls which way.
func forces(vehicle: SteeringVehicle) -> Array[Vector2]:
	return [separation.force(vehicle), alignment.force(vehicle), cohesion.force(vehicle)]


## The three forces times their weights, added, and clamped once.
func force(vehicle: SteeringVehicle) -> Vector2:
	return Steering.combined(vehicle, forces(vehicle), weights)
