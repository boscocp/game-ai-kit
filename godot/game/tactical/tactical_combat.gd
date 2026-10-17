## A fight on the tactical board: who may attack whom, and how it goes.
##
## The fight is the one the learned opponent's data was made of, rule for rule
## (ADR 0008): rounds of dice, the attacker swinging first, until one side has
## nothing left. The defender's cover adds to what it returns, numbers near
## the fight add to whoever has them, a friend a few cells off joins in once
## the fight has lasted that long, and -- new here -- the counter table adds
## to every blow of the side that is strong against the other. Every number
## is read from `combat_rules.json`, a byte-for-byte copy of
## `spec/combat/rules.json`, which the Python dataset reads too (ADR 0007).
##
## `fight` is a pure function of the dice it is handed, and that is how the
## two languages are held to one fight: their generators differ, so the
## vectors in `spec/vectors/combat/` hand both the same rolls.
##
## The loser is removed and the winner keeps what it has left -- except that a
## building is not fought to the death. An attack on one is a **siege**: one
## blow from the attacker and, if the building can reach back, one in return,
## and both stay standing unless that blow finished one of them. A workshop
## that fell to the first attack made every game a three-round race. The
## dataset has no buildings, so the siege is the game's alone and has no
## vector; the fight between walkers is the one both languages share. A side hits
## back only from within its own reach, so a mortar firing from three cells
## takes nothing back from a shield that reaches one -- the cycle `TacticalRules`
## describes, where the mortar outranges the shield.
##
## Complexity: a fight is O(rounds), at most the two healths added up.
##
## When not to use it: a game where a fight should wound both sides and leave
## them standing. Here every attack kills somebody, which is quick to read and
## keeps the dataset free of near-copies; it is also why a building, which
## cannot hit back, falls to any attack that reaches it.
class_name TacticalCombat
extends RefCounted

const RULES_PATH: String = "res://game/tactical/combat_rules.json"

## The reinforcement distance of a unit with no friend that can come: further
## than any fight lasts, so nobody arrives.
const NOBODY_COMING: int = 1 << 20

static var _rules: Dictionary = {}


## The shared rules, read once.
static func rules() -> Dictionary:
	if _rules.is_empty():
		_rules = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))
	return _rules


## Fight it out with the dice `roll` hands over, one call per blow, and say
## who won and what each side kept. `inputs` holds the two healths,
## `numeric_advantage`, `defender_terrain`, `reinforcement_distance`,
## `counter` (+1 the attacker is strong against the defender, -1 the other
## way) and `defender_hits_back`. The same function as Python's
## `combat.fight`, line for line.
static func fight(inputs: Dictionary, roll: Callable) -> Dictionary:
	var attacker_left: int = inputs["attacker_health"]
	var defender_left: int = inputs["defender_health"]
	var round_number: int = 1
	while true:
		defender_left -= _attacker_blow(inputs, round_number, roll)
		if defender_left <= 0:
			return {"attacker_won": true, "attacker_left": attacker_left, "defender_left": 0}
		if inputs["defender_hits_back"]:
			attacker_left -= _defender_blow(inputs, roll)
		if attacker_left <= 0:
			return {"attacker_won": false, "attacker_left": 0, "defender_left": defender_left}
		round_number += 1
	return {}


## One exchange against a building, with the dice `roll` hands over: the
## attacker's blow, then the building's, if it hits back and still stands.
## Same inputs and same blows as `fight`, one round of them.
static func siege(inputs: Dictionary, roll: Callable) -> Dictionary:
	var defender_left: int = inputs["defender_health"] - _attacker_blow(inputs, 1, roll)
	var attacker_left: int = inputs["attacker_health"]
	if defender_left > 0 and inputs["defender_hits_back"]:
		attacker_left -= _defender_blow(inputs, roll)
	return {"attacker_won": defender_left <= 0, "attacker_left": maxi(attacker_left, 0), "defender_left": maxi(defender_left, 0)}


