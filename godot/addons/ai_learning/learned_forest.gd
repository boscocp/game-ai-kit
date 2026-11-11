## A fitted random forest, read back in: many decision trees, each casting a vote.
##
## One tree fitted to few rows learns those rows; move a handful and its
## answers change. A forest fits many trees, each on its own bootstrap
## sample of the rows and with a random subset of the features at each
## node, so they disagree -- and asks them all. Each tree walks the
## situation and votes its leaf's likeliest answer; the forest answers with
## the most votes, of equal tallies the first in `classes`. A tree whose walk
## stops at a value it cannot read abstains. The fitting happened in Python
## (`gameaikit.training.forest`, seeded): invariant 6.
##
## Complexity: one walk per tree, so an answer costs the trees times their depth.
##
## When not to use it: when the reader needs one path they can read aloud --
## a forest's reasons are a tally -- or when the features carry no signal:
## averaging guesses removes their noise and adds nothing that was not there
## (docs/concepts/learning.md#a-random-forest measures both).
class_name LearnedForest
extends RefCounted

## The kind a forest is published as, in a model file beside `tree`.
const KIND: String = "forest"

## The feature names a situation is read by, shared by every tree.
var features: PackedStringArray
## The answers, in the order a tie between them is settled, shared by every tree.
var classes: PackedStringArray
## The trees, in the order the file lists them -- the order their votes are told in.
var trees: Array[LearnedTree] = []


func _init(forest_features: PackedStringArray, forest_classes: PackedStringArray,
		forest_trees: Array[LearnedTree]) -> void:
	features = forest_features
	classes = forest_classes
	trees = forest_trees


## The forest a model file publishes, built from its entry once `ModelFile`
## has checked it: each tree built as a published tree is, from its nodes
## and the features and classes the forest holds for all of them.
static func from_entry(entry: Dictionary) -> LearnedForest:
	var built: Array[LearnedTree] = []
	for nodes: Array in entry["trees"]:
		built.append(LearnedTree.from_entry({"features": entry["features"], "classes": entry["classes"],
			"nodes": nodes}))
	# `new()`, not its own class name: naming it would make the script hold itself (T162, docs/godot/exit-leaks.md).
	return new(PackedStringArray(entry["features"]), PackedStringArray(entry["classes"]), built)


## Each tree's vote for `values`, in tree order: its leaf's likeliest answer,
## or "" for a tree that abstains because its walk could not finish.
func votes(values: Dictionary) -> PackedStringArray:
	var cast := PackedStringArray()
	for tree: LearnedTree in trees:
		cast.append(tree.likeliest(values))
	return cast


## How many trees voted for each answer, by name, in `classes` order;
## answers nobody voted for, and abstentions, are left out. Takes the votes
## already cast, so a caller that shows them need not walk every tree twice.
func tally_of(cast: PackedStringArray) -> Dictionary:
	var tally: Dictionary = {}
	for name: String in classes:
		var count: int = cast.count(name)
		if count > 0:
			tally[name] = count
	return tally


## The answer with the most votes in `tally`; of equal tallies, the first in
## `classes` -- not whichever tree voted first; "" when every tree abstained.
func likeliest_in(tally: Dictionary) -> String:
	var best: String = ""
	for name: String in classes:
		if int(tally.get(name, 0)) > int(tally.get(best, 0)):
			best = name
	return best


## The forest's answer for `values`: the most votes, ties to the first in `classes`.
func likeliest(values: Dictionary) -> String:
	return likeliest_in(tally_of(votes(values)))


## Each answer's share of the votes cast, by name; empty when every tree abstained.
func shares_of(tally: Dictionary) -> Dictionary:
	var cast: int = 0
	for count: Variant in tally.values():
		cast += int(count)
	var shares: Dictionary = {}
	if cast == 0:
		return shares
	for name: String in classes:
		shares[name] = float(tally.get(name, 0)) / cast
	return shares
