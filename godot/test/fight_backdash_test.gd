# T40: the backdash, the evade. Pressed, it is committed for exactly its
# `frames`, travelling away from the way the fighter faces; on its first
# `invulnerable` frames a strike or a throw passes through it, and after
# them it cannot guard and can be thrown -- one rule at a time, both
# characters, from both sides. And it is a button of its own, so no input a
# log recorded before it could hold is ever read as an evade.
extends GdUnitTestSuite

const EVADE: int = FightInput.EVADE
const RIGHT: int = FightInput.RIGHT
const LEFT: int = FightInput.LEFT
const DOWN: int = FightInput.DOWN
const JAB: int = FightInput.LIGHT_PUNCH

var _data: FightData


func before_test() -> void:
	_data = FightData.read()


# --- the backdash itself --------------------------------------------------------

# Pressed, it lasts `frames` frames whatever is held -- no walking, no
# crouching -- goes `travel` times `speed` away, and on the frame after its
# last the fighter acts: here, it walks.
func test_a_backdash_is_committed_for_its_frames_and_no_more() -> void:
	for character: String in _data.character_names():
		var backdash: Dictionary = _data.character(character)["backdash"]
		var state: FightState = _alone(character, 300, 500)
		state = _step(state, EVADE, 0)
		var evading: int = 0
		while state.fighters[0].stun_kind == FightBackdash.KIND:
			evading += 1
			assert_bool(state.fighters[0].crouching).is_false()
			state = _step(state, RIGHT | DOWN if evading % 2 == 0 else RIGHT, 0)
		assert_int(evading).override_failure_message(character).is_equal(int(backdash["frames"]))
		var walked: int = 0 if state.fighters[0].crouching else int(_data.character(character)["walk_speed"])
		var travelled: int = int(backdash["travel"]) * int(backdash["speed"])
		assert_int(state.fighters[0].x).override_failure_message(character).is_equal(300 - travelled + walked)


# Pressed with down held, it starts standing and stays standing: a backdash
# that crouched would duck the highs its vulnerable frames are there for.
func test_a_backdash_pressed_holding_down_is_taken_standing() -> void:
	var state: FightState = _step(_alone("lancer", 300, 500), EVADE | DOWN, 0)
	while state.fighters[0].stun_kind == FightBackdash.KIND:
		assert_bool(state.fighters[0].crouching).is_false()
		state = _step(state, DOWN, 0)


# Away is away from the way it faces: the mirror image of a backdash is the
# same backdash.
func test_a_backdash_goes_away_from_the_other_fighter_on_either_side() -> void:
	var from_the_left: FightState = _step(_alone("dancer", 300, 500), EVADE, 0)
	var from_the_right: FightState = _step(_alone("dancer", 500, 300), EVADE, 0)
	assert_int(from_the_left.fighters[0].x).is_less(300)
	assert_int(from_the_right.fighters[0].x).is_greater(500)
	assert_int(300 - from_the_left.fighters[0].x).is_equal(from_the_right.fighters[0].x - 500)


# Against a wall it goes nowhere, and is protected all the same.
func test_a_backdash_into_the_wall_stays_against_it() -> void:
	var width: int = int(_data.table["stage"]["width"])
	var body: int = int(_data.character("dancer")["body"])
	var state: FightState = _step(_alone("dancer", width - body, 300), EVADE, 0)
	assert_int(state.fighters[0].x).is_equal(width - body)
	assert_bool(FightBackdash.invulnerable(state.fighters[0], _data)).is_true()


# --- what finds it, and when ------------------------------------------------------

# A jab arriving on each frame of the dancer's backdash: on the invulnerable
# ones it passes through and says so; on the first after them it lands, even
# with the dancer holding away -- it cannot guard -- and the hit ends the
# backdash.
func test_a_strike_passes_through_its_first_frames_and_catches_the_rest() -> void:
	var invulnerable: int = int(_data.character("dancer")["backdash"]["invulnerable"])
	for frame: int in range(1, invulnerable + 2):
		var state: FightState = _step(_jab_arriving_on(_evading_dancer(frame)), 0, RIGHT)
		var events: String = ", ".join(state.events)
		if frame <= invulnerable:
			assert_str(events).override_failure_message("frame %d: %s" % [frame, events]).contains("passes through p2 (evading)")
			assert_int(state.fighters[1].health).is_equal(int(_data.character("dancer")["health"]))
		else:
			assert_str(events).contains("p1 hits p2 with jab (caught evading, which cannot guard)")
			assert_str(state.fighters[1].stun_kind).is_equal("hit")


# A throw likewise passes through, and once the invulnerable frames are over
# it lands: a late backdash is thrown.
func test_a_throw_passes_through_its_first_frames_and_lands_after_them() -> void:
	var invulnerable: int = int(_data.character("dancer")["backdash"]["invulnerable"])
	for frame: int in [invulnerable, invulnerable + 1]:
		var state: FightState = _evading_dancer(frame)
		state.fighters[0].move = "throw"
		state.fighters[0].move_frame = int(_data.move("lancer", "throw")["startup"])
		var events: String = ", ".join(_step(state, 0, RIGHT).events)
		var expected: String = "p1's throw passes through p2" if frame <= invulnerable else "p1 throws p2"
		assert_str(events).override_failure_message("frame %d: %s" % [frame, events]).contains(expected)


# --- how it is started ------------------------------------------------------------

