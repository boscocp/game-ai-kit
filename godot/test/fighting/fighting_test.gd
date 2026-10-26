# T16 and T34: the fighting scenario's rules. Frame data from a file, moves
# that come out on the frame the data says, an input buffer and cancel
# windows, the resolution order as written -- blocks, hits, counter-hits,
# trades, guards that have a height, throws -- and two characters that differ
# in a way an opponent can exploit.
extends GdUnitTestSuite

const LEFT: int = FightInput.LEFT
const RIGHT: int = FightInput.RIGHT
const DOWN: int = FightInput.DOWN
const LIGHT: int = FightInput.LIGHT_PUNCH
const HEAVY: int = FightInput.HEAVY_PUNCH
const THROW: int = FightInput.THROW
## The lancer's sweep, a low: heavy kick while holding down.
const SWEEP: int = FightInput.DOWN | FightInput.HEAVY_KICK
## The lancer's axe kick, an overhead: heavy kick standing.
const AXE_KICK: int = FightInput.HEAVY_KICK

var _data: FightData

# English, whatever the machine speaks: the engine starts in the system's
# locale, and these read the English the game writes (T80). The locale
# found is put back.
var _locale_before: String


func before() -> void:
	_locale_before = TranslationServer.get_locale()
	TranslationServer.set_locale("en")


func after() -> void:
	TranslationServer.set_locale(_locale_before)


func before_test() -> void:
	_data = FightData.read()


# --- the frame data --------------------------------------------------------

func test_the_game_s_frame_data_is_the_spec_s_byte_for_byte() -> void:
	var spec: String = ProjectSettings.globalize_path("res://").path_join("../spec/frames/characters.json")
	assert_str(FileAccess.get_file_as_string(FightData.PATH)).is_equal(FileAccess.get_file_as_string(spec))
	assert_str(_data.refusal).is_empty()


func test_a_frame_count_that_is_not_whole_is_refused() -> void:
	var path: String = "user://planted_characters.json"
	var table: Dictionary = _data.table.duplicate(true)
	table["characters"]["dancer"]["moves"]["jab"]["startup"] = 3.5
	FileAccess.open(path, FileAccess.WRITE).store_string(JSON.stringify(table))
	assert_str(FightData.read(path).refusal).contains("startup")
	table["characters"]["dancer"]["moves"]["jab"]["startup"] = 3
	table["characters"]["dancer"]["moves"]["jab"].erase("damage")
	FileAccess.open(path, FileAccess.WRITE).store_string(JSON.stringify(table))
	assert_str(FightData.read(path).refusal).contains("damage")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


# --- a move comes out when the data says ---------------------------------

func test_a_hitbox_is_out_on_exactly_the_active_frames() -> void:
	var jab: Dictionary = _data.move("lancer", "jab")
	var state: FightState = _fight()
	state = _play(state, [[LIGHT, 0]])
	var out_on: Array[int] = []
	for frame: int in range(1, _data.length_of("lancer", "jab") + 1):
		if not FightBoxes.hitbox(state.fighters[0], _data).is_empty():
			out_on.append(frame)
		state = _play(state, [[0, 0]])
	var startup: int = int(jab["startup"])
	assert_array(out_on).is_equal(range(startup + 1, startup + int(jab["active"]) + 1))


func test_holding_a_button_does_not_repeat_the_move() -> void:
	var held: Array = []
	for frame: int in range(_data.length_of("dancer", "jab") + 3):
		held.append([0, LIGHT])
	var state: FightState = _play(_fight(), held)
	assert_str(state.fighters[1].move).is_empty()


# --- the buffer and cancels --------------------------------------------------

func test_a_press_during_recovery_comes_out_on_the_first_free_frame() -> void:
	var length: int = _data.length_of("dancer", "jab")
	var inputs: Array = [[0, LIGHT]]
	for frame: int in range(length - 3):
		inputs.append([0, 0])
	inputs.append([0, LIGHT])    # on the jab's next-to-last frame, inside the buffer
	inputs.append_array([[0, 0], [0, 0]])    # its last frame, then the first free one
	var state: FightState = _play(_fight(), inputs)
	assert_str(state.fighters[1].move).is_equal("jab")
	assert_int(state.fighters[1].move_frame).is_equal(1)


