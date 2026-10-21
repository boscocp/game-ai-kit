## What each driver is deciding, drawn on the road (invariant 13).
##
## Redrawn every frame from what the drivers decided last, never from
## anything they did not:
##
##   * the **aim**: a white post where each car's pursuit is steering;
##   * the **braking point**: a white bar across the road where the car must
##     already be braking -- the first point ahead its speed profile allows
##     less than it is doing. A harder car's bar comes later;
##   * each **tyre**, a post at its patch coloured by how much of its grip it
##     is using: green with grip to spare, yellow near the limit, red when
##     it is past its peak slip and sliding;
##   * for the watched car, the **heat line**: the array across the road at
##     its aim, cool blue to hot red, and the ball, a yellow post, where it
##     has rolled -- where the car means to be.
##
## When not to use it: in a check. Nothing here is read back by anything.
class_name RaceOverlay3D
extends MeshInstance3D

const AIM_COLOUR: Color = Color(1.0, 1.0, 1.0)
const BRAKE_COLOUR: Color = Color(1.0, 1.0, 1.0)
const GRIP_SPARE: Color = Color(0.2, 0.85, 0.3)
const GRIP_NEAR: Color = Color(1.0, 0.85, 0.15)
const SLIDING: Color = Color(0.95, 0.2, 0.15)
const COOL: Color = Color(0.2, 0.4, 1.0)
const HOT: Color = Color(1.0, 0.15, 0.1)
const BALL_COLOUR: Color = Color(1.0, 0.9, 0.1)
## The heat a cell is drawn fully hot at.
const HOTTEST: float = 4.0

var _lines := ImmediateMesh.new()
var _material := StandardMaterial3D.new()


func _init() -> void:
	name = "Overlay"
	mesh = _lines
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.vertex_color_use_as_albedo = true
	_material.no_depth_test = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Draw every car's decision in `race`, and the heat line of car `watched`.
func draw(race: Race3D, watched: int) -> void:
	_lines.clear_surfaces()
	if not race.racing or race.views.has(null):
		return
	_lines.surface_begin(Mesh.PRIMITIVE_LINES, _material)
	for number: int in range(race.cars.size()):
		_car(race, number)
	if watched >= 0:
		_heat(race, watched)
	_lines.surface_end()


## The colour of a tyre giving `force` of a `limit`, slipping `slip` radians
## past a peak of `peak`.
static func tyre_colour(force: float, limit: float, slip: float, peak: float) -> Color:
	if limit <= 0.0 or absf(slip) > peak:
		return SLIDING if limit > 0.0 else Color(0.5, 0.5, 0.5)
	return GRIP_SPARE.lerp(GRIP_NEAR, clampf(force / limit, 0.0, 1.0))


func _car(race: Race3D, number: int) -> void:
	var car: RaceCar3D = race.cars[number]
	var driver: RaceDriver3D = race.drivers[number]
	_post(_in_world(car, driver.aim_forward, driver.aim_left), 1.6, AIM_COLOUR)
	if driver.braking_in >= 0.0:
		_braking_bar(race, number, driver.braking_in)
	for wheel: int in range(4):
		var at: Vector3 = car.global_transform * car.mount(wheel)
		var peak: float = car.physics.peak_slip * (car.physics.rear_peak if wheel >= 2 else 1.0)
		var colour: Color = tyre_colour(car.wheel_force[wheel], car.wheel_limit[wheel], car.wheel_slip[wheel], peak)
		_post(Vector3(at.x, 0.05, at.z), 0.9, colour)


# A bar across the road at the point `ahead` metres on along car `number`'s
# view of the line.
func _braking_bar(race: Race3D, number: int, ahead: float) -> void:
	var view: RaceView3D = race.views[number]
	var index: int = view.line_forward.find(ahead)
	var sample: int = race.track.wrapped(race.samples[number] + maxi(index, 0))
	var centre: Vector2 = race.track.line[sample]
	var across: Vector2 = race.track.left[sample] * 3.0
	_segment(_flat(centre - across, 0.08), _flat(centre + across, 0.08), BRAKE_COLOUR)


# The watched car's heat array across the road at its aim, and its ball.
func _heat(race: Race3D, number: int) -> void:
	var driver: RaceDriver3D = race.drivers[number]
	var line: HeatLine = driver.traffic.heat
	if not driver.traffic.heat_vision or line.positions.is_empty():
		return
	var car: RaceCar3D = race.cars[number]
	# The line at the aim is where the aim would be without the offset.
	var on_line: float = driver.aim_left - driver.wanted_left
	for cell: int in range(line.positions.size()):
		var colour: Color = COOL.lerp(HOT, clampf(line.heat[cell] / HOTTEST, 0.0, 1.0))
		_post(_in_world(car, driver.aim_forward, on_line + line.positions[cell]), 0.5, colour)
	_post(_in_world(car, driver.aim_forward, on_line + line.ball), 2.2, BALL_COLOUR)


# A point `forward` metres ahead of `car` and `left` to its left, on the road.
func _in_world(car: RaceCar3D, forward: float, left: float) -> Vector3:
	var ahead: Vector3 = -car.global_transform.basis.z
	var leftward: Vector3 = -car.global_transform.basis.x
	var at: Vector3 = car.global_position + ahead * forward + leftward * left
	return Vector3(at.x, 0.05, at.z)


func _post(at: Vector3, height: float, colour: Color) -> void:
	_segment(at, at + Vector3(0.0, height, 0.0), colour)


func _segment(from: Vector3, to: Vector3, colour: Color) -> void:
	_lines.surface_set_color(colour)
	_lines.surface_add_vertex(from)
	_lines.surface_set_color(colour)
	_lines.surface_add_vertex(to)


static func _flat(at: Vector2, height: float) -> Vector3:
	return Vector3(at.x, height, at.y)
