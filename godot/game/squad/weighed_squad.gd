## The first enemy of the XCOM-style mode that is an agent (T85): for the
## piece about to act, it weighs every option one action ahead, on what its
## side perceives, and takes the best.
##
## Perceive: its side's view (`SideView`) -- its own pieces, the enemies
## one of them sees, and where it last saw the others. Of the state it is
## handed it reads nothing else: `_look` is the one door, besides the turn's
## number (`begin_turn`) and its own piece's cell when asked to build. Weigh: every walk open to the piece on that view, holding
## included, then every shot it may take from where the walk left it. Act:
## the option that scored highest, the first listed of equal scores.
##
## Each option is scored by `ActionChoice` (`ai_utility`), with the
## considerations in `weighing.json`: one action, "walk there" or "shoot
## it", asked once per option with that option's own percepts -- for a
## walk, the expected damage of the best shot it leaves (none after a
## dash), the damage the enemies it sees could do to it there, cover and
## flanking counted in both, and how far it is from the nearest enemy it
## knows of; for a shot, its expected damage and whether it destroys. The
## answers are multiplied, so a shot at 0% is never taken.
##
## A walk the board refuses -- it ran into a piece its side does not see --
## is answered with the next best (`after_refusal`): every cell of the
## refused route is avoided, and the piece weighs again. Holding is never
## refused, so the asking ends.
##
## Every option it weighed, with its score and the best hit chance in it,
## is kept in `weighed` for the board to draw before the decision is
## played: what the enemy is about to do and why can be read off the
## board, which is invariant 13.
##
## It is the baseline the searches must beat (T87, T88), as `LeveledBlue` is
## in Advance Wars; `make test-squad-match` holds it above `RandomSquad`.
##
## O(walks x enemies seen) a decision, each with a line of sight. When not to
## use it: as a planner. One action ahead never sets up a flank over two
## turns, or holds a piece back for the next one; that is search's.
class_name WeighedSquad
extends BlueController

const WEIGHING_PATH: String = "res://game/squad/weighing.json"
## The steps a cell with no route to any enemy it knows of is counted at:
## past the far end of the curve, so such a cell never reads as close.
const NO_ROUTE: int = 40

var _walk: ActionChoice.Action
var _shot: ActionChoice.Action
# What its side saw at its last look, remembered from one decision to the
# next; forgotten when a new game starts.
var _memory: SideView
var _last_turn: int = -1
var _weighed: Array[Dictionary] = []
# Cells a refused walk of `_avoiding_for` ran over, to keep out of its next try.
var _avoided: Array[Vector2i] = []
var _avoiding_for: int = -1


func _init(_seed_number: int = 0) -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(WEIGHING_PATH))
	_walk = ActionChoice.actions_from([data["walk"]])[0]
	_shot = ActionChoice.actions_from([data["shot"]])[0]


## "weighed".
func controller_name() -> String:
	return "weighed"  # not shown: a roster key


## What it is, for the screen.
func describe() -> String:
	return TranslationServer.translate("every option of the piece weighed one action ahead, on its side's view")


## A turn numbered no later than the last one it saw is a new game: what it
## remembered seeing belongs to the old one.
func begin_turn(state: BoardState) -> void:
	if state.turn_number <= _last_turn:
		_memory = null
	_last_turn = state.turn_number
	_avoiding_for = -1
	_avoided.clear()


## A squad has no workshop: it never builds.
func decide_build(state: BoardState, workshop_id: int) -> TacticalDecision:
	return TacticalDecision.hold(workshop_id, [], state.unit_by_id(workshop_id).cell)


## The walk -- holding is one -- that scored highest for `unit_id`.
func decide_move(state: BoardState, unit_id: int) -> TacticalDecision:
	var seen: SideView = _look(state)
	var unit: Unit = seen.state.unit_by_id(unit_id)
	if unit_id != _avoiding_for:
		_avoided.clear()
	var walks: Dictionary = _walks_not_avoided(seen.state, unit)
	var nearest: Dictionary = _routes_to_the_known(seen, unit)
	var best_cell: Vector2i = unit.cell
	var best: Dictionary = {}
	_weighed.clear()
	for cell: Vector2i in walks:
		var percepts: Dictionary = _walk_percepts(seen, unit, cell, walks[cell], nearest)
		var score: float = _score(_walk, percepts)
		_weighed.append({"cell": cell, "score": score, "chance": percepts["chance"], "chosen": false})
		if best.is_empty() or score > best["score"]:
			best = percepts.merged({"score": score})
			best_cell = cell
	_mark_chosen(best_cell)
	var why: Array = _why_walk(best, walks.size())
	if best_cell == unit.cell:
		return TacticalDecision.hold(unit_id, why, unit.cell)
	return TacticalDecision.walk(unit_id, walks[best_cell], why, best_cell)


