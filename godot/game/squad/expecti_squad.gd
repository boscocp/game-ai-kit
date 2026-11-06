## The XCOM-style mode's enemy that searches by working out the odds (T88):
## expectiminimax from `ai_adversarial`, over `SquadEvaluatedGame`, for the
## piece about to act. What it perceives, how it asks, and how it plays and
## shows the answer are `SearchingSquad`'s, shared with `MctsSquad` (T87),
## so the two searches are compared on the same information.
##
## Decide: every answer to the piece's question, each followed down the
## turn -- its own side's pieces as MAX, the other side's as MIN -- and at a
## shot both of its outcomes, hit and miss, weighed by the chance the person
## is shown. Where it stops it scores the position with an evaluation
## written by hand (`SquadEvaluatedGame`: health, cover, flanks), and plays
## the answer whose expected value is highest. Iterative deepening, one ply
## more each time, `positions_per_frame` positions a frame in the scene, up
## to `positions` a decision (`rules.json`'s `expectiminimax`): anytime, by
## a different route than MCTS -- it always has the deepest *finished*
## depth's answer.
##
## What it shows (invariant 13): every root answer's expected value on the
## board, the one it plays framed; in the status, the depth finished so far
## and the one under way, a bar for each answer worth most, and for a shot
## its hit and miss branches, each with its chance and what it is worth.
##
## O((b n)^d) a depth, b a piece's answers and n a shot's two outcomes: a
## walk question has some forty answers, so each ply costs about forty times
## the one before. When not to use it: when the evaluation cannot be
## written, or the useful depth is out of reach in the time there is -- MCTS
## needs neither.
class_name ExpectiSquad
extends SearchingSquad

## How many answers the status writes, the best first.
const LINES_SHOWN: int = 6
## The width of the longest bar, in characters.
const BAR_WIDTH: int = 20

## The positions it searches a decision, all depths together.
var positions: int

var _game := SquadEvaluatedGame.new()
# The search for the decision being made, the question it asks, what is
# left of its budget, and where it stands.
var _search: ExpectiminimaxSearch
var _root: SquadSearchGame.Position
var _left: int = 0
var _found: AdversarialResult


func _init(seed_number: int = 0, budget: int = -1) -> void:
	super(seed_number)
	positions = budget if budget > 0 else int(search_rules()["positions"])


## `rules.json`'s `expectiminimax`: the numbers this enemy searches with.
static func search_rules() -> Dictionary:
	return SquadTable.rules()["expectiminimax"]


## "expecti".
func controller_name() -> String:
	return "expecti"  # not shown: a roster key


## What it is, for the screen.
func describe() -> String:
	return TranslationServer.translate("expectiminimax over the piece's options and the turns after, every shot's hit and miss weighed by its chance, on the board its side believes in")


## "positions".
func work_unit() -> String:
	return "positions"  # not shown: the meter's unit, an identifier


## What its search did, as lines for the status: the depth finished and
## the one under way, a bar of expected value for each of the answers worth
## most, a shot's hit and miss besides. In the language on screen.
func search_lines() -> Array[String]:
	var lines: Array[String] = []
	if _search == null and _found == null:
		return lines
	lines.append(TranslationServer.translate("searched to depth {depth} of {deepest}, {visited} of {budget} positions; the bar is each option's expected value:").format({
		depth = _found.depth if _found != null else 0, deepest = int(search_rules()["deepest"]),
		visited = positions - _left, budget = positions}))
	if _found == null or _found.considered.is_empty():
		return lines
	var ranked: Array[Dictionary] = _found.considered.duplicate()
	ranked.sort_custom(func(one: Dictionary, other: Dictionary) -> bool: return one["value"] > other["value"])
	var worst: float = ranked.back()["value"]
	var spread: float = maxf(ranked[0]["value"] - worst, 1e-9)
	for entry: Dictionary in ranked.slice(0, LINES_SHOWN):
		lines.append(_line_for(entry, (entry["value"] - worst) / spread))
	if ranked.size() > LINES_SHOWN:
		lines.append(TranslationServer.translate("and {count} more").format({count = ranked.size() - LINES_SHOWN}))
	return lines


## How to read its search on the board.
func board_said() -> String:
	return TranslationServer.translate("on the board, every option it searched: its expected value above, a shot's hit chance below, the best framed; space stops the search and plays the deepest finished depth's answer; V shows your own view instead")


# One answer's line: its bar, its expected value, and for a shot its two
# branches.
func _line_for(entry: Dictionary, share: float) -> String:
	var said: Dictionary = {bar = "█".repeat(maxi(1, ceili(BAR_WIDTH * share))).rpad(BAR_WIDTH, "·"),
		option = answer_said(entry["action"]), value = "%+.3f" % entry["value"]}
	var branches: Array = entry["outcomes"]
	if entry["action"][0] != SquadSearchGame.SHOOT_WORD or branches.size() != 2:
		return TranslationServer.translate("{bar} {option}: expected {value}").format(said)
	said.merge({hit = roundi(100 * branches[0]["probability"]), if_hit = "%+.3f" % branches[0]["value"],
		miss = roundi(100 * branches[1]["probability"]), if_missed = "%+.3f" % branches[1]["value"]})
	return TranslationServer.translate("{bar} {option}: expected {value} -- hit {hit}%: {if_hit}, miss {miss}%: {if_missed}").format(said)


func _work_per_frame() -> int:
	return int(search_rules()["positions_per_frame"])


func _start_search(root: SquadSearchGame.Position) -> void:
	_root = root
	_search = ExpectiminimaxSearch.new(_game, root, int(search_rules()["deepest"]))
	_left = positions


func _search_more(count: int) -> void:
	var before: int = _search.positions_visited()
	_found = _search.step(mini(count, _left))
	var done: int = _search.positions_visited() - before
	_left -= done
	_work += done


func _has_work_left() -> bool:
	return _search != null and _left > 0 and not _search.is_complete()


func _stop_search() -> void:
	_search = null


func _drop_search() -> void:
	_search = null
	_found = null


# Every root answer of the deepest finished depth: its expected value is
# both its preference and the score the board draws; its outcomes besides.
func _options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	if _found == null:
		return options
	for entry: Dictionary in _found.considered:
		options.append({"action": entry["action"], "preference": entry["value"], "score": entry["value"],
			"chosen": entry["action"] == _found.action, "outcomes": entry["outcomes"], "depth": _found.depth})
	return options


# The answer worth most at the deepest finished depth, and why; before
# depth 1 has finished, holding, and saying so.
func _chosen() -> Variant:
	if _found == null:
		return null
	if _found.action == null:
		return {"action": [SquadSearchGame.HOLD_WORD, _root.unit_id],
			"reason": Sentence.of("has not finished depth 1 yet, and would hold", {})}  # shown through tr()
	return {"action": _found.action, "reason": Sentence.of("searched to depth {depth}: {count} option(s), this one worth most, expected {value}", {  # shown through tr()
		depth = _found.depth, count = _found.considered.size(), value = "%+.3f" % _found.value})}


func _refused_walk_reason() -> Array:
	return Sentence.of("its walk was refused; the next worth most", {})  # shown through tr()
