## What a walker knows when it decides, as yes-or-no facts: the same facts for
## the four teams written from T15's techniques (`MachineTeam`, `TreeTeam`,
## `GoapTeam`, `HtnTeam`), so that side by side they differ only in how a
## deed is chosen -- T15's guard, brought to the tactical board.
##
## Every fact is read off the board as the side to move sees it -- where the
## pieces stand, what the counter table says, how far a walk goes -- and
## nothing it could not see. Ten facts:
##
## - `home_threatened`: an enemy walker within `HOME_RADIUS` of its own
##   workshop, and this walker near enough home to answer it;
## - `home_clear`: no enemy walker within `HOME_RADIUS + CALM_MARGIN` -- the
##   state machine's way back, wider than its way in, so it does not flicker
##   (T14's gap);
## - `at_their_workshop`: their workshop is in reach to attack now;
## - `way_to_their_workshop`: some route round their pieces reaches it;
## - `prey_in_reach`: a piece it beats by the counter table that some walk
##   this turn brings into reach to attack;
## - `in_danger` and `wounded`: a piece that beats it can strike where it
##   stands next turn, and it has `WOUNDED_AT` health or less;
## - `prey_is_intruder`: the prey is that same enemy walker nearest home --
##   striking it answers the threat as well as walking back would;
## - `point_free`: a control point nobody else stands on and no walker of its
##   side has claimed this turn -- true for a walker standing on one, so a
##   holder sees its own point as free to keep.
##
## The cells behind the facts -- the prey, the point, the intruder -- are kept
## too, so a deed carries out what the fact said and not a second guess.
##
## Complexity: per walker, one flood for its walks and one for the way to
## their workshop; where each enemy walker could strike is flooded once a turn
## and handed in.
##
## When not to use it: as a judgement. A fact is a threshold, not a weight;
## the level that weighs the odds is T12's `LeveledBlue`.
class_name TeamFacts
extends RefCounted

## How near its workshop an enemy walker is a threat to it -- T12's guard
## radius, the same board's idea of "at home".
const HOME_RADIUS: int = 4
## How much further off it must be for home to count as clear again.
const CALM_MARGIN: int = 2
## How near home a walker must be to answer a threat there: about two turns
## of a shield's walk.
const ANSWER_RADIUS: int = 7
## A walker with this much health or less is wounded: half a fresh one's.
const WOUNDED_AT: int = 5

## The facts, by name.
var facts: Dictionary = {}
## The enemy piece `prey_in_reach` is about, and the cell it is struck from.
var prey: Unit
var prey_from: Vector2i
## The point `point_free` is about.
var point: Vector2i = Vector2i(-1, -1)
## The enemy walker nearest its workshop, when home is threatened.
var intruder: Unit
## The walks it has this turn, as `TacticalReach.walks_for` gives them.
var walks: Dictionary = {}


## The facts for `unit` on `state`. `strikes` is enemy id -> the cells it
## could strike next turn; `claimed` the points other walkers of its side took
## this turn; `workshop_reached` whether a route reaches their workshop.
static func of(state: BoardState, unit: Unit, strikes: Dictionary, claimed: Dictionary,
		workshop_reached: bool) -> TeamFacts:
	var known := TeamFacts.new()
	known.walks = TacticalReach.walks_for(state, unit)
	known._read_home(state, unit)
	known._read_prey(state, unit)
	known._read_point(state, unit, claimed)
	var danger: bool = _in_danger(state, unit, strikes)
	known.facts["at_their_workshop"] = _at_their_workshop(state, unit)
	known.facts["way_to_their_workshop"] = workshop_reached
	known.facts["in_danger"] = danger
	known.facts["wounded"] = unit.health <= WOUNDED_AT
	known.facts["prey_is_intruder"] = known.prey != null and known.intruder != null and known.prey.id == known.intruder.id
	return known


