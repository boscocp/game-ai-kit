# Wave 86: back tapped twice is the evade, for a person. The second tap adds
# the evade bit on the frame it goes down -- one frame, so it is pressed once
# -- and only inside the window, only back, and only the way the fighter
# faces now. Held back is a guard, never an evade.
extends GdUnitTestSuite

const RIGHT: int = FightInput.RIGHT
const LEFT: int = FightInput.LEFT
const EVADE: int = FightInput.EVADE
const FACING_RIGHT: int = 1
const FACING_LEFT: int = -1


# Back, let go, back again: the evade on the second press, and only there.
func test_back_tapped_twice_evades_on_the_second_press() -> void:
	var read: Array[int] = _read([LEFT, 0, LEFT, LEFT, 0], FACING_RIGHT)
	assert_array(read).is_equal([LEFT, 0, LEFT | EVADE, LEFT, 0])


# Facing left, back is right: the same taps on the other side.
func test_on_the_right_back_is_the_other_key() -> void:
	assert_int(_read([RIGHT, 0, RIGHT], FACING_LEFT).back()).is_equal(RIGHT | EVADE)
	assert_int(_read([LEFT, 0, LEFT], FACING_LEFT).back()).is_equal(LEFT)


# Held back is a guard: one press, however long, never evades.
func test_back_held_never_evades() -> void:
	var held: Array[int] = []
	for frame: int in range(40):
		held.append(LEFT)
	assert_bool(_read(held, FACING_RIGHT).any(func(input: int) -> bool: return input & EVADE != 0)).is_false()


# A second tap after the window is a first tap again.
func test_a_second_tap_too_late_does_not_count() -> void:
	var taps: Array[int] = [LEFT]
	for frame: int in range(FightDoubleTap.WINDOW):
		taps.append(0)
	taps.append(LEFT)
	assert_int(_read(taps, FACING_RIGHT).back()).is_equal(LEFT)
	taps.remove_at(1)
	assert_int(_read(taps, FACING_RIGHT).back()).is_equal(LEFT | EVADE)


# Forward twice is not an evade, and a first tap made before the fighter
# turned does not pair with one after.
func test_forward_twice_and_a_turn_in_between_do_not_count() -> void:
	assert_int(_read([RIGHT, 0, RIGHT], FACING_RIGHT).back()).is_equal(RIGHT)
	var tap: FightDoubleTap = FightDoubleTap.new()
	tap.read(LEFT, FACING_RIGHT)
	tap.read(0, FACING_RIGHT)
	assert_int(tap.read(RIGHT, FACING_LEFT)).is_equal(RIGHT)


# A key held through a turn -- forward on the way over, back once landed --
# was never pressed as back: let go and pressed again, it is one tap, a
# guard, and not the second of two (wave 86's review).
func test_a_key_held_through_a_turn_is_not_a_first_tap() -> void:
	var tap: FightDoubleTap = FightDoubleTap.new()
	tap.read(LEFT, FACING_LEFT)
	tap.read(LEFT, FACING_RIGHT)
	tap.read(0, FACING_RIGHT)
	assert_int(tap.read(LEFT, FACING_RIGHT)).is_equal(LEFT)


# The window runs from the first press: back briefly, then back held to
# guard inside it, is an evade. The trade-off the header names, pinned.
func test_back_then_back_held_inside_the_window_is_an_evade() -> void:
	var read: Array[int] = _read([LEFT, LEFT, LEFT, LEFT, LEFT, 0, 0, 0, LEFT, LEFT], FACING_RIGHT)
	assert_int(read[8]).is_equal(LEFT | EVADE)
	assert_int(read[9]).is_equal(LEFT)


# The scene feeds it: a double tap in the training mode starts a backdash.
func test_the_scene_turns_a_double_tap_into_a_backdash() -> void:
	var scene: FightingExample = auto_free(load("res://game/fighting/fighting.tscn").instantiate())
	add_child(scene)
	scene.paused = true
	scene.dummy_mode = "stand"
	for input: int in [LEFT, 0, LEFT]:
		scene.step_decision_with(input)
	assert_str(scene.state.fighters[0].stun_kind).is_equal(FightBackdash.KIND)
	assert_int(scene.input_log.back()[0] & EVADE).is_equal(EVADE)


func _read(inputs: Array[int], facing: int) -> Array[int]:
	var tap: FightDoubleTap = FightDoubleTap.new()
	var read: Array[int] = []
	for input: int in inputs:
		read.append(tap.read(input, facing))
	return read
