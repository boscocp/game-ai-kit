## A side played at a difficulty level: the same board, the same pieces, the
## same money and the same orders as the person across it -- only how much it
## is allowed to think changes (`Difficulty`, T12).
##
## - **The workshop** buys by the plan (`PlannedBlue`), looking
##   `plan_horizon` actions ahead -- and at 0, with no plan, by the rules.
##   Every preset is at 0, because on this board a plan is a handicap:
##   measured over 100 games at 2 plies, no plan beat T11's plan (save for
##   the forge, then a ram) 77 to 23, and a horizon of 2 or of 4 lost by the
##   same 77 to 23 (T12's record).
## - **Each walker** weighs three kinds of cell -- where the rules would walk
##   it, where it stands, and every cell it could attack a piece from -- with
##   every attack it could make there, and takes the one worth most. The
##   rules' walk is the default: the way round a queue, one walker per goal
##   and never idle are theirs (T45), and the search decides which fights to
##   take and when to stay out of reach. Worth is counted in pieces -- a piece
##   is worth its price, for the health it has left:
##   * ply 1, its own move: the fight's odds (`FightOdds`, from the rules and
##     the die, never the board's next roll), what it wins and what it risks;
##     how far short of the rules' walk the cell stops; a control point under
##     it. An enemy piece near its own workshop is worth more, which is how
##     it defends.
##   * ply 2, the answer: what the other side's best attack on it there would
##     win, and what the towers in reach would take -- subtracted.
##   `search_depth` is how many of these it weighs.
## - **Noise.** Every option's worth is blurred by up to `evaluation_noise`
##   times `NOISE_SCALE`, drawn from the seed this controller was given --
##   its own, never the board's.
##
## It reads the board as the person sees it and returns decisions the board
## judges as it judges the person's clicks (`BlueTurn`); `difficulty_knobs.gd`
## holds it to that.
##
## Complexity: per walker, the rules' walk, one flood for its walks and one
## back from the rules' cell, then the fights from each cell it weighs; at
## ply 2, one flood per enemy walker each turn for where it can strike.
##
## When not to use it: as a strong player. It weighs one walker at a time and
## never two turns ahead; a person who sees a trap two moves deep beats every
## level here.
class_name LeveledBlue
extends PlannedBlue

## Destroying their workshop: the game.
const WIN: float = 100.0
## A point of health off a building, in pieces: a siege is long, so each blow
## counts, and the workshop's is the one that wins.
const WORKSHOP_HEALTH_WORTH: float = 0.4
const TOWER_HEALTH_WORTH: float = 0.1
## A cell of route short of where the rules would walk it.
const STEP_WORTH: float = 0.15
## Standing on a control point.
const POINT_WORTH: float = 1.0
## How near its own workshop an enemy piece must be to be worth
## `GUARD_TIMES` its price: the defence, said as a price.
const GUARD_RADIUS: int = 4
const GUARD_TIMES: float = 3.0
## What a noise of 1.0 blurs an option by, at most, either way: a shield's
## worth, in the pieces every other number here is counted in.
const NOISE_SCALE: float = 2.0
## How little its own losses count against what it wins: they are weighed at
## `1 - AGGRESSION`. Wesnoth's default, 0.4 (`attack_analysis::rating`,
## `docs/design/tactical-references.md` 2.1) -- without it, ply 2 counted
## every answer in full and a side that could see the answer never walked
## into reach of anything: measured, it stayed home, and lost on score.
const AGGRESSION: float = 0.4

# What `_strike` holds for a walker whose search weighed attacking and chose
# not to: a deliberate "nobody", which the attack question must not overrule.
const CHOSE_NOT_TO: int = -2

## The level it plays at.
var level: Difficulty

var _blur := RandomNumberGenerator.new()
# Walker id -> the enemy piece it walked to attack, asked after the walk; or
# `CHOSE_NOT_TO`, which is a decision too, and not a question left open.
var _strike: Dictionary[int, int] = {}
# Enemy walker id -> the cells it could strike next turn (ply 2).
var _reach_of_theirs: Dictionary[int, Dictionary] = {}
# The turn `begin_turn` last opened, so a question asked outside a turn
# opens one first.
var _turn_begun: int = -1


## A side at `chosen`, its noise drawn from `seed_number`.
func _init(chosen: Difficulty, seed_number: int) -> void:
	level = chosen
	horizon = chosen.plan_horizon
	_blur.seed = seed_number


