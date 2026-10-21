# What the 3D tier stands on, measured headless on the pinned engine (T50).
# Every 3D example after this one assumes these hold, so each is held here
# rather than believed:
#
#   1. a body dropped on a floor comes to rest on it, within REST_TOLERANCE,
#      after REST_FRAMES physics frames -- 3D physics runs under --headless;
#   2. a ray asked on a physics frame (after `await physics_frame`, which is
#      where a SceneTree script's physics step is) hits a box, and one past
#      the box misses;
#   3. a navmesh baked from collision shapes gives a path round a wall;
#   4. a drop and a pushed box run twice give the same positions on every
#      frame -- the number later tolerances are stated in is zero, here --
#      and a run pushed one per cent harder does not;
#   5. the test arena, with its models missing, loads with primitives, offers
#      step_decision() and decision_overlay(); who sees whom changes as the
#      bots walk, the cover blocks some sight lines and not all, and with the
#      cover taken away every pair sees each other;
#   6. no engine error is logged while any of it runs. A custom Logger counts
#      them, because a SCRIPT ERROR aborts a function and the script still
#      exits 0 (CLAUDE.md's trap).
#
# Each is asked of a planted case too, which it must reject: no floor, a ray
# aimed past the box, a wall the bake never saw, a run pushed harder, the
# same sight lines twice, an arena with no cover.
#
#     ./scripts/godot --headless --path godot -s res://test/game3d/game3d_floor.gd
#
# Exit codes: 0 the floor holds; 1 a check failed, or a planted case passed.
extends SceneTree

const REST_FRAMES: int = 120
const REST_TOLERANCE: float = 0.05
const BALL_RADIUS: float = 0.5
const REPLAY_FRAMES: int = 300
## The force on the replayed box, in newtons: enough to slide 1200 kg.
const PUSH: float = 30000.0
const ARENA: String = "res://game3d/arena/test_arena.tscn"
## A folder nothing was downloaded into: every model must be a primitive.
const EMPTY_SHELF: String = "res://test/game3d/nothing_downloaded/"
## Decisions the arena is stepped through; who sees whom must change in them.
const ARENA_STEPS: int = 10
## Every blue bot looking at every red one, and back.
const EVERY_PAIR: int = 8 * 8 * 2


## Counts what the engine reports as an error while the checks run.
class ErrorCounter extends Logger:
	var errors: int = 0

	func _log_error(_function: String, _file: String, _line: int, _code: String,
			_rationale: String, _editor_notify: bool, _error_type: int,
			_script_backtraces: Array[ScriptBacktrace]) -> void:
		errors += 1

	func _log_message(_message: String, _error: bool) -> void:
		pass


var _counter := ErrorCounter.new()


func _initialize() -> void:
	OS.add_logger(_counter)
	_run()


func _run() -> void:
	var failures: Array[String] = []
	failures += await _check_rest()
	failures += await _check_rays()
	failures += await _check_path()
	failures += await _check_replay()
	failures += await _check_arena()
	failures += _check_shelf()
	if _counter.errors > 0:
		failures.append("%d engine error(s) while the checks ran" % _counter.errors)
	for failure: String in failures:
		print(failure)
	print("game3d floor: %d failure(s)" % failures.size())
	quit(1 if not failures.is_empty() else 0)


# --- 1. a body comes to rest ------------------------------------------------


func _check_rest() -> Array[String]:
	var resting: float = await _drop(true)
	var falling: float = await _drop(false)
	var failures: Array[String] = []
	var wanted: Array = [resting, BALL_RADIUS, REST_TOLERANCE]
	if absf(resting - BALL_RADIUS) > REST_TOLERANCE:
		failures.append("rest: the ball's centre is at %.3f m, not %.2f +- %.2f" % wanted)
	if absf(falling - BALL_RADIUS) <= REST_TOLERANCE:
		failures.append("rest: planted, a ball with no floor under it passed as resting")
	return failures


# The ball's height after REST_FRAMES, dropped from 3 m on a floor or not.
func _drop(with_floor: bool) -> float:
	var world := _world()
	if with_floor:
		_box(world, Vector3(20, 1, 20), Vector3(0, -0.5, 0))
	var ball := RigidBody3D.new()
	_shape(ball, _sphere(BALL_RADIUS))
	ball.position = Vector3(0, 3, 0)
	world.add_child(ball)
	for _frame: int in range(REST_FRAMES):
		await physics_frame
	var height: float = ball.position.y
	world.free()
	return height


# --- 2. a ray hits, and misses past ---------------------------------------


