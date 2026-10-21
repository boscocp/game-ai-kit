## The behaviour-tree team (T25), one of the board's controllers: one tree,
## asked from the root for every walker every turn.
##
##     selector "walker"
##       sequence "save itself"    in danger? wounded? then fall back
##       sequence "defend"         home threatened? then defend
##       sequence "siege"          at their workshop? then siege
##       sequence "hunt"           prey in reach? then hunt
##       sequence "take a point"   a point free? then take point
##       action   "march"          siege
##
## The order of the branches is the designer's ranking, and the whole of it:
## the tree keeps nothing between turns, so a walker that was defending last
## turn is a hunter this turn the moment a piece it beats comes into reach
## and home is no longer threatened -- it never waits for home to be clear,
## the way the state machine does. Adding a branch touches no other branch,
## which is what the state machine could not do.
##
## When not to use it: see `BehaviourTree`.
class_name TreeTeam
extends TechniqueTeam

## The tree; public so a test or the screen can read its trail.
var tree: BehaviourTree

# The deed the last tick chose, and each walker's last trail.
var _deed: String = SIEGE
var _trails: Dictionary[int, String] = {}


func _init() -> void:
	var branches: Array[BehaviourTree.TreeNode] = [
		_branch("save itself", ["in danger?", "in_danger", "wounded?", "wounded"], "fall back", FALL_BACK),
		_branch("defend", ["home threatened?", "home_threatened"], "defend", DEFEND),
		_branch("siege", ["at their workshop?", "at_their_workshop"], "siege", SIEGE),
		_branch("hunt", ["prey in reach?", "prey_in_reach"], "hunt", HUNT),
		_branch("take a point", ["a point free?", "point_free"], "take point", TAKE_POINT),
		_do("march", SIEGE),
	]
	tree = BehaviourTree.new(BehaviourTree.Selector.new("walker", branches))


## The name the league table and the screen give it.
func controller_name() -> String:
	return "behaviour tree"


## One line for the screen: what kind of thinking this is.
func describe() -> String:
	return "a behaviour tree, asked from the root every turn: it reconsiders everything, every time; builds by the rules"


## Tick the tree from the root; the deed is the action that answered.
func decide(unit: Unit, known: TeamFacts) -> String:
	_deed = SIEGE
	tree.tick(known.facts)
	_work += tree.trail.size()
	_trails[unit.id] = _answered(tree.trail)
	return _deed


## The branch that answered for this walker, from its last tick.
func thinking(unit_id: int) -> String:
	return _trails.get(unit_id, "not asked yet")


## "Nodes ticked": every node a tick visited.
func work_unit() -> String:
	return "nodes ticked"


# The trail's last few entries before the root's, which name the branch that
# answered: "take a point: running", and the conditions that let it.
static func _answered(trail: Array[String]) -> String:
	for entry: String in trail:
		if entry.ends_with(": running"):
			return "the tree answered with " + entry.trim_suffix(": running")
	return "the tree answered nothing"


# A sequence named `label`: each [question, fact] pair in `asks` must hold,
# then `action_label` does `chosen`.
func _branch(label: String, asks: Array, action_label: String, chosen: String) -> BehaviourTree.Sequence:
	var children: Array[BehaviourTree.TreeNode] = []
	for index: int in range(0, asks.size(), 2):
		var fact: String = asks[index + 1]
		children.append(BehaviourTree.Condition.new(asks[index], func(facts: Dictionary) -> bool: return facts[fact]))
	children.append(_do(action_label, chosen))
	return BehaviourTree.Sequence.new(label, children)


# An action node that chooses `chosen` as the deed and answers "running": a
# deed lasts this turn, and next turn the tree is asked again from the root.
func _do(label: String, chosen: String) -> BehaviourTree.Action:
	return BehaviourTree.Action.new(label, func(_facts: Dictionary) -> BehaviourTree.Status:
		_deed = chosen
		return BehaviourTree.Status.RUNNING)
