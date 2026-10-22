## The infiltration demo's switches and view keys, apart from the player's
## own controls: each technique and the off-screen halving turned on and
## off (invariant 13 -- see the difference), the watched guard, the level,
## pausing.
##
## 1 the belief, 2 the coordinator, 3 the arbiter, 4 the accumulator, 5 the
## off-screen halving; Tab the next guard, H the reasoning shown or hidden,
## L the next level, N again, P pause, Space one decision while paused.
##
## When not to use it: for moving the player. Those keys are read each step.
class_name InfiltrationKeys
extends RefCounted


## Act on `keycode` for `demo` (the scene's root).
static func switch(demo: Node, keycode: Key) -> void:
	var rules: InfiltrationRules = demo.rules
	match keycode:
		KEY_1:
			rules.use_belief = not rules.use_belief
		KEY_2:
			rules.use_coordinator = not rules.use_coordinator
		KEY_3:
			rules.use_arbiter = not rules.use_arbiter
		KEY_4:
			rules.use_accumulator = not rules.use_accumulator
		KEY_5:
			rules.off_screen_halving = not rules.off_screen_halving
		KEY_TAB:
			demo.watch_next()
		KEY_H:
			demo.toggle_thinking()
		KEY_L:
			demo.next_level()
		KEY_N:
			demo.new_world()
		KEY_P:
			demo.toggle_pause()
		KEY_SPACE:
			demo.step_decision()