func test_a_press_older_than_the_buffer_is_forgotten() -> void:
	var length: int = _data.length_of("lancer", "thrust")
	var inputs: Array = [[HEAVY, 0], [0, 0], [LIGHT, 0]]
	for frame: int in range(length + 2):
		inputs.append([0, 0])
	var state: FightState = _play(_fight(), inputs)
	assert_bool(length - 2 > _data.number("buffer_frames")).is_true()
	assert_str(state.fighters[0].move).is_empty()


func test_a_jab_that_connects_cancels_into_a_straight_and_one_that_whiffs_does_not() -> void:
	var close: FightState = _fight_at(520, 580)
	var hit: FightState = _play(close, [[0, LIGHT], [0, 0], [0, 0], [0, 0], [0, HEAVY]])
	assert_str(hit.fighters[1].move).is_equal("straight")
	assert_int(hit.fighters[1].move_frame).is_equal(1)
	var far: FightState = _play(_fight(), [[0, LIGHT], [0, 0], [0, 0], [0, 0], [0, HEAVY]])
	assert_str(far.fighters[1].move).is_equal("jab")


# --- the resolution order ------------------------------------------------------

func test_holding_away_blocks_and_takes_no_damage() -> void:
	var inputs: Array = [[HEAVY, RIGHT]] + _hold(20, [0, RIGHT])
	assert_str(_all_events(_fight_at(480, 618), inputs)).contains("p1 is blocked by p2 with thrust")
	var state: FightState = _play(_fight_at(480, 618), inputs)
	assert_int(state.fighters[1].health).is_equal(int(_data.character("dancer")["health"]))


func test_a_hit_in_the_defender_s_startup_is_a_counter_hit_for_more() -> void:
	var events: String = _all_events(_fight_at(546, 618), [[LIGHT, 0], [0, LIGHT]] + _hold(10, [0, 0]))
	assert_str(events).contains("p2 counter-hits p1 with jab")
	var damage: int = int(_data.move("dancer", "jab")["damage"]) * int(_data.table["counter_hit"]["damage_percent"]) / 100
	var state: FightState = _play(_fight_at(546, 618), [[LIGHT, 0], [0, LIGHT]] + _hold(10, [0, 0]))
	assert_int(state.fighters[0].health).is_equal(int(_data.character("lancer")["health"]) - damage)


func test_two_hits_on_one_frame_are_a_trade_and_both_land() -> void:
	# The sweep pressed on frame 1 and the snap kick on frame 7 are both active
	# from frame 11. A kick, not a punch: a high punch would pass over the sweep.
	var inputs: Array = [[SWEEP, 0]] + _hold(5, [0, 0]) + [[0, FightInput.LIGHT_KICK]] + _hold(20, [0, 0])
	assert_str(_all_events(_fight_at(530, 618), inputs)).contains("trade")
	var state: FightState = _play(_fight_at(530, 618), inputs)
	assert_int(state.fighters[0].health).is_less(int(_data.character("lancer")["health"]))
	assert_int(state.fighters[1].health).is_less(int(_data.character("dancer")["health"]))


func test_a_move_connects_once() -> void:
	var state: FightState = _play(_fight_at(480, 618), [[HEAVY, 0]] + _hold(30, [0, 0]))
	var thrust: int = int(_data.move("lancer", "thrust")["damage"])
	assert_int(state.fighters[1].health).is_equal(int(_data.character("dancer")["health"]) - thrust)


func test_bodies_never_overlap_and_stay_on_the_stage() -> void:
	var state: FightState = _play(_fight(), _hold(200, [RIGHT, LEFT]))
	var gap: int = absi(state.fighters[1].x - state.fighters[0].x)
	assert_int(gap).is_greater_equal(int(_data.character("lancer")["body"]) + int(_data.character("dancer")["body"]))
	state = _play(_fight(), _hold(300, [LEFT, RIGHT]))
	assert_int(state.fighters[0].x).is_equal(int(_data.character("lancer")["body"]))


# --- two characters an opponent can tell apart ---------------------------------

func test_the_lancer_reaches_further_and_the_dancer_is_quicker() -> void:
	var lancer_jab: Dictionary = _data.move("lancer", "jab")
	var dancer_jab: Dictionary = _data.move("dancer", "jab")
	assert_int(int(lancer_jab["hitbox"][1])).is_greater(int(dancer_jab["hitbox"][1]))
	assert_int(int(dancer_jab["startup"])).is_less(int(lancer_jab["startup"]))
	assert_int(int(_data.character("dancer")["walk_speed"])).is_greater(int(_data.character("lancer")["walk_speed"]))