## The level's name: the header says "hard", not "planner".
func controller_name() -> String:
	return level.name


## The level's three knobs, for the screen, in its language: the addon's
## `Difficulty.describe()` is English, and `DifficultyWords` translates it.
func describe() -> String:
	return DifficultyWords.said(level)


## A new turn: plan as the level allows, forget last turn's strikes, and at
## ply 2 work out where each red walker could strike next turn.
func begin_turn(state: BoardState) -> void:
	super.begin_turn(state)
	_turn_begun = state.turn_number
	_strike.clear()
	_reach_of_theirs.clear()
	if level.search_depth < 2:
		return
	for enemy: Unit in _enemies(state):
		if enemy.type.mobile:
			_reach_of_theirs[enemy.id] = _strike_cells(state, enemy)


## The cell, and the attack from it, worth most to this walker -- see the
## header for how it is counted.
func decide_move(state: BoardState, unit_id: int) -> TacticalDecision:
	if state.turn_number != _turn_begun:
		begin_turn(state)
	var unit: Unit = state.unit_by_id(unit_id)
	var best: Array = _best_option(state, unit)
	var cell: Vector2i = best[0]
	var target: Unit = best[1]
	_strike[unit_id] = target.id if target != null else CHOSE_NOT_TO
	var why: Array = Sentence.of("{deed} (worth {worth}, {depth} ply)", {  # shown through tr()
		deed = _said(unit, cell, target), worth = "%.2f" % best[2], depth = level.search_depth})
	if cell == unit.cell:
		return TacticalDecision.hold(unit_id, why, cell)
	return TacticalDecision.walk(unit_id, TacticalReach.walks_for(state, unit)[cell], why, cell)


## The attack this walker walked to make, if it can still make it; none, when
## its search chose none; otherwise -- the target gone, or never asked where
## to walk -- the best it can make from where it stands, if any is worth
## making by ply 1.
func decide_attack(state: BoardState, unit_id: int) -> TacticalDecision:
	var unit: Unit = state.unit_by_id(unit_id)
	var chosen: int = _strike.get(unit_id, -1)
	_strike.erase(unit_id)
	if chosen == CHOSE_NOT_TO:
		return null
	var planned: Unit = state.unit_by_id(chosen)
	if planned != null and TacticalCombat.why_refused(state, Attack.new(unit_id, planned.id)) == BoardState.LEGAL:
		return TacticalDecision.strike(unit_id, planned, Sentence.of("attacks {target} at {cell}, as it walked here to", {  # shown through tr()
			target = TacticalStatus.the_piece_sentence(planned.type.type_name), cell = planned.cell}))
	var best: Unit = null
	var best_worth: float = 0.0
	for enemy: Unit in _enemies(state):
		if TacticalCombat.why_refused(state, Attack.new(unit_id, enemy.id)) != BoardState.LEGAL:
			continue
		var worth: float = _attack_worth(state, unit, enemy, FightOdds.of_attack(state, unit, enemy))
		if worth > best_worth:
			best = enemy
			best_worth = worth
	if best == null:
		return null
	return TacticalDecision.strike(unit_id, best, Sentence.of("attacks {target} at {cell}: worth {worth} where it stands", {  # shown through tr()
		target = TacticalStatus.the_piece_sentence(best.type.type_name), cell = best.cell, worth = "%.2f" % best_worth}))


# [cell, target or null, worth] of the best option, ties to the first found.
func _best_option(state: BoardState, unit: Unit) -> Array:
	var claimed_before: Dictionary[Vector2i, int] = _claims.duplicate()
	var by_the_rules: Vector2i = _where_the_rules_walk(state, unit)
	var cells: Array[Vector2i] = _cells_worth_weighing(state, unit, by_the_rules)
	var to_goal: Dictionary = TacticalReach.route_costs(state.graph_for_type(unit.type), by_the_rules)
	var there: BoardState = state.duplicate_state()
	var moved: Unit = there.unit_by_id(unit.id)
	var best: Array = [unit.cell, null, -INF]
	for cell: Vector2i in cells:
		moved.cell = cell
		var here: Array = _best_from_here(there, moved, _standing_worth(cell, to_goal))
		if here[1] > best[2]:
			best = [cell, state.unit_by_id(here[0].id) if here[0] != null else null, here[1]]
	if best[0] != by_the_rules:
		_claims = claimed_before
	return best


