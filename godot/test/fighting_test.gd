# T16: the fighting scenario's rules. Frame data from a file, moves that come
# out on the frame the data says, an input buffer and cancel windows, the
# resolution order as written -- blocks, hits, counter-hits, trades -- and
# two characters that differ in a way an opponent can exploit.
extends GdUnitTestSuite

const LEFT: int = FightInput.LEFT
const RIGHT: int = FightInput.RIGHT
const LIGHT: int = FightInput.LIGHT
const HEAVY: int = FightInput.HEAVY

var _data: FightData


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


func test_a_jab_that_connects_cancels_into_a_kick_and_one_that_whiffs_does_not() -> void:
	var close: FightState = _fight_at(520, 580)
	var hit: FightState = _play(close, [[0, LIGHT], [0, 0], [0, 0], [0, 0], [0, HEAVY]])
	assert_str(hit.fighters[1].move).is_equal("kick")
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
	var inputs: Array = [[FightInput.SPECIAL, 0]] + _hold(4, [0, 0]) + [[0, FightInput.SPECIAL]] + _hold(20, [0, 0])
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
	var log: Dictionary = {"characters": ["lancer", "dancer"], "inputs": _hold(30, [RIGHT, LEFT]) + [[LIGHT, LIGHT]] + _hold(30, [0, 0])}
	assert_int(FightReplay.first_difference(FightReplay.digests(log, _data), FightReplay.digests(log, _data))).is_equal(-1)


# --- the scene ---------------------------------------------------------------

# The log the scene keeps is a replay of what it showed: T17 reads it.
func test_the_scene_s_log_replays_to_the_fight_on_screen() -> void:
	var scene: FightingExample = auto_free(load("res://game/fighting/fighting.tscn").instantiate())
	add_child(scene)
	scene.paused = true
	scene.dummy_mode = "jab"
	for frame: int in range(90):
		scene.step_decision()
	var log: Dictionary = {"characters": [scene.state.fighters[0].character, scene.state.fighters[1].character],
			"inputs": scene.log}
	var replayed: Array[String] = FightReplay.digests(log, _data)
	assert_str(replayed[replayed.size() - 1]).is_equal(scene.state.digest())


func test_the_blocking_dummy_takes_no_damage_from_a_thrust() -> void:
	var scene: FightingExample = auto_free(load("res://game/fighting/fighting.tscn").instantiate())
	add_child(scene)
	scene.paused = true
	scene.dummy_mode = "block"
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