# Pressed in a move, it waits: never a cancel, even in an open window of a
# move that connected, and it starts on the frame the move ends -- pressed on
# the window's last frame, which is within the buffer of the jab's end.
func test_an_evade_pressed_in_a_move_never_cancels_it_and_follows_it() -> void:
	var state: FightState = _alone("lancer", 300, 500)
	state.fighters[0].move = "jab"
	state.fighters[0].move_frame = int(_data.move("lancer", "jab")["cancel_window"][1]) - 1
	state.fighters[0].connected = true
	state = _step(state, EVADE, 0)
	while state.fighters[0].move == "jab":
		assert_str(state.fighters[0].stun_kind).is_empty()
		state = _step(state, 0, 0)
	assert_str(state.fighters[0].stun_kind).is_equal(FightBackdash.KIND)
	assert_int(FightBackdash.frame_of(state.fighters[0], _data)).is_equal(1)


# Pressed in the air, it is not a backdash there.
func test_an_evade_pressed_in_the_air_does_not_backdash_in_the_air() -> void:
	var state: FightState = _step(_alone("lancer", 300, 500), FightInput.UP, 0)
	while not state.fighters[0].is_airborne():
		state = _step(state, 0, 0)
	state = _step(state, EVADE, 0)
	while state.fighters[0].is_airborne():
		assert_str(state.fighters[0].stun_kind).is_not_equal(FightBackdash.KIND)
		state = _step(state, 0, 0)


# Every input a log recorded before T40 could hold -- any of the nine older
# bits, after any of them -- is never read as an evade: that is why those
# logs replay as they did.
func test_no_input_without_the_evade_bit_is_an_evade() -> void:
	for now: int in range(EVADE):
		assert_str(FightInput.pressed(now, 0)).is_not_equal(FightInput.EVADE_NAME)
		assert_str(FightInput.pressed(now, EVADE - 1)).is_not_equal(FightInput.EVADE_NAME)
	assert_str(FightInput.pressed(EVADE | JAB, 0)).is_equal(FightInput.EVADE_NAME)


func test_a_backdash_that_breaks_a_rule_is_refused() -> void:
	var path: String = "user://planted_backdash.json"
	var cases: Dictionary = {
		"inside it": func(backdash: Dictionary) -> void: backdash["invulnerable"] = int(backdash["frames"]) + 1,
		"travel inside": func(backdash: Dictionary) -> void: backdash["travel"] = int(backdash["frames"]) + 1,
		"each a whole number": func(backdash: Dictionary) -> void: backdash["speed"] = 7.5,
		"a frame or more": func(backdash: Dictionary) -> void: backdash.merge({"frames": 0, "invulnerable": 0, "travel": 0}, true),
	}
	for expected: String in cases:
		var table: Dictionary = _data.table.duplicate(true)
		(cases[expected] as Callable).call(table["characters"]["dancer"]["backdash"])
		FileAccess.open(path, FileAccess.WRITE).store_string(JSON.stringify(table))
		assert_str(FightData.read(path).refusal).override_failure_message(expected).contains(expected)
	var missing: Dictionary = _data.table.duplicate(true)
	missing["characters"]["lancer"].erase("backdash")
	FileAccess.open(path, FileAccess.WRITE).store_string(JSON.stringify(missing))
	assert_str(FightData.read(path).refusal).contains("lancer's backdash")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


# --- how the opponents read it -------------------------------------------------------

func test_a_backdash_is_read_as_the_evade() -> void:
	var state: FightState = _evading_dancer(3)
	assert_str(FightAction.of(state, 1, _data)).is_equal("evade")
	assert_bool(FightAction.ACTIONS.has("evade")).is_true()
	assert_str(FightSituation.condition_of(state.fighters[1])).is_equal("moving")
	assert_str(FightOpponent.situation_of(state, 0, _data)).is_equal("it evaded")
	state.fighters[1].stun_kind = "block"
	assert_str(FightOpponent.situation_of(state, 0, _data)).is_equal("it blocked")


# The fixed opponent's evade is the evade button, once, then nothing for as
# long as the backdash lasts; its long strike is the one that reaches furthest.
func test_the_fixed_opponent_evades_with_the_button_and_knows_its_longest_strike() -> void:
	var opponent := FightOpponent.new("hard", _data)
	var inputs: Array[int] = opponent._inputs_for("evade", _alone("dancer", 300, 500), 0)
	assert_int(inputs.size()).is_equal(int(_data.character("dancer")["backdash"]["frames"]))
	assert_int(inputs[0]).is_equal(EVADE)
	assert_bool(inputs.slice(1).all(func(input: int) -> bool: return input == 0)).is_true()
	assert_str(FightOpponent.longest_strike(_data, "lancer")).is_equal("thrust")
	assert_str(FightOpponent.longest_strike(_data, "dancer")).is_equal("straight")


# --- helpers ---------------------------------------------------------------------

# `character` as player one at `x`, the lancer or the dancer as player two at
# `other_x`, facing each other.
func _alone(character: String, x: int, other_x: int) -> FightState:
	var state: FightState = FightState.starting(_data, character, "lancer" if character == "dancer" else "dancer")
	state.fighters[0].x = x
	state.fighters[1].x = other_x
	state.fighters[0].facing = signi(other_x - x)
	state.fighters[1].facing = -state.fighters[0].facing
	return state


# The lancer at 300 and the dancer 48 to its right, facing it, on a frame of
# its backdash such that the next step puts it on `frame`.
func _evading_dancer(frame: int) -> FightState:
	var state: FightState = _alone("lancer", 300, 348)
	var dancer: FighterState = state.fighters[1]
	dancer.stun_kind = FightBackdash.KIND
	dancer.stun = int(_data.character("dancer")["backdash"]["frames"]) - frame + 2
	return state


# The lancer's jab one frame from active.
func _jab_arriving_on(state: FightState) -> FightState:
	state.fighters[0].move = "jab"
	state.fighters[0].move_frame = int(_data.move("lancer", "jab")["startup"])
	return state


func _step(state: FightState, first: int, second: int) -> FightState:
	return FightRules.step(state, [first, second] as Array[int], _data)
