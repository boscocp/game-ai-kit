## One team in the league written with one of T15's ways of deciding: the
## state machine, the behaviour tree, GOAP and the HTN each play the tactical
## board as a `BlueController`, the way `GuardBrain` lets them play T15's
## guard.
##
## A team answers one question per walker, `decide`: which of five deeds to do
## this turn, given the facts (`TeamFacts`). Everything else is shared, so the
## four differ only where the lesson is -- how a deed is chosen:
##
## - **siege**: the rules' walk at their workshop (`RuleBasedBlue`), with the
##   rules' way round a queue and their never-idle fallback;
## - **hunt**: walk to where it can strike the piece it beats, and strike it;
## - **defend**: walk at the enemy walker nearest its own workshop;
## - **take point**: walk to a control point, or keep standing on one;
## - **fall back**: walk where nothing that beats it can strike, nearest home.
##
## **What it delegates, and says so.** The workshop builds by the rules, and
## whom a walker strikes once it has walked is the rules' attack -- what is in
## reach and beaten by the counter table. The techniques decide where every
## walker goes and why, which is where they differ; production is one rule
## for all four, so a difference in the league is a difference in the walking.
##
## When not to use it: a team that decides production for itself. Then the
## four are not comparable, which is the only reason to write them alike.
@abstract
class_name TechniqueTeam
extends RuleBasedBlue

const SIEGE: String = "siege"
const HUNT: String = "hunt"
const DEFEND: String = "defend"
const TAKE_POINT: String = "take point"
const FALL_BACK: String = "fall back"

## Walker id -> the deed it was given last, for the screen.
var deeds: Dictionary[int, String] = {}
## Deed -> how many times it was chosen since the team was made: how the
## league says what each technique spent its walkers on.
var deed_counts: Dictionary[String, int] = {}

# Enemy id -> the cells it could strike next turn; read once a turn.
var _strikes: Dictionary = {}
var _turn_begun: int = -1
# How much deciding the technique has done since it was made, in
# `work_unit()`: what `work_done` reports.
var _work: int = 0


## The technique's name, as the league table and the screen give it.
@abstract func controller_name() -> String


## The deed for `unit` this turn, given what it knows.
@abstract func decide(unit: Unit, known: TeamFacts) -> String


## What it is thinking with for `unit_id` -- its state, the tree's trail, the
## plan -- as one line for the reason and the screen.
@abstract func thinking(unit_id: int) -> String


## A new turn: the rules' claims forgotten, and where each enemy piece could
## strike read once.
func begin_turn(state: BoardState) -> void:
	super.begin_turn(state)
	_turn_begun = state.turn_number
	_strikes = TeamFacts.enemy_strikes(state)


## How much deciding it has done since it was made, counted in `work_unit`.
func work_done() -> int:
	return _work


## The walker's deed, carried out, with the technique's reason in front of
## the board's.
func decide_move(state: BoardState, unit_id: int) -> TacticalDecision:
	if state.turn_number != _turn_begun:
		begin_turn(state)
	var unit: Unit = state.unit_by_id(unit_id)
	var reached: bool = _nearest_workshop(state, unit) != null
	var known: TeamFacts = TeamFacts.of(state, unit, _strikes, _claims, reached)
	var deed: String = decide(unit, known)
	deeds[unit_id] = deed
	deed_counts[deed] = deed_counts.get(deed, 0) + 1
	var done: TacticalDecision = _carry_out(state, unit, known, deed)
	done.reason = "%s -- %s: %s" % [deed, thinking(unit_id), done.reason]
	return done


# The deed as a decision on the board.
func _carry_out(state: BoardState, unit: Unit, known: TeamFacts, deed: String) -> TacticalDecision:
	# A deed whose piece or point is gone -- a plan's step outliving its
	# fact -- is the rules' walk, not a crash.
	if deed == HUNT and known.prey != null:
		return _hunt(unit, known)
	if deed == DEFEND:
		return _walk_at_piece(state, unit, known, known.intruder, "the enemy walker nearest its workshop")
	if deed == TAKE_POINT and known.facts["point_free"]:
		return _take_point(state, unit, known)
	if deed == FALL_BACK:
		return _fall_back(state, unit, known)
	return super.decide_move(state, unit.id)


