## The infiltration demo's switches and view keys, apart from the player's
## own controls: each technique and the off-screen halving turned on and
## off (invariant 13 -- see the difference), the watched guard, the level,
## pausing.
##
## 1 the belief -- off, the grid's, the particles' (T91), in turn -- 2 the
## coordinator, 3 the arbiter, 4 the accumulator, 5 the off-screen halving, 6 the director (T90:
## the world starts again, its reserve there only with it on); Tab the next guard, H the reasoning shown or hidden,
## L the next level, N again, P pause, Space one decision while paused, K
## how a generated level is made (T95: drawn, solved, solved and shown).
##
## When not to use it: for moving the player. Those keys are read each step.
class_name InfiltrationKeys
extends RefCounted


## The belief after `rules`' in the cycle key 1 turns: off, then the grid,
## then the particles, then off again.
static func next_belief(rules: InfiltrationRules) -> void:
	if not rules.use_belief:
		rules.use_belief = true
		rules.use_particles = false
	elif not rules.use_particles:
		rules.use_particles = true
	else:
		rules.use_belief = false
		rules.use_particles = false


## Act on `keycode` for `demo` (the scene's root).
static func switch(demo: Node, keycode: Key) -> void:
	var rules: InfiltrationRules = demo.rules
	match keycode:
		KEY_1:
			next_belief(rules)
		KEY_2:
			rules.use_coordinator = not rules.use_coordinator
		KEY_3:
			rules.use_arbiter = not rules.use_arbiter
		KEY_4:
			rules.use_accumulator = not rules.use_accumulator
		KEY_5:
			rules.off_screen_halving = not rules.off_screen_halving
		KEY_6:
			rules.use_director = not rules.use_director
			demo.new_world()
		KEY_TAB:
			demo.watch_next()
		KEY_H:
			demo.toggle_thinking()
		KEY_L:
			demo.next_level()
		KEY_N:
			demo.new_world()
		KEY_K:
			demo.next_generator()
		KEY_P:
			demo.toggle_pause()
		KEY_SPACE:
			demo.step_decision()
