## What a driver sees, made from the world: the one place a decision's
## snapshot is filled in.
##
## The world here is the track (its racing line and its width) and the
## cars as bodies. The view is in the driver's own frame, so the decision
## that reads it never meets a coordinate of the track: the line ahead
## becomes metres forward and to the left of the car, a rival becomes
## metres ahead along the track and to the left of the line. What a driver
## cannot see is not here: a rival's controls, its level, its plan.
## Linear in the horizon and the number of cars.
##
## When not to use it: a car that has left the track entirely. The nearest
## sample is looked for near the last one, which a car cut across the
## infield would outrun.
class_name RaceSenses3D
extends RefCounted

## How far behind and ahead along the track a rival is still seen, metres.
const SEEN_BEHIND: float = 30.0
const SEEN_AHEAD: float = 200.0


## The view of car `number`, nearest the track's sample `samples[number]`,
## among `cars`, `time` seconds into the race and for a decision `step`
## seconds long. A ghost race's cars drive through each other and do not
## see each other: each races alone (`with_rivals` false).
static func view_of(track: RaceTrack3D, cars: Array[RaceCar3D], samples: PackedInt64Array,
		number: int, time: float, step: float, with_rivals: bool = true) -> RaceView3D:
	var view := RaceView3D.new()
	var car: RaceCar3D = cars[number]
	var here: int = samples[number]
	var at: Vector2 = on_map(car)
	var forward: Vector2 = _facing(car)
	var left: Vector2 = RaceTrack3D.left_of(forward)
	view.time = time
	view.step = step
	view.speed = car.forward_speed()
	view.cross_track = track.sideways(at, here) - track.offsets[here]
	for ahead: int in range(RaceView3D.HORIZON):
		var sample: int = track.wrapped(here + ahead)
		var offset: Vector2 = track.line[sample] - at
		view.line_forward.append(offset.dot(forward))
		view.line_left.append(offset.dot(left))
		view.room_left.append(track.half_width - track.offsets[sample])
		view.room_right.append(track.half_width + track.offsets[sample])
	for other: int in range(cars.size()):
		if other != number and with_rivals:
			_see(view, track, cars[other], here, samples[other])
	return view


## Where a car is on the map, (x, z).
static func on_map(car: RaceCar3D) -> Vector2:
	return Vector2(car.global_position.x, car.global_position.z)


## The way a car points, on the map, as a unit vector.
static func _facing(car: RaceCar3D) -> Vector2:
	var forward: Vector3 = -car.global_transform.basis.z
	return Vector2(forward.x, forward.z).normalized()


# A rival at sample `there`, added to the view if it is near enough along
# the track, as [ahead, left of the line, speed].
static func _see(view: RaceView3D, track: RaceTrack3D, rival: RaceCar3D, here: int, there: int) -> void:
	var half: int = track.centre.size() / 2
	var ahead: float = (posmod(there - here + half, track.centre.size()) - half) * RaceTrack3D.SPACING
	if ahead < -SEEN_BEHIND or ahead > SEEN_AHEAD:
		return
	var left_of_line: float = track.sideways(on_map(rival), there) - track.offsets[there]
	view.rivals.append(PackedFloat64Array([ahead, left_of_line, rival.forward_speed()]))