func _check_rays() -> Array[String]:
	var world := _world()
	_box(world, Vector3(1, 2, 2), Vector3(0, 1, 0))
	await physics_frame
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var hit: Dictionary = space.intersect_ray(
			PhysicsRayQueryParameters3D.create(Vector3(-5, 1, 0), Vector3(5, 1, 0)))
	var past: Dictionary = space.intersect_ray(
			PhysicsRayQueryParameters3D.create(Vector3(-5, 1, 3), Vector3(5, 1, 3)))
	world.free()
	var failures: Array[String] = []
	if hit.is_empty() or absf((hit["position"] as Vector3).x + 0.5) > 1e-3:
		failures.append("rays: the ray at the box hit %s, not its face at x = -0.5" % [hit])
	if not past.is_empty():
		failures.append("rays: planted, a ray past the box hit %s" % [past])
	return failures


# --- 3. a baked path goes round a wall ------------------------------------


func _check_path() -> Array[String]:
	var round_wall: PackedVector3Array = await _path_across(true)
	var no_wall: PackedVector3Array = await _path_across(false)
	var failures: Array[String] = []
	if _widest(round_wall) < 5.0:
		failures.append("path: the path did not go round the wall: %s" % [round_wall])
	if _widest(no_wall) >= 5.0:
		failures.append("path: planted, with no wall the path still went wide: %s" % [no_wall])
	return failures


# A path from one side of a 10 m wall to the other, over a navmesh baked from
# collision shapes -- with the wall in the bake or not. The mesh is set before
# the region enters the tree: measured on 4.7.2, a mesh set on a region
# already in the tree on its second physics frame never reached the map.
func _path_across(with_wall: bool) -> PackedVector3Array:
	var world := _world()
	_box(world, Vector3(20, 1, 20), Vector3(0, -0.5, 0))
	if with_wall:
		_box(world, Vector3(1, 2, 10), Vector3(0, 1, 0))
	var mesh := NavigationMesh.new()
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.agent_radius = 0.5
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(mesh, source, world)
	NavigationServer3D.bake_from_source_geometry_data(mesh, source)
	# A map of its own. Every node under `root` shares the viewport's one map,
	# and measured, the planted run's query was answered from the run before
	# it: a freed region leaves the map on a later sync, not when it is freed.
	var map: RID = NavigationServer3D.map_create()
	NavigationServer3D.map_set_active(map, true)
	var region := NavigationRegion3D.new()
	region.navigation_mesh = mesh
	region.set_navigation_map(map)
	world.add_child(region)
	# The map syncs on a later physics frame, on a thread of its own; a query
	# before it answers empty. Asked until it answers, and never past a second.
	var path := PackedVector3Array()
	for _frame: int in range(60):
		await physics_frame
		path = NavigationServer3D.map_get_path(map, Vector3(-5, 0, 0), Vector3(5, 0, 0), true)
		if not path.is_empty():
			break
	world.free()
	NavigationServer3D.free_rid(map)
	return path


# How far off the straight line from start to end a path strays, in metres.
func _widest(path: PackedVector3Array) -> float:
	var widest: float = 0.0
	for point: Vector3 in path:
		widest = maxf(widest, absf(point.z))
	return widest


# --- 4. the same run twice -------------------------------------------------


func _check_replay() -> Array[String]:
	var first: Array[String] = await _record_run(PUSH)
	var second: Array[String] = await _record_run(PUSH)
	var harder: Array[String] = await _record_run(PUSH * 1.01)
	var failures: Array[String] = []
	if first.size() != REPLAY_FRAMES:
		failures.append("replay: recorded %d frames, not %d" % [first.size(), REPLAY_FRAMES])
	var differs: int = _first_difference(first, second)
	if differs >= 0:
		failures.append("replay: frame %d differs: %s against %s" % [differs, first[differs], second[differs]])
	# Planted: two runs that stood still would also be identical. A push one
	# per cent harder must show, or the comparison is looking at nothing.
	if _first_difference(first, harder) < 0:
		failures.append("replay: planted, a run pushed 1% harder was recorded the same")
	return failures


# The first frame where two recordings differ, or -1.
func _first_difference(one: Array[String], other: Array[String]) -> int:
	for frame: int in range(mini(one.size(), other.size())):
		if one[frame] != other[frame]:
			return frame
	return -1


# A ball dropped and a box pushed into a crate, every frame written down
# exactly (var_to_str keeps every bit of a float).
func _record_run(push: float) -> Array[String]:
	var world := _world()
	_box(world, Vector3(60, 1, 60), Vector3(0, -0.5, 0))
	_box(world, Vector3(1, 1, 1), Vector3(8, 0.5, 0))
	var ball := RigidBody3D.new()
	_shape(ball, _sphere(BALL_RADIUS))
	ball.position = Vector3(-3, 4, 0)
	world.add_child(ball)
	var car := RigidBody3D.new()
	car.mass = 1200.0
	_shape(car, _box_shape(Vector3(4.0, 0.6, 1.8)))
	car.position = Vector3(0, 0.3, 0)
	world.add_child(car)
	var frames: Array[String] = []
	for frame: int in range(REPLAY_FRAMES):
		car.apply_central_force(Vector3(push, 0, 0))
		car.apply_torque(Vector3(0, 4000.0 * sin(frame * 0.05), 0))
		await physics_frame
		frames.append(var_to_str([ball.global_transform, car.global_transform]))
	world.free()
	return frames


