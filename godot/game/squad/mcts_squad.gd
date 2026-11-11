## The XCOM-style mode's enemy that searches by sampling (T87): Monte Carlo
## tree search from `ai_adversarial`, over `SquadSearchGame`, for the piece
## about to act. What it perceives, how it asks, and how it plays and shows
## the answer are `SearchingSquad`'s, shared with `ExpectiSquad` (T88), so
## that the two searches are compared on the same information.
##
## Decide: `iterations` iterations of UCT on the board its side believes in
## (`rules.json`'s `search`), the most visited answer played. In the scene
## they are spread over frames, each searching until `frame_share_ms` of it
## is spent (T117); the count is the decision's, the clock only how soon. The tree is
## the piece's whole question -- hold, walk to each cell, or shoot each
## target -- and below it the rest of the turn, the other side's, and
## playouts scored on health. No evaluation to write: a playout's end is
## scored on health alone.
##
## What it shows (invariant 13): every root answer's visits, mean and UCB1
## bound, on the board (`weighed`) and as bars in the status
## (`search_lines`), growing while it thinks; then the line of play it
## expects (`MonteCarloSearch.principal_line`).
##
## O(iterations x playout length x a piece's reach) a decision. When not to
## use it: when one action ahead is enough to see the answer -- `WeighedSquad`
## decides in a millisecond what this takes a second to find, or misses.
class_name MctsSquad
extends SearchingSquad

## How many answers the status draws a bar for, the most visited first.
const LINES_SHOWN: int = 6
## The width of the longest bar, in characters.
const BAR_WIDTH: int = 20
## How many moves of the expected line the status writes.
const LINE_LENGTH: int = 6

## The iterations it searches a decision.
var iterations: int

var _game := SquadSearchGame.new()
# The search for the decision being made, what is left of its budget, and
# where it stands.
var _search: MonteCarloSearch
var _left: int = 0
var _found: MctsResult


func _init(seed_number: int = 0, budget: int = -1) -> void:
	super(seed_number)
	iterations = budget if budget > 0 else int(search_rules()["iterations"])


## `rules.json`'s `search`: the numbers this enemy searches with.
static func search_rules() -> Dictionary:
	return SquadTable.rules()["search"]


## UCB1's constant, from the rules.
static func exploration() -> float:
	return float(search_rules()["exploration"])


## How many answers a playout plays before it is scored, from the rules.
static func playout_limit() -> int:
	return int(search_rules()["playout_limit"])


## "mcts".
func controller_name() -> String:
	return "mcts"  # not shown: a roster key


## What it is, for the screen.
func describe() -> String:
	return TranslationServer.translate("Monte Carlo tree search over the piece's options and the turns after, on the board its side believes in")


## "iterations".
func work_unit() -> String:
	return "iterations"  # not shown: the meter's unit, an identifier


## What its search did, as lines for the status: the iterations so far, a
## bar of visits for each of the answers visited most, with the mean and the
## bound, and the line of play it expects. In the language on screen.
func search_lines() -> Array[String]:
	var lines: Array[String] = []
	if _found == null:
		return lines
	lines.append(TranslationServer.translate("searched {done} of {budget} iterations; the bar is each option's visits:").format({
		done = _found.iterations, budget = iterations}))
	var ranked: Array[Dictionary] = _found.considered.duplicate()
	ranked.sort_custom(func(one: Dictionary, other: Dictionary) -> bool: return one["visits"] > other["visits"])
	var most: int = maxi(1, ranked[0]["visits"])
	for entry: Dictionary in ranked.slice(0, LINES_SHOWN):
		lines.append(TranslationServer.translate("{bar} {option}: {visits} visits, mean {mean}, bound {bound}").format({
			bar = "█".repeat(ceili(BAR_WIDTH * float(entry["visits"]) / most)).rpad(BAR_WIDTH, "·"),
			option = answer_said(entry["action"]), visits = entry["visits"], mean = "%+.2f" % entry["mean"],
			bound = "%+.2f" % entry["bound"] if is_finite(entry["bound"]) else "∞"}))
	if ranked.size() > LINES_SHOWN:
		lines.append(TranslationServer.translate("and {count} more").format({count = ranked.size() - LINES_SHOWN}))
	var expected: Array = _search.principal_line(LINE_LENGTH) if _search != null else []
	if not expected.is_empty():
		lines.append(TranslationServer.translate("the line it expects: {line}").format({
			line = ", ".join(expected.map(answer_said))}))
	return lines


## How to read its search on the board.
func board_said() -> String:
	return TranslationServer.translate("on the board, every option it searched: its mean above, a shot's hit chance below, the most visited framed; space stops the search and plays it; V shows your own view instead")


func _work_per_frame() -> int:
	return int(search_rules()["iterations_per_frame"])


# The rules' `frame_share_ms` (T117): in the scene, after the first frame,
# iterations run until this much of the frame is spent.
func _frame_share_usec() -> int:
	return roundi(float(search_rules()["frame_share_ms"]) * 1000.0)


func _start_search(root: SquadSearchGame.Position) -> void:
	_search = MonteCarloSearch.new(_game, root, _decision_seed(), exploration(), playout_limit())
	_left = iterations if _clock_msec == 0 else UNLIMITED


func _search_more(count: int) -> void:
	var running: int = mini(count, _left)
	_found = _search.step(running)
	_left -= running
	_work += running


func _has_work_left() -> bool:
	return _search != null and _left > 0


func _stop_search() -> void:
	_search = null


func _drop_search() -> void:
	_search = null
	_found = null


# Every root answer: its visits are its preference; its mean is the score
# the board draws, with its visits and bound besides.
func _options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	if _found == null:
		return options
	for entry: Dictionary in _found.considered:
		options.append({"action": entry["action"], "preference": float(entry["visits"]), "score": entry["mean"],
			"chosen": entry["action"] == _found.action, "visits": entry["visits"], "bound": entry["bound"]})
	return options


# The most visited answer, and why, in the search's numbers.
func _chosen() -> Variant:
	if _found == null or _found.action == null:
		return null
	var action: Array = _found.action
	var best: Dictionary = _found.considered.filter(func(entry: Dictionary) -> bool: return entry["action"] == action)[0]
	return {"action": action, "reason": Sentence.of("searched {done} iterations: {count} option(s), this one visited most, {visits} times, mean {mean}", {  # shown through tr()
		done = _found.iterations, count = _found.considered.size(), visits = best["visits"], mean = "%+.2f" % best["mean"]})}


func _refused_walk_reason() -> Array:
	return Sentence.of("its walk was refused; the next most visited", {})  # shown through tr()