func test_a_replay_of_the_same_inputs_is_the_same_fight() -> void:
	var input_log: Dictionary = {"characters": ["lancer", "dancer"], "inputs": _hold(30, [RIGHT, LEFT]) + [[LIGHT, LIGHT]] + _hold(30, [0, 0])}
	assert_int(FightReplay.first_difference(FightReplay.digests(input_log, _data), FightReplay.digests(input_log, _data))).is_equal(-1)


# --- the scene ---------------------------------------------------------------

# The input_log the scene keeps is a replay of what it showed: T17 reads it.
func test_the_scene_s_log_replays_to_the_fight_on_screen() -> void:
	var scene: FightingExample = auto_free(load("res://game/fighting/fighting.tscn").instantiate())
	add_child(scene)
	scene.paused = true
	scene.dummy_mode = "jab"
	for frame: int in range(90):
		scene.step_decision()
	var input_log: Dictionary = {"characters": [scene.state.fighters[0].character, scene.state.fighters[1].character],
			"inputs": scene.input_log}
	var replayed: Array[String] = FightReplay.digests(input_log, _data)
	assert_str(replayed[replayed.size() - 1]).is_equal(scene.state.digest())


func test_the_blocking_dummy_takes_no_damage_from_a_thrust() -> void:
	var scene: FightingExample = auto_free(load("res://game/fighting/fighting.tscn").instantiate())
	add_child(scene)
	scene.paused = true
	scene.dummy_mode = "guard standing"
	scene.state.fighters[1].x = 618
	scene.state.fighters[0].x = 480
	scene.state = FightRules.step(scene.state, [HEAVY, scene._dummy_input()] as Array[int], _data)
	for frame: int in range(30):
		scene.state = FightRules.step(scene.state, [0, scene._dummy_input()] as Array[int], _data)
	assert_int(scene.state.fighters[1].health).is_equal(int(_data.character("dancer")["health"]))


func test_the_panel_names_the_move_its_frame_and_its_phase() -> void:
	var state: FightState = _play(_fight(), [[HEAVY, 0], [0, 0]])
	var words: String = FightingPanel.describe(state, _data, true)
	assert_str(words).contains("thrust, frame 2 of %d, startup" % _data.length_of("lancer", "thrust"))
	assert_str(words).contains("paused")


# --- the wave 34 review: one test per rule ------------------------------------

# A press is kept for exactly `buffer_frames` frames: on the last of them it
# still comes out, one frame later it is gone.
func test_the_buffer_lasts_exactly_its_frames() -> void:
	var length: int = _data.length_of("lancer", "thrust")
	var keep: int = _data.number("buffer_frames")
	for early: int in [0, 1]:
		var pressed_on: int = length + 2 - keep - early
		var inputs: Array = [[HEAVY, 0]] + _hold(pressed_on - 2, [0, 0]) + [[LIGHT, 0]]
		inputs += _hold(length + 1 - pressed_on, [0, 0])
		var state: FightState = _play(_fight(), inputs)
		var expected: String = "jab" if early == 0 else ""
		assert_int(state.frame).is_equal(length + 1)
		assert_str(state.fighters[0].move).override_failure_message("pressed %d early" % early).is_equal(expected)


func test_a_cancel_happens_on_the_window_s_last_frame_and_not_after() -> void:
	var window: Array = _data.move("dancer", "jab")["cancel_window"]
	var last: int = int(window[1])
	var on_time: FightState = _play(_fight_at(520, 580), [[0, LIGHT]] + _hold(last - 2, [0, 0]) + [[0, HEAVY]])
	assert_str(on_time.fighters[1].move).is_equal("straight")
	var late: FightState = _play(_fight_at(520, 580), [[0, LIGHT]] + _hold(last - 1, [0, 0]) + [[0, HEAVY]])
	assert_str(late.fighters[1].move).is_equal("jab")
	assert_str(_all_events(_fight_at(520, 580), [[0, LIGHT]] + _hold(last - 2, [0, 0]) + [[0, HEAVY]])).contains(
			"p2 cancels jab into straight")