## The shot that scored highest for `unit_id` from where it stands, or
## null when no shot scores above nothing.
func decide_attack(state: BoardState, unit_id: int) -> TacticalDecision:
	var seen: SideView = _look(state)
	var shooter: Unit = seen.state.unit_by_id(unit_id)
	var best_target: Unit = null
	var best: Dictionary = {}
	_weighed.clear()
	for enemy: Unit in seen.state.units:
		if SquadCombat.why_refused(seen.state, SquadScenario.rows(), Attack.new(unit_id, enemy.id)) != BoardState.LEGAL:
			continue
		var percepts: Dictionary = _shot_percepts(shooter, enemy)
		var score: float = _score(_shot, percepts)
		_weighed.append({"cell": enemy.cell, "score": score, "chance": percepts["chance"], "chosen": false})
		if score > 0.0 and (best.is_empty() or score > best["score"]):
			best = percepts.merged({"score": score})
			best_target = enemy
	if best_target == null:
		_weighed.clear()
		return null
	_mark_chosen(best_target.cell)
	var damage: int = SquadTable.number(shooter.type.type_name, "damage")
	return TacticalDecision.strike(unit_id, best_target, Sentence.of(  # shown through tr()
		"shoots {piece} at {cell}: {chance}% for {damage}, the best of {count} shot(s), scored {score}", {
			piece = TacticalStatus.the_piece_sentence(best_target.type.type_name), cell = best_target.cell,
			chance = best["chance"], damage = damage, count = _weighed.size(), score = "%.2f" % best["score"]}))


## The next best walk for the piece whose walk was refused: the refused
## route's cells avoided from now on this decision, and the piece weighed
## again. Null for anything but a walk.
func after_refusal(state: BoardState, refused: TacticalDecision) -> TacticalDecision:
	if refused.move == null:
		return null
	_avoiding_for = refused.unit_id
	_avoided.append_array(refused.move.path)
	return decide_move(state, refused.unit_id)


## Every option it weighed for its last decision, as `BlueController` asks.
func weighed() -> Array[Dictionary]:
	return _weighed


# Its side's view of `state`, remembering its last look: the only thing it
# reads of the board.
func _look(state: BoardState) -> SideView:
	_memory = SideView.seen_by(state, SquadScenario.rows(), state.current_faction, _memory)
	return _memory


# What a walk of `unit` along `path` to `cell` perceives: the best shot it
# would leave, the danger there, the steps to the nearest enemy it knows of.
func _walk_percepts(seen: SideView, unit: Unit, cell: Vector2i, path: Array[Vector2i], nearest: Dictionary) -> Dictionary:
	var rows: Array[String] = SquadScenario.rows()
	var shot: Dictionary = {"expected damage": 0.0, "chance": -1}
	if SquadRuleset.leaves_a_shot(seen.state, unit, path):
		shot = _best_shot_from(rows, seen, unit, cell)
	return {"expected damage": shot["expected damage"], "chance": shot["chance"], "danger": _danger_at(rows, seen, unit, cell),
		"steps to the nearest enemy": nearest.get(cell, NO_ROUTE)}


# The damage the enemies `seen` holds could expect to do to `unit` on `cell`,
# each shooting once from where it stands: the cover the cell has against
# each, and its flank, are in the chance.
func _danger_at(rows: Array[String], seen: SideView, unit: Unit, cell: Vector2i) -> float:
	var danger: float = 0.0
	var defence: int = SquadTable.number(unit.type.type_name, "defence")
	for enemy: Unit in seen.state.units:
		if enemy.faction == seen.side or not SquadCombat.reaches(rows, enemy.cell, enemy.type, cell):
			continue
		var cover: int = SquadCover.of(rows, enemy.cell, cell)["cover"]
		var chance: int = SquadCombat.hit_chance(SquadTable.number(enemy.type.type_name, "aim"), defence, cover)
		danger += chance / 100.0 * SquadTable.number(enemy.type.type_name, "damage")
	return danger


