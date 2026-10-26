## The guard as a behaviour tree, asked from the root every turn.
##
##     selector "guard"
##       sequence "chase"         alerted? then: catch, or chase if seen, or [go and look]
##       sequence "investigate"   suspicious? knows where? then [go and look]
##       action   "walk the round"
##
##     [go and look] = selector: (at the place? look round) or go there
##
## The same "go and look" subtree hangs in two places: under the chase, for a
## guard that has lost sight of whom it chased, and under the investigation.
## In the state machine that behaviour is written in two states; here it is
## one value. The tree keeps nothing between turns, so it reconsiders
## everything every turn -- the moment suspicion dips under a threshold, the
## branch that needed it fails and the next one answers.
##
## The nodes' names are English keys, translated where the panel draws the
## trail (`BrainPanel.words`).
##
## When not to use it: see `BehaviourTree`.
class_name GuardTree
extends GuardBrain

## The nodes' names: the words the trail shows. A deed's own name serves for
## the actions that choose it, and for the chase that ends in one.
const GO_AND_LOOK: String = BrainPanel.SHARED_SUBTREE
const LOOK_ROUND_THERE: String = "look round there"  # shown through tr()
const LOOK_ROUND: String = "look round"  # shown through tr()
const GO_THERE: String = "go there"  # shown through tr()
const CLOSE_IN: String = "close in"  # shown through tr()
const SEIZE: String = "seize"  # shown through tr()
const RUN: String = "run"  # shown through tr()
const INVESTIGATE: String = "investigate"  # shown through tr()
const WALK_THE_ROUND: String = "walk the round"  # shown through tr()
const ROOT: String = "guard"  # shown through tr()
## The question a condition node asks, by the fact it reads.
const QUESTIONS: Dictionary = {  # shown through tr()
	"at_last_known": "at the place?", "alerted": "alerted?", "next_to_player": "next to it?",
	"sees_player": "sees it?", "suspicious": "suspicious?", "knows_where": "knows where?",
}

## The tree; public so the demo can show its trail.
var tree: BehaviourTree


# The literals below are the facts the conditions read; the names are above.
func _init() -> void:
	var go_and_look := BehaviourTree.Selector.new(GO_AND_LOOK, [
		BehaviourTree.Sequence.new(LOOK_ROUND_THERE, [
			_ask("at_last_known"),
			_do(LOOK_ROUND, LOOK_AROUND),
		] as Array[BehaviourTree.TreeNode]),
		_do(GO_THERE, GO_TO_LAST_KNOWN),
	] as Array[BehaviourTree.TreeNode])
	var chase := BehaviourTree.Sequence.new(CHASE, [  # not shown: facts
		_ask("alerted"),
		BehaviourTree.Selector.new(CLOSE_IN, [
			BehaviourTree.Sequence.new(SEIZE, [_ask("next_to_player"), _do(CATCH, CATCH)] as Array[BehaviourTree.TreeNode]),
			BehaviourTree.Sequence.new(RUN, [_ask("sees_player"), _do(CHASE, CHASE)] as Array[BehaviourTree.TreeNode]),
			go_and_look,
		] as Array[BehaviourTree.TreeNode]),
	] as Array[BehaviourTree.TreeNode])
	var investigate := BehaviourTree.Sequence.new(INVESTIGATE, [  # not shown: facts
		_ask("suspicious"), _ask("knows_where"), go_and_look,
	] as Array[BehaviourTree.TreeNode])
	tree = BehaviourTree.new(BehaviourTree.Selector.new(ROOT, [
		chase, investigate, _do(WALK_THE_ROUND, WALK_ROUND),
	] as Array[BehaviourTree.TreeNode]))


## The name the screen gives this way of deciding.
func brain_name() -> String:
	return "behaviour tree"  # shown through tr()


## Tick the tree from the root; the deed is the action that answered.
func decide(facts: Dictionary) -> String:
	deed = WALK_ROUND
	tree.tick(facts)
	return deed


## The nodes the last tick asked, and what each answered.
func thinking() -> Dictionary:
	return {"trail": tree.trail.duplicate()}


# A condition node reading one fact, named by the question it asks.
static func _ask(fact: String) -> BehaviourTree.Condition:
	return BehaviourTree.Condition.new(QUESTIONS[fact], func(facts: Dictionary) -> bool: return facts[fact])


# An action node that chooses `chosen` as the deed and answers "running":
# a deed lasts this turn, and next turn the tree is asked again from the root.
func _do(label: String, chosen: String) -> BehaviourTree.Action:
	return BehaviourTree.Action.new(label, func(_facts: Dictionary) -> BehaviourTree.Status:
		deed = chosen
		return BehaviourTree.Status.RUNNING)