## Why this attack cannot be made, or `BoardState.LEGAL`. In the order a
## player wants to hear it: who is attacking, whose turn it is, whether it
## can attack at all, whom, and whether it reaches.
static func why_refused(state: BoardState, attack: Attack) -> String:
	var attacker: Unit = state.unit_by_id(attack.attacker_id)
	var target: Unit = state.unit_by_id(attack.target_id)
	if attacker == null:
		return "no unit %d is on the board" % attack.attacker_id
	if attacker.faction != state.current_faction:
		return "it is not the %s's side's turn" % attacker.type.type_name
	if attacker.type.attack_range <= 0:
		return "a %s cannot attack" % attacker.type.type_name
	if not attacker.type.mobile:
		return "a %s fires by itself, at the start of its side's turn" % attacker.type.type_name
	if target == null:
		return "no unit %d is on the board to attack" % attack.target_id
	if target.faction == attacker.faction:
		return "the %s at %s is on the same side" % [target.type.type_name, target.cell]
	var apart: int = distance(attacker.cell, target.cell)
	if apart > attacker.type.attack_range:
		return "%s's %s at %s is %d away, and a %s reaches %d" % [TacticalStatus.side_name(target.faction),
			target.type.type_name, target.cell, apart, attacker.type.type_name, attacker.type.attack_range]
	return BoardState.LEGAL


## The state after this attack, or null when it is refused. The dice come from
## `state.dice_seed`, and the next state carries a new one, so the same state
## and attack always give the same fight. The attacker has no movement left
## afterwards: attacking ends what a unit does that turn.
static func apply(state: BoardState, attack: Attack) -> BoardState:
	if why_refused(state, attack) != BoardState.LEGAL:
		return null
	return _resolve(state, attack)


# The fight itself, on an attack already judged legal -- or a tower's shot,
# which no player orders and `why_refused` therefore turns away.
static func _resolve(state: BoardState, attack: Attack) -> BoardState:
	var dice := RandomNumberGenerator.new()
	dice.seed = state.dice_seed
	var before: Dictionary = inputs(state, state.unit_by_id(attack.attacker_id), state.unit_by_id(attack.target_id))
	var roll: Callable = _roller(dice)
	var at_a_building: bool = not state.unit_by_id(attack.target_id).type.mobile
	var outcome: Dictionary = siege(before, roll) if at_a_building else fight(before, roll)
	var next: BoardState = state.duplicate_state()
	var attacker: Unit = next.unit_by_id(attack.attacker_id)
	attacker.health = outcome["attacker_left"]
	attacker.movement_points = 0
	next.unit_by_id(attack.target_id).health = outcome["defender_left"]
	next.dice_seed = dice.randi()
	# Built again so the dead are dropped, as the constructor drops them.
	var settled: BoardState = next.duplicate_state()
	return settled


## The state after the side to move's towers have fired, and one line for
## each shot, as `[BoardState, Array[String]]`. Called at the start of a
## side's turn, before it does anything: a tower fires on its own side's
## turn, so the other side walked past it knowing it would, and sees the
## shot before it has to answer it. Each tower fires once, at the weakest
## enemy walker in its reach, ties to the lower id.
static func towers_fire(state: BoardState) -> Array:
	var said: Array[String] = []
	for tower: Unit in state.units_of(state.current_faction):
		if tower.type.mobile or tower.type.attack_range <= 0 or state.unit_by_id(tower.id) == null:
			continue
		var target: Unit = _weakest_walker_in_reach(state, tower)
		if target == null:
			continue
		var after: BoardState = _resolve(state, Attack.new(tower.id, target.id))
		said.append(told(state, Attack.new(tower.id, target.id), after))
		state = after
	return [state, said]


## One line saying what an attack did: who attacked whom, who is left
## standing, and with how much.
static func told(before: BoardState, attack: Attack, after: BoardState) -> String:
	var attacker: Unit = before.unit_by_id(attack.attacker_id)
	var target: Unit = before.unit_by_id(attack.target_id)
	var who: String = "%s %s at %s" % [TacticalStatus.side_name(attacker.faction), attacker.type.type_name, attacker.cell]
	var whom: String = "%s %s at %s" % [TacticalStatus.side_name(target.faction), target.type.type_name, target.cell]
	var survivor: Unit = after.unit_by_id(attacker.id)
	var struck: Unit = after.unit_by_id(target.id)
	if survivor != null and struck != null:
		return "the %s struck the %s, which has %d health left (the attacker %d)" % [
			who, whom, struck.health, survivor.health]
	if survivor != null:
		return "the %s destroyed the %s, and has %d health left" % [who, whom, survivor.health]
	return "the %s attacked the %s and was destroyed; it has %d health left" % [who, whom, struck.health]


