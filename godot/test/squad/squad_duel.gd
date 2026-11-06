## T88's duel, the rules apart from the runner: a position of
## `spec/squad/duel.json` read and written, searched by each of the two
## searches for a time on the wall clock, and what a row of the duel must
## hold. `squad_duel_test.gd` hands `wrong_position` and `wrong_match`
## planted rows, and watches them object.
##
## Both searches are the ones the controllers make (`MctsSquad`,
## `ExpectiSquad`), with the rules' numbers, handed the position's board as
## it is written -- the same board to both, the guess at the fog already in
## it -- for the same time on the wall clock. In the matches the
## controllers themselves play, both guessing at the fog the same way
## (`SearchingSquad.believe`).
##
## When not to use it: to decide which search is better. One machine, one
## load, one run: the duel says what happened, and the page says so.
class_name SquadDuel
extends RefCounted

## The budgets a decision, in milliseconds, the task's three.
const BUDGETS: Array[int] = [50, 200, 1000]
const RUNNER: Script = preload("res://test/squad/squad_search_vectors_runner.gd")


## The root question a duel position writes -- `positions.json`'s shape.
static func root(position: Dictionary) -> SquadSearchGame.Position:
	return RUNNER.root(position)


## The board a position writes, the side to move's.
static func board_of(position: Dictionary) -> BoardState:
	return root(position).board


## A position as the file keeps it: `unit_id`'s `phase` question on `board`.
static func written(board: BoardState, unit_id: int, phase: int) -> Dictionary:
	var pieces: Array = []
	for unit: Unit in board.units:
		pieces.append([unit.id, unit.faction, unit.type.type_name, unit.cell.x, unit.cell.y, unit.health, unit.movement_points])
	var waiting: Array = []
	var asked_already: bool = true
	for piece: Unit in board.units_of(board.current_faction):
		if not asked_already:
			waiting.append(piece.id)
		asked_already = asked_already and piece.id != unit_id
	return {"turn": board.turn_number, "to_move": board.current_faction, "acting": unit_id,
		"phase": "walk" if phase == SquadSearchGame.WALK else "shoot", "waiting": waiting, "pieces": pieces}


## What a position holds, of a flank, a long shot and a retreat to cover.
static func tags(board: BoardState, unit_id: int, phase: int) -> Array[String]:
	var unit: Unit = board.unit_by_id(unit_id)
	if phase == SquadSearchGame.SHOOT:
		return _shot_tags(board, unit)
	var hurt: bool = unit.health < SquadTable.number(unit.type.type_name, "health")
	var safe: Callable = func(walk: Array) -> bool: return not _open_at(board, unit, walk[2])
	if hurt and _open_at(board, unit, unit.cell) and SquadSearchGame.walks(board, unit).any(safe):
		return ["retreat to cover"] as Array[String]
	return [] as Array[String]


## The answer each search gives to `position` after `milliseconds` on the
## wall clock: `{"mcts": answer, "iterations", "expecti": answer, "depth",
## "positions"}`, answers as the vectors write them. Each is the search its
## controller makes, with the rules' numbers, run in shares of one unit of
## work between looks at the clock, as `SearchingSquad.think_for` runs it.
static func searched(position: Dictionary, milliseconds: int, seed_number: int) -> Dictionary:
	var question: SquadSearchGame.Position = root(position)
	var sampled := MonteCarloSearch.new(SquadSearchGame.new(), question, seed_number, MctsSquad.exploration(),
		MctsSquad.playout_limit())
	var found: MctsResult = sampled.result()
	var deadline: int = Time.get_ticks_usec() + milliseconds * 1000
	while Time.get_ticks_usec() < deadline:
		found = sampled.step(SearchingSquad.CLOCK_SHARE)
	var weighed := ExpectiminimaxSearch.new(SquadEvaluatedGame.new(), question,
		int(ExpectiSquad.search_rules()["deepest"]))
	deadline = Time.get_ticks_usec() + milliseconds * 1000
	while Time.get_ticks_usec() < deadline and not weighed.is_complete():
		weighed.step(SearchingSquad.CLOCK_SHARE)
	var worked_out: AdversarialResult = weighed.result()
	return {"mcts": SquadSearchGame.described(found.action), "iterations": found.iterations,
		"expecti": SquadSearchGame.described(worked_out.action) if worked_out.action != null else "nothing",
		"depth": worked_out.depth, "positions": weighed.positions_visited()}