func _hunt(unit: Unit, known: TeamFacts) -> TacticalDecision:
	var aim: String = "the %s at %s, which a %s beats" % [known.prey.type.type_name, known.prey.cell, unit.type.type_name]
	if known.prey_from == unit.cell:
		return TacticalDecision.hold(unit.id, "stays in reach of %s, to strike it" % aim, unit.cell)
	return TacticalDecision.walk(unit.id, known.walks[known.prey_from], "walks to %s, in reach of %s" % [known.prey_from, aim], known.prey_from)


# A walk towards `piece` by the rules' route; a hold when it is in reach or no
# walk gets nearer -- or the rules' walk, when there is no such piece.
func _walk_at_piece(state: BoardState, unit: Unit, known: TeamFacts, piece: Unit, what: String) -> TacticalDecision:
	if piece == null:
		return super.decide_move(state, unit.id)
	var aim: String = "%s, the %s at %s" % [what, piece.type.type_name, piece.cell]
	if TacticalCombat.distance(unit.cell, piece.cell) <= unit.type.attack_range:
		return TacticalDecision.hold(unit.id, "stays in reach of %s" % aim, unit.cell)
	var best: Vector2i = _nearest_walk_to(state, unit, known.walks, piece.cell)
	if best == unit.cell:
		return TacticalDecision.hold(unit.id, "stays: no walk this turn brings it nearer %s" % aim, unit.cell)
	return TacticalDecision.walk(unit.id, known.walks[best], "walks to %s, towards %s" % [best, aim], best)


func _take_point(state: BoardState, unit: Unit, known: TeamFacts) -> TacticalDecision:
	if unit.cell == known.point:
		_claims[known.point] = 1
		return TacticalDecision.hold(unit.id, "stays on the point at %s, which pays while it holds it" % known.point, unit.cell)
	var best: Vector2i = _nearest_walk_to(state, unit, known.walks, known.point)
	if best == unit.cell:
		return TacticalDecision.hold(unit.id, "stays: no walk this turn brings it nearer the point at %s" % known.point, unit.cell)
	_claims[known.point] = 1
	return TacticalDecision.walk(unit.id, known.walks[best], "walks to %s, towards the point at %s" % [best, known.point], best)


# The cell it can reach that the fewest pieces beating it could strike, ties
# to the one nearest its own workshop.
func _fall_back(state: BoardState, unit: Unit, known: TeamFacts) -> TacticalDecision:
	var home: Unit = TeamFacts.own_workshop(state, unit.faction)
	var anchor: Vector2i = home.cell if home != null else unit.cell
	var best: Vector2i = unit.cell
	for cell: Vector2i in known.walks:
		var fewer: int = _strikers(state, unit, cell) - _strikers(state, unit, best)
		var nearer: bool = TacticalCombat.distance(cell, anchor) < TacticalCombat.distance(best, anchor)
		if fewer < 0 or (fewer == 0 and nearer):
			best = cell
	var count: int = _strikers(state, unit, best)
	if best == unit.cell:
		return TacticalDecision.hold(unit.id, "stays: no walk this turn leaves fewer of what beats it in reach (%d)" % count, unit.cell)
	return TacticalDecision.walk(unit.id, known.walks[best], "walks back to %s, where %d of what beats it could strike" % [best, count], best)


# How many living enemy pieces that beat `unit` could strike `cell` next turn.
func _strikers(state: BoardState, unit: Unit, cell: Vector2i) -> int:
	var count: int = 0
	for enemy_id: int in _strikes:
		var enemy: Unit = state.unit_by_id(enemy_id)
		if enemy != null and unit.type.type_name in enemy.type.strong_against and _strikes[enemy_id].has(cell):
			count += 1
	return count
