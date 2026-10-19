## A game of the tactical board, kept: every decision both sides played, in
## order, written to a file -- the human reference T25's league measures its
## teams against, and what behaviour cloning on this board will learn from.
##
## What is kept is the decision log and nothing else, as ADR 0017 keeps a
## fight's inputs: the board's dice seed, and each decision -- who decided,
## on which turn, and what -- because the board is deterministic, so the
## same decisions from the same seed give the same game, and every board a
## side saw can be rebuilt from it (`replay`). A recording outlives every
## change to what is cut from it.
##
## A row of the human reference is one decision of the person: the board as
## they saw it when they made it, and what they did (`rows_of`). That is the
## shape T18's rows have -- what was seen, what was done -- with this board's
## contents, not a fight's.
##
## When not to use it: a game played under other rules. A recording is
## decisions, not outcomes, and a decision the current rules refuse makes the
## replay stop and say so.
class_name TacticalRecording
extends RefCounted

## What a file says it is, so a reader can refuse anything else.
const FORMAT: String = "tactical-decisions"
const VERSION: int = 1
## Who a recording is of, when it is of a person.
const PERSON: String = "person"


## Where recordings live: `data/tactical/` at the top of the repository,
## beside `data/fights/`, outside the Godot project.
static func directory() -> String:
	return ProjectSettings.globalize_path("res://").path_join("../data/tactical").simplify_path()


## A decision as a row: its side, the turn it was made on, and what it was.
static func row_of(decision: TacticalDecision, state: BoardState) -> Dictionary:
	var row: Dictionary = {"side": state.current_faction, "turn": state.turn_number, "kind": decision.kind(),
		"unit": decision.unit_id}
	if decision.move != null:
		row["path"] = decision.move.path.map(func(cell: Vector2i) -> Array: return [cell.x, cell.y])
	elif decision.order != null:
		row["type"] = decision.order.unit_type.type_name
		row["cell"] = [decision.order.cell.x, decision.order.cell.y]
	elif decision.attack != null:
		row["target"] = decision.attack.target_id
	elif decision.upgrade != null:
		row["upgrade"] = decision.upgrade.upgrade_name
	return row


## The decision a row says, to be played again.
static func decision_of(row: Dictionary) -> TacticalDecision:
	var unit_id: int = int(row["unit"])
	match row["kind"]:
		"move":
			var path: Array[Vector2i] = _cells(row["path"])
			return TacticalDecision.walk(unit_id, path, "recorded", path.back())
		"build":
			var at := Vector2i(int(row["cell"][0]), int(row["cell"][1]))
			var order := ProductionOrder.new(unit_id, TacticalRules.unit_types()[row["type"]], at)
			return TacticalDecision.build(unit_id, order, "recorded")
		"attack":
			var decision := TacticalDecision.new(unit_id, "recorded", Vector2i.ZERO)
			decision.attack = Attack.new(unit_id, int(row["target"]))
			return decision
		"buy":
			return TacticalDecision.buy(unit_id, TacticalRules.forge(), "recorded", Vector2i.ZERO)
	return TacticalDecision.hold(unit_id, "recorded", Vector2i.ZERO)


# A path as the file writes it, [[x, y], ...], as cells.
static func _cells(written: Array) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	for cell: Array in written:
		path.append(Vector2i(int(cell[0]), int(cell[1])))
	return path


## A recording of a game on dice `dice_seed`, of `rows`, played by `player`
## as `side` against `opponent`, ending as `winner` after `rounds`.
static func made(rows: Array[Dictionary], dice_seed: int, player: String, side: int, opponent: String,
		winner: int, rounds: int) -> Dictionary:
	return {"format": FORMAT, "version": VERSION, "player": player, "side": side, "opponent": opponent,
		"dice_seed": dice_seed, "decisions": rows, "end": {"winner": winner, "rounds": rounds}}


## Write `recording` to `folder`, named for the moment; its path, or "" when
## the file could not be written.
static func save(recording: Dictionary, folder: String) -> String:
	DirAccess.make_dir_recursive_absolute(folder)
	var name: String = "%s-%s" % [Time.get_datetime_string_from_system().replace(":", "-"), Time.get_ticks_msec()]
	var path: String = folder.path_join(name + ".json")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_string(JSON.stringify(recording) + "\n")
	return path


## The game played again: `{"before": the board before each decision, in
## order, "end": the board after the last, "refused": the index of the first
## decision the board refused, or -1}`. Turns are opened as the game opens
## them (`TurnStart`) whenever the next decision was made on a later turn.
static func replay(recording: Dictionary) -> Dictionary:
	var state: BoardState = TacticalScenario.build()
	state.dice_seed = int(recording["dice_seed"])
	var before: Array[BoardState] = []
	var rows: Array = recording["decisions"]
	for index: int in range(rows.size()):
		while state.turn_number < int(rows[index]["turn"]):
			state = TurnStart.open(state)[0]
		before.append(state)
		var after: BoardState = decision_of(rows[index]).played_on(state)
		if after == null:
			return {"before": before, "end": state, "refused": index}
		state = after
	return {"before": before, "end": state, "refused": -1}


## The person's decisions in `recording`, each with the board they made it
## on: `{"board": BoardState, "decision": row}`, oldest first.
static func rows_of(recording: Dictionary) -> Array[Dictionary]:
	var played: Dictionary = replay(recording)
	var rows: Array[Dictionary] = []
	var side: int = int(recording["side"])
	for index: int in range(played["before"].size()):
		var row: Dictionary = recording["decisions"][index]
		if int(row["side"]) == side:
			rows.append({"board": played["before"][index], "decision": row})
	return rows


## Why `parsed` is not a recording this reads, or "" when it is one.
static func why_not_a_recording(parsed: Variant) -> String:
	if not parsed is Dictionary:
		return "not a JSON object"
	for key: String in ["format", "version", "player", "side", "opponent", "dice_seed", "decisions", "end"]:
		if not parsed.has(key):
			return "no %s" % key
	if parsed["format"] != FORMAT or int(parsed["version"]) != VERSION:
		return "a %s version %s, not %s version %d" % [parsed["format"], parsed["version"], FORMAT, VERSION]
	return ""
