# T22's three claims, over seeded starts, because one trajectory that happens
# to end in the right place proves nothing:
#
#   1. arrive comes to rest inside its braking radius and stays there --
#      once at rest, it is still at rest, and still inside, every step after;
#   2. seek at a target that does not move never comes to rest: the defect
#      arrive exists to fix, measured rather than claimed;
#   3. no behaviour returns a force above the vehicle's maximum, or one that
#      is not a number, on any input -- a target on top of the vehicle and
#      targets at infinity included.
#
# At rest: under a thousandth of top speed for a whole second. Measured
# before it was written: over 300 starts seek's longest such run was one
# step, and arrive ended near 1e-11.
#
# Each claim is first shown a case it must refuse -- seek passed off as
# arrive, arrive passed off as seek, a behaviour that forgets to clamp -- so
# a check that only goes green cannot pass.
#
#     ./scripts/godot --headless --path godot -s res://test/steering_properties.gd
#
# Exit codes: 0 every claim held; 1 one did not.
extends SceneTree

const SEED: int = 22
const STARTS: int = 100
const STEPS: int = 1800
const DT: float = 1.0 / 60.0
const REST_FRACTION: float = 0.001
const REST_STEPS: int = 60
const BRAKING_RADIUS: float = 8.0


## A behaviour that forgets the one rule: twice the force anybody may ask for.
class Unclamped extends SteeringBehaviour:
	## Twice the vehicle's limit, to the right, whatever is asked.
	func force(vehicle: SteeringVehicle) -> Vector2:
		return Vector2.RIGHT * vehicle.max_force * 2.0


func _init() -> void:
	var failures: Array[String] = _planted()
	var dice := RandomNumberGenerator.new()
	dice.seed = SEED
	var settled: int = 0
	for start: int in range(STARTS):
		var target := Vector2(dice.randf_range(-50, 50), dice.randf_range(-50, 50))
		var car: SteeringVehicle = _random_vehicle(dice)
		var arriving: String = _why_not_at_rest(_copy(car), ArriveBehaviour.new(target, BRAKING_RADIUS), target)
		if arriving != "":
			failures.append("start %d, arrive: %s" % [start, arriving])
		var seeking: int = _longest_rest(_copy(car), SeekBehaviour.new(target))
		if seeking >= REST_STEPS:
			failures.append("start %d, seek rested for %d steps" % [start, seeking])
		settled += 1 if arriving == "" else 0
	failures.append_array(_forces_bounded(dice))
	for failure: String in failures:
		print(failure)
	print("steering properties: %d starts, arrive settled in %d, %d failure(s)" % [STARTS, settled, failures.size()])
	quit(1 if not failures.is_empty() else 0)


# Claim 1, for one start: "" when it came to rest inside the radius and
# never left either, else what went wrong.
func _why_not_at_rest(car: SteeringVehicle, behaviour: SteeringBehaviour, target: Vector2) -> String:
	var resting: int = 0
	for step: int in range(STEPS):
		car.step(behaviour.force(car), DT)
		var still: bool = car.speed() < REST_FRACTION * car.max_speed
		if resting >= REST_STEPS and (not still or car.position.distance_to(target) >= BRAKING_RADIUS):
			return "rested, then moved again at step %d" % step
		resting = resting + 1 if still else 0
	if resting < REST_STEPS:
		return "still moving at %.4f after %d steps" % [car.speed(), STEPS]
	if car.position.distance_to(target) >= BRAKING_RADIUS:
		return "rested %.2f from the target, outside the braking radius" % car.position.distance_to(target)
	return ""


# Claim 2's measure: the longest run of steps spent at rest.
func _longest_rest(car: SteeringVehicle, behaviour: SteeringBehaviour) -> int:
	var longest: int = 0
	var current: int = 0
	for _step: int in range(STEPS):
		car.step(behaviour.force(car), DT)
		current = current + 1 if car.speed() < REST_FRACTION * car.max_speed else 0
		longest = maxi(longest, current)
	return longest


# Claim 3: every behaviour, from a vehicle still and one at full speed, at
# random places and at the awkward ones.
func _forces_bounded(dice: RandomNumberGenerator) -> Array[String]:
	var failures: Array[String] = []
	for trial: int in range(STARTS):
		var car: SteeringVehicle = _random_vehicle(dice)
		var places: Array[Vector2] = [car.position, Vector2(INF, 0), Vector2(-INF, INF), Vector2(1e30, -1e30),
			Vector2(dice.randf_range(-50, 50), dice.randf_range(-50, 50))]
		for place: Vector2 in places:
			failures.append_array(_unbounded(car, _every_behaviour(place), "trial %d at %s" % [trial, place]))
	return failures


func _every_behaviour(place: Vector2) -> Array[SteeringBehaviour]:
	return [SeekBehaviour.new(place), ArriveBehaviour.new(place, BRAKING_RADIUS),
		PursueBehaviour.new(place, Vector2(3, -4)), AvoidBehaviour.new([place] as Array[Vector2], PackedFloat64Array([2.0]), 5.0)]


# The behaviours of `behaviours` whose force is too long or not a number.
func _unbounded(car: SteeringVehicle, behaviours: Array[SteeringBehaviour], where: String) -> Array[String]:
	var failures: Array[String] = []
	for behaviour: SteeringBehaviour in behaviours:
		var force: Vector2 = behaviour.force(car)
		var name: String = behaviour.get_script().get_global_name()
		if not force.is_finite() or force.length() > car.max_force * (1.0 + 1e-5):
			failures.append("%s: %s asked for %s, more than %.1f" % [where, name, force, car.max_force])
	return failures


# Each claim shown the case it must refuse.
func _planted() -> Array[String]:
	var failures: Array[String] = []
	var target := Vector2(20, 15)
	var car := SteeringVehicle.new(Vector2.ZERO, Vector2(0, -5), 10.0, 20.0)
	if _why_not_at_rest(_copy(car), SeekBehaviour.new(target), target) == "":
		failures.append("planted: seek passed as arrive")
	if _longest_rest(_copy(car), ArriveBehaviour.new(target, BRAKING_RADIUS)) < REST_STEPS:
		failures.append("planted: arrive passed as seek")
	if _unbounded(car, [Unclamped.new()] as Array[SteeringBehaviour], "planted").is_empty():
		failures.append("planted: a force twice the limit was let through")
	return failures


func _random_vehicle(dice: RandomNumberGenerator) -> SteeringVehicle:
	var moving := Vector2(dice.randf_range(-10, 10), dice.randf_range(-10, 10)).limit_length(10.0)
	return SteeringVehicle.new(Vector2(dice.randf_range(-50, 50), dice.randf_range(-50, 50)), moving, 10.0, 20.0)


func _copy(car: SteeringVehicle) -> SteeringVehicle:
	return SteeringVehicle.new(car.position, car.velocity, car.max_speed, car.max_force)
