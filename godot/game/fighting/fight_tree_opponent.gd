## The learner with a decision tree reading you instead of the n-gram (T113).
##
## The question is T17's: what will you do next? The n-gram answers from
## your last action, counted during this fight. The tree answers from the
## whole situation as you saw it -- your last action, what this fighter was
## doing, your condition, the distance, the health, the corner: the six
## words behaviour cloning (T18) reads -- and it was fitted in Python, on
## your recorded fights, before this one began (`gameaikit.cloning.
## opponent_tree`; invariant 6). It learns nothing here: the n-gram still
## counts beside it, and the panel scores the two against each other.
##
## Everything else is the learner's: it sits behind `FightDelay` and reads
## the fight `reaction` frames late, its level's options are the only ones
## it has, and an expected action leans its answers up by how much surer
## than chance the leaf is -- `LEAN` when the leaf saw nothing else.
##
## Shown, not only used: `walked` is the path the last decision took, each
## test, the word it read and which way it went, and the leaf's counts.
##
## When not to use it: against a player the tree was not fitted on, or with
## few recordings of them. A tree learns the rows it was given -- the report
## shows how little of that carries to a new fight -- and a player who
## changes their habits mid-fight is the n-gram's to read, not the tree's.
class_name FightTreeOpponent
extends FightModelOpponent

## Where the published tree lives. Published by `make train-tree`.
const PUBLISHED_PATH: String = "res://game/fighting/opponent_tree.json"
## The name the tree is published under in that file.
const MODEL_NAME: String = "next action"  # not shown: an identifier

## The tree, or null when the file was refused; `refusal` says why.
var reader: LearnedTree
var refusal: String = ""
## What its last decision read, as your situation, and the path the tree
## took through it: `LearnedTree.steps`, ending at the leaf.
var person_situation: Dictionary = {}
var walked: Array[Dictionary] = []
## What the n-gram beside it expected at the same decision, and how sure.
var ngram_expected: String = "nothing yet"  # not shown: an identifier
var ngram_confidence: float = 0.0
## For each action it has seen you start: whether the tree had expected it
## at its last decision, and whether the n-gram had, at that same decision.
## Both are asked at the same moment, so the two scores are a fair contest;
## `guesses` keeps the learner's own, scored on every frame's table.
var tree_guesses: Array[bool] = []
var ngram_guesses: Array[bool] = []

var _person_last: String = ""
var _person_action: String = ""


## An opponent at `level_name` reading you with the tree `published` holds,
## drawing its chances from `chance_seed`.
func _init(level_name: String, published: ModelFile, data: FightData, chance_seed: int = 0) -> void:
	super(level_name, data, chance_seed)
	reader = published.tree(MODEL_NAME) if published.is_loaded() else null
	if not published.is_loaded():
		refusal = published.error
	elif reader == null:
		refusal = "the file publishes no tree named `next action`"  # shown through tr()


## A new fight: nothing read, nothing guessed. The tree itself is the same
## tree it was: nothing in a fight changes it.
func new_fight() -> void:
	super()
	_person_last = ""
	_person_action = ""
	person_situation = {}
	walked = []
	ngram_expected = "nothing yet"  # not shown: an identifier
	ngram_confidence = 0.0
	tree_guesses.clear()
	ngram_guesses.clear()


## As the learner's, and the tree's last guess is scored when you start a
## new action; your `last` is then the last action you were seen doing, as
## of the frame it reads -- as `FightRecording.last_seen` writes the rows.
func watch(seen: FightState, me: int) -> void:
	var action: String = FightAction.of(seen, 1 - me, _data)
	if action != "" and action != _person_action and not walked.is_empty():
		tree_guesses.append(expected == action)
		ngram_guesses.append(ngram_expected == action)
	_person_action = action
	if action != "":
		_person_last = action
	super(seen, me)


## How many of its last `SCORED` guesses the tree had right, and of how many.
func tree_score() -> Array[int]:
	return _scored(tree_guesses)


## The same for the n-gram's guesses at the tree's decisions.
func ngram_score() -> Array[int]:
	return _scored(ngram_guesses)


# How many of the last `SCORED` of `list` were right, and of how many.
static func _scored(list: Array[bool]) -> Array[int]:
	var recent: Array[bool] = list.slice(maxi(0, list.size() - SCORED))
	return [recent.count(true), recent.size()]


# Your situation, read off the late frame, before the learner decides.
func _decide(seen: FightState, me: int) -> void:
	person_situation = FightSituation.of(seen, 1 - me, _person_last, _data)
	walked = []
	if reader != null:
		walked = reader.steps(person_situation)
	super(seen, me)


# The tree's answer, in the learner's fields: what it expects, and the
# leaf's share for it. With no tree, or a walk it could not finish, it
# expects nothing and leans nothing. The n-gram's guess is kept beside it.
func _expect() -> void:
	ngram_expected = model.likeliest()
	ngram_confidence = model.probabilities()[ngram_expected]
	expected_after = ""
	var leaf: Dictionary = walked.back().get("counts", {}) if not walked.is_empty() else {}
	if leaf.is_empty():
		expected = "nothing yet"  # not shown: an identifier
		confidence = 0.0
		return
	expected = reader.likeliest_in(leaf)
	confidence = reader.shares_of(leaf)[expected]


## The surest a leaf can be: all of its rows one action.
func ceiling() -> float:
	return 1.0
