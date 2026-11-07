# T137: a hit chance does not cover the piece's number.
#
# The owner's manual check of 2026-11-06 found T's hit chance written in the
# bottom-right corner of an enemy's cell, on the piece's id: "5" and "55"
# read as one number. The chance now has the top-right corner, and these
# tests hold each number's box -- the rectangle its letters cover, measured
# with the font the board draws with -- clear of the others'. Headless
# nothing is drawn, so what is held is what `_draw` would be handed.
#
# The planted case is the old place: drawn there, the chance's box meets the
# id's, and the same comparison that passes for the new corner says so.
extends GdUnitTestSuite

const RED: int = TacticalScenario.RED
const BLUE: int = TacticalScenario.BLUE
const SHIELD_CELL: Vector2i = Vector2i(7, 4)
const CURSOR: Vector2i = Vector2i(4, 4)
## Half the outline the corner numbers are drawn with.
const OUTLINE: float = 2.0
## Ids from one digit to two: a squad has fewer than ten a side.
const IDS: Array[String] = ["5", "9", "12"]


func test_a_chance_on_an_enemy_under_the_cursor_is_clear_of_its_id_and_health() -> void:
	var scene: TacticalGame = _hovering()
	assert_bool(scene._intent._threat.has(SHIELD_CELL)).override_failure_message("no chance drawn on the shield").is_true()
	var label: Dictionary = scene._intent.tint_label(SHIELD_CELL)
	assert_str(label["words"]).is_equal("%d%%" % scene._intent._threat[SHIELD_CELL])
	var centre: Vector2 = scene._board.centre_of(SHIELD_CELL)
	var shield: Unit = scene.state.unit_at(SHIELD_CELL)
	var chance_box: Rect2 = UnitView.text_box(label["baseline"], label["words"])
	_assert_apart(chance_box, UnitView.text_box(centre + UnitView.ID_AT, str(shield.id)), "the id")
	_assert_apart(chance_box, UnitView.text_box(centre + UnitView.HEALTH_AT, str(shield.health)), "the health")


# The widest a chance can be is the best aim in the table against no
# defence and no cover, and the widest health the most a piece starts with:
# both read from `rules.json`, so a piece given aim 100 there is measured
# here as "100%", not assumed to fit.
func test_every_chance_is_clear_of_every_id_and_health_and_inside_its_cell() -> void:
	var half: float = BoardView.TILE_PIXELS / 2.0
	for chance: String in ["5%", "%d%%" % _most("aim")]:
		var chance_box: Rect2 = UnitView.text_box(IntentView.chance_at(chance), chance)
		assert_bool(chance_box.position.x >= -half and chance_box.end.x <= half).override_failure_message(
			"%s leaves its cell's width: %s" % [chance, chance_box]).is_true()
		for unit_id: String in IDS:
			_assert_apart(chance_box, UnitView.text_box(UnitView.ID_AT, unit_id), "id %s" % unit_id)
		for health: String in ["1", str(_most("health"))]:
			_assert_apart(chance_box, UnitView.text_box(UnitView.HEALTH_AT, health), "health %s" % health)


# The planted case: the corner the chance had before T137 meets the id's,
# so the comparison above is one that can fail.
func test_the_old_corner_is_caught_covering_the_id() -> void:
	var half: float = BoardView.TILE_PIXELS / 2.0
	var old_place: Vector2 = IntentView.COUNT_AT - Vector2(half, half)
	var old_box: Rect2 = UnitView.text_box(old_place, "55")
	assert_bool(old_box.intersects(UnitView.text_box(UnitView.ID_AT, "5"))).is_true()


# Advance Wars mode: nothing moves. Its tint is a count, without a `%`, in
# the bottom-right corner where it always was -- held through the scene's own
# two ways of drawing it, a refresh and the cursor moving (the review of
# wave 160 found a direct `show_threat` let both call sites be wrong).
func test_in_advance_wars_the_count_stays_where_it_was() -> void:
	var scene: TacticalGame = _opened(0)
	scene._showing_threat = true
	scene._refresh()
	_assert_counts_where_they_were(scene, "after a refresh")
	scene.point_at(Vector2i(2, 2))
	_assert_counts_where_they_were(scene, "after the cursor moved")


func _assert_counts_where_they_were(scene: TacticalGame, when: String) -> void:
	var threat: Dictionary[Vector2i, int] = scene._intent._threat
	assert_bool(threat.is_empty()).override_failure_message("no threatened cell %s" % when).is_false()
	assert_bool(scene._intent._threat_is_chance).override_failure_message("a chance %s" % when).is_false()
	for cell: Vector2i in threat:
		var corner: Vector2 = scene._board.centre_of(cell) - Vector2(BoardView.TILE_PIXELS, BoardView.TILE_PIXELS) / 2.0
		assert_dict(scene._intent.tint_label(cell)).is_equal(
			{"words": str(threat[cell]), "baseline": corner + Vector2(BoardView.TILE_PIXELS - 12.0, BoardView.TILE_PIXELS - 4.0)})


# The largest `number` of any piece in the squad's table.
func _most(number: String) -> int:
	var most: int = 0
	for piece_name: String in SquadTable.squad():
		most = maxi(most, SquadTable.number(piece_name, number))
	return most


# Apart with their outlines: both numbers are drawn with a 4-pixel outline,
# 2 pixels outside the letters on every side.
func _assert_apart(chance_box: Rect2, other: Rect2, what: String) -> void:
	assert_bool(chance_box.grow(OUTLINE).intersects(other.grow(OUTLINE))).override_failure_message(
		"the chance at %s covers %s at %s" % [chance_box, what, other]).is_false()


# The XCOM scene with a red runner in hand on (3, 4), a blue shield on (7, 4)
# across open ground, and the cursor on (4, 4): T's tint is the shield's
# chance against the runner there.
func _hovering() -> TacticalGame:
	var scene: TacticalGame = _opened(1)
	scene.state = _facing(scene.ruleset as SquadRuleset)
	scene._selected_id = 1
	scene._person_fog = null
	scene._refresh()
	scene.point_at(CURSOR)
	return scene


# The tactical scene opened as the menu opens it: both modes, the one at
# `chosen` first.
func _opened(chosen: int) -> TacticalGame:
	var scene: TacticalGame = auto_free((load("res://game/tactical/tactical.tscn") as PackedScene).instantiate())
	scene.play_in_modes([AdvanceWarsRuleset.new(), SquadRuleset.new()], chosen)
	add_child(scene)
	return scene


func _facing(rules: SquadRuleset) -> BoardState:
	var types: Dictionary = SquadTable.unit_types()
	var runner: UnitType = types[TacticalRules.RUNNER]
	var shield: UnitType = types[TacticalRules.SHIELD]
	var units: Array[Unit] = [
		Unit.new(1, RED, Vector2i(3, 4), SquadTable.number(runner.type_name, "health"), runner.movement, runner),
		Unit.new(2, BLUE, SHIELD_CELL, SquadTable.number(shield.type_name, "health"), shield.movement, shield)]
	var start: BoardState = rules.start()
	var state := BoardState.new(start.graph, units, RED)
	state.movement_graphs = start.movement_graphs
	return state
