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
## When the lancer's jump-in kick is pressed, counted from up: after its four
## take-off frames, the fourteenth of its flight, at the top of the arc.
const KICK_ON: int = 18
## When the dancer's uppercut is pressed against that jump-in: in time, and
## too late.
const EARLY: int = 12
const LATE: int = 20
## When the lancer's light kick is pressed in a jump forwards from 60 units
## away: after it has crossed over the dancer, on the way down.
const CROSS_UP_KICK: int = 28
const JUMP_IN_FROM: Array[int] = [250, 380]

var _data: FightData


func before_test() -> void:
	_data = FightData.read()


# --- the arc -------------------------------------------------------------------

func test_the_arc_rises_holds_and_falls_in_whole_units() -> void:
	for character: String in _data.character_names():
		var jump: Dictionary = _data.character(character)["jump"]
		var length: int = _data.jump_length(character)
		var heights: Array[int] = []
		for frame: int in range(1, length + 1):
			heights.append(_data.height_at(character, frame))
		assert_bool(heights.all(func(height: int) -> bool: return height > 0)).is_true()
		assert_int(heights.max()).is_equal(int(jump["height"]))
		assert_int(heights[int(jump["rise"]) - 1]).is_equal(int(jump["height"]))
		assert_int(_data.height_at(character, 0)).is_equal(0)
		assert_int(_data.height_at(character, length + 1)).is_equal(0)


# Up pressed: `takeoff` frames on the ground, then exactly `jump_length`
# frames in the air whatever is held, then the landing frames.
func test_a_jump_is_committed_from_the_press_to_the_landing() -> void:
	var jump: Dictionary = _data.character("lancer")["jump"]
	var state: FightState = _step(_fight(300, 500), UP | RIGHT, 0)
	var on_the_ground: int = 0
	while not state.fighters[0].is_airborne():
		assert_str(state.fighters[0].stun_kind).is_equal("takeoff")
		on_the_ground += 1
		state = _step(state, LEFT, 0)
	assert_int(on_the_ground).is_equal(int(jump["takeoff"]))
	var in_the_air: int = 0
	while state.fighters[0].is_airborne():
		in_the_air += 1
		state = _step(state, LEFT | FightInput.LIGHT_PUNCH * (in_the_air % 2), 0)
	var lancer: FighterState = state.fighters[0]
	assert_int(in_the_air).is_equal(_data.jump_length("lancer"))
	assert_int(lancer.y).is_equal(0)
	assert_int(lancer.x).is_equal(300 + in_the_air * int(jump["speed"]))
	assert_str(lancer.stun_kind).is_equal("landing")
	assert_int(lancer.stun).is_equal(int(jump["landing"]))


func test_holding_down_in_the_air_does_not_crouch() -> void:
	var state: FightState = _airborne(_fight(300, 500))
	for frame: int in range(5):
		state = _step(state, DOWN, 0)
		assert_bool(state.fighters[0].crouching).is_false()


func test_in_the_air_only_an_air_move_comes_out_and_only_one_a_jump() -> void:
	var state: FightState = _step(_airborne(_fight(300, 500)), FightInput.LIGHT_PUNCH, 0)
	assert_str(state.fighters[0].move).is_equal("air_jab")
	for frame: int in range(_data.length_of("lancer", "air_jab") + 1):
		state = _step(state, 0, 0)
	state = _step(state, FLYING_KICK, 0)
	for frame: int in range(3):
		state = _step(state, 0, 0)
	assert_bool(state.fighters[0].is_airborne()).is_true()
	assert_str(state.fighters[0].move).is_empty()


func test_an_air_move_ends_when_the_jump_does() -> void:
	var state: FightState = _airborne(_fight(300, 500))
	while state.fighters[0].jump_frame < _data.jump_length("lancer") - 2:
		state = _step(state, 0, 0)
	state = _step(state, FLYING_KICK, 0)
	for frame: int in range(3):
		state = _step(state, 0, 0)
	assert_bool(state.fighters[0].is_airborne()).is_false()
	assert_str(state.fighters[0].move).is_empty()