# Home: the enemy walker nearest its workshop, and whether it is near enough
# to be a threat -- and this walker near enough to answer.
func _read_home(state: BoardState, unit: Unit) -> void:
	var home: Unit = own_workshop(state, unit.faction)
	var nearest: int = 1 << 30
	for enemy: Unit in state.units:
		if enemy.faction == unit.faction or not enemy.type.mobile or home == null:
			continue
		var apart: int = TacticalCombat.distance(enemy.cell, home.cell)
		if apart < nearest:
			nearest = apart
			intruder = enemy
	var answering: bool = home != null and TacticalCombat.distance(unit.cell, home.cell) <= ANSWER_RADIUS
	facts["home_threatened"] = nearest <= HOME_RADIUS and answering
	facts["home_clear"] = nearest > HOME_RADIUS + CALM_MARGIN


# Prey: the weakest piece it beats that a walk this turn -- or standing --
# brings into reach, and the first cell found it can be struck from: where it
# stands, when it can.
func _read_prey(state: BoardState, unit: Unit) -> void:
	var places: Array = [unit.cell] + walks.keys()
	for enemy: Unit in state.units:
		if enemy.faction == unit.faction or not enemy.type.type_name in unit.type.strong_against:
			continue
		if prey != null and enemy.health >= prey.health:
			continue
		var from: Vector2i = _striking_place(places, enemy, unit.type.attack_range)
		if from.x >= 0:
			prey = enemy
			prey_from = from
	facts["prey_in_reach"] = prey != null


# The first of `places` within `reach` of `enemy`, or (-1, -1).
static func _striking_place(places: Array, enemy: Unit, reach: int) -> Vector2i:
	for cell: Vector2i in places:
		if TacticalCombat.distance(cell, enemy.cell) <= reach:
			return cell
	return Vector2i(-1, -1)


# Point: the nearest control point nobody else of its side stands on or has
# claimed this turn.
func _read_point(state: BoardState, unit: Unit, claimed: Dictionary) -> void:
	for candidate: Vector2i in TacticalScenario.POINTS:
		var standing: Unit = state.unit_at(candidate)
		# A point anyone else stands on is not free: one of ours holds it, and
		# an enemy on it cannot be walked onto -- only struck, which is a hunt.
		var someone_else: bool = standing != null and standing.id != unit.id
		if someone_else or claimed.get(candidate, 0) > 0:
			continue
		if point.x < 0 or TacticalCombat.distance(unit.cell, candidate) < TacticalCombat.distance(unit.cell, point):
			point = candidate
	facts["point_free"] = point.x >= 0


# True when a living enemy that beats `unit` could strike its cell next turn.
static func _in_danger(state: BoardState, unit: Unit, strikes: Dictionary) -> bool:
	for enemy_id: int in strikes:
		var enemy: Unit = state.unit_by_id(enemy_id)
		if enemy != null and unit.type.type_name in enemy.type.strong_against and strikes[enemy_id].has(unit.cell):
			return true
	return false


static func _at_their_workshop(state: BoardState, unit: Unit) -> bool:
	for enemy: Unit in state.units:
		var theirs: bool = enemy.faction != unit.faction and enemy.type.type_name == TacticalRules.WORKSHOP
		if theirs and TacticalCombat.distance(unit.cell, enemy.cell) <= unit.type.attack_range:
			return true
	return false


## The workshop of `side`, or null once it has fallen.
static func own_workshop(state: BoardState, side: int) -> Unit:
	for unit: Unit in state.units_of(side):
		if unit.type.type_name == TacticalRules.WORKSHOP:
			return unit
	return null


## Enemy id -> every cell that piece could strike on its next turn, for each
## enemy piece that attacks at all: `ThreatMap.strikes`, kept by piece so a
## fact can ask whether the one that beats it is among them.
static func enemy_strikes(state: BoardState) -> Dictionary:
	var found: Dictionary = {}
	for enemy: Unit in state.units:
		if enemy.faction == state.current_faction or enemy.type.attack_range <= 0:
			continue
		var cells: Dictionary = {}
		for cell: Vector2i in ThreatMap.strikes(state, enemy):
			cells[cell] = true
		found[enemy.id] = cells
	return found
