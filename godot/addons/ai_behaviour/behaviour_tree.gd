## A behaviour tree: the decision as a tree of small questions and actions,
## asked from the root every tick.
##
## Four kinds of node, which are all a teaching tree needs:
##
## - a **condition** asks one thing of the facts and succeeds or fails;
## - an **action** does one thing and says whether it succeeded, failed, or is
##   still running;
## - a **sequence** runs its children in order and stops at the first that
##   does not succeed -- "and then";
## - a **selector** runs its children in order and stops at the first that
##   does not fail -- "or else".
##
## Where it wins over a state machine is reuse: a subtree is a value, so the
## same "go and look" can hang under the alert branch and the searching one
## without being written twice, and adding a branch touches no other branch.
## It keeps no memory between ticks -- every tick starts at the root -- so it
## reconsiders everything, every time; a running action is simply asked again.
## That is the classic tree, and the cost of it is that it cannot commit.
##
## Each tick leaves a `trail`: every node it visited and what it answered, a
## composite after its children -- so "go and look" shows up by name under
## whichever branch reached it -- which is what the demo lights.
##
## Complexity: a tick visits at most every node once, O(nodes).
##
## When not to use it: behaviour that is a sequence of steps the agent must
## find for itself. A tree only knows the orders a designer wrote; a planner
## searches for one.
class_name BehaviourTree
extends RefCounted

enum Status { SUCCESS, FAILURE, RUNNING }

## The root node.
var root: TreeNode
## The last tick's path through the tree: "name: answer", in the order asked.
var trail: Array[String] = []


## One node: a name for the screen, and an answer when it is asked.
@abstract
class TreeNode extends RefCounted:
	## What the screen calls it.
	var name: String

	## Ask this node, given the facts, and write each node asked into `trail`.
	@abstract func tick(facts: Dictionary, trail: Array[String]) -> Status


## Succeeds when `question(facts)` is true.
class Condition extends TreeNode:
	var _question: Callable

	func _init(node_name: String, question: Callable) -> void:
		name = node_name
		_question = question

	## The question's answer, as success or failure.
	func tick(facts: Dictionary, trail: Array[String]) -> Status:
		var answer: Status = Status.SUCCESS if _question.call(facts) else Status.FAILURE
		trail.append("%s: %s" % [name, BehaviourTree.said(answer)])
		return answer


## Does `deed(facts)`, which returns a `Status`.
class Action extends TreeNode:
	var _deed: Callable

	func _init(node_name: String, deed: Callable) -> void:
		name = node_name
		_deed = deed

	## What the deed answered.
	func tick(facts: Dictionary, trail: Array[String]) -> Status:
		var answer: Status = _deed.call(facts)
		trail.append("%s: %s" % [name, BehaviourTree.said(answer)])
		return answer


## Its children in order, until one does not succeed.
class Sequence extends TreeNode:
	var children: Array[TreeNode]

	func _init(node_name: String, kids: Array[TreeNode]) -> void:
		name = node_name
		children = kids

	## Success only when every child succeeded; otherwise what stopped it.
	func tick(facts: Dictionary, trail: Array[String]) -> Status:
		var answer: Status = Status.SUCCESS
		for child: TreeNode in children:
			answer = child.tick(facts, trail)
			if answer != Status.SUCCESS:
				break
		trail.append("%s: %s" % [name, BehaviourTree.said(answer)])
		return answer


## Its children in order, until one does not fail.
class Selector extends TreeNode:
	var children: Array[TreeNode]

	func _init(node_name: String, kids: Array[TreeNode]) -> void:
		name = node_name
		children = kids

	## Failure only when every child failed; otherwise what answered.
	func tick(facts: Dictionary, trail: Array[String]) -> Status:
		var answer: Status = Status.FAILURE
		for child: TreeNode in children:
			answer = child.tick(facts, trail)
			if answer != Status.FAILURE:
				break
		trail.append("%s: %s" % [name, BehaviourTree.said(answer)])
		return answer


## A tree with `top` at its root.
func _init(top: TreeNode) -> void:
	root = top


## Ask the tree from the root, given the facts; `trail` says what was asked.
func tick(facts: Dictionary) -> Status:
	trail.clear()
	return root.tick(facts, trail)


## A status in words, for the trail.
static func said(answer: Status) -> String:
	return ["success", "failure", "running"][answer]