func test_a_fighter_hit_in_the_air_has_no_air_move_left_and_its_stun_runs_down() -> void:
	var state: FightState = _airborne(_fight(300, 350))
	state.fighters[1].move = "jab"
	state.fighters[1].move_frame = int(_data.move("dancer", "jab")["startup"])
	state.fighters[1].facing = -1
	state = _step(state, 0, 0)
	assert_str(", ".join(state.events)).contains("p2 hits p1 with jab")
	var stunned: int = state.fighters[0].stun
	state = _step(_step(state, 0, 0), 0, 0)
	assert_int(state.fighters[0].stun).is_equal(stunned - 2)
	while state.fighters[0].stun > 0:
		state = _step(state, 0, 0)
	state = _step(_step(state, FLYING_KICK, 0), 0, 0)
	assert_bool(state.fighters[0].is_airborne()).is_true()
	assert_str(state.fighters[0].move).is_empty()


# --- the fourth corner -----------------------------------------------------------

func test_a_low_passes_under_a_jump() -> void:
	var events: String = _play(_fight(300, 370), _once(UP, 0), _once(DOWN | FightInput.LIGHT_KICK, 4), 40)
	assert_str(events).contains("p2's low_kick passes under p1 (a low misses a fighter in the air)")
	assert_str(events).not_contains("hits")


func test_a_mid_under_a_jump_is_not_called_a_low() -> void:
	var state: FightState = _airborne(_fight(300, 360))
	while state.fighters[0].y < 100:
		state = _step(state, 0, 0)
	state.fighters[1].move = "snap_kick"
	state.fighters[1].move_frame = int(_data.move("dancer", "snap_kick")["startup"])
	state.fighters[1].facing = -1
	state = _step(state, 0, 0)
	assert_str(", ".join(state.events)).contains("p2's snap_kick passes under p1 (it is in the air)")


func test_a_low_catches_a_jump_still_taking_off() -> void:
	var state: FightState = _fight(300, 370)
	state.fighters[1].move = "low_kick"
	state.fighters[1].move_frame = int(_data.move("dancer", "low_kick")["startup"])
	state.fighters[1].facing = -1
	state = _step(state, UP, DOWN)
	assert_str(", ".join(state.events)).contains("p2 hits p1 with low_kick")


func test_a_throw_does_not_catch_a_fighter_in_the_air() -> void:
	var events: String = _play(_airborne(_fight(300, 340)), _held(0), _once(FightInput.THROW, 0), 30)
	assert_str(events).is_empty()


# Up pressed on the frame a throw arrives is too late: the take-off is on the
# ground. So are the landing frames.
func test_taking_off_and_landing_can_be_thrown() -> void:
	var taking_off: FightState = _throw_arriving(_fight(300, 340))
	taking_off = _step(taking_off, UP, 0)
	assert_str(", ".join(taking_off.events)).contains("p2 throws p1")
	var landing: FightState = _throw_arriving(_fight(300, 340))
	landing.fighters[0].stun = int(_data.character("lancer")["jump"]["landing"])
	landing.fighters[0].stun_kind = "landing"
	landing = _step(landing, 0, 0)
	assert_str(", ".join(landing.events)).contains("p2 throws p1")


# Taking off is committed: it cannot guard, and holding down does not
# crouch it. Nor does landing.
func test_taking_off_and_landing_neither_guard_nor_crouch() -> void:
	var state: FightState = _fight(300, 345)
	state.fighters[1].move = "jab"
	state.fighters[1].move_frame = int(_data.move("dancer", "jab")["startup"])
	state.fighters[1].facing = -1
	state = _step(state, UP | LEFT, 0)
	assert_str(", ".join(state.events)).contains("p2 hits p1 with jab")
	var landing: FightState = _fight(300, 500)
	landing.fighters[0].stun = int(_data.character("lancer")["jump"]["landing"])
	landing.fighters[0].stun_kind = "landing"
	assert_bool(_step(landing, DOWN, 0).fighters[0].crouching).is_false()
	var taking_off: FightState = _step(_fight(300, 500), UP, 0)
	assert_bool(_step(taking_off, DOWN, 0).fighters[0].crouching).is_false()


