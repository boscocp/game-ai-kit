## What will the player do next? A table of what it did after what, counted
## as it plays, and read back as a probability for each action.
##
## An n-gram of order `order` looks at the last `order - 1` actions -- the
## context -- and counts, for each context it has seen, which action came
## next. Order 1 is a plain frequency count; order 2 asks "after a low kick,
## what?"; order 3 "after a low kick and a jab, what?". The order is the
## lesson: too low and it cannot tell one moment from another, too high and
## it never sees the same context twice before the fight is over.
##
## Two refinements, each one number:
##
## * **Smoothing.** Every action starts with `prior` imaginary sightings in
##   every context -- additive smoothing; Laplace's when `prior` is 1. So a
##   context never seen predicts every action alike, "I do not know", instead
##   of a confident answer drawn from nothing; and an action never seen keeps
##   a little probability. Chosen over backing off to a shorter context
##   (Katz) because it is one line and one number, and what it does to a table
##   can be worked out by hand.
## * **Decay.** Each time a context is seen again, its old counts are
##   multiplied by `decay` before the new one is added: a sighting `k` visits
##   ago weighs `decay^k`. At 1 the table averages the whole fight; below 1
##   it follows a player who changes habits, forgetting the old ones at that
##   rate. Only the context seen is decayed, so the cost is one row.
##
## The table is counts of what was on screen, nothing else: it starts empty,
## and replaying the same actions rebuilds it exactly (ADR 0016). It is
## printable on purpose -- `rows` -- because a table you can read is the point
## of choosing an n-gram over a network.
##
## Complexity: `observe` and `probabilities` are linear in the number of
## actions; the table grows with the contexts actually seen, at most
## actions^(order - 1).
##
## When not to use it: actions that depend on more than the last few -- on
## distance, on health, on the clock. The n-gram sees only the sequence; for
## anything else, the context has to be built into the symbols.
class_name NGramPredictor
extends RefCounted

## How many actions it looks at to predict the next, plus one.
var order: int
## Every action it may see or predict, in the order ties are broken in.
var actions: Array[String]
## How much a context's old counts are kept each time it is seen again.
var decay: float
## How many imaginary sightings every action starts with, in every context.
var prior: float

## Context, as its actions joined by " > ", to `{action: weight}`.
var _counts: Dictionary = {}
## The last `order - 1` actions seen, oldest first.
var _recent: Array[String] = []


## A predictor of `known` actions at `n_gram_order` (1 or more), forgetting at
## `forgetting` per sighting (0 < it <= 1) and smoothing with `pseudo_count`
## (0 or more). `problem` says what is wrong with any of those.
func _init(n_gram_order: int, known: Array[String], forgetting: float = 1.0, pseudo_count: float = 1.0) -> void:
	order = n_gram_order
	actions = known
	decay = forgetting
	prior = pseudo_count


## What is wrong with this predictor's settings, or "" when nothing is.
func problem() -> String:
	if order < 1:
		return "an n-gram's order is at least 1, and this one is %d" % order
	if actions.is_empty():
		return "a predictor needs at least one action to predict"
	if decay <= 0.0 or decay > 1.0:
		return "decay must be above 0 and at most 1, and is %s" % decay
	if prior < 0.0 or (prior == 0.0 and actions.size() > 1):
		return "prior must be above 0, or nothing could be said about a context never seen"
	return ""


## The player did `action`: count it after the current context, then make it
## part of the next one. An action it was not told about is ignored.
func observe(action: String) -> void:
	if not action in actions:
		return
	if _recent.size() == order - 1:
		var row: Dictionary = _counts.get_or_add(context(), {})
		for seen: String in row:
			row[seen] = row[seen] * decay
		row[action] = row.get(action, 0.0) + 1.0
	_recent.append(action)
	if _recent.size() > order - 1:
		_recent.pop_front()


## The context the next action will be counted under, as the table writes it:
## the last `order - 1` actions joined by " > ", "" for order 1.
func context() -> String:
	return " > ".join(_recent)


## How likely each action is next, from the current context, the smoothed
## counts over their smoothed total. Every action is present; they sum to 1.
## Before `order - 1` actions have been seen there is no context yet, and the
## answer is the prior alone: every action alike.
func probabilities() -> Dictionary:
	var row: Dictionary = _counts.get(context(), {}) if _recent.size() == order - 1 else {}
	var total: float = prior * actions.size()
	for seen: String in row:
		total += row[seen]
	var chances: Dictionary = {}
	for action: String in actions:
		chances[action] = (row.get(action, 0.0) + prior) / total
	return chances


## The likeliest next action; of equal ones, the first in `actions`.
func likeliest() -> String:
	var chances: Dictionary = probabilities()
	var best: String = actions[0]
	for action: String in actions:
		if chances[action] > chances[best]:
			best = action
	return best


## The table as text, one row a context: the context, then each action seen
## after it with its weight, heaviest first. For a person, not for the code.
func rows() -> PackedStringArray:
	var lines: PackedStringArray = []
	for key: String in _counts:
		var row: Dictionary = _counts[key]
		var seen: Array = row.keys()
		seen.sort_custom(func(first: String, second: String) -> bool: return row[first] > row[second])
		var cells: PackedStringArray = []
		for action: String in seen:
			cells.append("%s %.1f" % [action, row[action]])
		lines.append("%s -> %s" % [key if key != "" else "(anything)", ", ".join(cells)])
	return lines