static func _weakest_walker_in_reach(state: BoardState, tower: Unit) -> Unit:
	var weakest: Unit = null
	for enemy: Unit in state.units:
		if enemy.faction == tower.faction or not enemy.type.mobile:
			continue
		if distance(enemy.cell, tower.cell) <= tower.type.attack_range and (weakest == null or enemy.health < weakest.health):
			weakest = enemy
	return weakest


## The fight's inputs, read off the board: the same four numbers the learned
## model sees, plus what the game adds -- the counter table and who can hit
## back. Only units that can move count as near or as coming: a tower beside
## a fight does not join it.
static func inputs(state: BoardState, attacker: Unit, defender: Unit) -> Dictionary:
	var radius: int = rules()["nearby_radius"]
	return {
		"attacker_health": attacker.health,
		"defender_health": defender.health,
		"numeric_advantage": _near(state, attacker, defender.cell, radius) - _near(state, defender, attacker.cell, radius),
		"defender_terrain": maxi(state.graph_for(defender).cost_at(defender.cell), GridGraph.DEFAULT_COST),
		"reinforcement_distance": _nearest_friend(state, attacker),
		"counter": counter(attacker.type, defender.type),
		"defender_hits_back": defender.type.attack_range >= distance(attacker.cell, defender.cell),
	}


## +1 when `attacker` is strong against `defender` by the counter table, -1
## the other way round, 0 for neither or both.
static func counter(attacker: UnitType, defender: UnitType) -> int:
	var for_attacker: int = 1 if defender.type_name in attacker.strong_against else 0
	var for_defender: int = 1 if attacker.type_name in defender.strong_against else 0
	return for_attacker - for_defender


## Manhattan distance, which is how far an attack reaches on this grid.
static func distance(one: Vector2i, other: Vector2i) -> int:
	return absi(one.x - other.x) + absi(one.y - other.y)


static func _attacker_blow(inputs: Dictionary, round_number: int, roll: Callable) -> int:
	var worth: Dictionary = rules()
	var blow: int = roll.call()
	if inputs["numeric_advantage"] > 0:
		blow += inputs["numeric_advantage"] * int(worth["numbers_worth"])
	if round_number > inputs["reinforcement_distance"]:
		blow += int(worth["numbers_worth"])
	if inputs["counter"] > 0:
		blow += int(worth["counter_worth"])
	return blow


static func _defender_blow(inputs: Dictionary, roll: Callable) -> int:
	var worth: Dictionary = rules()
	var blow: int = roll.call()
	if inputs["numeric_advantage"] < 0:
		blow += -inputs["numeric_advantage"] * int(worth["numbers_worth"])
	if inputs["counter"] < 0:
		blow += int(worth["counter_worth"])
	return blow + (inputs["defender_terrain"] - 1) * int(worth["terrain_worth"])


static func _roller(dice: RandomNumberGenerator) -> Callable:
	var lowest: int = rules()["die"]["lowest"]
	var highest: int = rules()["die"]["highest"]
	return func() -> int: return dice.randi_range(lowest, highest)


# How many of `unit`'s other walking units stand within `radius` of `cell`.
static func _near(state: BoardState, unit: Unit, cell: Vector2i, radius: int) -> int:
	var count: int = 0
	for other: Unit in state.units_of(unit.faction):
		if other.id != unit.id and other.type.mobile and distance(other.cell, cell) <= radius:
			count += 1
	return count


# How far `unit`'s nearest other walking unit is, or `NOBODY_COMING`.
static func _nearest_friend(state: BoardState, unit: Unit) -> int:
	var nearest: int = NOBODY_COMING
	for other: Unit in state.units_of(unit.faction):
		if other.id != unit.id and other.type.mobile:
			nearest = mini(nearest, distance(other.cell, unit.cell))
	return nearest
