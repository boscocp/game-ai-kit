# The 3D tier's frame rate, measured on the test arena in a window (T50).
#
# The arena is T51's size -- sixteen bots, a blocky arena, one light with
# shadows -- and every bot asks its sight lines on each physics frame, as a
# match would (60 a second; the drawing runs as fast as it can). Vsync is off, so the number is what the machine can draw, not
# the monitor's rate. It cannot run headless: the dummy renderer draws
# nothing, and the number would be the CPU's. So it is not in `make check`;
# `make measure-3d` runs it, and the README's tier row states what it said.
#
#     ./scripts/godot --path godot -s res://test/game3d/arena_fps.gd [-- --primitives]
#
# `--primitives` measures the arena as a fresh checkout draws it, with no
# model downloaded.
#
# Exit codes: 0 measured (the number is printed); 1 the window never drew.
extends SceneTree

const ARENA: String = "res://game3d/arena/test_arena.tscn"
const WARM_UP_SECONDS: float = 3.0
const MEASURE_SECONDS: float = 10.0


func _initialize() -> void:
	_run()


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var arena: Node3D = (load(ARENA) as PackedScene).instantiate() as Node3D
	var primitives: bool = "--primitives" in OS.get_cmdline_user_args()
	if primitives:
		arena.set("shelf", AssetShelf.new(AssetShelf.MANIFEST, "res://test/game3d/nothing_downloaded/"))
	root.add_child(arena)
	await create_timer(WARM_UP_SECONDS).timeout
	var started_frames: int = Engine.get_frames_drawn()
	var started_at: int = Time.get_ticks_usec()
	var worst_usec: int = 0
	var last: int = started_at
	# The decisions on the physics step, the timing on the drawn frames.
	physics_frame.connect(Callable(arena, "step_decision"))
	while Time.get_ticks_usec() - started_at < int(MEASURE_SECONDS * 1e6):
		await process_frame
		var now: int = Time.get_ticks_usec()
		worst_usec = maxi(worst_usec, now - last)
		last = now
	var frames: int = Engine.get_frames_drawn() - started_frames
	var seconds: float = (Time.get_ticks_usec() - started_at) / 1e6
	print("arena fps (%s): %.1f mean over %.1f s, worst frame %.1f ms, on %s (%s), %dx%d" % [
			"primitives" if primitives else "models", frames / seconds, seconds, worst_usec / 1000.0,
			RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_vendor(),
			root.size.x, root.size.y])
	quit(0 if frames > 0 else 1)
