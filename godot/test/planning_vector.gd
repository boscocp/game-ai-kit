## One planning vector: the domain it describes and the claims it makes.
##
## Separate from the runner that reads the files, for the reason the search
## side had to learn the hard way: a runner is a `SceneTree`, a `SceneTree` is
## awkward to test, and a conformance gate whose rules live somewhere no test
## can reach them is a gate whose rules can be deleted one at a time with every
## check in the repository staying green. `lint-selftests` cannot help -- it
## only looks inside `scripts/`, and this is GDScript.
##
## When not to use it: anything but planning vectors. The shape is specific and
## is documented in `spec/vectors/planning/README.md`.
class_name PlanningVector
extends RefCounted

const SOLVED: String = "solved"
const STEPS: String = "steps"
const LISTS: Array[String] = ["preconditions", "deletes", "adds"]


## Why this dictionary is not a usable vector, or "" when it is one.
static func why_not_a_vector(data: Dictionary) -> String:
	var shape: String = _why_shape_is_wrong(data)
	if shape != "":
		return shape
	var actions: Array = data["actions"]
	for index: int in range(actions.size()):
		var wrong: String = _why_an_action_is_wrong(actions[index], index)
		if wrong != "":
			return wrong
	return _why_expect_is_wrong(data["expect"])


## The domain this vector describes.
static func domain_of(data: Dictionary) -> Array[StripsAction]:
	var actions: Array[StripsAction] = []
	for entry: Dictionary in data["actions"]:
		actions.append(StripsAction.new(
			str(entry["name"]),
			_strings(entry["preconditions"]),
			_strings(entry["deletes"]),
			_strings(entry["adds"]),
		))
	return actions


## The world this vector starts in.
static func start_of(data: Dictionary) -> WorldState:
	return WorldState.new(_strings(data["init"]))


## What this vector asks the planner to bring about.
static func goal_of(data: Dictionary) -> PackedStringArray:
	return _strings(data["goal"])


## Which of the PDDL files this vector names is not beside it.
##
## The Python half of the conformance run reads those two files; a vector
## naming one that does not exist would quietly halve the check, and the half
## that went missing is the one nothing else covers.
static func why_files_are_missing(directory: String, data: Dictionary) -> String:
	for field: String in ["domain", "problem"]:
		var path: String = directory + "/" + str(data[field])
		if not FileAccess.file_exists(path):
			return "`%s` names %s, which is not beside the vector" % [field, data[field]]
	return ""


## Everything this vector claims, checked against the planner.
##
## The plan is replayed here rather than trusted. A planner reports its own
## `solved`, and a conformance runner that reads that field and stops is
## checking the planner's opinion of itself -- which is the hole the wave 08
## review found on the search side, where every step of a path was legal and
## nothing asked where it ended up.
static func check(name: String, data: Dictionary, planner: StripsPlanner) -> Array[String]:
	var start: WorldState = start_of(data)
	var goal: PackedStringArray = goal_of(data)
	var expected: Dictionary = data["expect"]
	var result: PlanResult = planner.plan(domain_of(data), start, goal)
	var should_solve: bool = expected[SOLVED]

	if result.solved != should_solve:
		return ["%s: solved=%s, expected %s" % [name, result.solved, should_solve]]
	if not should_solve:
		return _check_no_plan(name, result)

	var problems: Array[String] = _why_the_plan_does_not_run(name, result, start, goal)
	if result.steps.size() != int(expected[STEPS]):
		problems.append("%s: %d steps, and the fewest is %d"
			% [name, result.steps.size(), int(expected[STEPS])])
	return problems


static func _why_shape_is_wrong(data: Dictionary) -> String:
	for field: String in ["actions", "init", "goal", "expect", "domain", "problem"]:
		if not data.has(field):
			return "no `%s` field" % field
	for field: String in ["domain", "problem"]:
		if not (data[field] is String) or not str(data[field]).ends_with(".pddl"):
			return "`%s` does not name a .pddl file" % field
	if not (data["actions"] is Array) or (data["actions"] as Array).is_empty():
		return "`actions` is not a non-empty array"
	for field: String in ["init", "goal"]:
		var wrong: String = _why_a_list_is_wrong(data[field], field)
		if wrong != "":
			return wrong
	# A goal of `[]` holds in every state, so a vector with one pins nothing
	# and would pass against a planner that always answers "already done".
	if (data["goal"] as Array).is_empty():
		return "`goal` is empty, which every state satisfies"
	if not (data["expect"] is Dictionary):
		return "`expect` is not a dictionary"
	return ""


static func _why_an_action_is_wrong(entry: Variant, index: int) -> String:
	if not (entry is Dictionary):
		return "action %d is not a dictionary" % index
	var action: Dictionary = entry
	if not action.has("name") or not (action["name"] is String) or str(action["name"]) == "":
		return "action %d has no name" % index
	for field: String in LISTS:
		if not action.has(field):
			return "action %s has no `%s`" % [action["name"], field]
		var wrong: String = _why_a_list_is_wrong(action[field], field)
		if wrong != "":
			return "action %s: %s" % [action["name"], wrong]
	return ""


# `expect.steps` is required when a plan is claimed and refused when it is not.
# A vector saying only `"solved": true` passes against a planner that returns
# any plan at all, however long the way round -- and the number of steps is the
# one claim breadth-first actually makes.
static func _why_expect_is_wrong(expected: Dictionary) -> String:
	if not expected.has(SOLVED) or not (expected[SOLVED] is bool):
		return "`expect` has no `solved`"
	var claims_a_plan: bool = expected[SOLVED]
	if claims_a_plan and not expected.has(STEPS):
		return "`expect.solved` is true and there is no `steps` to pin it to"
	if not claims_a_plan and expected.has(STEPS):
		return "`expect.solved` is false, so there is no plan to have `steps`"
	if claims_a_plan and int(expected[STEPS]) < 0:
		return "`expect.steps` is negative"
	return ""


static func _why_a_list_is_wrong(value: Variant, field: String) -> String:
	if not (value is Array):
		return "`%s` is not an array" % field
	for item: Variant in value:
		if not (item is String) or str(item) == "":
			return "`%s` holds something that is not a predicate name" % field
	return ""


# No plan, in a domain small enough that the planner must have proved it rather
# than run out of room to look.
static func _check_no_plan(name: String, result: PlanResult) -> Array[String]:
	var problems: Array[String] = []
	if not result.steps.is_empty():
		problems.append("%s: no plan, but %d steps came back"
			% [name, result.steps.size()])
	if result.gave_up:
		problems.append("%s: gave up after %d states; a vector this size has an answer"
			% [name, result.visited])
	return problems


# The plan, run from the start the vector declares.
static func _why_the_plan_does_not_run(name: String, result: PlanResult,
		start: WorldState, goal: PackedStringArray) -> Array[String]:
	var world: WorldState = start
	for index: int in range(result.steps.size()):
		var action: StripsAction = result.steps[index]
		if not action.is_applicable(world):
			return [_cannot_run(name, index, action)]
		world = action.apply(world)
	if not world.holds_all(goal):
		return ["%s: the plan ran to the end and the goal does not hold" % name]
	return []


# The sentence for a step that cannot run, kept out of the loop above so the
# loop stays three levels deep and readable.
static func _cannot_run(name: String, index: int, action: StripsAction) -> String:
	return "%s: step %d (%s) cannot run where the plan puts it" % [
		name, index, action.name,
	]


static func _strings(value: Variant) -> PackedStringArray:
	var found := PackedStringArray()
	for item: Variant in value:
		found.append(str(item))
	return found