func test_a_move_cancels_only_into_the_moves_it_lists() -> void:
	var opens: int = int(_data.move("lancer", "jab")["cancel_window"][0])
	var listed: FightState = _play(_fight_at(520, 580), [[LIGHT, 0]] + _hold(opens, [0, 0]) + [[HEAVY, 0]])
	assert_str(listed.fighters[0].move).is_equal("thrust")
	var unlisted: FightState = _play(_fight_at(520, 580), [[LIGHT, 0]] + _hold(opens, [0, 0]) + [[AXE_KICK, 0]])
	assert_str(unlisted.fighters[0].move).is_equal("jab")


func test_a_hit_pushes_the_defender_away() -> void:
	var before: FightState = _fight_at(440, 560)
	var inputs: Array = [[HEAVY, 0]] + _hold(int(_data.move("lancer", "thrust")["startup"]), [0, 0])
	var after: FightState = _play(before, inputs)
	assert_str(", ".join(after.events)).contains("p1 hits p2")
	assert_int(after.fighters[1].x).is_equal(560 + _data.number("pushback"))
	assert_int(after.fighters[0].x).is_equal(440)


# Against a wall the defender cannot go back, so the attacker does.
func test_against_a_wall_the_attacker_takes_the_pushback() -> void:
	var inputs: Array = [[HEAVY, 0]] + _hold(int(_data.move("lancer", "thrust")["startup"]), [0, 0])
	var after: FightState = _play(_fight_at(480, 618), inputs)
	assert_int(after.fighters[1].x).is_equal(618)
	assert_int(after.fighters[0].x).is_equal(480 - _data.number("pushback"))


func test_two_knockouts_on_one_frame_are_a_draw() -> void:
	var start: FightState = _fight_at(530, 618)
	start.fighters[0].health = 1
	start.fighters[1].health = 1
	var inputs: Array = [[SWEEP, 0]] + _hold(5, [0, 0]) + [[0, FightInput.LIGHT_KICK]] + _hold(10, [0, 0])
	assert_int(_play(start, inputs).winner).is_equal(FightState.DRAW)


# Holding away blocks while free or already blocking -- and not in hitstun.
func test_a_fighter_already_blocking_blocks_again_and_one_in_hitstun_cannot() -> void:
	for kind: String in ["block", "hit"]:
		var state: FightState = _fight_at(480, 560)
		state.fighters[0].move = "thrust"
		state.fighters[0].move_frame = int(_data.move("lancer", "thrust")["startup"])
		state.fighters[1].stun = 5
		state.fighters[1].stun_kind = kind
		var after: FightState = FightRules.step(state, [0, RIGHT] as Array[int], _data)
		var expected: String = "is blocked by" if kind == "block" else "hits"
		assert_str(", ".join(after.events)).override_failure_message(kind).contains(expected)


func test_a_counter_hit_adds_its_hitstun() -> void:
	# The dancer presses on frame 2; its jab is active from its own frame 4,
	# frame 5 of the fight, the frame the counter-hit lands on.
	var state: FightState = _play(_fight_at(546, 618), [[LIGHT, 0], [0, LIGHT]] + _hold(3, [0, 0]))
	assert_str(", ".join(state.events)).contains("counter-hits")
	var expected: int = int(_data.move("dancer", "jab")["hitstun"]) + int(_data.table["counter_hit"]["extra_hitstun"])
	assert_int(state.fighters[0].stun).is_equal(expected)


func test_a_fighter_in_a_move_keeps_facing_the_way_it_was() -> void:
	var state: FightState = _fight_at(300, 340)
	state.fighters[0].move = "thrust"
	state.fighters[0].move_frame = 1
	state.fighters[1].x = 200
	var after: FightState = FightRules.step(state, [0, 0] as Array[int], _data)
	assert_int(after.fighters[0].facing).is_equal(1)
	assert_int(after.fighters[1].facing).is_equal(1)


