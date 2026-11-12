# T126: what the scene shows of Advance Wars, asked of `AdvanceWarsView`.
# The defaults it leans on moved from the ruleset untested (wave 128's
# review): T's tint is the threat map whatever the cursor, and the board
# marks the two control points.
extends GdUnitTestSuite

const RED: int = TacticalScenario.RED
const BLUE: int = TacticalScenario.BLUE

var _view: TacticalModeView = AdvanceWarsRuleset.new().mode_view()


func test_t_tints_the_threat_map_wherever_the_cursor_is() -> void:
	var state: BoardState = TacticalScenario.build()
	var threat: Dictionary[Vector2i, int] = ThreatMap.of(state, BLUE)
	assert_dict(threat).is_not_empty()
	assert_dict(_view.tint_at(state, BLUE, Vector2i(4, 4), RED, -1)).is_equal(threat)
	assert_dict(_view.tint_at(state, BLUE, Vector2i(-1, -1), RED, 1)).is_equal(threat)


func test_the_board_marks_the_two_control_points() -> void:
	assert_array(_view.points()).is_equal(TacticalScenario.POINTS)
	assert_array(_view.points()).is_not_empty()


func test_the_view_shows_the_ruleset_that_handed_it() -> void:
	var rules := AdvanceWarsRuleset.new()
	assert_object(rules.mode_view().rules).is_same(rules)
	assert_bool(rules.mode_view() is AdvanceWarsView).is_true()


# T124: Advance Wars has no fog to lift, so V starts on in play and in the
# teaching view alike; only a mode with something hidden starts it off.
func test_v_starts_on_in_play_and_in_the_teaching_view() -> void:
	assert_bool(_view.shows_the_computer_at_start(false)).is_true()
	assert_bool(_view.shows_the_computer_at_start(true)).is_true()
