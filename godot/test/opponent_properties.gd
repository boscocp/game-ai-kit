# T17: the opponent model learns a habit, and follows a change of habit.
#
#     ./scripts/godot --headless --path godot -s res://test/opponent_properties.gd
#
# A scripted player repeats a fixed habit -- low, high, throw, over and over
# -- for 60 actions, then switches to the same three in the other order --
# low, throw, high -- for 60 more. The same contexts, different answers:
# exactly the change a model that never forgets is slow to see. A medium
# `FightModelOpponent` watches through `FightDelay`, as it would in a fight,
# and scores each guess. Its own inputs are thrown away: this measures the
# model, not the fighting.
#
# Chance is 1 in 3: the three actions come equally often. The claims, each
# over a window of 20 actions:
#
#   * within 40 actions it beats chance: at least 16 of actions 21-40 right;
#   * within 40 actions of the switch it recovers: at least 16 of 81-100.
#
# And two planted models that must fail, or the claims prove nothing:
#
#   * one that never forgets (decay 1) does not recover within 40;
#   * one of order 1 -- no context at all -- does not beat chance: a cycle of
#     three equally frequent actions is invisible without the last one.
#
# Exit codes: 0 every claim holds, 1 one does not, 2 the frame data could not
# be read.
extends SceneTree

const HABIT: Array[String] = ["low", "high", "throw"]
const SWITCHED: Array[String] = ["low", "throw", "high"]
const PER_HABIT: int = 60
const WINDOW: int = 20
const RIGHT_IN_A_WINDOW: int = 16
## What the scripted player presses for each action, and the frames it then
## stands still: long enough that the next press is a new action.
const PRESSES: Dictionary = {"low": FightInput.DOWN | FightInput.LIGHT_KICK, "high": FightInput.LIGHT_PUNCH,
		"throw": FightInput.THROW}
const PAUSE: int = 12


func _init() -> void:
	quit(_run())


func _run() -> int:
	var data := FightData.read()
	if data.refusal != "":
		printerr("opponent_properties: the frame data was refused: %s" % data.refusal)
		return 2
	var failures: int = 0
	var learner: Array[bool] = guesses(FightModelOpponent.new("medium", data, 1), data)
	failures += _claim("beats chance within 40", right_in(learner, 20), true)
	failures += _claim("recovers within 40 of the switch", right_in(learner, 80), true)
	var never_forgets: Array[bool] = guesses(FightModelOpponent.new("medium", data, 1, 2, 1.0), data)
	failures += _claim("planted, never forgets: recovers within 40", right_in(never_forgets, 80), false)
	var order_one: Array[bool] = guesses(FightModelOpponent.new("medium", data, 1, 1, 0.8), data)
	failures += _claim("planted, order 1: beats chance within 40", right_in(order_one, 20), false)
	print("opponent properties: %d failure(s)" % failures)
	return 1 if failures > 0 else 0


# 0 when `right` out of `WINDOW` is on the side of `RIGHT_IN_A_WINDOW` the
# claim expects; 1, and said so, when not.
func _claim(label: String, right: int, should_reach: bool) -> int:
	var holds: bool = (right >= RIGHT_IN_A_WINDOW) == should_reach
	print("%s: %s -- %d of %d right (needs %s %d)" % ["ok" if holds else "FAIL", label, right, WINDOW,
			"at least" if should_reach else "under", RIGHT_IN_A_WINDOW])
	return 0 if holds else 1


## How many guesses in the window of `WINDOW` after the first `skip` were right.
func right_in(scored: Array[bool], skip: int) -> int:
	return scored.slice(skip, skip + WINDOW).count(true)


## Every guess `watcher` makes about the scripted player, in order.
func guesses(watcher: FightModelOpponent, data: FightData) -> Array[bool]:
	var seat := FightDelay.new(watcher, 1)
	var state: FightState = FightState.starting(data, "lancer", "dancer")
	for press: int in script(data):
		seat.input_for(state)
		state = FightRules.step(state, [press, 0] as Array[int], data)
	for frame: int in range(watcher.reaction + 1):
		seat.input_for(state)
		state = FightRules.step(state, [0, 0] as Array[int], data)
	return watcher.guesses


## The scripted player's inputs, frame by frame: each action pressed once,
## held through its move, then a pause.
func script(data: FightData) -> Array[int]:
	var inputs: Array[int] = []
	for count: int in range(PER_HABIT * 2):
		var habit: Array[String] = HABIT if count < PER_HABIT else SWITCHED
		var press: int = PRESSES[habit[count % habit.size()]]
		var move: String = data.move_for_button("lancer", FightInput.pressed(press, 0), FightInput.holds_down(press))
		inputs.append(press)
		for frame: int in range(data.length_of("lancer", move) + PAUSE):
			inputs.append(0)
	return inputs