# The mirror image of a push is the same push: a dancer walking right into
# another moves the pair exactly as one walking left does, mirrored.
func test_pushing_right_and_pushing_left_are_mirror_images() -> void:
	var width: int = int(_data.table["stage"]["width"])
	var rightwards: FightState = FightState.starting(_data, "dancer", "dancer")
	rightwards.fighters[0].x = 300
	rightwards.fighters[1].x = 345
	var leftwards: FightState = rightwards.copy()
	leftwards.fighters[0].x = width - 345
	leftwards.fighters[1].x = width - 300
	leftwards.fighters[0].facing = 1
	leftwards.fighters[1].facing = -1
	for frame: int in range(9):
		rightwards = FightRules.step(rightwards, [RIGHT, 0] as Array[int], _data)
		leftwards = FightRules.step(leftwards, [0, LEFT] as Array[int], _data)
	assert_int(rightwards.fighters[0].x).is_equal(width - leftwards.fighters[1].x)
	assert_int(rightwards.fighters[1].x).is_equal(width - leftwards.fighters[0].x)


func test_boxes_that_touch_at_an_edge_overlap() -> void:
	assert_bool(FightBoxes.overlap([0, 10] as Array[int], [10, 20] as Array[int])).is_true()
	assert_bool(FightBoxes.overlap([0, 9] as Array[int], [10, 20] as Array[int])).is_false()


func test_frame_data_that_breaks_a_rule_is_refused() -> void:
	var path: String = "user://planted_characters.json"
	var cases: Dictionary = {
		"startup": func(moves: Dictionary) -> void: moves["jab"]["startup"] = 0,
		"damage": func(moves: Dictionary) -> void: moves["jab"]["damage"] = -40,
		"cancels into": func(moves: Dictionary) -> void: moves["jab"]["cancels_into"] = ["haymaker"],
		"button": func(moves: Dictionary) -> void: moves["jab"].erase("button"),
		"hitbox": func(moves: Dictionary) -> void: moves["jab"]["hitbox"] = [14, 50.5],
		"stance": func(moves: Dictionary) -> void: moves["jab"]["stance"] = "kneeling",
		"a throw": func(moves: Dictionary) -> void: moves["jab"]["height"] = "throw",
		"tell them apart": func(moves: Dictionary) -> void: moves["jab"]["button"] = "heavy_punch",
		"a height among": func(moves: Dictionary) -> void: moves["jab"]["height"] = "Low",
		"done standing": func(moves: Dictionary) -> void: moves["jab"].merge({"height": "throw", "button": "throw", "stance": "crouching"}, true),
		"standing it does nothing": _jab_only_in_the_air,
		"hits as an overhead": _jab_in_the_air_still_high,
		"needs a rise": func(moves: Dictionary) -> void: moves["jab"]["rise"] = [40.5, 90],
	}
	for expected: String in cases:
		var table: Dictionary = _data.table.duplicate(true)
		(cases[expected] as Callable).call(table["characters"]["dancer"]["moves"])
		FileAccess.open(path, FileAccess.WRITE).store_string(JSON.stringify(table))
		assert_str(FightData.read(path).refusal).override_failure_message(expected).contains(expected)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


# The dancer's light punch made an air move only: pressed standing, it would
# do nothing.
func _jab_only_in_the_air(moves: Dictionary) -> void:
	moves.erase("air_jab")
	moves["jab"].merge({"stance": "air", "height": "overhead"}, true)


# The dancer's light punch made an air move that is still a high.
func _jab_in_the_air_still_high(moves: Dictionary) -> void:
	moves.erase("air_jab")
	moves["jab"]["stance"] = "air"


# --- T34: guards that have a height, and the throw -----------------------------

func test_holding_down_crouches_and_does_not_walk() -> void:
	var state: FightState = _play(_fight(), _hold(20, [DOWN | RIGHT, 0]))
	assert_int(state.fighters[0].x).is_equal(int(_data.table["stage"]["starts"][0]))
	assert_bool(state.fighters[0].crouching).is_true()
	assert_bool(_play(state, [[RIGHT, 0]]).fighters[0].crouching).is_false()


# Holding down picks a button's crouching move; a button with none does its
# standing one, so no button is dead while crouched.
func test_holding_down_picks_the_crouching_move_and_falls_back_to_standing() -> void:
	assert_str(_play(_fight(), [[DOWN | FightInput.LIGHT_KICK, 0]]).fighters[0].move).is_equal("low_kick")
	assert_str(_play(_fight(), [[FightInput.LIGHT_KICK, 0]]).fighters[0].move).is_equal("side_kick")
	var throw: FighterState = _play(_fight(), [[DOWN | THROW, 0]]).fighters[0]
	assert_str(throw.move).is_equal("throw")
	assert_bool(throw.crouching).is_false()
	assert_str(_play(_fight(), [[DOWN | HEAVY, 0]]).fighters[0].move).is_equal("uppercut")


