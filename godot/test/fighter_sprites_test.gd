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


func test_the_pose_follows_the_fight_not_a_clock() -> void:
	var fighter := FighterState.new("lancer", 300, 1000)
	assert_array(_sprites.pose(fighter, _data, false, 0, false)).is_equal(["idle", 0])
	fighter.crouching = true
	assert_str(_sprites.pose(fighter, _data, false, 0, false)[0]).is_equal("crouch")
	fighter.stun = 10
	fighter.stun_kind = "block"
	assert_str(_sprites.pose(fighter, _data, false, 0, false)[0]).is_equal("guard_crouching")
	fighter.stun_kind = "hit"
	assert_str(_sprites.pose(fighter, _data, false, 0, false)[0]).is_equal("hit")
	fighter.stun = 0
	fighter.crouching = false
	assert_str(_sprites.pose(fighter, _data, true, 0, false)[0]).is_equal("walk")
	assert_str(_sprites.pose(fighter, _data, false, 0, true)[0]).is_equal("down")


# Walking backwards plays the walk backwards: the cel is read off the place
# the fighter stands, relative to the way it faces.
func test_walking_backwards_plays_the_walk_backwards() -> void:
	var count: int = _sprites.cels("dancer", "walk").size()
	var here: int = _walk_cel(300)
	assert_int(_walk_cel(300 + FighterSprites.UNITS_PER_CEL)).is_equal(posmod(here + 1, count))
	assert_int(_walk_cel(300 - FighterSprites.UNITS_PER_CEL)).is_equal(posmod(here - 1, count))


func test_with_no_strips_a_fighter_is_a_block() -> void:
	var view: FightView = auto_free(FightView.new())
	view.sprites = FighterSprites.read("res://no/such/table.json")
	var fighter := FighterState.new("lancer", 300, 1000)
	assert_bool(view.sprites.complete("lancer")).is_false()
	assert_float(view.figure_height(fighter)).is_equal(FightView.BODY_HEIGHT)
	var drawn: FightView = auto_free(FightView.new())
	assert_bool(drawn.sprites.complete("lancer")).is_true()
	assert_float(drawn.figure_height(fighter)).is_greater(FightView.BODY_HEIGHT)


# A missing strip leaves the whole character on its block, not half drawn.
func test_one_missing_strip_leaves_the_character_on_its_block() -> void:
	var sprites: FighterSprites = FighterSprites.read()
	sprites.table["characters"]["dancer"]["animations"]["planted"] = [4]
	assert_bool(sprites.complete("dancer")).is_false()
	assert_bool(sprites.complete("lancer")).is_true()


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


func _walk_cel(x: int) -> int:
	var fighter := FighterState.new("dancer", x, 900)
	return int(_sprites.pose(fighter, _data, true, 0, false)[1])
