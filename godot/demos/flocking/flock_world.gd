## The flocking demo's world, without a node: a hundred boids, the rules
## switched on, the obstacles clicked in, and what the watched boid decided.
##
## Kept out of the scene so a test can fly it headless and twice. A step
## finds every boid's neighbours with a `NeighbourGrid`, asks `Flock` for the
## three forces, adds `AvoidBehaviour`'s for the obstacles, and only then
## moves anybody: every boid decides from the same snapshot, in id order, so
## two runs from one seed agree. The world wraps round at its edges, as the
## first boids' did; a boid near an edge does not see across it.
##
## The numbers are Shiffman's, from Processing's "Flocking" example (the one
## *The Nature of Code* builds in chapter 6): a top speed of 2 pixels a frame
## and a force of 0.03 pixels a frame each frame, at 60 frames a second;
## sight 50, too close 25, separation weighed 1.5. And Shiffman steers a
## frame at a time: his desired velocity minus the velocity is the force,
## clamped, every frame. Here that is a `time_to_target` of one frame, not
## the library's default second -- with a second, measured, the flock flies
## at 76 of its 120 and agrees on a heading less (review of wave 157).
class_name FlockWorld
extends RefCounted

const SIZE := Vector2(920.0, 680.0)
const BOIDS: int = 100
const SEED: int = 150
const MAX_SPEED: float = 120.0
const MAX_FORCE: float = 108.0
## How far a boid sees, and how close is too close.
const SIGHT: float = 50.0
const TOO_CLOSE: float = 25.0
## What avoid adds: its look ahead, its weight against the flock's three,
## and how big a clicked obstacle is.
const LOOK_AHEAD: float = 60.0
const AVOID_WEIGHT: float = 3.0
const OBSTACLE_RADIUS: float = 28.0
const DT: float = 1.0 / 60.0
## The time alignment and cohesion are given to turn: one frame, as Shiffman's.
const TIME_TO_TARGET: float = DT
## The flock's own weights; a switched-off rule's goes to zero.
const WEIGHTS: Array[float] = [1.5, 1.0, 1.0]
## The rules' names, in `Flock.Rule` order: also the words the demo shows.
const RULES: Array[String] = ["separation", "alignment", "cohesion"]  # shown through tr()

var boids: Array[SteeringVehicle] = []
var flock := Flock.new(TOO_CLOSE, TIME_TO_TARGET, PackedFloat64Array(WEIGHTS))
## Which of the three rules count, in `Flock.Rule` order.
var rules_on: Array[bool] = [true, true, true]
var obstacles: Array[Vector2] = []
## The boid whose decision is drawn and reported.
var watched: int = 0
## What the watched boid decided on the last step: the neighbours it
## counted, by index, and its three forces and avoid's, unweighted.
var counted := PackedInt32Array()
## Where every boid was when they decided: the snapshot the forces above
## were worked out from, which the drawing uses, not where the step left them.
var decided_at := PackedVector2Array()
var forces: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
var steps: int = 0
var _grid := NeighbourGrid.new(SIGHT)


func _init() -> void:
	restart()


## The boids back where `SEED` puts them -- bunched in the middle, heading
## every way at half speed -- and no obstacle. The switches stay as they are.
func restart() -> void:
	var dice := RandomNumberGenerator.new()
	dice.seed = SEED
	boids.clear()
	for _index: int in range(BOIDS):
		var at := SIZE / 2.0 + Vector2(dice.randf_range(-200, 200), dice.randf_range(-150, 150))
		var heading := Vector2.RIGHT.rotated(dice.randf_range(0.0, TAU))
		boids.append(SteeringVehicle.new(at, heading * MAX_SPEED / 2.0, MAX_SPEED, MAX_FORCE))
	obstacles.clear()
	steps = 0
	# What the watched boid sees, for the first frame, before anybody moves.
	decide()


## Switches rule `rule` (a `Flock.Rule`) on or off: an off rule's force is
## still worked out and drawn, and weighs nothing in the sum.
func toggle(rule: int) -> void:
	rules_on[rule] = not rules_on[rule]


## The weights this step adds the four forces with: the flock's three, zero
## for a rule switched off, and avoid's.
func weights_now() -> PackedFloat64Array:
	var weights := PackedFloat64Array()
	for rule: int in range(RULES.size()):
		weights.append(WEIGHTS[rule] if rules_on[rule] else 0.0)
	weights.append(AVOID_WEIGHT)
	return weights


## One sixtieth of a second: every boid decides, then every boid moves.
func step() -> void:
	var pushes: Array[Vector2] = decide()
	for index: int in range(boids.size()):
		boids[index].step(pushes[index], DT)
		boids[index].position = Vector2(fposmod(boids[index].position.x, SIZE.x),
			fposmod(boids[index].position.y, SIZE.y))
	steps += 1


## Every boid's force, from where everyone is now; the watched boid's
## neighbours and forces are kept for the drawing.
func decide() -> Array[Vector2]:
	var points := PackedVector2Array()
	for boid: SteeringVehicle in boids:
		points.append(boid.position)
	_grid.fill(points)
	decided_at = points
	var avoid := AvoidBehaviour.new(obstacles, _radii(), LOOK_AHEAD)
	var weights: PackedFloat64Array = weights_now()
	var pushes: Array[Vector2] = []
	for index: int in range(boids.size()):
		var seen: PackedInt32Array = _grid.near(points, index, SIGHT)
		flock.see(_vehicles(seen))
		var four: Array[Vector2] = flock.forces(boids[index])
		four.append(avoid.force(boids[index]))
		pushes.append(Steering.combined(boids[index], four, weights))
		if index == watched:
			counted = seen
			forces = four
	return pushes


## Puts an obstacle at `at`, inside the world.
func place_obstacle(at: Vector2) -> void:
	obstacles.append(at.clamp(Vector2.ZERO, SIZE))


## Watches the next boid, round to the first after the last.
func watch_next() -> void:
	watched = (watched + 1) % boids.size()
	decide()


## The middle of the watched boid's neighbours when it decided, as cohesion
## steered at it; its own place then when it counted nobody.
func centre_seen() -> Vector2:
	if counted.is_empty():
		return decided_at[watched]
	var total := Vector2.ZERO
	for index: int in counted:
		total += decided_at[index]
	return total / counted.size()


## How many distances the grid measured in the last step's queries, against
## the naive search's n(n - 1).
func distances_measured() -> int:
	return _grid.distances


func _vehicles(indices: PackedInt32Array) -> Array[SteeringVehicle]:
	var seen: Array[SteeringVehicle] = []
	for index: int in indices:
		seen.append(boids[index])
	return seen


func _radii() -> PackedFloat64Array:
	var radii := PackedFloat64Array()
	radii.resize(obstacles.size())
	radii.fill(OBSTACLE_RADIUS)
	return radii