func test_a_low_gets_through_a_standing_guard_and_not_a_crouching_one() -> void:
	var inputs: Array = [[SWEEP, RIGHT]] + _hold(20, [0, RIGHT])
	assert_str(_all_events(_fight_at(530, 618), inputs)).contains("p1 hits p2 with sweep (a low through a standing guard)")
	inputs = [[SWEEP, RIGHT | DOWN]] + _hold(20, [0, RIGHT | DOWN])
	assert_str(_all_events(_fight_at(530, 618), inputs)).contains("p1 is blocked by p2 with sweep (holding away, crouching)")
	assert_int(_play(_fight_at(530, 618), inputs).fighters[1].health).is_equal(int(_data.character("dancer")["health"]))


func test_an_overhead_gets_through_a_crouching_guard_and_not_a_standing_one() -> void:
	var inputs: Array = [[AXE_KICK, RIGHT | DOWN]] + _hold(30, [0, RIGHT | DOWN])
	assert_str(_all_events(_fight_at(530, 618), inputs)).contains("p1 hits p2 with axe_kick (an overhead through a crouching guard)")
	inputs = [[AXE_KICK, RIGHT]] + _hold(30, [0, RIGHT])
	assert_str(_all_events(_fight_at(530, 618), inputs)).contains("p1 is blocked by p2 with axe_kick (holding away, standing)")


# A mid is stopped by either guard: the lancer's side kick.
func test_a_mid_is_stopped_by_both_guards() -> void:
	for guard: int in [RIGHT, RIGHT | DOWN]:
		var inputs: Array = [[FightInput.LIGHT_KICK, guard]] + _hold(20, [0, guard])
		assert_str(_all_events(_fight_at(530, 618), inputs)).contains("p1 is blocked by p2 with side_kick")


# T39: a standing punch is high. It passes over a crouching fighter --
# guarding or not, nothing connects -- lands on a standing one, and is
# stopped by a standing guard. A kick at the same crouch still lands.
func test_a_high_punch_passes_over_a_crouch_and_a_kick_does_not() -> void:
	var full: int = int(_data.character("dancer")["health"])
	for crouch: int in [DOWN, DOWN | RIGHT]:
		var inputs: Array = [[HEAVY, crouch]] + _hold(20, [0, crouch])
		var events: String = _all_events(_fight_at(480, 618), inputs)
		assert_str(events).contains("p1's thrust passes over p2 (a high misses a crouch)")
		assert_str(events).not_contains("p1 hits")
		assert_str(events).not_contains("blocked")
		assert_int(_play(_fight_at(480, 618), inputs).fighters[1].health).is_equal(full)
	assert_str(_all_events(_fight_at(480, 618), [[HEAVY, 0]] + _hold(20, [0, 0]))).contains("p1 hits p2 with thrust")
	assert_str(_all_events(_fight_at(480, 618), [[HEAVY, RIGHT]] + _hold(20, [0, RIGHT]))).contains(
			"p1 is blocked by p2 with thrust")
	var kick: Array = [[FightInput.LIGHT_KICK, DOWN]] + _hold(20, [0, DOWN])
	assert_str(_all_events(_fight_at(530, 618), kick)).contains("p1 hits p2 with side_kick")


# A kick aimed at the head is high too: the dancer's roundhouse passes over
# a crouching lancer and lands on a standing one.
func test_a_high_kick_passes_over_a_crouch() -> void:
	var crouched: Array = [[DOWN, FightInput.HEAVY_KICK]] + _hold(30, [DOWN, 0])
	var events: String = _all_events(_fight_at(560, 618), crouched)
	assert_str(events).contains("p2's roundhouse passes over p1")
	assert_str(events).not_contains("hits")
	var standing: Array = [[0, FightInput.HEAVY_KICK]] + _hold(30, [0, 0])
	assert_str(_all_events(_fight_at(560, 618), standing)).contains("p2 hits p1 with roundhouse")


# A high passes over a fighter crouching in a move too: the dancer's straight
# over the lancer's sweep, which lands alone -- no trade.
func test_a_high_passes_over_a_crouching_move() -> void:
	var inputs: Array = [[SWEEP, 0]] + _hold(2, [0, 0]) + [[0, HEAVY]] + _hold(20, [0, 0])
	var events: String = _all_events(_fight_at(530, 618), inputs)
	assert_str(events).contains("p2's straight passes over p1 (a high misses a crouch)")
	assert_str(events).contains("p1 hits p2 with sweep")
	assert_str(events).not_contains("trade")


