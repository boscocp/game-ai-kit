## The learner with a random forest reading you instead of one tree (T114).
##
## The question is the tree's, T17's: what will you do next? The tree
## answers from one path. The forest asks 25 trees, each fitted in Python on
## its own bootstrap of your recorded fights, with a random subset of the
## situation's words at each node (`gameaikit.cloning.opponent_forest`;
## invariant 6), and each votes. It expects the answer with the most votes,
## and leans its answers up by how much surer than chance the vote is --
## `LEAN` when every tree agreed. It learns nothing here: the n-gram still
## counts beside it, scored at the same decisions, as beside the tree.
##
## Shown, not only used: `cast` is each tree's vote at its last decision,
## "" for a tree that could not read your situation, and `tally` the count.
## The cost: one walk per tree, so 25 walks of at most three tests a decision.
##
## When not to use it: as the tree's, against a player it was not fitted on.
## And not to find what one tree missed: on these recordings the vote moves
## less than one tree's guess, and scores no better on fights it never saw
## (docs/concepts/learning.md#a-random-forest). A forest takes out variance;
## it adds no signal.
class_name FightForestOpponent
extends FightTreeOpponent

## Where the published forest lives. Published by `make train-forest`; its
## own name, because the tree's `PUBLISHED_PATH` is inherited.
const FOREST_PATH: String = "res://game/fighting/opponent_forest.json"

## The forest, or null when the file was refused; `refusal` says why.
var forest: LearnedForest
## Each tree's vote at its last decision, in tree order, "" for one that
## abstained; and how many votes each answer got, in `classes` order.
var cast: PackedStringArray = PackedStringArray()
var tally: Dictionary = {}


## A new fight: no votes cast. The forest is the same forest it was.
func new_fight() -> void:
	super()
	cast = PackedStringArray()
	tally = {}


## How many of its last `SCORED` guesses the vote had right, and of how
## many: kept by the tree's `watch`, which scores whatever this reads with.
func forest_score() -> Array[int]:
	return tree_score()


## True once its trees have voted on a situation: a guess to score.
func has_read() -> bool:
	return not cast.is_empty()


# The forest out of `published`, or why there is none.
func _take_model(published: ModelFile) -> void:
	forest = published.forest(MODEL_NAME) if published.is_loaded() else null
	if not published.is_loaded():
		refusal = published.error
	elif forest == null:
		refusal = "the file publishes no forest named `next action`"  # shown through tr()


# Every tree's vote on `situation`, and the tally of them; none with no forest.
func _read(situation: Dictionary) -> void:
	walked = []
	cast = PackedStringArray()
	tally = {}
	if forest != null:
		cast = forest.votes(situation)
		tally = forest.tally_of(cast)


# The vote's answer, in the learner's fields: what it expects, and the share
# of the votes cast for it. With no forest, or every tree abstaining, it
# expects nothing and leans nothing. The n-gram's guess is kept beside it.
func _expect() -> void:
	_keep_ngram_guess()
	if tally.is_empty():
		expected = "nothing yet"  # not shown: an identifier
		confidence = 0.0
		return
	expected = forest.likeliest_in(tally)
	confidence = forest.shares_of(tally)[expected]
