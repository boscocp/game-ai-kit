# T38: the jump, a fourth corner on the triangle. An arc in whole frames and
# whole units, committed at take-off; a fighter in the air cannot be thrown
# and cannot guard; a kick from the air hits as an overhead; a low passes
# under a jump; and an anti-air beats a jump-in when it is early, and loses
# to it when it is late. Boxes are two intervals now, and a hit needs both.
extends GdUnitTestSuite

const UP: int = FightInput.UP
const RIGHT: int = FightInput.RIGHT
const LEFT: int = FightInput.LEFT
const DOWN: int = FightInput.DOWN
const FLYING_KICK: int = FightInput.HEAVY_KICK
const UPPERCUT: int = FightInput.DOWN | FightInput.HEAVY_PUNCH
## When the lancer's jump-in kick is pressed: the eighteenth frame of a jump
## forwards from `JUMP_IN_FROM`, near the top of the arc.
const KICK_ON: int = 18
const JUMP_IN_FROM: Array[int] = [250, 380]

var _data: FightData


func before_test() -> void:
	_data = FightData.read()


# --- the arc -------------------------------------------------------------------

func test_the_arc_rises_holds_and_falls_in_whole_units() -> void:
	for character: String in _data.character_names():
		var jump: Dictionary = _data.character(character)["jump"]
		var heights: Array[int] = []
		for frame: int in range(_data.jump_length(character) + 2):
			heights.append(_data.height_at(character, frame))
		assert_int(heights[0]).is_equal(0)
		assert_int(heights.max()).is_equal(int(jump["height"]))
		assert_int(heights[int(jump["rise"])]).is_equal(int(jump["height"]))
		assert_int(heights.back()).is_equal(0)
		assert_int(_data.height_at(character, _data.jump_length(character))).is_equal(0)


func test_a_jump_is_committed_and_ends_in_its_landing_frames() -> void:
	var state: FightState = _fight(300, 500)
	state = _step(state, UP | RIGHT, 0)
	var length: int = _data.jump_length("lancer")
	for frame: int in range(length):
		assert_bool(state.fighters[0].is_airborne()).is_true()
		state = _step(state, LEFT | FightInput.LIGHT_PUNCH * (frame % 2), 0)
	var lancer: FighterState = state.fighters[0]
	assert_bool(lancer.is_airborne()).is_false()
	assert_int(lancer.y).is_equal(0)
	assert_int(lancer.x).is_equal(300 + length * int(_data.character("lancer")["jump"]["speed"]))
	assert_str(lancer.stun_kind).is_equal("landing")
	assert_int(lancer.stun).is_equal(int(_data.character("lancer")["jump"]["landing"]))


func test_in_the_air_only_an_air_move_comes_out() -> void:
	var state: FightState = _step(_fight(300, 500), UP, 0)
	state = _step(_step(state, 0, 0), FightInput.LIGHT_PUNCH, 0)
	assert_str(state.fighters[0].move).is_empty()
	state = _step(_step(state, 0, 0), FLYING_KICK, 0)
	assert_str(state.fighters[0].move).is_equal("flying_kick")


func test_an_air_move_ends_when_the_jump_does() -> void:
	var state: FightState = _step(_fight(300, 500), UP, 0)
	for frame: int in range(_data.jump_length("lancer") - 3):
		state = _step(state, 0, 0)
	state = _step(state, FLYING_KICK, 0)
	for frame: int in range(3):
		state = _step(state, 0, 0)
	assert_bool(state.fighters[0].is_airborne()).is_false()
	assert_str(state.fighters[0].move).is_empty()


# --- the fourth corner -----------------------------------------------------------

func test_a_low_passes_under_a_jump() -> void:
	var events: String = _play(_fight(300, 370), _once(UP, 0), _once(DOWN | FightInput.LIGHT_KICK, 0), 40)
	assert_str(events).contains("p2's low_kick passes under p1 (a low misses a fighter in the air)")
	assert_str(events).not_contains("hits")


func test_a_low_still_catches_a_jump_leaving_the_ground() -> void:
	var state: FightState = _fight(300, 370)
	state.fighters[1].move = "low_kick"
	state.fighters[1].move_frame = int(_data.move("dancer", "low_kick")["startup"])
	state.fighters[1].facing = -1
	state = _step(state, UP, DOWN)
	assert_str(", ".join(state.events)).contains("p2 hits p1 with low_kick")


func test_a_throw_does_not_catch_a_fighter_in_the_air() -> void:
	var events: String = _play(_fight(300, 340), _once(UP, 0), _once(FightInput.THROW, 2), 30)
	assert_str(events).is_empty()


func test_a_kick_from_the_air_is_an_overhead() -> void:
	var crouched: String = _play(_fight(JUMP_IN_FROM[0], JUMP_IN_FROM[1]), _jump_in(), _held(RIGHT | DOWN), 45)
	assert_str(crouched).contains("p1 hits p2 with flying_kick (an overhead through a crouching guard)")
	var wall: int = int(_data.table["stage"]["width"]) - int(_data.character("dancer")["body"])
	var stood: String = _play(_fight(wall - 130, wall), _jump_in(), _held(RIGHT), 45)
	assert_str(stood).contains("p1 is blocked by p2 with flying_kick (holding away, standing)")