# Hitstun counts down on every frame of a fall, the landing frame too.
func test_hitstun_runs_down_through_the_landing() -> void:
	var state: FightState = _airborne(_fight(300, 500))
	while state.fighters[0].jump_frame < _data.jump_length("lancer") - 1:
		state = _step(state, 0, 0)
	state.fighters[0].stun = 10
	state.fighters[0].stun_kind = "hit"
	var stun: Array[int] = []
	for frame: int in range(3):
		state = _step(state, 0, 0)
		stun.append(state.fighters[0].stun)
	assert_bool(state.fighters[0].is_airborne()).is_false()
	assert_array(stun).is_equal([9, 8, 7])


# Two fighters on one spot -- one landed on the other -- are pushed apart by
# which way they face, the one facing right going left, so swapping the
# players swaps the result and nothing else.
func test_two_on_one_spot_part_by_which_way_they_face() -> void:
	for lancer_faces: int in [1, -1]:
		var state: FightState = _fight(300, 300)
		state.fighters[0].facing = lancer_faces
		state.fighters[1].facing = -lancer_faces
		state = _step(state, 0, 0)
		var lancer_left: bool = state.fighters[0].x < state.fighters[1].x
		assert_bool(lancer_left).is_equal(lancer_faces == 1)


# On one spot there is no "away"; the guard is held back from the way the
# strike travels, so the answer does not hang on which way the defender steps.
func test_on_one_spot_the_guard_is_held_back_from_the_strike() -> void:
	for guard: int in [RIGHT, LEFT]:
		var state: FightState = _fight(300, 300)
		state.fighters[0].jump_frame = 10
		state.fighters[0].y = 40
		state.fighters[0].move = "air_kick"
		state.fighters[0].move_frame = int(_data.move("lancer", "air_kick")["startup"])
		state.fighters[0].facing = 1
		var events: String = ", ".join(_step(state, 0, guard).events)
		assert_str(events).contains("is blocked by" if guard == RIGHT else "p1 hits p2 with air_kick")


func test_taking_off_shows_the_first_cel_of_the_jump() -> void:
	var state: FightState = _step(_fight(300, 500), UP, 0)
	assert_array(FighterSprites.read().pose(state.fighters[0], _data, state.frame, false)).is_equal(["jump", 0])


func test_a_kick_from_the_air_is_an_overhead() -> void:
	var crouched: String = _play(_fight(JUMP_IN_FROM[0], JUMP_IN_FROM[1]), _jump_in(), _held(RIGHT | DOWN), 50)
	assert_str(crouched).contains("p1 hits p2 with flying_kick (an overhead through a crouching guard)")
	var wall: int = int(_data.table["stage"]["width"]) - int(_data.character("dancer")["body"])
	var stood: String = _play(_fight(wall - 130, wall), _jump_in(), _held(RIGHT), 50)
	assert_str(stood).contains("p1 is blocked by p2 with flying_kick (holding away, standing)")


func test_a_fighter_in_the_air_cannot_guard() -> void:
	var state: FightState = _airborne(_fight(300, 345))
	state.fighters[1].move = "jab"
	state.fighters[1].move_frame = int(_data.move("dancer", "jab")["startup"])
	state.fighters[1].facing = -1
	state = _step(state, LEFT, 0)
	assert_str(", ".join(state.events)).contains("p2 hits p1 with jab (in the air, which cannot guard)")


func test_a_jump_crosses_over_and_turns_to_face_its_target() -> void:
	var state: FightState = _fight(300, 360)
	state = _step(state, UP | RIGHT, 0)
	var passed_through: bool = false
	while state.fighters[0].is_airborne() or state.fighters[0].stun_kind == "takeoff":
		state = _step(state, 0, 0)
		passed_through = passed_through or absi(state.fighters[0].x - state.fighters[1].x) < 20
	assert_bool(passed_through).is_true()
	assert_int(state.fighters[0].x).is_greater(state.fighters[1].x)
	assert_int(state.fighters[0].facing).is_equal(-1)
	assert_int(state.fighters[1].facing).is_equal(1)


