## A fitted decision tree, read back in: one question per level, then a leaf.
##
## Each test asks about one feature -- is `distance` the word "close"? is
## `health` at most 2.5? -- and sends the walk to its `yes` or its `no`
## child. A leaf holds how often each answer was seen among the training
## rows that came the same way, and the likeliest is the answer it saw most.
## So the path is a rule a person can read aloud, which is why the panel
## shows it. The fitting -- CART, Gini impurity, a capped depth -- happened
## in Python (`gameaikit.training.tree`): invariant 6. Complexity: one
## comparison per level, so a walk costs the depth.
##
## When not to use it: alone, deep, on few rows. It learns the rows rather
## than the player -- the fighting report shows it -- and a forest of them
## voting (T114) is the usual answer.
class_name LearnedTree
extends RefCounted

## The kind a tree is published as, in a model file beside `logistic`.
const KIND: String = "tree"
## Which way a test sent the walk, and the word for a test it could not read.
const YES: String = "yes"
const NO: String = "no"
const UNREAD: String = "unread"

## The feature names a situation is read by.
var features: PackedStringArray
## The answers, in the order a tie between them is settled.
var classes: PackedStringArray
## The nodes, root first, every child after its parent. A test is
## `{feature, is | at_most, yes, no}`, a leaf `{counts}`: as the file has
## them, with the indices and the counts made whole numbers.
var nodes: Array[Dictionary] = []


func _init(tree_features: PackedStringArray, tree_classes: PackedStringArray, tree_nodes: Array[Dictionary]) -> void:
	features = tree_features
	classes = tree_classes
	nodes = tree_nodes


## The tree a model file publishes, built from its entry once `ModelFile`
## has checked it. JSON reads every number as a float; the children's
## indices and the leaves' counts are whole numbers, and become ints here.
static func from_entry(entry: Dictionary) -> LearnedTree:
	var built: Array[Dictionary] = []
	for node: Dictionary in entry["nodes"]:
		built.append(_with_whole_numbers(node))
	return LearnedTree.new(PackedStringArray(entry["features"]), PackedStringArray(entry["classes"]), built)


# A new node like `node`, its children and counts ints, as JSON never gives
# them. Built afresh from the file's values, never written back over them.
static func _with_whole_numbers(node: Dictionary) -> Dictionary:
	var built: Dictionary = {}
	for key: String in node:
		var value: Variant = node[key]
		if key == YES or key == NO:
			built[key] = int(value)
		elif key == "counts":
			built[key] = _whole_counts(value)
		else:
			built[key] = value
	return built


# The same counts, each an int.
static func _whole_counts(given: Dictionary) -> Dictionary:
	var whole: Dictionary = {}
	for name: String in given:
		whole[name] = int(given[name])
	return whole


## The walk, told a node at a time, for whoever shows it: each test with
## the value it read and which way it went, ending at the leaf with its
## counts -- or at the test it could not read, whose `went` is `UNREAD`.
func steps(values: Dictionary) -> Array[Dictionary]:
	var told: Array[Dictionary] = [_step(0, values)]
	while told.back().get("went", UNREAD) != UNREAD:
		var last: Dictionary = told.back()
		told.append(_step(nodes[last["node"]][last["went"]], values))
	return told


# One node of the walk: a leaf and its counts, or a test, what it read and
# which way it sent the walk.
func _step(index: int, values: Dictionary) -> Dictionary:
	var node: Dictionary = nodes[index]
	if node.has("counts"):
		return {"node": index, "counts": node["counts"]}
	return {"node": index, "feature": node["feature"], "test": "at_most" if node.has("at_most") else "is",
		"against": node.get("at_most", node.get("is")), "seen": values.get(node["feature"]), "went": answer(node, values)}


## The nodes visited, root first: the path `steps` tells.
func path(values: Dictionary) -> PackedInt32Array:
	var visited := PackedInt32Array()
	for step: Dictionary in steps(values):
		visited.append(step["node"])
	return visited


## The leaf's counts for `values`; empty when the walk stopped at a test it
## could not read. Empty, not a guess: a "no" for a missing feature would be
## an answer nobody fitted.
func counts(values: Dictionary) -> Dictionary:
	var last: Dictionary = steps(values).back()
	return last.get("counts", {})


## The answer the leaf saw most; of equal counts, the first in `classes`;
## "" when the walk could not finish.
func likeliest(values: Dictionary) -> String:
	var counted: Dictionary = counts(values)
	var best: String = ""
	for name: String in classes:
		if int(counted.get(name, 0)) > int(counted.get(best, 0)):
			best = name
	return best


## Each answer's share of the leaf, by name; empty when the walk could not finish.
func probabilities(values: Dictionary) -> Dictionary:
	var counted: Dictionary = counts(values)
	var total: int = 0
	for count: Variant in counted.values():
		total += int(count)
	var shares: Dictionary = {}
	if total == 0:
		return shares
	for name: String in classes:
		shares[name] = float(counted.get(name, 0)) / total
	return shares


## `YES` or `NO` for one test, or `UNREAD` when the value is missing or of
## the wrong kind: `is` compares words only, `at_most` numbers only.
static func answer(node: Dictionary, values: Dictionary) -> String:
	var seen: Variant = values.get(node["feature"])
	if node.has("at_most"):
		if not (seen is int or seen is float):
			return UNREAD
		return YES if float(seen) <= float(node["at_most"]) else NO
	if not seen is String:
		return UNREAD
	return YES if seen == node["is"] else NO