# The best shot `unit` would have from `cell` at an enemy it sees: its
# expected damage and its chance, or none.
func _best_shot_from(rows: Array[String], seen: SideView, unit: Unit, cell: Vector2i) -> Dictionary:
	var best: Dictionary = {"expected damage": 0.0, "chance": -1}
	for enemy: Unit in seen.state.units:
		if enemy.faction == seen.side or not SquadCombat.reaches(rows, cell, unit.type, enemy.cell):
			continue
		var cover: int = SquadCover.of(rows, cell, enemy.cell)["cover"]
		var chance: int = SquadCombat.hit_chance(SquadTable.number(unit.type.type_name, "aim"),
			SquadTable.number(enemy.type.type_name, "defence"), cover)
		var expected: float = chance / 100.0 * mini(SquadTable.number(unit.type.type_name, "damage"), enemy.health)
		if expected > best["expected damage"]:
			best = {"expected damage": expected, "chance": chance}
	return best


# What a shot of `shooter` at `enemy` perceives: its chance, its expected
# damage, and whether a hit destroys.
func _shot_percepts(shooter: Unit, enemy: Unit) -> Dictionary:
	var damage: int = SquadTable.number(shooter.type.type_name, "damage")
	var chance: int = SquadCombat.chance_of(SquadScenario.rows(), shooter, enemy)
	return {"chance": chance, "expected damage": chance / 100.0 * mini(damage, enemy.health),
		"destroys it": 1.0 if damage >= enemy.health else 0.0}


# Cell -> the cost of the cheapest route, on `unit`'s own ground, to the
# nearest enemy its side knows of: the ones it sees, the ones it remembers,
# or -- knowing of none -- the cells the other squad starts on, which the
# map tells everybody.
func _routes_to_the_known(seen: SideView, unit: Unit) -> Dictionary:
	var known: Array[Vector2i] = []
	for enemy_id: int in seen.seen_enemies():
		known.append(seen.state.unit_by_id(enemy_id).cell)
	known.append_array(seen.last_seen.values())
	if known.is_empty():
		for cell: Vector2i in SquadScenario.RED_CELLS:
			known.append(cell if seen.side == TacticalScenario.BLUE else SquadScenario.TURNED - cell)
	var nearest: Dictionary = {}
	for goal: Vector2i in known:
		var costs: Dictionary = TacticalReach.route_costs(seen.state.graph_for(unit), goal)
		for cell: Vector2i in costs:
			nearest[cell] = mini(nearest.get(cell, costs[cell]), costs[cell])
	return nearest


# Holding, and every walk of `unit` on `seen` that crosses no avoided cell.
func _walks_not_avoided(seen: BoardState, unit: Unit) -> Dictionary:
	var walks: Dictionary = {unit.cell: [] as Array[Vector2i]}
	var open: Dictionary = TacticalReach.walks_for(seen, unit)
	for cell: Vector2i in open:
		if not (open[cell] as Array).any(func(step: Vector2i) -> bool: return step in _avoided):
			walks[cell] = open[cell]
	return walks


func _score(action: ActionChoice.Action, percepts: Dictionary) -> float:
	return ActionChoice.choose([action] as Array[ActionChoice.Action], percepts).scores[0]


func _mark_chosen(cell: Vector2i) -> void:
	for option: Dictionary in _weighed:
		option["chosen"] = option["cell"] == cell


# Why the walk it took won, in the numbers it was weighed on.
func _why_walk(best: Dictionary, count: int) -> Array:
	var shot: Array = Sentence.of("no shot from there")  # shown through tr()
	if int(best["chance"]) >= 0:
		shot = Sentence.of("a {chance}% shot from there", {chance = best["chance"]})  # shown through tr()
	return Sentence.of("weighed {count} cell(s) and took the best, scored {score}: {shot}, {danger} damage it may take there, {steps} to the nearest enemy it knows of", {  # shown through tr()
		count = count, score = "%.2f" % best["score"], shot = shot, danger = "%.1f" % best["danger"],
		steps = best["steps to the nearest enemy"]})