# [target or null, worth] of the best attack -- or none -- for `moved` where
# it stands on `there`, each option blurred by the level's noise.
func _best_from_here(there: BoardState, moved: Unit, standing: float) -> Array:
	var best: Array = [null, -INF]
	for target: Unit in _targets_from(there, moved):
		var worth: float = standing + _option_worth(there, moved, target) + _noise()
		if worth > best[1]:
			best = [target, worth]
	return best


# Where the rules would walk this walker this turn -- its own cell when they
# would hold it. That walk is the default the search measures every other
# option against: the way round a queue, the one walker per goal and the
# never idle of T45 are the rules', and the search adds which fights to take
# and, at ply 2, when to stay out of reach.
#
# Asking the rules takes a goal for this walker (T45's one walker per goal);
# `_best_option` gives it back when the walker goes elsewhere.
func _where_the_rules_walk(state: BoardState, unit: Unit) -> Vector2i:
	var by_the_rules: TacticalDecision = super.decide_move(state, unit.id)
	if by_the_rules.move == null or by_the_rules.move.path.is_empty():
		return unit.cell
	return by_the_rules.move.path[-1]


# Where this walker might end its walk: where it stands, where the rules
# would walk it, and every cell it could attack an enemy piece from.
func _cells_worth_weighing(state: BoardState, unit: Unit, by_the_rules: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = [by_the_rules]
	if unit.cell not in cells:
		cells.append(unit.cell)
	var walks: Dictionary = TacticalReach.walks_for(state, unit)
	for cell: Vector2i in walks:
		if cell not in cells and _in_reach_of_an_enemy(state, unit, cell):
			cells.append(cell)
	return cells


func _in_reach_of_an_enemy(state: BoardState, unit: Unit, cell: Vector2i) -> bool:
	for enemy: Unit in _enemies(state):
		if TacticalCombat.distance(cell, enemy.cell) <= unit.type.attack_range:
			return true
	return false


# Every enemy piece `moved` could attack from where it stands on `there`, and
# null for attacking nobody.
func _targets_from(there: BoardState, moved: Unit) -> Array[Unit]:
	var targets: Array[Unit] = [null]
	for enemy: Unit in _enemies(there):
		if TacticalCombat.distance(moved.cell, enemy.cell) <= moved.type.attack_range and moved.type.attack_range > 0:
			targets.append(enemy)
	return targets


# Ply 1's fight, and at ply 2 the answer to it, for `moved` on `there`.
func _option_worth(there: BoardState, moved: Unit, target: Unit) -> float:
	var worth: float = 0.0
	var health_after: float = moved.health
	if target != null:
		var odds: Array[float] = FightOdds.of_attack(there, moved, target)
		worth += _attack_worth(there, moved, target, odds)
		health_after = odds[1]
	if level.search_depth >= 2 and health_after > 0.0:
		worth -= _their_answer(there, moved, target, health_after) * (1.0 - AGGRESSION)
	return worth


# What the cell is worth before any fight: how far short of the rules' walk
# it stops, and a control point under it.
func _standing_worth(cell: Vector2i, to_goal: Dictionary) -> float:
	var worth: float = 0.0
	if to_goal.has(cell):
		worth -= STEP_WORTH * to_goal[cell]
	if cell in TacticalScenario.POINTS:
		worth += POINT_WORTH
	return worth


## What an attack is worth, in pieces, from its odds [win, attacker left,
## defender left]: for a fight between walkers, the piece it takes against
## the piece it risks; for a building, the health it takes off it -- and the
## game, for a workshop that falls -- less the health it loses.
func _attack_worth(state: BoardState, unit: Unit, target: Unit, odds: Array[float]) -> float:
	var lost: float = (unit.health - odds[1]) / 10.0 * unit.type.cost * (1.0 - AGGRESSION)
	if target.type.type_name == TacticalRules.WORKSHOP:
		return odds[0] * WIN + (target.health - odds[2]) * WORKSHOP_HEALTH_WORTH - lost
	if not target.type.mobile:
		return (target.health - odds[2]) * TOWER_HEALTH_WORTH - lost
	return odds[0] * _worth(state, target) - (1.0 - odds[0]) * _worth(state, unit) * (1.0 - AGGRESSION)


# Ply 2: the most the other side's best single answer would win against
# `moved` -- left with `health_after` -- standing where it is, plus what
# their towers in reach take. The piece it attacks is not counted: a fight
# between walkers kills somebody, and if it is not that piece it is this one;
# a tower it attacks is not counted either, which is generous -- a siege
# leaves a tower standing, and it fires next turn.
func _their_answer(there: BoardState, moved: Unit, target: Unit, health_after: float) -> float:
	var worst: float = 0.0
	var risked: float = health_after / 10.0 * moved.type.cost
	for enemy: Unit in _enemies(there):
		if target != null and enemy.id == target.id:
			continue
		if enemy.type.mobile and _reach_of_theirs.get(enemy.id, {}).has(moved.cell):
			worst = maxf(worst, _answer_worth(there, enemy, moved, health_after, risked))
		elif not enemy.type.mobile and enemy.type.attack_range > 0 and TacticalCombat.distance(enemy.cell, moved.cell) <= enemy.type.attack_range:
			worst += _tower_shot(there, enemy, moved, health_after)
	return worst


# What `enemy` attacking `moved` -- with `health_after` left -- would win for
# the other side: the piece it takes against the piece it risks. Simplified,
# and on purpose: the enemy is taken to strike from its full reach, with the
# numbers near the fight as they stand now, not as they will after its walk.
func _answer_worth(there: BoardState, enemy: Unit, moved: Unit, health_after: float, risked: float) -> float:
	var inputs: Dictionary = TacticalCombat.inputs(there, enemy, moved)
	inputs["defender_health"] = maxi(roundi(health_after), 1)
	inputs["defender_hits_back"] = moved.type.attack_range >= enemy.type.attack_range
	var odds: Array[float] = FightOdds.of(inputs, false)
	return odds[0] * risked - (1.0 - odds[0]) * enemy.health / 10.0 * enemy.type.cost


# What a tower's one shot at `moved` would take, in pieces.
func _tower_shot(there: BoardState, tower: Unit, moved: Unit, health_after: float) -> float:
	var inputs: Dictionary = TacticalCombat.inputs(there, tower, moved)
	inputs["defender_health"] = maxi(roundi(health_after), 1)
	var odds: Array[float] = FightOdds.of(inputs, true)
	return (health_after - odds[2]) / 10.0 * moved.type.cost


# What a piece is worth: its price, for the health it has -- `GUARD_TIMES`
# that for an enemy piece near this side's workshop.
func _worth(state: BoardState, unit: Unit) -> float:
	var worth: float = unit.health / 10.0 * unit.type.cost
	if unit.faction != state.current_faction and _near_our_workshop(state, unit):
		worth *= GUARD_TIMES
	return worth


func _near_our_workshop(state: BoardState, unit: Unit) -> bool:
	for ours: Unit in state.units_of(state.current_faction):
		if ours.type.type_name == TacticalRules.WORKSHOP and TacticalCombat.distance(ours.cell, unit.cell) <= GUARD_RADIUS:
			return true
	return false


# Every cell enemy walker `enemy` could attack next turn: within its reach of
# a cell it could walk to, counting terrain and not pieces -- a piece in the
# way may have moved by then.
func _strike_cells(state: BoardState, enemy: Unit) -> Dictionary:
	var costs: Dictionary = TacticalReach.route_costs(state.graph_for(enemy), enemy.cell)
	var cells: Dictionary = {}
	for stand: Vector2i in costs:
		if costs[stand] > enemy.type.movement:
			continue
		for cell: Vector2i in _within(stand, enemy.type.attack_range):
			cells[cell] = true
	return cells


# Every cell no further than `reach` from `centre`, as an attack measures it.
static func _within(centre: Vector2i, reach: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for across: int in range(-reach, reach + 1):
		var down: int = reach - absi(across)
		for along: int in range(-down, down + 1):
			cells.append(centre + Vector2i(across, along))
	return cells


func _noise() -> float:
	return _blur.randf_range(-1.0, 1.0) * level.evaluation_noise * NOISE_SCALE


# What the option is, as a sentence.
func _said(unit: Unit, cell: Vector2i, target: Unit) -> Array:
	var stays: bool = cell == unit.cell
	if target == null:
		return Sentence.of("stays at {walk}" if stays else "walks to {walk}", {walk = cell})  # shown through tr()
	var deed: String = "stays at {walk} to attack {target} at {cell}" if stays else "walks to {walk} to attack {target} at {cell}"  # shown through tr()
	return Sentence.of(deed, {walk = cell, target = TacticalStatus.the_piece_sentence(target.type.type_name), cell = target.cell})
