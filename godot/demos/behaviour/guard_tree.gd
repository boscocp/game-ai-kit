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
## When not to use it: see `BehaviourTree`.
class_name GuardTree
extends GuardBrain

## The tree; public so the demo can show its trail.
var tree: BehaviourTree


func _init() -> void:
	var go_and_look := BehaviourTree.Selector.new("go and look", [
		BehaviourTree.Sequence.new("look round there", [
			_ask("at the place?", "at_last_known"),
			_do("look round", LOOK_AROUND),
		] as Array[BehaviourTree.TreeNode]),
		_do("go there", GO_TO_LAST_KNOWN),
	] as Array[BehaviourTree.TreeNode])
	var chase := BehaviourTree.Sequence.new("chase", [
		_ask("alerted?", "alerted"),
		BehaviourTree.Selector.new("close in", [
			BehaviourTree.Sequence.new("seize", [_ask("next to it?", "next_to_player"), _do("catch", CATCH)] as Array[BehaviourTree.TreeNode]),
			BehaviourTree.Sequence.new("run", [_ask("sees it?", "sees_player"), _do("chase", CHASE)] as Array[BehaviourTree.TreeNode]),
			go_and_look,
		] as Array[BehaviourTree.TreeNode]),
	] as Array[BehaviourTree.TreeNode])
	var investigate := BehaviourTree.Sequence.new("investigate", [
		_ask("suspicious?", "suspicious"), _ask("knows where?", "knows_where"), go_and_look,
	] as Array[BehaviourTree.TreeNode])
	tree = BehaviourTree.new(BehaviourTree.Selector.new("guard", [
		chase, investigate, _do("walk the round", WALK_ROUND),
	] as Array[BehaviourTree.TreeNode]))


## The name the screen gives this way of deciding.
func brain_name() -> String:
	return "behaviour tree"


## Tick the tree from the root; the deed is the action that answered.
func decide(facts: Dictionary) -> String:
	deed = WALK_ROUND
	tree.tick(facts)
	return deed


## The nodes the last tick asked, and what each answered.
func thinking() -> Dictionary:
	return {"trail": tree.trail.duplicate()}


# A condition node reading one fact.
static func _ask(question: String, fact: String) -> BehaviourTree.Condition:
	return BehaviourTree.Condition.new(question, func(facts: Dictionary) -> bool: return facts[fact])


# An action node that chooses `chosen` as the deed and answers "running":
# a deed lasts this turn, and next turn the tree is asked again from the root.
func _do(label: String, chosen: String) -> BehaviourTree.Action:
	return BehaviourTree.Action.new(label, func(_facts: Dictionary) -> BehaviourTree.Status:
		deed = chosen
		return BehaviourTree.Status.RUNNING)
