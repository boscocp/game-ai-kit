## The words beside the infiltration level: the watched guard's whole
## decision -- every action's score, highest first, and the numbers it was
## weighed from -- and the switches and knobs that are on.
##
## Every score is the one `GuardChoice` recorded, so the panel shows what
## the guard weighed, not a second guess at it (invariant 13).
##
## When not to use it: in the world. The bars and zones are drawn there.
class_name InfiltrationText
extends RefCounted

const SHOWN: int = 7


## The panel for `world`, watching guard `watched`.
static func panel(world: InfiltrationWorld, watched: int) -> String:
	var lines: PackedStringArray = []
	lines.append("%s -- %s" % [world.level.name, _switches(world)])
	var guard: InfiltrationGuard = world.guard(watched)
	var sight: float = guard.mind.awareness["sight"].value
	var sound: float = guard.mind.awareness["sound"].value
	lines.append("guard %d (%s): %s, sight %.2f, sound %.2f, %s" % [guard.id, guard.type.name, guard.mind.phase_name(), sight, sound, "downed" if not guard.alive() else guard.action])
	lines.append("  eye: %s" % (guard.percept.sight.why if guard.percept.sight.why != "" else "nothing"))
	lines.append_array(_scores(world, guard))
	return "\n".join(lines)


static func _scores(world: InfiltrationWorld, guard: InfiltrationGuard) -> PackedStringArray:
	var record: Dictionary = world.decisions.get(guard.id, {})
	var found := PackedStringArray()
	if record.is_empty():
		return found
	var order: Array = range(record["names"].size())
	order.sort_custom(func(one: int, other: int) -> bool: return float(record["scores"][one]) > float(record["scores"][other]))
	for index: int in order.slice(0, SHOWN):
		var mark: String = "> " if record["names"][index] == record["action"] else "  "
		found.append("%s%-20s %.3f" % [mark, record["names"][index], float(record["scores"][index])])
	return found


static func _switches(world: InfiltrationWorld) -> String:
	var rules: InfiltrationRules = world.rules
	return "1 belief %s, 2 coordinator %s, 3 arbiter %s, 4 accumulator %s, 5 off-screen halving %s" % [
		_on(rules.use_belief), _on(rules.use_coordinator), _on(rules.use_arbiter), _on(rules.use_accumulator),
		_on(rules.off_screen_halving)]


static func _on(value: bool) -> String:
	return "on" if value else "off"