# Hitstun is taken standing: the dancer's jab, landing on frame 4, cancelled
# into its straight, lands both, though the lancer holds down from frame 5.
func test_a_fighter_in_hitstun_cannot_duck_the_next_hit() -> void:
	var inputs: Array = [[0, LIGHT]] + _hold(3, [0, 0]) + [[DOWN, HEAVY]] + _hold(20, [DOWN, 0])
	var events: String = _all_events(_fight_at(520, 580), inputs)
	assert_str(events).contains("p2 hits p1 with jab")
	assert_str(events).contains("p2 hits p1 with straight")


func test_every_standing_punch_is_high() -> void:
	for name: String in _data.character_names():
		for button: String in ["light_punch", "heavy_punch"]:
			var move: String = _data.move_for_button(name, button)
			assert_str(_data.move(name, move)["height"]).override_failure_message("%s's %s" % [name, move]).is_equal("high")


func test_a_throw_gets_through_either_guard() -> void:
	var damage: int = int(_data.move("lancer", "throw")["damage"])
	for guard: int in [RIGHT, RIGHT | DOWN]:
		var inputs: Array = [[THROW, guard]] + _hold(10, [0, guard])
		assert_str(_all_events(_fight_at(560, 618), inputs)).contains("p1 throws p2 with throw (a throw cannot be blocked)")
		assert_int(_play(_fight_at(560, 618), inputs).fighters[1].health).is_equal(int(_data.character("dancer")["health"]) - damage)


# A throw does not find a fighter in stun -- and does find the same fighter
# out of it, so the test can tell "no throw" from "no reach".
# Stun is counted down in step 2, before step 4 looks: a fighter starting the
# frame with 2 left still has 1, and one starting with 1 has none.
func test_a_throw_cannot_catch_a_fighter_in_stun() -> void:
	for kind: String in ["block", "hit"]:
		for stun: int in [2, 1]:
			var state: FightState = _fight_at(560, 618)
			state.fighters[0].move = "throw"
			state.fighters[0].move_frame = int(_data.move("lancer", "throw")["startup"])
			state.fighters[1].stun = stun
			state.fighters[1].stun_kind = kind
			var thrown: bool = ", ".join(FightRules.step(state, [0, 0] as Array[int], _data).events).contains("throws")
			assert_bool(thrown).override_failure_message("%sstun %d" % [kind, stun]).is_equal(stun == 1)


func test_a_throw_is_never_a_counter_hit() -> void:
	var state: FightState = _fight_at(560, 618)
	state.fighters[0].move = "throw"
	state.fighters[0].move_frame = int(_data.move("lancer", "throw")["startup"])
	state.fighters[1].move = "roundhouse"
	state.fighters[1].move_frame = 1
	var after: FightState = FightRules.step(state, [0, 0] as Array[int], _data)
	assert_str(", ".join(after.events)).contains("p1 throws p2")
	assert_int(after.fighters[1].stun).is_equal(int(_data.move("lancer", "throw")["hitstun"]))


# The lancer's throw pressed on frame 1 and the dancer's on frame 2 are both
# active from frame 6.
func test_two_throws_on_one_frame_break_each_other() -> void:
	var inputs: Array = [[THROW, 0], [0, THROW]] + _hold(10, [0, 0])
	assert_str(_all_events(_fight_at(560, 618), inputs)).contains("the throws clash and both break")
	var after: FightState = _play(_fight_at(560, 618), inputs)
	assert_int(after.fighters[0].health).is_equal(int(_data.character("lancer")["health"]))
	assert_int(after.fighters[1].health).is_equal(int(_data.character("dancer")["health"]))
	# On the clash frame itself: both moves over, and both pushed -- the
	# dancer is at its wall, so the lancer takes both pushes.
	var clash: FightState = _play(_fight_at(560, 618), [[THROW, 0], [0, THROW]] + _hold(4, [0, 0]))
	assert_str(clash.fighters[0].move + clash.fighters[1].move).is_empty()
	assert_int(clash.fighters[1].x).is_equal(618)
	assert_int(clash.fighters[0].x).is_equal(560 - 2 * _data.number("pushback"))
	var open: FightState = _play(_fight_at(300, 358), [[THROW, 0], [0, THROW]] + _hold(4, [0, 0]))
	assert_int(open.fighters[0].x).is_equal(300 - _data.number("pushback"))
	assert_int(open.fighters[1].x).is_equal(358 + _data.number("pushback"))