func test_a_fighter_in_the_air_cannot_guard() -> void:
	var state: FightState = _fight(300, 360)
	state = _step(state, UP, 0)
	state = _step(state, LEFT, FightInput.LIGHT_PUNCH)
	var seen: PackedStringArray = []
	for frame: int in range(12):
		state = _step(state, LEFT, 0)
		seen.append_array(state.events)
	assert_str(", ".join(seen)).contains("p2 hits p1 with jab (in the air, which cannot guard)")


func test_an_early_anti_air_beats_the_jump_in_and_a_late_one_loses() -> void:
	var early: String = _play(_fight(JUMP_IN_FROM[0], JUMP_IN_FROM[1]), _jump_in(), _once(UPPERCUT, 12), 45)
	assert_str(early).contains("p2 counter-hits p1 with uppercut")
	assert_str(early).not_contains("with flying_kick")
	var late: String = _play(_fight(JUMP_IN_FROM[0], JUMP_IN_FROM[1]), _jump_in(), _once(UPPERCUT, 20), 45)
	assert_str(late).contains("p1 counter-hits p2 with flying_kick")
	assert_str(late).not_contains("with uppercut")


# --- the training mode -------------------------------------------------------

func test_the_anti_air_dummy_knocks_a_jump_in_out_of_the_air() -> void:
	var scene: FightingExample = auto_free(load("res://game/fighting/fighting.tscn").instantiate())
	add_child(scene)
	scene.paused = true
	scene.dummy_mode = "anti-air (sees you now)"
	scene.state.fighters[0].x = JUMP_IN_FROM[0]
	scene.state.fighters[1].x = JUMP_IN_FROM[1]
	var jump_in: Callable = _jump_in()
	var seen: PackedStringArray = []
	for frame: int in range(45):
		scene.state = _step(scene.state, jump_in.call(frame), scene._dummy_input())
		seen.append_array(scene.state.events)
	assert_str(", ".join(seen)).contains("p1 with uppercut")
	assert_str(", ".join(seen)).not_contains("with flying_kick")


func test_the_panel_says_where_a_fighter_is_in_its_jump() -> void:
	var state: FightState = _step(_step(_fight(300, 500), UP, 0), 0, 0)
	var words: String = FightingPanel.describe(state, _data, true)
	assert_str(words).contains("in the air, frame 2 of %d" % _data.jump_length("lancer"))
	assert_str(words).not_contains("player 1, the lancer: 1000 health\n  free to act")


# --- rectangles ------------------------------------------------------------------

# A high passes over a crouch because of where it reaches, not because of a
# rule about highs: so every high must start above every crouch, and every
# low and mid must reach one. A move that broke this would be a high that
# hits a crouching fighter, with nothing in the rules to say why.
func test_every_high_is_above_every_crouch_and_every_other_strike_reaches_one() -> void:
	var crouches: Array = _data.character_names().map(func(name: String) -> int:
			return int(_data.character(name)["crouching_tall"]))
	for character: String in _data.character_names():
		var moves: Dictionary = _data.character(character)["moves"]
		for name: String in moves:
			_check_rise(name, moves[name], crouches)


# A high starts above every crouch; any other strike from the ground starts
# low enough to meet the lowest one.
func _check_rise(name: String, frames: Dictionary, crouches: Array) -> void:
	if frames["stance"] == "air" or frames["height"] == "throw":
		return
	var bottom: int = int(frames["rise"][0])
	if frames["height"] == "high":
		assert_int(bottom).override_failure_message(name).is_greater(crouches.max())
	else:
		assert_int(bottom).override_failure_message(name).is_less_equal(crouches.min())


func test_a_jump_missing_a_number_is_refused() -> void:
	var path: String = "user://planted_jump.json"
	var table: Dictionary = _data.table.duplicate(true)
	table["characters"]["dancer"]["jump"].erase("hang")
	FileAccess.open(path, FileAccess.WRITE).store_string(JSON.stringify(table))
	assert_str(FightData.read(path).refusal).contains("dancer's jump needs")
	table["characters"]["dancer"]["jump"]["hang"] = 4
	table["characters"]["dancer"]["jump"]["fall"] = 0
	FileAccess.open(path, FileAccess.WRITE).store_string(JSON.stringify(table))
	assert_str(FightData.read(path).refusal).contains("one frame up and one down")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


# --- helpers ---------------------------------------------------------------------

func _fight(lancer_x: int, dancer_x: int) -> FightState:
	var state: FightState = FightState.starting(_data, "lancer", "dancer")
	state.fighters[0].x = lancer_x
	state.fighters[1].x = dancer_x
	return state


func _step(state: FightState, first: int, second: int) -> FightState:
	return FightRules.step(state, [first, second] as Array[int], _data)


# Every event of `frames` frames, each player's input a function of the frame.
func _play(state: FightState, first: Callable, second: Callable, frames: int) -> String:
	var seen: PackedStringArray = []
	for frame: int in range(frames):
		state = _step(state, first.call(frame), second.call(frame))
		seen.append_array(state.events)
	return ", ".join(seen)


# `input` on frame `on` and nothing on any other.
func _once(input: int, on: int) -> Callable:
	return func(frame: int) -> int: return input if frame == on else 0


func _held(input: int) -> Callable:
	return func(_frame: int) -> int: return input


# The lancer jumps forwards and kicks on `KICK_ON`.
func _jump_in() -> Callable:
	return func(frame: int) -> int: return UP | RIGHT if frame == 0 else (FLYING_KICK if frame == KICK_ON else 0)
