# The table on docs/concepts/steering.md, "What each rule was doing": the
# demo's world flown ten seconds with nothing switched off, then with each
# rule off in turn, and measured.
#
# A measurement, not a gate: `make measure-flocking` runs it through
# scripts/godot_checked.py, which fails it on any engine error it prints,
# and it is not in `make check`. Seeded and stepped, so it prints the same
# numbers on any machine; the page's table is its output.
#
#     ./scripts/godot --headless --path godot -s res://test/demo_flocking/flocking_table.gd
#
# Exit codes: 0 it printed a row for each case; 1 a row came out not a number.
extends SceneTree

## Ten seconds at sixty steps a second.
const STEPS: int = 600


func _init() -> void:
	print("| switched off | nearest other, on average | speed, of %d | headings agree | neighbours | distances a step |"
		% FlockWorld.MAX_SPEED)
	print("|---|---|---|---|---|---|")
	var broken: int = 0
	for off: int in [-1, Flock.Rule.SEPARATION, Flock.Rule.ALIGNMENT, Flock.Rule.COHESION]:
		var row: PackedFloat64Array = _measure(off)
		broken += 0 if Array(row).all(func(value: float) -> bool: return is_finite(value)) else 1
		var name: String = "nothing" if off < 0 else FlockWorld.RULES[off]
		print("| %s | %.1f | %.0f | %.2f | %.1f | %d |" % [name, row[0], row[1], row[2], row[3], int(row[4])])
	quit(1 if broken > 0 else 0)


# [nearest other on average, speed, how far the headings agree, neighbours
# a boid sees, distances the grid measured in the last step], after STEPS
# steps with rule `off` switched off (none when it is negative).
func _measure(off: int) -> PackedFloat64Array:
	var world := FlockWorld.new()
	if off >= 0:
		world.toggle(off)
	for _step: int in range(STEPS):
		world.step()
	var points := PackedVector2Array()
	var heading := Vector2.ZERO
	var speed: float = 0.0
	for boid: SteeringVehicle in world.boids:
		points.append(boid.position)
		heading += boid.velocity.normalized()
		speed += boid.speed()
	var nearest: float = 0.0
	var seen: int = 0
	for index: int in range(points.size()):
		nearest += _nearest(points, index)
		seen += NeighbourGrid.near_naively(points, index, FlockWorld.SIGHT).size()
	var count: float = points.size()
	return PackedFloat64Array([nearest / count, speed / count, heading.length() / count, seen / count,
		world.distances_measured()])


# How far point `index` is from the nearest other.
func _nearest(points: PackedVector2Array, index: int) -> float:
	var nearest: float = INF
	for other: int in range(points.size()):
		if other != index:
			nearest = minf(nearest, points[index].distance_to(points[other]))
	return nearest