# The cross-up: a kick from the air that lands after the jump has crossed is
# guarded by holding away from where the attacker is now, not from where it
# jumped from. Guarding the old way is the mistake the jump was for.
func test_a_cross_up_is_guarded_the_other_way() -> void:
	var cross_up: Callable = func(frame: int) -> int:
		return UP | RIGHT if frame == 0 else (FightInput.LIGHT_KICK if frame == CROSS_UP_KICK else 0)
	var old_way: Callable = func(frame: int) -> int: return RIGHT if frame >= CROSS_UP_KICK else 0
	var new_way: Callable = func(frame: int) -> int: return LEFT if frame >= CROSS_UP_KICK else 0
	assert_str(_play(_fight(300, 360), cross_up, old_way, 60)).contains("p1 hits p2 with air_kick")
	assert_str(_play(_fight(300, 360), cross_up, new_way, 60)).contains("p1 is blocked by p2 with air_kick")


func test_an_early_anti_air_beats_the_jump_in_and_a_late_one_loses() -> void:
	var early: String = _play(_fight(JUMP_IN_FROM[0], JUMP_IN_FROM[1]), _jump_in(), _once(UPPERCUT, EARLY), 50)
	assert_str(early).contains("p2 counter-hits p1 with uppercut")
	assert_str(early).not_contains("with flying_kick")
	var late: String = _play(_fight(JUMP_IN_FROM[0], JUMP_IN_FROM[1]), _jump_in(), _once(UPPERCUT, LATE), 50)
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
	var state: FightState = _step(_airborne(_fight(300, 500)), 0, 0)
	var words: String = FightingPanel.describe(state, _data, true)
	assert_str(words).contains("in the air, frame 2 of %d" % _data.jump_length("lancer"))
	words = FightingPanel.describe(_step(_fight(300, 500), UP, 0), _data, true)
	assert_str(words).contains("taking off, ")
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


# A high starts above every crouch and low enough to meet every standing
# fighter; any other strike from the ground starts low enough to meet the
# lowest crouch.
func _check_rise(name: String, frames: Dictionary, crouches: Array) -> void:
	if frames["stance"] == "air" or frames["height"] == "throw":
		return
	var bottom: int = int(frames["rise"][0])
	var shortest: int = _data.character_names().map(func(other: String) -> int:
			return int(_data.character(other)["tall"])).min()
	if frames["height"] == "high":
		assert_int(bottom).override_failure_message(name).is_greater(crouches.max())
		assert_int(bottom).override_failure_message(name).is_less_equal(shortest)
	else:
		assert_int(bottom).override_failure_message(name).is_less_equal(crouches.min())


func test_a_box_from_the_air_is_where_the_fighter_is() -> void:
	var fighter := FighterState.new("lancer", 300, 1000)
	fighter.move = "flying_kick"
	fighter.y = 50
	var rise: Array = _data.move("lancer", "flying_kick")["rise"]
	assert_array(FightBoxes.hit_rise(fighter, _data)).is_equal([50 + int(rise[0]), 50 + int(rise[1])])
	assert_array(FightBoxes.hurt_rise(fighter, _data)).is_equal([50, 50 + int(_data.character("lancer")["tall"])])


# Up is up: a box from the floor to 40 is drawn from the floor line upwards.
func test_a_box_on_screen_stands_on_the_floor() -> void:
	var box: Rect2 = FightView.on_screen([100, 140] as Array[int], [0, 40] as Array[int])
	assert_vector(box.position).is_equal(Vector2(100.0, FightView.FLOOR_Y - 40.0))
	assert_vector(box.size).is_equal(Vector2(40.0, 40.0))


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


# The fight after the lancer has pressed up and left the ground.
func _airborne(state: FightState) -> FightState:
	state = _step(state, UP, 0)
	while not state.fighters[0].is_airborne():
		state = _step(state, 0, 0)
	return state


# The dancer's throw, one frame from active, facing the lancer.
func _throw_arriving(state: FightState) -> FightState:
	state.fighters[1].move = "throw"
	state.fighters[1].move_frame = int(_data.move("dancer", "throw")["startup"])
	state.fighters[1].facing = -1
	return state


# `input` on frame `on` and nothing on any other.
func _once(input: int, on: int) -> Callable:
	return func(frame: int) -> int: return input if frame == on else 0


func _held(input: int) -> Callable:
	return func(_frame: int) -> int: return input


# The lancer jumps forwards and kicks on `KICK_ON`.
func _jump_in() -> Callable:
	return func(frame: int) -> int: return UP | RIGHT if frame == 0 else (FLYING_KICK if frame == KICK_ON else 0)