# The lancer's throw pressed on frame 1 and the dancer's jab on frame 3 are
# both active on frame 6: the strike lands and the throw does not.
func test_a_strike_beats_a_throw_on_the_same_frame() -> void:
	var inputs: Array = [[THROW, 0], [0, 0], [0, LIGHT]] + _hold(6, [0, 0])
	assert_str(_all_events(_fight_at(560, 618), inputs)).contains("p1's throw is beaten by p2's jab")
	var after: FightState = _play(_fight_at(560, 618), inputs)
	assert_int(after.fighters[1].health).is_equal(int(_data.character("dancer")["health"]))
	assert_int(after.fighters[0].health).is_equal(int(_data.character("lancer")["health"]) - int(_data.move("dancer", "jab")["damage"]))


# Light is quick and does little, heavy is slow and does a lot: for both
# characters, punch and kick alike.
func test_light_buttons_are_quicker_and_heavy_ones_hurt_more() -> void:
	for name: String in _data.character_names():
		for pair: Array in [["light_punch", "heavy_punch"], ["light_kick", "heavy_kick"]]:
			var light: Dictionary = _data.move(name, _data.move_for_button(name, pair[0]))
			var heavy: Dictionary = _data.move(name, _data.move_for_button(name, pair[1]))
			assert_int(int(light["startup"])).override_failure_message("%s %s" % [name, pair]).is_less(int(heavy["startup"]))
			assert_int(int(light["damage"])).override_failure_message("%s %s" % [name, pair]).is_less(int(heavy["damage"]))


# A cancel takes the crouching move when down is held as it comes out: the
# lancer's jab that hit cancels into its low kick, and without down into
# nothing it lists, since its standing light kick is not in `cancels_into`.
func test_a_cancel_with_down_held_takes_the_crouching_move() -> void:
	var opens: int = int(_data.move("lancer", "jab")["cancel_window"][0])
	var low: FightState = _play(_fight_at(520, 580), [[LIGHT, 0]] + _hold(opens, [0, 0]) + [[DOWN | FightInput.LIGHT_KICK, 0]])
	assert_str(low.fighters[0].move).is_equal("low_kick")
	var standing: FightState = _play(_fight_at(520, 580), [[LIGHT, 0]] + _hold(opens, [0, 0]) + [[FightInput.LIGHT_KICK, 0]])
	assert_str(standing.fighters[0].move).is_equal("jab")


func test_the_dummy_guards_crouching_and_throws_as_its_modes_say() -> void:
	var scene: FightingExample = auto_free(load("res://game/fighting/fighting.tscn").instantiate())
	add_child(scene)
	scene.dummy_mode = "guard crouching"
	assert_int(scene._dummy_input()).is_equal(FightInput.RIGHT | DOWN)
	scene.dummy_mode = "throw"
	scene.state.frame = 0
	assert_int(scene._dummy_input()).is_equal(THROW)
	scene.state.frame = 1
	assert_int(scene._dummy_input()).is_equal(0)


# --- helpers -------------------------------------------------------------------

func _fight() -> FightState:
	return FightState.starting(_data, "lancer", "dancer")


func _fight_at(lancer_x: int, dancer_x: int) -> FightState:
	var state: FightState = _fight()
	state.fighters[0].x = lancer_x
	state.fighters[1].x = dancer_x
	return state


func _play(state: FightState, inputs: Array) -> FightState:
	for pair: Array in inputs:
		state = FightRules.step(state, [int(pair[0]), int(pair[1])] as Array[int], _data)
	return state


func _all_events(state: FightState, inputs: Array) -> String:
	var seen: PackedStringArray = PackedStringArray()
	for pair: Array in inputs:
		state = FightRules.step(state, [int(pair[0]), int(pair[1])] as Array[int], _data)
		seen.append_array(state.events)
	return ", ".join(seen)


func _hold(frames: int, pair: Array) -> Array:
	var held: Array = []
	for frame: int in range(frames):
		held.append(pair)
	return held
