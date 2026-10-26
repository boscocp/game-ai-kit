# The minimal example on docs/techniques/ai_behaviour.md, run by
# guard_example_test.gd. A guard of your own: chase what it sees, look
# where it heard something, otherwise walk its round.
extends Node

## What the last tick chose. Your game reads it and moves the guard.
var doing: String = ""

var _tree: BehaviourTree


func _ready() -> void:
	_tree = BehaviourTree.new(BehaviourTree.Selector.new("guard", [
		BehaviourTree.Sequence.new("chase", [
			BehaviourTree.Condition.new("sees someone?", _fact.bind("sees_player")),
			BehaviourTree.Action.new("run at them", _choose.bind("chase")),
		] as Array[BehaviourTree.TreeNode]),
		BehaviourTree.Sequence.new("investigate", [
			BehaviourTree.Condition.new("heard something?", _fact.bind("heard_noise")),
			BehaviourTree.Action.new("go and look", _choose.bind("investigate")),
		] as Array[BehaviourTree.TreeNode]),
		BehaviourTree.Action.new("walk the round", _choose.bind("patrol")),
	] as Array[BehaviourTree.TreeNode]))


## Ask the tree once, from the root, with what your game knows this tick.
func decide(facts: Dictionary) -> String:
	_tree.tick(facts)
	return doing


## Every node the last tick asked and what each answered: draw it, and the
## player sees why the guard did what it did.
func trail() -> Array[String]:
	return _tree.trail


# A condition: one fact, read from what the game filled in.
func _fact(facts: Dictionary, fact_name: String) -> bool:
	return facts.get(fact_name, false)


# An action: here it only records the choice; your game acts on `doing`.
func _choose(_facts: Dictionary, choice: String) -> BehaviourTree.Status:
	doing = choice
	return BehaviourTree.Status.SUCCESS