# --- 5. the arena, its models missing --------------------------------------


func _check_arena() -> Array[String]:
	var arena: Node3D = await _mount_arena(false)
	var failures: Array[String] = _arena_built_of_primitives(arena)
	var seen: Array[String] = []
	for _step: int in range(ARENA_STEPS):
		arena.call("step_decision")
		var overlay: Dictionary = arena.call("decision_overlay")
		seen.append(str(overlay["seen_by"]))
		var lines: int = int(overlay["sight_lines"])
		if lines <= 0 or lines >= EVERY_PAIR:
			failures.append("arena: %d sight lines of %d; the cover blocks none, or all" % [lines, EVERY_PAIR])
	if not _ever_changes(seen):
		failures.append("arena: who sees whom did not change in %d decisions" % ARENA_STEPS)
	if _ever_changes([seen[0], seen[0]]):
		failures.append("arena: planted, the same sight lines twice passed as a change")
	_unmount(arena)
	var bare: Node3D = await _mount_arena(true)
	bare.call("step_decision")
	var open_lines: int = int(bare.call("decision_overlay")["sight_lines"])
	if open_lines != EVERY_PAIR:
		failures.append("arena: planted, with no cover %d of %d pairs see each other" % [open_lines, EVERY_PAIR])
	_unmount(bare)
	return failures


# The arena with nothing downloaded, in the tree and through one physics frame.
func _mount_arena(without_cover: bool) -> Node3D:
	var arena: Node3D = (load(ARENA) as PackedScene).instantiate() as Node3D
	arena.set("shelf", AssetShelf.new(AssetShelf.MANIFEST, EMPTY_SHELF))
	root.add_child(arena)
	await process_frame
	if without_cover:
		arena.call("remove_cover")
	await physics_frame
	return arena


func _unmount(arena: Node3D) -> void:
	root.remove_child(arena)
	arena.free()


# Whether any entry differs from the one before it.
func _ever_changes(entries: Array[String]) -> bool:
	for index: int in range(1, entries.size()):
		if entries[index] != entries[index - 1]:
			return true
	return false


func _arena_built_of_primitives(arena: Node3D) -> Array[String]:
	var failures: Array[String] = []
	var legend: Legend = arena.find_child("Legend", true, false) as Legend
	if legend == null or legend.entries.is_empty():
		failures.append("arena: no legend, or an empty one")
	var bots: Array = arena.call("bots")
	if bots.size() != 16:
		failures.append("arena: %d bots, not 16" % bots.size())
	for bot: Node3D in bots:
		if bot.find_child("Primitive_capsule", false, false) == null:
			failures.append("arena: %s is not a capsule with nothing downloaded" % bot.name)
	return failures


# --- 6. the shelf's models stand on the floor at the height asked ----------


# A model is placed by its feet and sized in metres, downloaded or not. The
# downloaded half runs only where `make assets-3d` has, and says so.
func _check_shelf() -> Array[String]:
	var failures: Array[String] = []
	var shelves: Array[AssetShelf] = [AssetShelf.new(AssetShelf.MANIFEST, EMPTY_SHELF)]
	var real := AssetShelf.new()
	if real.has_model("bot_blue"):
		shelves.append(real)
	else:
		print("note: no model downloaded; the shelf was checked on primitives only")
	for shelf: AssetShelf in shelves:
		var model: Node3D = shelf.model("bot_blue", 1.8, Color.WHITE)
		var bounds: AABB = AssetShelf.bounds_of(model)
		var stands: Array = [model.name, bounds.position.y, bounds.end.y]
		if absf(bounds.position.y) > 0.01 or absf(bounds.size.y - 1.8) > 0.01:
			failures.append("shelf: %s stands from %.3f to %.3f m, not 0 to 1.8" % stands)
		model.free()
	return failures


# --- building blocks -------------------------------------------------------


func _world() -> Node3D:
	var world := Node3D.new()
	root.add_child(world)
	return world


func _box(world: Node3D, size: Vector3, place: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	_shape(body, _box_shape(size))
	body.position = place
	world.add_child(body)
	return body


func _shape(body: CollisionObject3D, shape: Shape3D) -> void:
	var holder := CollisionShape3D.new()
	holder.shape = shape
	body.add_child(holder)


func _box_shape(size: Vector3) -> BoxShape3D:
	var box := BoxShape3D.new()
	box.size = size
	return box


func _sphere(radius: float) -> SphereShape3D:
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	return sphere
