## The words beside the infiltration level: the watched guard's whole
## decision -- every action's score, highest first, and the numbers it was
## weighed from -- and the switches and knobs that are on.
##
## Every score is the one `GuardChoice` recorded, so the panel shows what
## the guard weighed, not a second guess at it (invariant 13).
##
## When not to use it: in the world. The bars and zones are drawn there.
##
## Rebuilt every frame, as before T80: each sentence is one key with named
## placeholders, each name in it translated where it is shown
## (`InfiltrationWords`). The scores keep the point: they are measurements.
class_name InfiltrationText
extends RefCounted

## A switch, as the panel says it: on, then off.
const ON_OFF: Array[String] = ["on", "OFF"]  # shown through tr()
## The watched guard: standing, then downed.
const GUARD_LINE: Array[String] = [  # shown through tr()
	"guard {guard} ({type}): {phase}, sight {sight}, sound {sound}, {action}",
	"guard {guard} ({type}): {phase}, sight {sight}, sound {sound}, downed",
]

const SHOWN: int = 7


## The panel for `world`, watching guard `watched`.
static func panel(world: InfiltrationWorld, watched: int) -> String:
	var lines: PackedStringArray = []
	lines.append("%s -- %s" % [InfiltrationWords.level(world.level.name), _switches(world)])
	var guard: InfiltrationGuard = world.guard(watched)
	var words: Dictionary = {guard = guard.id, type = InfiltrationWords.word(guard.type.name),
		phase = InfiltrationWords.word(guard.mind.phase_name()),
		sight = "%.2f" % guard.mind.awareness["sight"].value, sound = "%.2f" % guard.mind.awareness["sound"].value,
		action = InfiltrationWords.word(guard.action)}
	lines.append(TranslationServer.translate(GUARD_LINE[0 if guard.alive() else 1]).format(words))
	var why: String = guard.percept.sight.why
	lines.append(TranslationServer.translate("  eye: {why}").format({
		why = InfiltrationWords.eye(why) if why != "" else TranslationServer.translate("nothing")}))
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
		found.append("%s%-20s %.3f" % [mark, InfiltrationWords.word(record["names"][index]), float(record["scores"][index])])
	return found


static func _switches(world: InfiltrationWorld) -> String:
	var rules: InfiltrationRules = world.rules
	return TranslationServer.translate("1 belief {belief}, 2 coordinator {coordinator}, 3 arbiter {arbiter}, 4 accumulator {accumulator}, 5 off-screen halving {halving}").format({
		belief = on(rules.use_belief), coordinator = on(rules.use_coordinator), arbiter = on(rules.use_arbiter),
		accumulator = on(rules.use_accumulator), halving = on(rules.off_screen_halving)})


## A switch's state as the panel and the corner say it.
static func on(value: bool) -> String:
	return TranslationServer.translate(ON_OFF[0 if value else 1])
