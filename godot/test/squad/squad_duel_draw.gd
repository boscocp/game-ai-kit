# How `spec/squad/duel.json`'s 30 positions were drawn (T88), kept so they
# can be drawn again. Not a gate: it writes the file, and a person reads it
# before it is committed.
#
# Seeded matches of the first enemy against itself (`WeighedSquad`, dice
# seeds 1 to `MATCHES`); every question asked of a piece with more than one
# answer is a candidate, on the board its side believes in -- the same
# guess both searches make (`SearchingSquad.believe`). Each candidate is
# tagged by what it holds:
#
# - **a flank**: a shot at a target whose cover faces another way;
# - **a long shot**: a shot at 25% or less, or from 6 steps or more;
# - **a retreat to cover**: a hurt piece some enemy could shoot in the open,
#   with a walk to a cell where no enemy could.
#
# The first position is the opening. Then `EACH_TAG` of each tag, the
# first found, and the rest spread evenly through the candidates left, to
# 30. Then each position's expected values, as the squad's gate checks
# them: expectiminimax with the hand-written evaluation, to `DEPTH` plies --
# a walk and the shot after it, or a shot and the next piece's walk: about
# four seconds for all thirty here, and a few in Python.
#
#     ./scripts/godot --headless --path godot -s res://test/squad/squad_duel_draw.gd -- /absolute/path/to/spec/squad/duel.json
#
# Exit codes: 0 written; 2 no path given, or the file could not be written.
extends SceneTree

const MATCHES: int = 6
const POSITIONS: int = 30
const EACH_TAG: int = 4
const DEPTH: int = 2
const TAGS: Array[String] = ["flank", "long shot", "retreat to cover"]


func _init() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var file: FileAccess = FileAccess.open(arguments[0], FileAccess.WRITE) if not arguments.is_empty() else null
	if file == null:
		printerr("squad_duel_draw: give me the path of the file to write after `--`")
		quit(2)
		return
	var candidates: Array[Dictionary] = []
	for match_seed: int in range(1, MATCHES + 1):
		var red := Recorder.new(match_seed, candidates)
		var blue := Recorder.new(match_seed, candidates)
		SquadMatch.play(red, blue, match_seed)
	var chosen: Array[Dictionary] = _chosen(candidates)
	for position: Dictionary in chosen:
		position["expected"] = expected(position)
		position.erase("tags")
	# Every digit of a value kept: the tests compare to 1e-9.
	file.store_string(JSON.stringify({"about": ABOUT, "map": SquadScenario.rows(), "positions": chosen}, " ", false, true) + "\n")
	file.close()
	quit(0)


## The root's expected values, as the file keeps them: `{"depth", "values":
## [[answer, value], ...], "decision"}`.
static func expected(position: Dictionary) -> Dictionary:
	var root: SquadSearchGame.Position = SquadDuel.root(position)
	var found: AdversarialResult = ExpectiminimaxSearch.new(SquadEvaluatedGame.new(), root).search_to(DEPTH)
	var values: Array = found.considered.map(func(entry: Dictionary) -> Array:
		return [SquadSearchGame.described(entry["action"]), entry["value"]])
	return {"depth": found.depth, "values": values, "decision": SquadSearchGame.described(found.action)}


# The opening, then `EACH_TAG` of each tag, then the rest spread out.
static func _chosen(candidates: Array[Dictionary]) -> Array[Dictionary]:
	var chosen: Array[Dictionary] = [candidates[0]]
	candidates[0]["about"] = "the opening"
	for tag: String in TAGS:
		var tagged: Array = candidates.filter(func(candidate: Dictionary) -> bool:
			return tag in candidate["tags"] and not candidate in chosen)
		for candidate: Dictionary in tagged.slice(0, EACH_TAG):
			candidate["about"] = tag
			chosen.append(candidate)
	var left: Array = candidates.filter(func(candidate: Dictionary) -> bool: return not candidate in chosen)
	var wanted: int = POSITIONS - chosen.size()
	for index: int in range(wanted):
		var candidate: Dictionary = left[index * left.size() / wanted]
		candidate["about"] = "drawn from the rest"
		chosen.append(candidate)
	for index: int in range(chosen.size()):
		chosen[index]["name"] = "%02d %s" % [index + 1, chosen[index]["about"]]
	return chosen


const ABOUT: Array[String] = [
	"T88's duel: 30 positions of the XCOM-style mode, searched by Monte Carlo tree search (T87) and by expectiminimax (T88) at the same wall-clock budget, 50, 200 and 1,000 ms a decision. `make measure-squad-duel` prints what each chose; `make test-squad-duel` holds them on counted budgets.",
	"Drawn by `godot/test/squad/squad_duel_draw.gd` from seeded matches of the first enemy against itself, on the board the side to move believes in: the opening, four flanks, four long shots, four retreats to cover, and the rest spread through the candidates left. `drawn_from` says which match and turn.",
	"A position has the shape of `positions.json`'s: every piece `[id, side, kind, column, row, health, movement left]`, side 0 red and 1 blue, in the board's order; the turn; the piece about to act; whether it is to `walk` or to `shoot`; the pieces of its side still to act after it.",
	"`expected` is expectiminimax's root with the hand-written evaluation (`rules.json`'s `evaluation`): every answer, in the game's order, with its expected value, at `depth` plies, and the answer worth most. Written from one run and held equal in both languages: `godot/test/squad/expecti_squad_test.gd` and `python/tests/test_squad_duel.py`.",
]


## A first enemy that writes down every question it is asked with more than
## one answer, on the board its side believes in, before answering it.
class Recorder extends WeighedSquad:
	var _match_seed: int
	var _candidates: Array[Dictionary]
	var _believer := MctsSquad.new()

	func _init(match_seed: int, candidates: Array[Dictionary]) -> void:
		super(match_seed)
		_match_seed = match_seed
		_candidates = candidates

	## Its believer looks at the turn too, so its memory runs with the game's.
	func begin_turn(state: BoardState) -> void:
		_believer.begin_turn(state)
		super(state)

	## The walk question written down, then answered as the first enemy would.
	func decide_move(state: BoardState, unit_id: int) -> TacticalDecision:
		_record(state, unit_id, SquadSearchGame.WALK)
		return super(state, unit_id)

	## The shot question written down, then answered as the first enemy would.
	func decide_attack(state: BoardState, unit_id: int) -> TacticalDecision:
		_record(state, unit_id, SquadSearchGame.SHOOT)
		return super(state, unit_id)

	func _record(state: BoardState, unit_id: int, phase: int) -> void:
		var believed: BoardState = _believer.believe(state)
		if SquadSearchGame.answers(believed, unit_id, phase).size() <= 1:
			return
		var written: Dictionary = SquadDuel.written(believed, unit_id, phase)
		# Matches on other dice play alike until the first shot: one copy.
		if _candidates.any(func(seen: Dictionary) -> bool: return seen["pieces"] == written["pieces"] and seen["acting"] == unit_id):
			return
		written["drawn_from"] = {"match": _match_seed, "turn": state.turn_number}
		written["tags"] = SquadDuel.tags(believed, unit_id, phase)
		_candidates.append(written)
