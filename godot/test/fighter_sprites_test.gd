# T35: the fighters' pictures. Every move the frame data has is drawn, each
# phase of a move shows that phase's cels and no others -- so the picture of
# a move can never disagree with its boxes -- every strip on disk is the size
# its table says, and a fighter with no strips falls back on its block.
extends GdUnitTestSuite

const PHASES: Array[String] = ["startup", "active", "recovery"]

var _data: FightData
var _sprites: FighterSprites


func before_test() -> void:
	_data = FightData.read()
	_sprites = FighterSprites.read()


func test_every_move_of_every_character_has_cels_for_every_phase() -> void:
	for character: String in _data.character_names():
		for move: String in _data.character(character)["moves"]:
			var label: String = "%s's %s" % [character, move]
			assert_array(_phase_sizes(character, move)).override_failure_message(label).not_contains([0])


# The point of the table: on every frame of every move, the cel shown is one
# of the cels listed for the phase the frame data says the move is in.
func test_each_frame_of_a_move_shows_a_cel_of_its_own_phase() -> void:
	for character: String in _data.character_names():
		for move: String in _data.character(character)["moves"]:
			_assert_phases_line_up(character, move)


func test_every_strip_is_its_cels_side_by_side() -> void:
	for character: String in _data.character_names():
		var cell: Vector2i = _sprites.cell(character)
		var drawn: Dictionary = _sprites.table["characters"][character]
		for animation: String in drawn["animations"].keys() + drawn["moves"].keys():
			var strip: Texture2D = _sprites.strip(character, animation)
			assert_object(strip).override_failure_message("%s %s" % [character, animation]).is_not_null()
			var expected := Vector2i(cell.x * _sprites.cels(character, animation).size(), cell.y)
			assert_that(Vector2i(strip.get_size())).override_failure_message("%s %s" % [character, animation]).is_equal(expected)


func test_a_cel_is_inside_its_sheet() -> void:
	for character: String in _data.character_names():
		var drawn: Dictionary = _sprites.table["characters"][character]
		var sheet: Dictionary = _sprites.table["sheets"][drawn["sheet"]]
		var last: int = int(sheet["columns"]) * int(sheet["rows"]) - 1
		var every: Array[int] = []
		for animation: String in drawn["animations"].keys() + drawn["moves"].keys():
			every.append_array(_sprites.cels(character, animation))
		assert_int(every.max()).is_less_equal(last)
		assert_int(every.min()).is_greater_equal(0)


func test_the_pose_follows_the_fight() -> void:
	var fighter := FighterState.new("lancer", 300, 1000)
	assert_array(_sprites.pose(fighter, _data, 0, false)).is_equal(["idle", 0])
	fighter.crouching = true
	assert_str(_sprites.pose(fighter, _data, 0, false)[0]).is_equal("crouch")
	fighter.stun = 10
	fighter.stun_kind = "block"
	assert_str(_sprites.pose(fighter, _data, 0, false)[0]).is_equal("guard_crouching")
	fighter.stun_kind = "hit"
	assert_str(_sprites.pose(fighter, _data, 0, false)[0]).is_equal("hit")
	fighter.stun = 0
	fighter.crouching = false
	fighter.held_before = FightInput.RIGHT
	assert_str(_sprites.pose(fighter, _data, 0, false)[0]).is_equal("walk")
	assert_str(_sprites.pose(fighter, _data, 0, true)[0]).is_equal("down")


# Every cel a move lists is shown on some frame of it: a table cel that is
# never reached is a picture nobody sees.
func test_every_cel_of_a_move_is_shown() -> void:
	for character: String in _data.character_names():
		for move: String in _data.character(character)["moves"]:
			var label: String = "%s's %s" % [character, move]
			var listed: int = _sprites.cels(character, move).size()
			assert_int(_cels_shown(character, move).size()).override_failure_message(label).is_equal(listed)


# A hit plays forwards: the first cel at the start of the stun, the last as
# it ends.
func test_a_hit_plays_from_its_first_cel_to_its_last() -> void:
	var fighter := FighterState.new("dancer", 300, 900)
	fighter.stun_kind = "hit"
	var last: int = _sprites.cels("dancer", "hit").size() - 1
	fighter.stun = (last + 1) * FighterSprites.STUN_PER_CEL
	assert_int(int(_sprites.pose(fighter, _data, 0, false)[1])).is_equal(0)
	fighter.stun = 1
	assert_int(int(_sprites.pose(fighter, _data, 0, false)[1])).is_equal(last)


func test_standing_still_breathes_with_the_fight_s_frame() -> void:
	var fighter := FighterState.new("lancer", 300, 1000)
	var first: int = int(_sprites.pose(fighter, _data, 0, false)[1])
	var later: int = int(_sprites.pose(fighter, _data, FighterSprites.FRAMES_PER_CEL, false)[1])
	assert_int(later).is_equal(first + 1)


# Walking is the fighter's own input moving it, read off the fight: a fighter
# pushed while holding nothing does not walk, and one holding a direction
# while crouching, stunned or in a move does not either.
func test_walking_is_read_off_the_fight() -> void:
	var state: FightState = FightRules.step(FightState.starting(_data, "lancer", "dancer"),
			[FightInput.RIGHT, 0] as Array[int], _data)
	assert_bool(FighterSprites.walks(state.fighters[0])).is_true()
	assert_bool(FighterSprites.walks(state.fighters[1])).is_false()
	var pushed: FightState = FightState.starting(_data, "lancer", "dancer")
	pushed.fighters[0].x = 400
	pushed.fighters[1].x = 440
	pushed = FightRules.step(pushed, [0, 0] as Array[int], _data)
	assert_int(pushed.fighters[1].x).is_not_equal(440)
	assert_bool(FighterSprites.walks(pushed.fighters[1])).is_false()
	var crouched: FightState = FightRules.step(FightState.starting(_data, "lancer", "dancer"),
			[FightInput.RIGHT | FightInput.DOWN, 0] as Array[int], _data)
	assert_bool(FighterSprites.walks(crouched.fighters[0])).is_false()