# A flank, a long shot or both, among `unit`'s shots on `board`.
static func _shot_tags(board: BoardState, unit: Unit) -> Array[String]:
	var rows: Array[String] = SquadScenario.rows()
	var found: Array[String] = []
	for shot: Array in SquadSearchGame.shots(board, unit):
		var target: Unit = board.unit_by_id(shot[2])
		var far: bool = SquadSight.steps(unit.cell, target.cell) >= 6 or SquadCombat.chance_of(rows, unit, target) <= 25
		if SquadCover.of(rows, unit.cell, target.cell)["flanked"] and not "flank" in found:
			found.append("flank")
		if far and not "long shot" in found:
			found.append("long shot")
	return found


## Everything wrong with one position's row, each budget's answers in
## `rows` in `BUDGETS`' order: an answer that is not one of the position's,
## an expectiminimax that finished no depth, an MCTS that ran no iteration,
## or a longer budget that searched less -- a shallower depth, fewer
## iterations -- than a shorter one.
static func wrong_position(position: Dictionary, rows: Array[Dictionary]) -> Array[String]:
	var answers: Array = SquadSearchGame.answers(board_of(position), int(position["acting"]),
		SquadSearchGame.WALK if position["phase"] == "walk" else SquadSearchGame.SHOOT).map(SquadSearchGame.described)
	var wrong: Array[String] = []
	for index: int in range(rows.size()):
		var row: Dictionary = rows[index]
		wrong += _not_its_answers(position, row, answers)
		if row["depth"] < 1 or row["iterations"] < 1:
			wrong.append("%s: at %d ms a search finished nothing" % [position["name"], BUDGETS[index]])
		if index > 0 and (row["depth"] < rows[index - 1]["depth"] or row["iterations"] < rows[index - 1]["iterations"]):
			wrong.append("%s: %d ms searched less than %d ms" % [position["name"], BUDGETS[index], BUDGETS[index - 1]])
	return wrong


# The searches in `row` whose answer is not one of `answers`.
static func _not_its_answers(position: Dictionary, row: Dictionary, answers: Array) -> Array[String]:
	var wrong: Array[String] = []
	for search: String in ["mcts", "expecti"]:
		if not row[search] in answers:
			wrong.append("%s: %s answered %s, not one of its answers" % [position["name"], search, row[search]])
	return wrong


## Everything wrong with one match's row: no winner and no draw, or a
## decision lost to a refused walk.
static func wrong_match(row: Dictionary) -> Array[String]:
	var wrong: Array[String] = []
	if row["winner"] == TacticalVictory.NOBODY:
		wrong.append("match %d: it ended with no winner and no draw" % row["game"])
	if row["lost"][0] + row["lost"][1] > 0:
		wrong.append("match %d: %d decision(s) lost to a refused walk" % [row["game"], row["lost"][0] + row["lost"][1]])
	return wrong


# True when some enemy on `board` could shoot `unit` standing on `cell`,
# with no cover facing it there.
static func _open_at(board: BoardState, unit: Unit, cell: Vector2i) -> bool:
	var rows: Array[String] = SquadScenario.rows()
	for enemy: Unit in board.units:
		var shoots: bool = enemy.faction != unit.faction and SquadCombat.can_reach(rows, enemy, cell)
		if shoots and SquadCover.of(rows, enemy.cell, cell)["cover"] == 0:
			return true
	return false