# Walking backwards plays the walk backwards, one cel every few frames at
# either character's speed.
func test_walking_backwards_plays_the_walk_backwards() -> void:
	for character: String in _data.character_names():
		var stride: int = int(_data.character(character)["walk_speed"]) * FighterSprites.WALK_FRAMES_PER_CEL
		var count: int = _sprites.cels(character, "walk").size()
		var here: int = _walk_cel(character, 300)
		assert_int(_walk_cel(character, 300 + stride)).is_equal(posmod(here + 1, count))
		assert_int(_walk_cel(character, 300 - stride)).is_equal(posmod(here - 1, count))


func test_with_no_table_a_fighter_is_a_block() -> void:
	var view: FightView = auto_free(FightView.new())
	view.sprites = FighterSprites.read("res://no/such/table.json")
	view.show_fight(FightState.starting(_data, "lancer", "dancer"), _data)
	assert_bool(view.sprites.complete("lancer", _data)).is_false()
	var drawn: FightView = auto_free(FightView.new())
	drawn.show_fight(FightState.starting(_data, "lancer", "dancer"), _data)
	assert_bool(drawn.sprites.complete("lancer", _data)).is_true()


# The boxes are drawn from the frame data, one unit a pixel, and the figure
# from its sprite: they sit on each other only if the frame data's standing
# height is the sprite's, as drawn, to the pixel (T38).
func test_the_frame_data_s_height_is_the_figure_s_on_screen() -> void:
	for character: String in _data.character_names():
		var drawn: Dictionary = _sprites.table["characters"][character]
		var on_screen: int = roundi(float(drawn["standing_height"]) * float(drawn["scale_percent"]) / 100.0)
		assert_int(int(_data.character(character)["tall"])).is_equal(on_screen)


func test_a_fighter_in_the_air_shows_its_jump_rising_then_falling() -> void:
	var fighter := FighterState.new("lancer", 300, 1000)
	var shown: Array[int] = []
	for frame: int in range(1, _data.jump_length("lancer") + 1):
		fighter.jump_frame = frame
		var pose: Array = _sprites.pose(fighter, _data, frame, false)
		assert_str(pose[0]).is_equal("jump")
		shown.append(pose[1])
	assert_int(shown[0]).is_equal(0)
	assert_int(shown.back()).is_equal(_sprites.cels("lancer", "jump").size() - 1)
	for index: int in range(1, shown.size()):
		assert_int(shown[index]).is_greater_equal(shown[index - 1])


# A missing strip, or a move the frame data has and the table does not,
# leaves the whole character on its block, not half drawn.
func test_anything_missing_leaves_the_character_on_its_block() -> void:
	var planted: FighterSprites = FighterSprites.read()
	planted.table["characters"]["dancer"]["animations"]["planted"] = [4]
	assert_bool(planted.complete("dancer", _data)).is_false()
	assert_bool(planted.complete("lancer", _data)).is_true()
	var no_sweep: FighterSprites = FighterSprites.read()
	no_sweep.table["characters"]["dancer"]["moves"].erase("sweep")
	assert_bool(no_sweep.complete("dancer", _data)).is_false()
	var missing_strip: FighterSprites = FighterSprites.read()
	missing_strip._strips[Art.fighter_strip("lancer", "jab")] = null
	assert_bool(missing_strip.complete("lancer", _data)).is_false()


# --- helpers -------------------------------------------------------------------

func _assert_phases_line_up(character: String, move: String) -> void:
	var listed: Array[int] = _sprites.cels(character, move)
	var fighter := FighterState.new(character, 300, 1000)
	fighter.move = move
	for frame: int in range(1, _data.length_of(character, move) + 1):
		fighter.move_frame = frame
		var phase: String = FightBoxes.phase(fighter, _data)
		var cel: int = listed[_sprites.move_index(fighter, _data)]
		var label: String = "%s's %s frame %d (%s) shows cel %d" % [character, move, frame, phase, cel]
		assert_bool(_phase_cels(character, move, phase).has(cel)).override_failure_message(label).is_true()


# The cels a phase of a move lists, as whole numbers.
func _phase_cels(character: String, move: String, phase: String) -> Array[int]:
	var phases: Dictionary = _sprites.table["characters"][character]["moves"].get(move, {})
	var found: Array[int] = []
	found.assign((phases.get(phase, []) as Array).map(func(cel: float) -> int: return int(cel)))
	return found


# How many cels each phase of a move lists, or [0] when the move is missing.
func _phase_sizes(character: String, move: String) -> Array[int]:
	if not _sprites.table["characters"][character]["moves"].has(move):
		return [0]
	var sizes: Array[int] = []
	for phase: String in PHASES:
		sizes.append(_phase_cels(character, move, phase).size())
	return sizes


func _walk_cel(character: String, x: int) -> int:
	var fighter := FighterState.new(character, x, 1000)
	fighter.held_before = FightInput.RIGHT
	return int(_sprites.pose(fighter, _data, 0, false)[1])


# The cels a move shows over its frames, as a set.
func _cels_shown(character: String, move: String) -> Dictionary:
	var listed: Array[int] = _sprites.cels(character, move)
	var fighter := FighterState.new(character, 300, 1000)
	fighter.move = move
	var shown: Dictionary = {}
	for frame: int in range(1, _data.length_of(character, move) + 1):
		fighter.move_frame = frame
		shown[_sprites.move_index(fighter, _data)] = true
	return shown
